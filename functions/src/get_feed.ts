import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

type FeedRequest = {
  limit?: number;
};

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'unauthenticated');
  }
  return uid;
}

function freshnessScore(createdAt: admin.firestore.Timestamp) {
  const hours = (Date.now() - createdAt.toMillis()) / 3600000;
  if (hours < 1) return 30;
  if (hours < 6) return 20;
  if (hours < 24) return 10;
  return 2;
}

function distanceScore(km: number) {
  if (km < 5) return 20;
  if (km < 20) return 10;
  if (km < 100) return 5;
  return 1;
}

function qualityScore(catchCount: number, impressions: number) {
  if (impressions <= 0) return 3;
  const rate = catchCount / impressions;
  if (rate > 0.4) return 20;
  if (rate > 0.2) return 10;
  return 3;
}

function riskPenalty(reportCount: number) {
  if (reportCount >= 3) return -30;
  if (reportCount >= 1) return -10;
  return 0;
}

function spamPenalty(catchCount: number, impressions: number) {
  if (impressions > 50 && catchCount === 0) return -25;
  return 0;
}

export const getFeed = functions.region('europe-west1').https.onCall(
  async (data: FeedRequest, context: functions.https.CallableContext) => {
    const uid = requireAuth(context);
    const limit = Math.max(1, Math.min(data?.limit ?? 20, 50));

    const userSnap = await db.collection('users').doc(uid).get();
    const user = userSnap.data() || {};
    const userLat = typeof user.lat === 'number' ? user.lat : 0;
    const userLng = typeof user.lng === 'number' ? user.lng : 0;

    const now = admin.firestore.Timestamp.now();
    const poolSnap = await db.collection('secrets').limit(200).get();

    const results: any[] = [];

    for (const doc of poolSnap.docs) {
      const s = doc.data();

      if (s.banned === true) continue;
      if ((s.reportCount || 0) >= 5) continue;

      const expiresAt = s.expiresAt as admin.firestore.Timestamp | undefined;
      if (expiresAt && expiresAt.toMillis() <= now.toMillis()) continue;

      const createdAt =
        (s.createdAt as admin.firestore.Timestamp | undefined) ||
        admin.firestore.Timestamp.now();

      const freshness = freshnessScore(createdAt);

      const lat = typeof s.lat === 'number' ? s.lat : userLat;
      const lng = typeof s.lng === 'number' ? s.lng : userLng;

      const dx = userLat - lat;
      const dy = userLng - lng;
      const km = Math.sqrt(dx * dx + dy * dy) * 111;

      const distance = distanceScore(km);
      const quality = qualityScore(s.catchCount || 0, s.impressions || 0);
      const risk = riskPenalty(s.reportCount || 0);
      const spam = spamPenalty(s.catchCount || 0, s.impressions || 0);

      const score = freshness + distance + quality + risk + spam;

      results.push({
        id: doc.id,
        score,
        ...s,
      });
    }

    results.sort((a, b) => b.score - a.score);

    return {
      ok: true,
      secrets: results.slice(0, limit),
    };
  }
);
