
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const notifySecretCaught = functions
.region("europe-west1")
.firestore.document("secrets/{secretId}/catches/{catchId}")
.onCreate(async (snap, context) => {

  const data = snap.data();
  const ownerUid = data.ownerUid;

  if (!ownerUid) return;

  const userSnap = await db.collection("users").doc(ownerUid).get();
  const user = userSnap.data();

  const token = user?.fcmToken;
  if (!token) return;

  await admin.messaging().send({
    token: token,
    notification: {
      title: "Sırın yakalandı",
      body: "Birisi sırrını yakaladı."
    },
    data: {
      type: "secret_catch"
    }
  });

});
