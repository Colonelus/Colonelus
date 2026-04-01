import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

function assertAdmin(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'unauthenticated');
  }
  if (uid !== 's9Vo2O5FnKZ7grNN3kRu7DUsN222') {
    throw new functions.https.HttpsError('permission-denied', 'permission-denied');
  }
  return uid;
}

type AdminGetUserData = {
  query?: string;
};

type AdminSetBanData = {
  uid?: string;
  bannedUntil?: string | null;
};

type AdminSetVipData = {
  uid?: string;
  isVip?: boolean;
  vipUntil?: string | null;
};

type AdminSetCoinsData = {
  uid?: string;
  coins?: number;
};

type AdminUserActionResult = {
  ok: true;
  uid: string;
};

export const adminGetUser = functions.region('europe-west1').https.onCall(
  async (data: AdminGetUserData, context: functions.https.CallableContext) => {
    assertAdmin(context);

    const rawQuery = typeof data?.query === 'string' ? data.query : '';
    const query = rawQuery.trim();

    if (!query) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');
    }

    const normalized = query.toLowerCase();
    const authCandidates = new Map<string, admin.auth.UserRecord>();
    const docCandidates = new Map<string, admin.firestore.DocumentSnapshot>();

    const addAuthCandidate = (user: admin.auth.UserRecord | null | undefined) => {
      if (user?.uid) authCandidates.set(user.uid, user);
    };

    const addDocCandidate = (doc: admin.firestore.DocumentSnapshot | null | undefined) => {
      if (doc?.exists) docCandidates.set(doc.id, doc);
    };

    try {
      const userByUid = await admin.auth().getUser(query);
      addAuthCandidate(userByUid);
    } catch {}

    if (query.includes('@')) {
      try {
        const userByEmail = await admin.auth().getUserByEmail(query);
        addAuthCandidate(userByEmail);
      } catch {}
    }

    const usersRef = db.collection('users');
    const directDoc = await usersRef.doc(query).get();
    addDocCandidate(directDoc);

    const emailSnap = await usersRef.where('email', '==', query).limit(10).get();
    emailSnap.docs.forEach(addDocCandidate);

    const usernameSnap = await usersRef.where('username', '==', query).limit(10).get();
    usernameSnap.docs.forEach(addDocCandidate);

    const displayNameExactSnap = await usersRef.where('displayName', '==', query).limit(10).get();
    displayNameExactSnap.docs.forEach(addDocCandidate);

    const nicknameExactSnap = await usersRef.where('nickname', '==', query).limit(10).get();
    nicknameExactSnap.docs.forEach(addDocCandidate);

    if (docCandidates.size === 0 && authCandidates.size === 0) {
      const prefixQueries = await Promise.all([
        usersRef.orderBy('displayName').startAt(query).endAt(query + '\uf8ff').limit(10).get().catch(() => null),
        usersRef.orderBy('username').startAt(query).endAt(query + '\uf8ff').limit(10).get().catch(() => null),
        usersRef.orderBy('nickname').startAt(query).endAt(query + '\uf8ff').limit(10).get().catch(() => null),
      ]);

      for (const snap of prefixQueries) {
        snap?.docs.forEach(addDocCandidate);
      }

      const loweredCandidates = Array.from(docCandidates.values()).filter((doc) => {
        const d = doc.data() || {};
        const email = typeof d.email === 'string' ? d.email.toLowerCase() : '';
        const displayName = typeof d.displayName === 'string' ? d.displayName.toLowerCase() : '';
        const username = typeof d.username === 'string' ? d.username.toLowerCase() : '';
        const nickname = typeof d.nickname === 'string' ? d.nickname.toLowerCase() : '';
        return (
          doc.id.toLowerCase().includes(normalized) ||
          email.includes(normalized) ||
          displayName.includes(normalized) ||
          username.includes(normalized) ||
          nickname.includes(normalized)
        );
      });

      docCandidates.clear();
      loweredCandidates.forEach(addDocCandidate);
    }

    const mergedUids = new Set<string>([
      ...Array.from(docCandidates.keys()),
      ...Array.from(authCandidates.keys()),
    ]);

    const result = [];

    for (const uid of mergedUids) {
      let authUser = authCandidates.get(uid) || null;
      if (!authUser) {
        try { authUser = await admin.auth().getUser(uid); } catch { authUser = null; }
      }

      let doc = docCandidates.get(uid) || null;
      if (!doc) {
        try {
          const fetched = await usersRef.doc(uid).get();
          if (fetched.exists) doc = fetched;
        } catch {}
      }

      const d = doc?.data() || {};
      const email = typeof d.email === 'string' ? d.email : authUser?.email || null;
      const displayName = typeof d.displayName === 'string' ? d.displayName : authUser?.displayName || null;

      result.push({
        uid,
        email,
        displayName,
        username: typeof d.username === 'string' ? d.username : null,
        nickname: typeof d.nickname === 'string' ? d.nickname : null,
        photoURL: typeof d.photoURL === 'string' ? d.photoURL : authUser?.photoURL || null,
        providerIds: authUser?.providerData?.map((p) => p.providerId) || [],
        disabled: authUser?.disabled ?? false,
        emailVerified: authUser?.emailVerified ?? false,
        createdAt: authUser?.metadata?.creationTime || null,
        lastSignInAt: authUser?.metadata?.lastSignInTime || null,
        bannedUntil: d.bannedUntil ?? null,
        isVip: d.isVip === true,
        vipUntil: d.vipUntil ?? null,
        coins: typeof d.coins === 'number' ? d.coins : 0,
        secretCount: typeof d.secretCount === 'number' ? d.secretCount : 0,
        reportCount: typeof d.reportCount === 'number' ? d.reportCount : 0,
        raw: d,
      });
    }

    result.sort((a, b) => {
      if (a.uid === query) return -1;
      if (b.uid === query) return 1;
      return 0;
    });

    return {
      ok: true,
      count: result.length,
      users: result.slice(0, 20),
    };
  }
);

