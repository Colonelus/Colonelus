import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const createInviteLink = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated','auth');
  const code = uid.substring(0,6) + Math.floor(Math.random()*9999).toString();
  const db = admin.firestore();
  await db.collection('invites').doc(code).set({
    owner: uid,
    createdAt: Date.now()
  });
  return {code: code};
});

export const claimInvite = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const code = data.code;
  if (!uid) throw new functions.https.HttpsError('unauthenticated','auth');
  const db = admin.firestore();
  const ref = await db.collection('invites').doc(code).get();
  if (!ref.exists) return {ok:false};
  const owner = ref.data()?.owner;
  if (!owner) return {ok:false};
  const now = Date.now();
  const vipUntil = now + 3 * 24 * 60 * 60 * 1000;
  await db.collection('users').doc(owner).set({vip:true,vipUntil:vipUntil},{merge:true});
  await db.collection('users').doc(uid).set({vip:true,vipUntil:vipUntil},{merge:true});
  return {ok:true};
});
