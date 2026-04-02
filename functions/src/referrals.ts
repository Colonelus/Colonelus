import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function normalizeCode(input: string): string {
  return input.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function randomCode(length = 8): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return out;
}

async function getReferralConfig() {
  const snap = await db.collection('growth_config').doc('referrals').get();
  const data = snap.data() || {};
  return {
    enabled: data.enabled !== false,
    inviterBonusCatches: Number(data.inviterBonusCatches ?? 3),
    inviteeBonusCatches: Number(data.inviteeBonusCatches ?? 2),
  };
}

async function generateUniqueInviteCode(): Promise<string> {
  for (let i = 0; i < 20; i += 1) {
    const code = randomCode(8);
    const existing = await db.collection('users').where('inviteCode', '==', code).limit(1).get();
    if (existing.empty) {
      return code;
    }
  }
  throw new HttpsError('internal', 'invite-code-generation-failed');
}

export const ensureInviteCode = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'authentication-required');
  }

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const data = userSnap.data() || {};
  const existing = String(data.inviteCode || '').trim().toUpperCase();

  if (existing) {
    return { inviteCode: existing };
  }

  const inviteCode = await generateUniqueInviteCode();

  await userRef.set(
    {
      inviteCode,
      growth: {
        referrals: {
          invitedCount: Number(data?.growth?.referrals?.invitedCount ?? 0),
          qualifiedInvites: Number(data?.growth?.referrals?.qualifiedInvites ?? 0),
        },
      },
    },
    { merge: true },
  );

  return { inviteCode };
});

export const bindReferralCode = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'authentication-required');
  }

  const code = normalizeCode(String(request.data?.code || ''));
  if (!code) {
    throw new HttpsError('invalid-argument', 'invalid-referral-code');
  }

  const config = await getReferralConfig();
  if (!config.enabled) {
    throw new HttpsError('failed-precondition', 'referrals-disabled');
  }

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError('failed-precondition', 'user-document-not-found');
  }

  const userData = userSnap.data() || {};
  const ownCode = normalizeCode(String(userData.inviteCode || ''));
  if (ownCode && ownCode === code) {
    throw new HttpsError('failed-precondition', 'self-referral-not-allowed');
  }

  if (userData.referredByUid || userData.referredByCode) {
    throw new HttpsError('failed-precondition', 'referral-already-bound');
  }

  const inviterQuery = await db.collection('users').where('inviteCode', '==', code).limit(1).get();
  if (inviterQuery.empty) {
    throw new HttpsError('not-found', 'referral-code-not-found');
  }

  const inviterDoc = inviterQuery.docs[0];
  const inviterUid = inviterDoc.id;
  if (inviterUid === uid) {
    throw new HttpsError('failed-precondition', 'self-referral-not-allowed');
  }

  const referralRef = db.collection('referrals').doc(`${inviterUid}_${uid}`);
  const now = Timestamp.now();

  await db.runTransaction(async (tx) => {
    const freshUser = await tx.get(userRef);
    const freshReferral = await tx.get(referralRef);
    const freshUserData = freshUser.data() || {};

    if (freshUserData.referredByUid || freshUserData.referredByCode) {
      throw new HttpsError('failed-precondition', 'referral-already-bound');
    }

    tx.set(
      userRef,
      {
        referredByUid: inviterUid,
        referredByCode: code,
        referredAt: now,
      },
      { merge: true },
    );

    if (!freshReferral.exists) {
      tx.set(referralRef, {
        inviterUid,
        inviteeUid: uid,
        inviteCode: code,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      });
      tx.set(
        db.collection('users').doc(inviterUid),
        {
          growth: {
            referrals: {
              invitedCount: FieldValue.increment(1),
            },
          },
        },
        { merge: true },
      );
    }
  });

  return { ok: true, inviterUid };
});

export const markReferralQualified = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'authentication-required');
  }

  const config = await getReferralConfig();
  if (!config.enabled) {
    throw new HttpsError('failed-precondition', 'referrals-disabled');
  }

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};
  const inviterUid = String(userData.referredByUid || '').trim();
  const inviteCode = normalizeCode(String(userData.referredByCode || ''));

  if (!inviterUid || !inviteCode) {
    return { ok: true, skipped: true, reason: 'no-referral' };
  }

  const referralRef = db.collection('referrals').doc(`${inviterUid}_${uid}`);
  const inviterRef = db.collection('users').doc(inviterUid);
  const rewardRef = db.collection('referral_rewards').doc(`${inviterUid}_${uid}`);
  const now = Timestamp.now();

  await db.runTransaction(async (tx) => {
    const [referralSnap, rewardSnap] = await Promise.all([
      tx.get(referralRef),
      tx.get(rewardRef),
    ]);

    if (!referralSnap.exists) {
      tx.set(referralRef, {
        inviterUid,
        inviteeUid: uid,
        inviteCode,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      }, { merge: true });
    }

    if (rewardSnap.exists) {
      return;
    }

    tx.set(referralRef, {
      status: 'rewarded',
      qualifiedAt: now,
      rewardedAt: now,
      updatedAt: now,
    }, { merge: true });

    tx.set(rewardRef, {
      inviterUid,
      inviteeUid: uid,
      inviterBonusCatches: config.inviterBonusCatches,
      inviteeBonusCatches: config.inviteeBonusCatches,
      createdAt: now,
    });

    tx.set(inviterRef, {
      entitlements: {
        referralBonusCatches: FieldValue.increment(config.inviterBonusCatches),
      },
      growth: {
        referrals: {
          qualifiedInvites: FieldValue.increment(1),
        },
      },
    }, { merge: true });

    tx.set(userRef, {
      entitlements: {
        referralBonusCatches: FieldValue.increment(config.inviteeBonusCatches),
      },
      growth: {
        referrals: {
          qualifiedAsInvitee: true,
        },
      },
    }, { merge: true });
  });

  return {
    ok: true,
    inviterBonusCatches: config.inviterBonusCatches,
    inviteeBonusCatches: config.inviteeBonusCatches,
  };
});

export const getReferralSummary = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'authentication-required');
  }

  const userSnap = await db.collection('users').doc(uid).get();
  const userData = userSnap.data() || {};
  const referralsSnap = await db.collection('referrals').where('inviterUid', '==', uid).get();

  const pending = referralsSnap.docs.filter((d) => (d.data().status || 'pending') === 'pending').length;
  const qualified = referralsSnap.docs.filter((d) => ['qualified', 'rewarded'].includes(String(d.data().status || ''))).length;

  return {
    inviteCode: String(userData.inviteCode || ''),
    invitedCount: referralsSnap.size,
    pendingCount: pending,
    qualifiedCount: qualified,
    bonusCatches: Number(userData?.entitlements?.referralBonusCatches ?? 0),
  };
});
