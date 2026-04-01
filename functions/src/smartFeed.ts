
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const getSmartFeed = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {

    const snap = await db
      .collection("secrets")
      .where("active", "==", true)
      .limit(200)
      .get();

    const now = Date.now();

    const items = snap.docs.map((d) => {
      const s = d.data();

      const catchCount = s.catchCount ?? 0;
      const replyCount = s.replyCount ?? 0;
      const reportCount = s.reportCount ?? 0;
      const createdAt = s.createdAt?.toMillis?.() ?? now;

      const ageHours = (now - createdAt) / 3600000;

      const freshness = Math.max(0, 24 - ageHours);

      const score =
        catchCount * 3 +
        replyCount * 4 +
        freshness -
        reportCount * 10;

      return {
        id: d.id,
        score,
        ...s
      };
    });

    items.sort((a, b) => b.score - a.score);

    return {
      items: items.slice(0, 50)
    };
  });
