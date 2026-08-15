const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

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
    const userId = event.params.userId;
    const user = await getFirestore().doc(`users/${userId}`).get();
    const tokens = (user.get("fcmTokens") || []).filter(
      (t) => typeof t === "string" && t.length > 0,
    );
    if (!tokens.length) return;

    const type = notif.type || "follow";
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
