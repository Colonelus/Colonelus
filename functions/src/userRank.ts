
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const updateUserRank = functions
.region("europe-west1")
.firestore.document("users/{uid}")
.onUpdate(async (change, context) => {

  const after = change.after.data();

  const secrets = after.secretCount || 0;
  const catches = after.catchCount || 0;

  const score = secrets * 5 + catches * 2;

  let rank = "Yeni";

  if (score > 500) rank = "Orakel";
  else if (score > 200) rank = "Gölge";
  else if (score > 100) rank = "Sırdaş";
  else if (score > 30) rank = "Dinleyici";

  await change.after.ref.update({
    rank: rank
  });

});
