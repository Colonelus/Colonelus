const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.adminAuthLookup = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth gerekli");
  const callerUid = context.auth.uid;
  const callerSnap = await admin.firestore().collection("admins").doc(callerUid).get();
  if (!callerSnap.exists) throw new functions.https.HttpsError("permission-denied", "Admin değil");
  const uid = (data && data.uid) || "";
  if (!uid) throw new functions.https.HttpsError("invalid-argument", "UID gerekli");
  let user;
  try {
    user = await admin.auth().getUser(uid);
  } catch (e) {
    throw new functions.https.HttpsError("not-found", "Kullanıcı bulunamadı");
  }
  const result = {
    uid: user.uid,
    email: user.email || null,
    phoneNumber: user.phoneNumber || null,
    disabled: !!user.disabled,
    creationTime: user.metadata && user.metadata.creationTime ? user.metadata.creationTime : null,
    lastSignInTime: user.metadata && user.metadata.lastSignInTime ? user.metadata.lastSignInTime : null,
    providerData: (user.providerData || []).map(p => ({
      providerId: p.providerId,
      uid: p.uid,
      email: p.email || null,
      phoneNumber: p.phoneNumber || null
    }))
  };
  await admin.firestore().collection("admin_audit_logs").add({
    action: "auth_lookup",
    targetUid: uid,
    requestedBy: callerUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  return result;
});

exports.revenueCatWebhook = functions.region('europe-west1').https.onRequest(async (req, res) => {
  const secret = "YOUR_REVENUECAT_WEBHOOK_AUTH_TOKEN";
  if (req.headers['authorization'] !== `Bearer ${secret}`) {
    return res.status(401).send('Unauthorized');
  }

  const event = req.body.event;
  if (!event) return res.sendStatus(400);

  const uid = event.app_user_id;
  if (!uid) return res.sendStatus(400);

  const userRef = admin.firestore().collection('users').doc(uid);
  const expirationDate = event.expiration_at_ms 
    ? admin.firestore.Timestamp.fromMillis(event.expiration_at_ms) 
    : null;

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
});

