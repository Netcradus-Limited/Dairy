const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// Agent commission rate applied to the order subtotal. Must stay in sync with
// OrderService.agentEarningRate (0.10) in the Flutter app.
const AGENT_EARNING_RATE = 0.10;

/**
 * Core business logic for processing an earning record upon order delivery.
 * Verifies the transition, agent authorization, calculates 10% commission,
 * and writes the earning document atomically inside a Firestore transaction.
 *
 * @param {FirebaseFirestore.Firestore} db - Firestore database instance
 * @param {object|null} beforeData - Order document data before update
 * @param {object|null} afterData - Order document data after update
 * @param {string} orderId - Document ID of the order
 * @returns {Promise<{status: string, reason?: string, amountEarned?: number, agentId?: string, orderId?: string}>}
 */
async function processOrderDeliveredEarning(db, beforeData, afterData, orderId) {
  if (!afterData) {
    console.warn(`Order ${orderId} has no post-update data; skipping.`);
    return { status: "skipped", reason: "no_after_data" };
  }

  const beforeStatus = (beforeData && beforeData.status ? String(beforeData.status) : "").toLowerCase();
  const afterStatus = (afterData && afterData.status ? String(afterData.status) : "").toLowerCase();

  // Only act on a transition INTO "delivered".
  // Skip if status did not change, or if target status is not delivered.
  if (beforeStatus === afterStatus || afterStatus !== "delivered") {
    return { status: "skipped", reason: "not_delivered_transition" };
  }

  console.log(
    `[Debug] processOrderDeliveredEarning - orderId: ${orderId}, keys: [${Object.keys(afterData).join(", ")}], assignedAgentId: "${afterData.assignedAgentId}", status: "${afterData.status}"`
  );

  const rawAgentId =
    afterData.assignedAgentId ||
    afterData.assigned_agent_id ||
    afterData.agentId ||
    afterData.deliveryAgentId;

  if (rawAgentId == null || String(rawAgentId).trim() === "") {
    console.log(
      `Order ${orderId} delivered with no valid assignedAgentId; skipping earnings.`
    );
    return { status: "skipped", reason: "missing_assigned_agent" };
  }

  const cleanAgentId = String(rawAgentId).trim();

  // Verify the agent exists and has delivery privileges (in users or delivery_agents)
  const userSnap = await db.collection("users").doc(cleanAgentId).get();
  let isAuthorizedAgent = false;

  if (userSnap.exists) {
    const userData = userSnap.data();
    const userRole = userData && userData.role ? String(userData.role).toLowerCase().trim() : "";
    if (["delivery", "admin", "delivery_agent", "driver"].includes(userRole)) {
      isAuthorizedAgent = true;
    }
  } else {
    const agentSnap = await db.collection("delivery_agents").doc(cleanAgentId).get();
    if (agentSnap.exists) {
      isAuthorizedAgent = true;
    }
  }

  if (!isAuthorizedAgent) {
    console.warn(
      `Assigned agent ${cleanAgentId} is not a valid delivery agent; skipping earnings.`
    );
    return { status: "skipped", reason: "invalid_delivery_agent" };
  }

  const rawSubtotal = afterData.subtotal != null
    ? Number(afterData.subtotal)
    : (afterData.totalAmount != null ? Number(afterData.totalAmount) : 0);

  if (isNaN(rawSubtotal) || rawSubtotal < 0) {
    console.warn(`Invalid subtotal for order ${orderId}; skipping earnings.`);
    return { status: "skipped", reason: "invalid_subtotal" };
  }

  const deliveryFee = Number(afterData.deliveryCharge) || 0;
  // Calculate 10% commission on subtotal with 2 decimal precision
  const amountEarned = Math.round((rawSubtotal * AGENT_EARNING_RATE) * 100) / 100;

  const earningRef = db.collection("earnings").doc(orderId);
  let resultStatus = "created";

  // Atomically check and write in a Firestore transaction to prevent duplicate records
  await db.runTransaction(async (transaction) => {
    const existingDoc = await transaction.get(earningRef);
    if (existingDoc.exists) {
      console.log(
        `Earning record already exists for order ${orderId}; skipping duplicate creation.`
      );
      resultStatus = "skipped_duplicate";
      return;
    }

    transaction.set(earningRef, {
      id: orderId,
      orderId: orderId,
      agentId: cleanAgentId,
      amountEarned: amountEarned,
      tipAmount: 0.0,
      deliveryFee: deliveryFee,
      status: "pending",
      timestamp: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  if (resultStatus === "created") {
    console.log(
      `Successfully logged earning for order ${orderId} (agent ${cleanAgentId}): ₹${amountEarned}`
    );
  }

  return {
    status: resultStatus,
    amountEarned,
    agentId: cleanAgentId,
    orderId,
  };
}

/**
 * Triggered whenever an order in Firestore is updated.
 * When status transitions to "delivered", creates a secure, idempotent earning.
 */
exports.logEarningOnDelivered = onDocumentUpdated(
  {
    region: "asia-south2",
    document: "orders/{orderId}",
  },
  async (event) => {
    if (!event.data || !event.data.after) {
      console.warn("No document data found in event; skipping.");
      return;
    }

    const before = event.data.before ? event.data.before.data() : null;
    const after = event.data.after.data();
    const orderId = event.params.orderId;

    const db = getFirestore();
    await processOrderDeliveredEarning(db, before, after, orderId);
  }
);

exports.processOrderDeliveredEarning = processOrderDeliveredEarning;
exports.AGENT_EARNING_RATE = AGENT_EARNING_RATE;

/**
 * Core business logic for sending an FCM push notification when a notification
 * document is created under users/{userId}/notifications/{notifId}.
 * Fetches the user's FCM registration tokens, formats high-priority Android & iOS
 * notification payloads, dispatches them via FCM, and prunes stale/invalid tokens.
 *
 * @param {FirebaseFirestore.Firestore} db - Firestore database instance
 * @param {import("firebase-admin/messaging").Messaging} messaging - Firebase Messaging instance
 * @param {object|null} notifData - Document data from users/{userId}/notifications/{notifId}
 * @param {string} userId - User UID
 * @param {string} notifId - Notification document ID
 * @returns {Promise<{status: string, reason?: string, successCount?: number, failureCount?: number}>}
 */
async function processSendPushNotification(db, messaging, notifData, userId, notifId) {
  if (!notifData) {
    console.warn(`[FCM Push] Notification ${notifId} has no data; skipping.`);
    return { status: "skipped", reason: "no_data" };
  }

  if (!userId || String(userId).trim() === "") {
    console.warn(`[FCM Push] Notification ${notifId} has no target userId; skipping.`);
    return { status: "skipped", reason: "missing_user_id" };
  }

  // Retrieve user's registration tokens from Firestore profile
  const userSnap = await db.collection("users").doc(userId).get();
  if (!userSnap.exists) {
    console.warn(`[FCM Push] Target user ${userId} does not exist; skipping.`);
    return { status: "skipped", reason: "user_not_found" };
  }

  const userData = userSnap.data() || {};
  let tokens = [];

  if (Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
    tokens = userData.fcmTokens.filter((t) => typeof t === "string" && t.trim().length > 0);
  } else if (typeof userData.fcmToken === "string" && userData.fcmToken.trim().length > 0) {
    tokens = [userData.fcmToken.trim()];
  }

  // Deduplicate tokens
  tokens = [...new Set(tokens)];

  if (tokens.length === 0) {
    console.log(`[FCM Push] User ${userId} has no registered FCM tokens; skipping push.`);
    return { status: "skipped", reason: "no_fcm_tokens" };
  }

  const title = notifData.title || "Sawariya Dairy";
  const body = notifData.body || "";
  const orderId = notifData.orderId ? String(notifData.orderId) : (notifData.order_id ? String(notifData.order_id) : "");
  const assignedAgentId = notifData.assignedAgentId ? String(notifData.assignedAgentId) : (notifData.assigned_agent_id ? String(notifData.assigned_agent_id) : "");
  const route = notifData.route ? String(notifData.route) : (orderId ? `/orders/${orderId}` : "/notifications");
  const type = notifData.type ? String(notifData.type) : "system";
  const isActionable = notifData.isActionable ? "true" : "false";

  let successCount = 0;
  let failureCount = 0;
  const staleTokens = [];

  for (const token of tokens) {
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        notificationId: String(notifId),
        userId: String(userId),
        orderId: orderId,
        order_id: orderId,
        assignedAgentId: assignedAgentId,
        route: route,
        type: type,
        isActionable: isActionable,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "order_alerts",
          icon: "ic_launcher",
          sound: "default",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await messaging.send(message);
      successCount++;
    } catch (err) {
      failureCount++;
      console.warn(`[FCM Push] Failed to deliver push to token (${token.substring(0, 8)}...): ${err.message}`);
      if (
        err.code === "messaging/invalid-registration-token" ||
        err.code === "messaging/registration-token-not-registered"
      ) {
        staleTokens.push(token);
      }
    }
  }

  // Prune invalid/stale tokens from user profile
  if (staleTokens.length > 0) {
    try {
      await db.collection("users").doc(userId).update({
        fcmTokens: FieldValue.arrayRemove(...staleTokens),
      });
      console.log(`[FCM Push] Pruned ${staleTokens.length} stale tokens for user ${userId}.`);
    } catch (cleanupErr) {
      console.warn(`[FCM Push] Error pruning stale tokens: ${cleanupErr.message}`);
    }
  }

  console.log(
    `[FCM Push] Finished dispatching notification ${notifId} to user ${userId} (Sent: ${successCount}, Failed: ${failureCount})`
  );

  return {
    status: "sent",
    successCount,
    failureCount,
  };
}

/**
 * Triggered whenever a notification is added to users/{userId}/notifications/{notifId}.
 * Sends an immediate high-priority push notification to all devices registered for that user.
 */
exports.sendPushNotificationOnNewDoc = onDocumentCreated(
  {
    region: "asia-south2",
    document: "users/{userId}/notifications/{notifId}",
  },
  async (event) => {
    if (!event.data) {
      console.warn("No document data found in notification event; skipping.");
      return;
    }

    const notifData = event.data.data();
    const userId = event.params.userId;
    const notifId = event.params.notifId;

    const db = getFirestore();
    const messaging = getMessaging();
    await processSendPushNotification(db, messaging, notifData, userId, notifId);
  }
);

exports.processSendPushNotification = processSendPushNotification;
