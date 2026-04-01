import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const grantSignupVip = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();
  const now = Date.now();
  const vipUntil = now + 14 * 24 * 60 * 60 * 1000;

  await db.collection('users').doc(user.uid).set({
    vip: true,
    vipUntil: vipUntil,
    coins: 0,
    createdAt: now
  }, { merge: true });
});
