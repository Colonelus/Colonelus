
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const claimDailyReward = functions
.region("europe-west1")
.https.onCall(async (data, context) => {

  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated","login required");
  }

  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  const user = snap.data() || {};

  const now = Date.now();
  const last = user.lastDailyReward || 0;

  const diff = now - last;

  if (diff < 86400000) {
    return { ok:false };
  }

  const coins = (user.coins || 0) + 20;

  await ref.update({
    coins: coins,
    lastDailyReward: now
  });

  return {
    ok:true,
    coins:coins
  };

});