export const adminSetBan = functions.region('europe-west1').https.onCall(
  async (data: AdminSetBanData, context: functions.https.CallableContext): Promise<AdminUserActionResult> => {
    assertAdmin(context);
    const uid = typeof data?.uid === 'string' ? data.uid.trim() : '';
    if (!uid) throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');

    const bannedUntilRaw = data?.bannedUntil;
    let bannedUntilValue: any = null;

    if (!bannedUntilRaw) {
      bannedUntilValue = admin.firestore.FieldValue.delete();
    } else {
      const ms = Date.parse(bannedUntilRaw);
      if (Number.isNaN(ms)) throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');
      bannedUntilValue = admin.firestore.Timestamp.fromDate(new Date(ms));
    }

    await db.collection('users').doc(uid).set({
      bannedUntil: bannedUntilValue,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, uid };
  }
);

export const adminSetVip = functions.region('europe-west1').https.onCall(
  async (data: AdminSetVipData, context: functions.https.CallableContext): Promise<AdminUserActionResult> => {
    assertAdmin(context);
    const uid = typeof data?.uid === 'string' ? data.uid.trim() : '';
    const isVip = data?.isVip === true;
    if (!uid) throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');

    const vipUntilRaw = data?.vipUntil;
    let vipUntilValue: any;

    if (!isVip || !vipUntilRaw) {
      vipUntilValue = admin.firestore.FieldValue.delete();
    } else {
      const ms = Date.parse(vipUntilRaw);
      if (Number.isNaN(ms)) throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');
      vipUntilValue = admin.firestore.Timestamp.fromDate(new Date(ms));
    }

    await db.collection('users').doc(uid).set({
      isVip,
      vipUntil: vipUntilValue,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, uid };
  }
);

export const adminSetCoins = functions.region('europe-west1').https.onCall(
  async (data: AdminSetCoinsData, context: functions.https.CallableContext): Promise<AdminUserActionResult> => {
    assertAdmin(context);
    const uid = typeof data?.uid === 'string' ? data.uid.trim() : '';
    const coins = typeof data?.coins === 'number' ? data.coins : NaN;
    if (!uid || !Number.isFinite(coins) || coins < 0) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');
    }

    await db.collection('users').doc(uid).set({
      coins: Math.floor(coins),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, uid };
  }
);

export const revenueCatWebhook = functions.region('europe-west1').https.onRequest(async (req, res) => {
  const secret = "SIRDAS_RC_2026_TOKEN";
  if (req.headers['authorization'] !== `Bearer ${secret}`) {
    res.status(401).send('Unauthorized');
    return;
  }
  const event = req.body.event || req.body;
  const uid = event.app_user_id;
  if (!uid) {
    res.sendStatus(400);
    return;
  }
  const userRef = db.collection('users').doc(uid);
  const expirationDate = event.expiration_at_ms ? admin.firestore.Timestamp.fromMillis(event.expiration_at_ms) : null;
  try {
    switch (event.type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'PRODUCT_CHANGE':
      case 'UNCANCELLATION':
      case 'SUBSCRIPTION_PAUSED':
        await userRef.set({
          isVip: true,
          vipUntil: expirationDate,
          revenueCatId: event.original_transaction_id || null
        }, { merge: true });
        break;
      case 'EXPIRATION':
      case 'REVOKE':
      case 'BILLING_ERROR':
        await userRef.set({
          isVip: false,
          vipUntil: expirationDate,
        }, { merge: true });
        break;
      case 'CANCELLATION':
        await userRef.set({
          autoRenewStatus: false
        }, { merge: true });
        break;
    }
    res.sendStatus(200);
  } catch (err: any) {
    res.status(500).send(err.message);
  }
});

export { getMyLimits, consumeShareSecret, consumeCatchSecret } from './vip_limits';
export { getFeed } from './get_feed';
export { catchSecret, passSecret } from './secret_interaction';
export {
  bindReferralCode,
  ensureInviteCode,
  getReferralSummary,
  markReferralQualified,
} from './referrals';
export { createSecretShareLink, resolveSecretShareLink, claimSecretShareAttribution, qualifySecretShareAttribution, secretShareEntry } from './viralLoop';
export * from './referral_functions';
export { getSmartFeed } from "./smartFeed";
export { assignSecretRarity } from "./rareSecret";
export { claimDailyReward } from "./dailyReward";
export { notifySecretCaught } from "./pushGrowth";
export { updateUserRank } from "./userRank";
export { getShadowFeed } from "./shadowFeed";