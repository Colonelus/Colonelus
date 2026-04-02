
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const assignSecretRarity = functions
.region("europe-west1")
.firestore.document("secrets/{secretId}")
.onCreate(async (snap, context) => {

  const r = Math.random();

  let rarity = "common";

  if (r < 0.02) rarity = "legendary";
  else if (r < 0.07) rarity = "epic";
  else if (r < 0.20) rarity = "rare";

  await snap.ref.update({
    rarity: rarity
  });

});
