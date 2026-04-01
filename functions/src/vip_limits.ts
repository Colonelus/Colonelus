import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

const ADMIN_UID = 's9Vo2O5FnKZ7grNN3kRu7DUsN222';

const STANDARD_SECRET_SHARE_LIMIT = 1;
const STANDARD_SECRET_CATCH_LIMIT = 3;
const VIP_SECRET_SHARE_LIMIT = 5;
const VIP_SECRET_CATCH_LIMIT = 20;

type LimitAction = 'share_secret' | 'catch_secret';

type LimitConfig = {
  action: LimitAction;
};

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'unauthenticated');
  }
  return uid;
}

function isAdminUid(uid: string): boolean {
  return uid === ADMIN_UID;
}

async function getUserPlan(uid: string) {
  if (isAdminUid(uid)) {
    return {
      isAdmin: true,
      isVip: true,
      isUnlimited: true,
      vipUntilMs: 0,
      shareLimit: Number.MAX_SAFE_INTEGER,
      catchLimit: Number.MAX_SAFE_INTEGER,
    };
  }

  const snap = await db.collection('users').doc(uid).get();
  const data = snap.data() || {};
  const vipUntilRaw = data.vipUntil;
  let vipUntilMs = 0;

  if (vipUntilRaw?.toMillis) {
    vipUntilMs = vipUntilRaw.toMillis();
  } else if (typeof vipUntilRaw === 'string') {
    const parsed = Date.parse(vipUntilRaw);
    vipUntilMs = Number.isNaN(parsed) ? 0 : parsed;
  }

  const isVip = data.isVip === true && vipUntilMs > Date.now();

  return {
    isAdmin: false,
    isVip,
    isUnlimited: false,
    vipUntilMs,
    shareLimit: isVip ? VIP_SECRET_SHARE_LIMIT : STANDARD_SECRET_SHARE_LIMIT,
    catchLimit: isVip ? VIP_SECRET_CATCH_LIMIT : STANDARD_SECRET_CATCH_LIMIT,
  };
}

async function countRecentEvents(uid: string, action: LimitAction) {
  const since = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('limitEvents')
    .where('action', '==', action)
    .where('createdAt', '>=', since)
    .get();

  let resetAtMs = 0;
  for (const doc of snap.docs) {
    const createdAt = doc.get('createdAt');
    const createdMs =
      createdAt?.toMillis?.() ??
      (typeof createdAt === 'string' ? Date.parse(createdAt) : 0);
    if (createdMs > 0) {
      const candidate = createdMs + 24 * 60 * 60 * 1000;
      if (candidate > resetAtMs) resetAtMs = candidate;
    }
  }

  return {
    used: snap.size,
    resetAtMs,
  };
}

async function buildLimitState(uid: string) {
  const plan = await getUserPlan(uid);
  const [share, catcher] = await Promise.all([
    countRecentEvents(uid, 'share_secret'),
    countRecentEvents(uid, 'catch_secret'),
  ]);

  if (plan.isUnlimited) {
    return {
      ok: true,
      isAdmin: true,
      isVip: true,
      isUnlimited: true,
      vipUntil: null,
      limits: {
        shareSecret: {
          limit: null,
          used: share.used,
          remaining: null,
          resetAt: null,
        },
        catchSecret: {
          limit: null,
          used: catcher.used,
          remaining: null,
          resetAt: null,
        },
      },
    };
  }

  return {
    ok: true,
    isAdmin: false,
    isVip: plan.isVip,
    isUnlimited: false,
    vipUntil: plan.vipUntilMs > 0 ? new Date(plan.vipUntilMs).toISOString() : null,
    limits: {
      shareSecret: {
        limit: plan.shareLimit,
        used: share.used,
        remaining: Math.max(0, plan.shareLimit - share.used),
        resetAt: share.resetAtMs > 0 ? new Date(share.resetAtMs).toISOString() : null,
      },
      catchSecret: {
        limit: plan.catchLimit,
        used: catcher.used,
        remaining: Math.max(0, plan.catchLimit - catcher.used),
        resetAt: catcher.resetAtMs > 0 ? new Date(catcher.resetAtMs).toISOString() : null,
      },
    },
  };
}

async function consume(uid: string, config: LimitConfig) {
  const plan = await getUserPlan(uid);

  if (plan.isUnlimited) {
    const nextState = await buildLimitState(uid);
    return {
      ok: true,
      consumedAction: config.action,
      isAdmin: true,
      isVip: true,
      isUnlimited: true,
      limits: nextState.limits,
    };
  }

  const current = await countRecentEvents(uid, config.action);
  const limit = config.action === 'share_secret' ? plan.shareLimit : plan.catchLimit;
  const remaining = Math.max(0, limit - current.used);

  if (remaining <= 0) {
    throw new functions.https.HttpsError('resource-exhausted', 'limit-exceeded');
  }

  await db
    .collection('users')
    .doc(uid)
    .collection('limitEvents')
    .add({
      action: config.action,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  const nextState = await buildLimitState(uid);

  return {
    ok: true,
    consumedAction: config.action,
    isAdmin: false,
    isVip: nextState.isVip,
    isUnlimited: nextState.isUnlimited,
    limits: nextState.limits,
  };
}

export const getMyLimits = functions.region('europe-west1').https.onCall(
  async (_data: unknown, context: functions.https.CallableContext) => {
    const uid = requireAuth(context);
    return buildLimitState(uid);
  }
);

export const consumeShareSecret = functions.region('europe-west1').https.onCall(
  async (_data: unknown, context: functions.https.CallableContext) => {
    const uid = requireAuth(context);
    return consume(uid, { action: 'share_secret' });
  }
);

export const consumeCatchSecret = functions.region('europe-west1').https.onCall(
  async (_data: unknown, context: functions.https.CallableContext) => {
    const uid = requireAuth(context);
    return consume(uid, { action: 'catch_secret' });
  }
);
