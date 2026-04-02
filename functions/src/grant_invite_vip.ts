import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const grantInviteVip = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated','auth');

  const db = admin.firestore();
  const now = Date.now();
  const vipUntil = now + 3 * 24 * 60 * 60 * 1000;

  await db.collection('users').doc(uid).set({
    vip: true,
    vipUntil: vipUntil
  }, { merge: true });

  return { ok: true };
});
