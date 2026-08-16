const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

initializeApp();

const titles = {
  follow: "새 팔로우",
  basket: "살까말까",
  review: "친구 리뷰",
  list: "리스트 공개",
};

exports.pushOnInbox = onDocumentCreated(
  "users/{userId}/notifications/{notifId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const notif = snap.data() || {};
    const type = notif.type || "follow";
    if (type === "review" || type === "list") return;
    const userId = event.params.userId;
    const user = await getFirestore().doc(`users/${userId}`).get();
    const tokens = (user.get("fcmTokens") || []).filter(
      (t) => typeof t === "string" && t.length > 0,
    );
    if (!tokens.length) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: titles[type] || "wishkit",
        body: notif.message || "새 알림이 있어요",
      },
      data: {
        type: String(type),
        relatedId: String(notif.relatedId || ""),
        notificationId: String(notif.id || event.params.notifId),
      },
      android: {
        priority: "high",
        notification: { channelId: "wishkit_social" },
      },
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
    });

    const stale = [];
    response.responses.forEach((result, i) => {
      if (
        !result.success &&
        result.error &&
        result.error.code === "messaging/registration-token-not-registered"
      ) {
        stale.push(tokens[i]);
      }
    });
    if (stale.length) {
      await user.ref.update({
        fcmTokens: FieldValue.arrayRemove(...stale),
      });
    }
  },
);

/// Deletes hosted 살까말까 HTML pages whose 28-day expiry has passed.
exports.cleanupExpiredSharePages = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const db = getFirestore();
    const bucket = getStorage().bucket();
    const now = Timestamp.now();
    let deleted = 0;

    while (deleted < 2000) {
      const snap = await db
        .collection("sharePages")
        .where("expiresAt", "<=", now)
        .limit(100)
        .get();
      if (snap.empty) break;

      for (const doc of snap.docs) {
        const path = doc.get("storagePath");
        if (typeof path === "string" && path.startsWith("share-pages/")) {
          try {
            await bucket.file(path).delete();
          } catch (err) {
            if (err && err.code !== 404) {
              console.error("share page delete failed", path, err);
            }
          }
        }
        await doc.ref.delete();
        deleted += 1;
      }
    }

    console.log(`cleanupExpiredSharePages removed ${deleted} pages`);
  },
);
