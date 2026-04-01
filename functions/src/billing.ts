import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { google } from 'googleapis';

const db = admin.firestore();

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'unauthenticated');
  }
  return uid;
}

function env(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new functions.https.HttpsError('failed-precondition', 'missing-env-' + name.toLowerCase());
  }
  return value;
}

function getAndroidPublisher() {
  const clientEmail = env('GOOGLE_PLAY_CLIENT_EMAIL');
  const privateKey = env('GOOGLE_PLAY_PRIVATE_KEY').replace(/\\n/g, '\n');

  const auth = new google.auth.JWT({
    email: clientEmail,
    key: privateKey,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  return google.androidpublisher({
    version: 'v3',
    auth,
  });
}

export const verifyAndroidSubscription = functions.region('europe-west1').https.onCall(
  async (data: { purchaseToken?: string; packageName?: string }, context: functions.https.CallableContext) => {
    const uid = requireAuth(context);
    const purchaseToken = typeof data?.purchaseToken === 'string' ? data.purchaseToken.trim() : '';
    const packageName = typeof data?.packageName === 'string' ? data.packageName.trim() : '';

    if (!purchaseToken || !packageName) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');
    }

    const publisher = getAndroidPublisher();

    const purchase = await publisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken,
    });

    const body = purchase.data;
    const state = body.subscriptionState || '';
    const lineItem = body.lineItems?.[0];

    if (!lineItem || !lineItem.expiryTime) {
      throw new functions.https.HttpsError('failed-precondition', 'missing-expiry');
    }

    if (
      state !== 'SUBSCRIPTION_STATE_ACTIVE' &&
      state !== 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' &&
      state !== 'SUBSCRIPTION_STATE_CANCELED'
    ) {
      throw new functions.https.HttpsError('failed-precondition', 'subscription-not-active');
    }

    const expiryMs = Date.parse(lineItem.expiryTime);
    if (Number.isNaN(expiryMs)) {
      throw new functions.https.HttpsError('failed-precondition', 'invalid-expiry');
    }

    const basePlanId = lineItem.offerDetails?.basePlanId || '';
    const productId = lineItem.productId || 'sirdas_vip';
    const purchaseRef = db.collection('billingPurchases').doc(purchaseToken);
    const userRef = db.collection('users').doc(uid);

    await db.runTransaction(async (tx) => {
      tx.set(
        purchaseRef,
        {
          uid,
          productId,
          basePlanId,
          purchaseToken,
          packageName,
          subscriptionState: state,
          latestOrderId: body.latestOrderId || null,
          expiryTime: admin.firestore.Timestamp.fromMillis(expiryMs),
          acknowledged: body.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        userRef,
        {
          isVip: true,
          vipPlan: basePlanId || productId,
          vipUntil: admin.firestore.Timestamp.fromMillis(expiryMs),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    return {
      ok: true,
      productId,
      basePlanId,
      vipUntil: new Date(expiryMs).toISOString(),
    };
  }
);
