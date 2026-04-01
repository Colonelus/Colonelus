import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'unauthenticated');
  }
  return uid;
}

type CatchRequest = {
  secretId: string;
};

type PassRequest = {
  secretId: string;
};

export const catchSecret = functions.region('europe-west1').https.onCall(
  async (data: CatchRequest, context: functions.https.CallableContext) => {
    const uid = requireAuth(context);
    const secretId = data.secretId;

    if (!secretId || typeof secretId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');
    }

    const secretRef = db.collection('secrets').doc(secretId);
    const caughtRef = db.collection('users').doc(uid).collection('caughtSecrets').doc(secretId);
    const passedRef = db.collection('users').doc(uid).collection('passedSecrets').doc(secretId);

    await db.runTransaction(async (tx) => {
      const [secretSnap, caughtSnap, passedSnap] = await Promise.all([
        tx.get(secretRef),
        tx.get(caughtRef),
        tx.get(passedRef),
      ]);

      if (!secretSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'not-found');
      }

      if (caughtSnap.exists || passedSnap.exists) {
        return;
      }

      const catchCount = (secretSnap.get('catchCount') || 0) + 1;

      tx.update(secretRef, {
        catchCount,
      });

      tx.set(caughtRef, {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { ok: true };
  }
);

export const passSecret = functions.region('europe-west1').https.onCall(
  async (data: PassRequest, context: functions.https.CallableContext) => {
    const uid = requireAuth(context);
    const secretId = data.secretId;

    if (!secretId || typeof secretId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'invalid-argument');
    }

    const secretRef = db.collection('secrets').doc(secretId);
    const passedRef = db.collection('users').doc(uid).collection('passedSecrets').doc(secretId);
    const caughtRef = db.collection('users').doc(uid).collection('caughtSecrets').doc(secretId);

    await db.runTransaction(async (tx) => {
      const [secretSnap, passedSnap, caughtSnap] = await Promise.all([
        tx.get(secretRef),
        tx.get(passedRef),
        tx.get(caughtRef),
      ]);

      if (!secretSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'not-found');
      }

      if (passedSnap.exists || caughtSnap.exists) {
        return;
      }

      const passCount = (secretSnap.get('passCount') || 0) + 1;

      tx.update(secretRef, {
        passCount,
      });

      tx.set(passedRef, {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { ok: true };
  }
);
