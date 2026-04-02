import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import * as functions from 'firebase-functions';

const db = admin.firestore();

function requireUid(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'auth-required');
  }
  return uid;
}

function normalizePreviewText(value: unknown): string {
  return String(value ?? '').trim().replace(/\s+/g, ' ').slice(0, 180);
}

function makeToken(): string {
  return crypto.randomBytes(9).toString('base64url');
}

async function getGrowthConfig() {
  const snap = await db.collection('growth_config').doc('viral_loop').get();
  const data = snap.data() || {};
  return {
    appBaseUrl: String(data.appBaseUrl || 'https://sirdas.app/invite'),
    webBaseUrl: String(data.webBaseUrl || 'https://sirdas.app/s'),
    rewardType: String(data.rewardType || 'bonus_catch'),
    ownerRewardValue: Number(data.ownerRewardValue || 3),
    guestRewardValue: Number(data.guestRewardValue || 2),
    maxClaimsPerOwnerPerDay: Number(data.maxClaimsPerOwnerPerDay || 25),
  };
}

async function ensureOwnerDailyLimit(ownerUid: string, maxClaimsPerOwnerPerDay: number) {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0));
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1, 0, 0, 0, 0));
  const snap = await db.collection('secret_share_claims')
    .where('ownerUid', '==', ownerUid)
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
    .where('createdAt', '<', admin.firestore.Timestamp.fromDate(end))
    .get();
  if (snap.size >= maxClaimsPerOwnerPerDay) {
    throw new functions.https.HttpsError('resource-exhausted', 'daily-owner-limit');
  }
}

export const createSecretShareLink = functions.https.onCall(async (data, context) => {
  const uid = requireUid(context);
  const secretId = String(data?.secretId || '').trim();
  const previewText = normalizePreviewText(data?.previewText);
  const source = String(data?.source || 'app').trim();
  if (!secretId) {
    throw new functions.https.HttpsError('invalid-argument', 'secretId-required');
  }
  if (!previewText) {
    throw new functions.https.HttpsError('invalid-argument', 'previewText-required');
  }

  const config = await getGrowthConfig();
  const token = makeToken();
  const now = admin.firestore.FieldValue.serverTimestamp();

  await db.collection('secret_share_links').doc(token).set({
    token,
    ownerUid: uid,
    secretId,
    previewText,
    source,
    status: 'active',
    claimedByUid: null,
    qualifiedByUid: null,
    createdAt: now,
    updatedAt: now,
  });

  await db.collection('growth_events').add({
    type: 'secret_share_link_created',
    token,
    ownerUid: uid,
    secretId,
    source,
    createdAt: now,
  });

  return {
    ok: true,
    token,
    url: `${config.webBaseUrl}?vt=${encodeURIComponent(token)}`,
  };
});

export const resolveSecretShareLink = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid || null;
  const token = String(data?.token || '').trim();
  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'token-required');
  }

  const snap = await db.collection('secret_share_links').doc(token).get();
  if (!snap.exists) {
    return { ok: false };
  }

  const item = snap.data()!;
  const ownerUid = String(item.ownerUid || '');
  const claimedByUid = item.claimedByUid ? String(item.claimedByUid) : '';

  return {
    ok: true,
    token,
    ownerUid,
    secretId: String(item.secretId || ''),
    previewText: String(item.previewText || ''),
    alreadyClaimed: claimedByUid.length > 0,
    ownerIsCurrentUser: uid !== null && uid === ownerUid,
  };
});

