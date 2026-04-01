import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const getShadowFeed = functions
  .region("europe-west1")
  .https.onCall(async (_data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError("unauthenticated", "login required");
    }

    const snap = await db.collection("secrets").limit(200).get();
    const now = Date.now();

    const items = snap.docs
      .map((d) => {
        const s: any = d.data();

        if ((s.authorId || "") === uid) return null;
        if (s.banned === true) return null;
        if (s.expiresAt?.toMillis?.() && s.expiresAt.toMillis() <= now) return null;

        const catchCount = s.catchCount || 0;
        const replyCount = s.replyCount || 0;
        const reportCount = s.reportCount || 0;
        const createdAt = s.createdAt?.toMillis?.() || now;
        const ageHours = (now - createdAt) / 3600000;
        const freshness = Math.max(0, 24 - ageHours);

        const score = catchCount * 3 + replyCount * 4 + freshness - reportCount * 10;

        return {
          id: d.id,
          score,
          ...s,
        };
      })
      .filter(Boolean) as any[];

    items.sort((a, b) => b.score - a.score);

    const feed = [];

    for (let i = 0; i < items.length; i++) {
      const item = items[i];

      const showChance =
        item.score > 50 ? 1 :
        item.score > 20 ? 0.6 :
        0.25;

      if (Math.random() < showChance) {
        feed.push(item);
      }

      if (feed.length >= 50) break;
    }

    return { items: feed };
  });
