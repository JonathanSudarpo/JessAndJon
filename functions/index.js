const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function: Send push notification when new content is created
 *
 * This function triggers automatically when a new document is created in the
 * 'content' collection. It sends a push notification to the partner's device
 * to update their widget instantly.
 */
exports.sendContentNotification = onDocumentCreated(
    "content/{contentId}",
    async (event) => {
      const snap = event.data;
      const contentId = event.params.contentId;
      if (!snap) {
        console.log("No data in snapshot");
        return null;
      }

      const content = snap.data();
      const senderId = content.senderId;

      console.log(`New content created: ${contentId} from sender: ${senderId}`);

      // Get sender's user data to find partner
      const senderDoc = await admin.firestore()
          .collection("users").doc(senderId).get();

      if (!senderDoc.exists) {
        console.log(`Sender document not found: ${senderId}`);
        return null;
      }

      const senderData = senderDoc.data();
      const partnerId = senderData.partnerId;

      if (!partnerId) {
        console.log(`No partner found for sender: ${senderId}`);
        return null;
      }

      // Get partner's FCM token
      const partnerDoc = await admin.firestore()
          .collection("users").doc(partnerId).get();

      if (!partnerDoc.exists) {
        console.log(`Partner document not found: ${partnerId}`);
        return null;
      }

      const partnerData = partnerDoc.data();
      const fcmToken = partnerData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token found for partner: ${partnerId}`);
        return null;
      }

      // Prepare notification content based on content type
      const senderName = senderData.name || "Your partner";
      const notificationTitle = `New content from ${senderName}`;
      let notificationBody = "";

      switch (content.contentType) {
        case "photo":
          notificationBody = content.caption || "Sent a photo 📸";
          break;
        case "note":
          notificationBody = content.noteText || "Sent a note 💌";
          break;
        case "drawing":
          notificationBody = "Sent a drawing ✏️";
          break;
        case "status":
          notificationBody = content.statusText || "Updated status";
          break;
        default:
          notificationBody = "New update!";
      }

      // Prepare notification payload
      const message = {
        token: fcmToken,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          contentType: content.contentType || "",
          contentId: contentId,
          senderId: senderId,
          senderName: senderData.name || "",
          // Trigger widget update
          widgetUpdate: "true",
          // Include content data for widget
          timestamp: content.timestamp ?
            content.timestamp.toMillis().toString() :
            Date.now().toString(),
        },
        apns: {
          payload: {
            aps: {
              "content-available": 1, // Background update for widget
              "mutable-content": 1,
              "sound": "default",
              "badge": 1,
            },
          },
          headers: {
            "apns-priority": "10", // High priority for instant delivery
          },
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "lovance_notifications",
          },
        },
      };

      // Add optional content fields to data payload
      if (content.caption) {
        message.data.caption = content.caption;
      }
      if (content.noteText) {
        message.data.noteText = content.noteText;
      }
      if (content.statusText) {
        message.data.statusText = content.statusText;
      }
      if (content.statusEmoji) {
        message.data.statusEmoji = content.statusEmoji;
      }
      if (content.imageUrl) {
        message.data.imageUrl = content.imageUrl;
      }

      try {
        // Send notification
        const response = await admin.messaging().send(message);
        console.log(`✅ Successfully sent notification to partner ` +
            `${partnerId}: ${response}`);
        return response;
      } catch (error) {
        console.error(`❌ Error sending notification to partner ` +
            `${partnerId}:`, error);
        // Don't throw - we don't want to fail the content creation
        // if notification fails
        return null;
      }
    });

/**
 * Cloud Function: Clean up old FCM tokens
 *
 * This function runs daily to remove stale FCM tokens that haven't been
 * updated in 30 days.
 */
exports.cleanupOldFCMTokens = onSchedule(
    {schedule: "every 24 hours", timeZone: "UTC"},
    async (event) => {
      const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
      );

      const usersRef = admin.firestore().collection("users");
      const snapshot = await usersRef
          .where("fcmTokenUpdatedAt", "<", thirtyDaysAgo)
          .get();

      const batch = admin.firestore().batch();
      let count = 0;

      snapshot.forEach((doc) => {
        batch.update(doc.ref, {
          fcmToken: admin.firestore.FieldValue.delete(),
          fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
        });
        count++;
      });

      if (count > 0) {
        await batch.commit();
        console.log(`Cleaned up ${count} old FCM tokens`);
      }

      return null;
    });