export const claimSecretShareAttribution = functions.https.onCall(async (data, context) => {
  const uid = requireUid(context);
  const token = String(data?.token || '').trim();
  const trigger = String(data?.trigger || 'manual_claim').trim();
  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'token-required');
  }

  const config = await getGrowthConfig();
  const ref = db.collection('secret_share_links').doc(token);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'token-not-found');
    }
    const item = snap.data()!;
    const ownerUid = String(item.ownerUid || '');
    const status = String(item.status || 'active');
    const claimedByUid = item.claimedByUid ? String(item.claimedByUid) : '';

    if (ownerUid === uid) {
      throw new functions.https.HttpsError('failed-precondition', 'self-claim-blocked');
    }
    if (status !== 'active' && status !== 'claimed') {
      throw new functions.https.HttpsError('failed-precondition', 'link-inactive');
    }
    if (claimedByUid && claimedByUid !== uid) {
      throw new functions.https.HttpsError('already-exists', 'already-claimed');
    }

    tx.set(db.collection('secret_share_claims').doc(`${token}_${uid}`), {
      token,
      ownerUid,
      guestUid: uid,
      secretId: String(item.secretId || ''),
      trigger,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.update(ref, {
      claimedByUid: uid,
      status: 'claimed',
      claimTrigger: trigger,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(db.collection('growth_events').doc(), {
      type: 'secret_share_claimed',
      token,
      ownerUid,
      guestUid: uid,
      secretId: String(item.secretId || ''),
      trigger,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await ensureOwnerDailyLimit((await ref.get()).data()!.ownerUid, config.maxClaimsPerOwnerPerDay);

  return { ok: true };
});

export const qualifySecretShareAttribution = functions.https.onCall(async (data, context) => {
  const uid = requireUid(context);
  const token = String(data?.token || '').trim();
  const trigger = String(data?.trigger || 'qualified_action').trim();
  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'token-required');
  }

  const config = await getGrowthConfig();
  const ref = db.collection('secret_share_links').doc(token);
  const rewardOwnerRef = db.collection('growth_rewards').doc(`owner_${token}`);
  const rewardGuestRef = db.collection('growth_rewards').doc(`guest_${token}`);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'token-not-found');
    }
    const item = snap.data()!;
    const ownerUid = String(item.ownerUid || '');
    const claimedByUid = item.claimedByUid ? String(item.claimedByUid) : '';
    const qualifiedByUid = item.qualifiedByUid ? String(item.qualifiedByUid) : '';

    if (!claimedByUid || claimedByUid !== uid) {
      throw new functions.https.HttpsError('failed-precondition', 'claim-required');
    }
    if (qualifiedByUid) {
      throw new functions.https.HttpsError('already-exists', 'already-qualified');
    }
    if (ownerUid === uid) {
      throw new functions.https.HttpsError('failed-precondition', 'self-qualify-blocked');
    }

    tx.set(rewardOwnerRef, {
      uid: ownerUid,
      token,
      rewardType: config.rewardType,
      rewardValue: config.ownerRewardValue,
      side: 'owner',
      status: 'granted',
      secretId: String(item.secretId || ''),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(rewardGuestRef, {
      uid,
      token,
      rewardType: config.rewardType,
      rewardValue: config.guestRewardValue,
      side: 'guest',
      status: 'granted',
      secretId: String(item.secretId || ''),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(db.collection('users').doc(ownerUid), {
      growthBalance: {
        bonusCatch: admin.firestore.FieldValue.increment(config.ownerRewardValue),
      },
    }, { merge: true });

    tx.set(db.collection('users').doc(uid), {
      growthBalance: {
        bonusCatch: admin.firestore.FieldValue.increment(config.guestRewardValue),
      },
    }, { merge: true });

    tx.update(ref, {
      qualifiedByUid: uid,
      qualifiedTrigger: trigger,
      status: 'qualified',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(db.collection('growth_events').doc(), {
      type: 'secret_share_qualified',
      token,
      ownerUid,
      guestUid: uid,
      secretId: String(item.secretId || ''),
      trigger,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {
    ok: true,
    ownerRewardType: config.rewardType,
    ownerRewardValue: config.ownerRewardValue,
    guestRewardType: config.rewardType,
    guestRewardValue: config.guestRewardValue,
  };
});

export const secretShareEntry = functions.https.onRequest(async (req, res) => {
  const token = String(req.query.vt || '').trim();
  const config = await getGrowthConfig();
  if (!token) {
    res.redirect(config.appBaseUrl);
    return;
  }
  const ref = db.collection('secret_share_links').doc(token);
  const snap = await ref.get();
  if (!snap.exists) {
    res.redirect(config.appBaseUrl);
    return;
  }
  const item = snap.data()!;
  await ref.set({
    openCount: admin.firestore.FieldValue.increment(1),
    lastOpenedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await db.collection('growth_events').add({
    type: 'secret_share_landing_opened',
    token,
    ownerUid: String(item.ownerUid || ''),
    secretId: String(item.secretId || ''),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    userAgent: String(req.get('user-agent') || ''),
    ip: String(req.ip || ''),
  });
  const previewText = String(item.previewText || 'Sırdaş');
  const appUrl = `${config.appBaseUrl}?vt=${encodeURIComponent(token)}`;
  res.status(200).send(`<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Sırdaş</title><meta property="og:title" content="Sırdaş"><meta property="og:description" content="${previewText.replace(/"/g, '&quot;')}"><meta http-equiv="refresh" content="0;url=${appUrl}"></head><body><script>window.location.replace(${JSON.stringify(appUrl)});</script></body></html>`);
});
