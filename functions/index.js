const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
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

/**
 * Core business logic for creating Admin notifications when a new customer complaint is filed.
 * Uses Firebase Admin SDK to query the `users` collection for valid Admin accounts
 * (roles: admin, owner, superadmin or isAdmin: true) and writes an idempotent notification document
 * under `users/{adminUid}/notifications/complaint_{complaintId}`.
 *
 * @param {FirebaseFirestore.Firestore} db - Firestore database instance
 * @param {object|null} complaintData - Document data from complaints/{complaintId}
 * @param {string} complaintId - Document ID of the complaint
 * @returns {Promise<{status: string, reason?: string, count?: number, adminUids?: string[], notificationId?: string}>}
 */
async function processComplaintCreatedNotification(db, complaintData, complaintId) {
  if (!complaintData) {
    console.warn(`[Complaint Notify] Complaint ${complaintId} has no data; skipping.`);
    return { status: "skipped", reason: "no_data" };
  }

  const cleanComplaintId = String(complaintId || "").trim();
  if (!cleanComplaintId) {
    console.warn("[Complaint Notify] Missing complaint ID; skipping.");
    return { status: "skipped", reason: "missing_complaint_id" };
  }

  // Discover genuine Admin accounts from the users collection by role / flag.
  // Note: Only genuine user document IDs (Firebase Auth UIDs) are collected.
  // Role strings like "owner" or "admin" are NEVER used as UIDs.
  const adminUids = new Set();
  const validAdminRoles = ["admin", "owner", "superadmin", "Admin", "ADMIN", "Owner", "Superadmin"];

  try {
    const roleSnap = await db.collection("users").where("role", "in", validAdminRoles).get();
    for (const doc of roleSnap.docs) {
      if (doc.id && doc.id.trim()) {
        adminUids.add(doc.id.trim());
      }
    }
  } catch (err) {
    console.warn(`[Complaint Notify] Error querying users by role: ${err.message}`);
  }

  try {
    const isAdminSnap = await db.collection("users").where("isAdmin", "==", true).get();
    for (const doc of isAdminSnap.docs) {
      if (doc.id && doc.id.trim()) {
        adminUids.add(doc.id.trim());
      }
    }
  } catch (err) {
    console.warn(`[Complaint Notify] Error querying users by isAdmin: ${err.message}`);
  }

  if (adminUids.size === 0) {
    console.warn(`[Complaint Notify] No admin accounts found in users collection for complaint ${cleanComplaintId}.`);
    return { status: "skipped", reason: "no_admins_found", count: 0, adminUids: [] };
  }

  const customerName = String(complaintData.customerName || "Customer").trim();
  const subject = String(complaintData.subject || "").trim();
  const description = String(complaintData.description || "").trim();
  const previewText = description || subject || "New support request";
  const body = `${customerName}: ${previewText}`;
  const category = String(complaintData.category || complaintData.issueType || "Support").trim();
  const ticketId = String(complaintData.ticketId || `CMP-${cleanComplaintId.substring(0, 6)}`).trim();
  const customerId = String(complaintData.customerId || complaintData.userId || "customer").trim();
  const orderId = complaintData.orderId ? String(complaintData.orderId).trim() : null;

  // Deterministic notification ID prevents duplicate notifications during Cloud Function retries
  const notifDocId = `complaint_${cleanComplaintId}`;
  const uidsList = Array.from(adminUids);
  let writeCount = 0;

  for (const adminUid of uidsList) {
    const notifRef = db.collection("users").doc(adminUid).collection("notifications").doc(notifDocId);

    const payload = {
      title: "New Customer Complaint",
      body: body,
      type: "support",
      timestamp: FieldValue.serverTimestamp(),
      isRead: false,
      isActionable: true,
      route: "/support",
      createdBy: customerId,
      userId: adminUid,
      metadata: {
        source: "complaint",
        complaintId: cleanComplaintId,
        ticketId: ticketId,
        category: category,
        customerId: customerId,
      },
    };

    if (orderId) {
      payload.orderId = orderId;
    }

    try {
      await notifRef.set(payload, { merge: true });
      writeCount++;
      console.log(`[Complaint Notify] Created admin notification at users/${adminUid}/notifications/${notifDocId}`);
    } catch (writeErr) {
      console.error(`[Complaint Notify] Failed to write notification for admin ${adminUid}: ${writeErr.message}`);
    }
  }

  return {
    status: "created",
    count: writeCount,
    adminUids: uidsList,
    notificationId: notifDocId,
  };
}

/**
 * Triggered whenever a new complaint document is created in complaints/{complaintId}.
 * Discovers active Admin users and creates an idempotent Admin notification under
 * users/{adminUid}/notifications/complaint_{complaintId}.
 */
exports.notifyAdminsOnComplaint = onDocumentCreated(
  {
    region: "asia-south2",
    document: "complaints/{complaintId}",
  },
  async (event) => {
    if (!event.data) {
      console.warn("No document data found in complaint event; skipping.");
      return;
    }

    const complaintData = event.data.data();
    const complaintId = event.params.complaintId;

    const db = getFirestore();
    await processComplaintCreatedNotification(db, complaintData, complaintId);
  }
);

exports.processComplaintCreatedNotification = processComplaintCreatedNotification;

/**
 * Core business logic for creating Admin notifications when a delivery event occurs
 * (agent accepts, declines, starts pickup, starts delivery, confirms delivery, or fails/cancels).
 * Uses Firebase Admin SDK to query the `users` collection for valid Admin accounts
 * (roles: admin, owner, superadmin or isAdmin: true) and writes idempotent notification documents
/**
 * Core business logic for creating Admin notifications when a delivery event occurs
 * (agent accepts, declines, starts pickup, starts delivery, confirms delivery, or fails/cancels).
 * Uses Firebase Admin SDK to query the `users` collection for valid Admin accounts
 * (roles: admin, owner, superadmin or isAdmin: true) and writes idempotent notification documents
 * under `users/{adminUid}/notifications/delivery_{orderId}_{eventType}`.
 *
 * @param {FirebaseFirestore.Firestore} db - Firestore database instance
 * @param {object|null} orderData - Document data from orders/{orderId} (after state)
 * @param {string} orderId - Document ID of the order
 * @param {string|object|null} previousStatusOrBefore - Status string or before data
 * @returns {Promise<{status: string, reason?: string, count?: number, adminUids?: string[], notificationId?: string}>}
 */
async function processDeliveryEventNotification(db, orderData, orderId, previousStatusOrBefore) {
  if (!orderData) {
    console.warn(`[Delivery Event Notify] Order ${orderId} has no data; skipping.`);
    return { status: "skipped", reason: "no_data" };
  }

  const cleanOrderId = String(orderId || "").trim();
  if (!cleanOrderId) {
    console.warn("[Delivery Event Notify] Missing order ID; skipping.");
    return { status: "skipped", reason: "missing_order_id" };
  }

  const previousData =
    typeof previousStatusOrBefore === "object" && previousStatusOrBefore !== null
      ? previousStatusOrBefore
      : null;
  const previousStatusRaw = previousData
    ? (previousData.status || "")
    : (previousStatusOrBefore || "");
  const previousStatusLower = String(previousStatusRaw).toLowerCase().trim();
  const newStatus = (orderData.status ? String(orderData.status) : "").toLowerCase().trim();

  // 1. Unrelated update check: skip if status did not change (e.g. notes, timestamps, GPS ticks)
  if (previousStatusLower && previousStatusLower === newStatus) {
    return { status: "skipped", reason: "status_not_changed" };
  }

  // 2. Extract assignedAgentId (with fallback to previous data for orderDeclined)
  const rawAgentId =
    orderData.assignedAgentId ||
    orderData.assigned_agent_id ||
    orderData.agentId ||
    orderData.deliveryAgentId ||
    (previousData && (
      previousData.assignedAgentId ||
      previousData.assigned_agent_id ||
      previousData.agentId ||
      previousData.deliveryAgentId
    ));

  if (!rawAgentId || String(rawAgentId).trim() === "") {
    console.warn(
      `[Delivery Event Notify] Order ${cleanOrderId} has no assignedAgentId; skipping admin notification.`
    );
    return { status: "skipped", reason: "no_assigned_agent" };
  }
  const assignedAgentId = String(rawAgentId).trim();

  // 3. Security verification: Verify the agent exists and has delivery privileges
  const userSnap = await db.collection("users").doc(assignedAgentId).get();
  let isAuthorizedAgent = false;

  if (userSnap.exists) {
    const userData = userSnap.data();
    const userRole = userData && userData.role ? String(userData.role).toLowerCase().trim() : "";
    if (["delivery", "admin", "owner", "superadmin", "delivery_agent", "driver"].includes(userRole)) {
      isAuthorizedAgent = true;
    }
  } else {
    const agentSnap = await db.collection("delivery_agents").doc(assignedAgentId).get();
    if (agentSnap.exists) {
      isAuthorizedAgent = true;
    }
  }

  if (!isAuthorizedAgent) {
    console.warn(
      `[Delivery Event Notify] Assigned agent ${assignedAgentId} is not a valid delivery agent; skipping.`
    );
    return { status: "skipped", reason: "invalid_delivery_agent" };
  }

  // 4. Determine and validate status transition for delivery events
  let eventType = null;

  // ACCEPT: Moves to 'accepted' (or 'confirmed' from pending/placed)
  if (
    newStatus === "accepted" ||
    (newStatus === "confirmed" && ["pending", "placed", ""].includes(previousStatusLower))
  ) {
    if (["pending", "placed", "confirmed", ""].includes(previousStatusLower)) {
      eventType = "orderAccepted";
    }
  }
  // DECLINE: Order released back to pending/placed from accepted, or explicit declined status
  else if (
    newStatus === "declined" ||
    (["accepted", "confirmed"].includes(previousStatusLower) && ["pending", "placed"].includes(newStatus))
  ) {
    eventType = "orderDeclined";
  }
  // PICKUP START: Moves to 'preparing' or 'pickup'
  else if (newStatus === "preparing" || newStatus === "pickup") {
    if (["accepted", "confirmed", "pending", "placed", ""].includes(previousStatusLower)) {
      eventType = "pickupStarted";
    }
  }
  // DELIVERY START: Moves to 'outfordelivery' or 'out for delivery'
  else if (newStatus === "outfordelivery" || newStatus === "out for delivery") {
    if (["preparing", "pickup", "accepted", "confirmed", ""].includes(previousStatusLower)) {
      eventType = "deliveryStarted";
    }
  }
  // DELIVERY CONFIRMED: Moves to 'delivered'
  else if (newStatus === "delivered") {
    if (["outfordelivery", "out for delivery", "preparing", "pickup", "accepted", "confirmed", ""].includes(previousStatusLower)) {
      eventType = "deliveryConfirmed";
    }
  }
  // DELIVERY FAILED / CANCELLED: Moves to 'cancelled' or 'failed'
  else if (newStatus === "cancelled" || newStatus === "failed") {
    if (["outfordelivery", "out for delivery", "preparing", "pickup", "accepted", "confirmed", ""].includes(previousStatusLower)) {
      eventType = "deliveryFailed";
    }
  }

  if (eventType == null) {
    console.log(
      `[Delivery Event Notify] Order ${cleanOrderId} status transition "${previousStatusLower}" -> "${newStatus}" is not a recognized delivery event; skipping.`
    );
    return { status: "skipped", reason: "not_a_delivery_event" };
  }

  // 5. Discover genuine Admin accounts from the users collection by role / flag.
  // Note: Only genuine user document IDs (Firebase Auth UIDs) are collected.
  // Role strings like "owner" or "admin" are NEVER used as UIDs.
  const adminUids = new Set();
  const validAdminRoles = ["admin", "owner", "superadmin", "Admin", "ADMIN", "Owner", "Superadmin"];

  try {
    const roleSnap = await db.collection("users").where("role", "in", validAdminRoles).get();
    for (const doc of roleSnap.docs) {
      if (doc.id && doc.id.trim()) {
        adminUids.add(doc.id.trim());
      }
    }
  } catch (err) {
    console.warn(`[Delivery Event Notify] Error querying users by role: ${err.message}`);
  }

  try {
    const isAdminSnap = await db.collection("users").where("isAdmin", "==", true).get();
    for (const doc of isAdminSnap.docs) {
      if (doc.id && doc.id.trim()) {
        adminUids.add(doc.id.trim());
      }
    }
  } catch (err) {
    console.warn(`[Delivery Event Notify] Error querying users by isAdmin: ${err.message}`);
  }

  if (adminUids.size === 0) {
    console.warn(`[Delivery Event Notify] No admin accounts found for delivery event on order ${cleanOrderId}.`);
    return { status: "skipped", reason: "no_admins_found", count: 0, adminUids: [] };
  }

  // 6. Build notification content specific to the delivery event
  const customerName = String(orderData.customerName || orderData.customer_name || "Customer").trim();
  const customerId = String(orderData.customerId || orderData.customer_id || "customer").trim();

  let title, body, route;

  switch (eventType) {
    case "orderAccepted":
      title = "Order Accepted 📦";
      body = `${customerName}: Agent accepted order #${cleanOrderId}`;
      route = "/delivery";
      break;
    case "orderDeclined":
      title = "Order Declined ❌";
      body = `${customerName}: Agent declined order #${cleanOrderId}`;
      route = "/delivery";
      break;
    case "pickupStarted":
      title = "Pickup Started 🚐";
      body = `${customerName}: Agent started pickup for order #${cleanOrderId}`;
      route = "/delivery";
      break;
    case "deliveryStarted":
      title = "Delivery Started 🚚";
      body = `${customerName}: Agent started delivery for order #${cleanOrderId}`;
      route = "/delivery";
      break;
    case "deliveryConfirmed":
      title = "Delivery Confirmed ✅";
      body = `${customerName}: Order #${cleanOrderId} delivered successfully`;
      route = "/admin/orders";
      break;
    case "deliveryFailed":
      title = "Delivery Failed ❌";
      body = `${customerName}: Order #${cleanOrderId} delivery failed/cancelled`;
      route = "/admin/orders";
      break;
    default:
      title = "Delivery Update";
      body = "";
      route = "/delivery";
  }

  // 7. Deterministic notification ID prevents duplicate notifications during Cloud Function retries
  const notifDocId = `delivery_${cleanOrderId}_${eventType}`;
  const uidsList = Array.from(adminUids);
  let writeCount = 0;

  for (const adminUid of uidsList) {
    const notifRef = db.collection("users").doc(adminUid).collection("notifications").doc(notifDocId);

    const payload = {
      notificationId: notifDocId,
      id: notifDocId,
      title: title,
      body: body,
      type: "delivery",
      timestamp: FieldValue.serverTimestamp(),
      isRead: false,
      isActionable: true,
      route: route,
      createdBy: customerId,
      userId: adminUid,
      orderId: cleanOrderId,
      assignedAgentId: assignedAgentId,
      eventType: eventType,
      metadata: {
        source: "delivery",
        orderId: cleanOrderId,
        eventType: eventType,
        agentId: assignedAgentId,
      },
    };

    try {
      await notifRef.set(payload, { merge: true });
      writeCount++;
      console.log(`[Delivery Event Notify] Created admin notification at users/${adminUid}/notifications/${notifDocId}`);
    } catch (writeErr) {
      console.error(`[Delivery Event Notify] Failed to write notification for admin ${adminUid}: ${writeErr.message}`);
    }
  }

  return {
    status: "created",
    count: writeCount,
    adminUids: uidsList,
    notificationId: notifDocId,
    eventType: eventType,
  };
}

/**
 * Triggered whenever an order in Firestore is updated.
 * When status transitions to a meaningful delivery event, creates a secure, idempotent Admin notification.
 */
exports.notifyAdminsOnDeliveryEvent = onDocumentUpdated(
  {
    region: "asia-south2",
    document: "orders/{orderId}",
  },
  async (event) => {
    if (!event.data || !event.data.after) {
      console.warn("No document data found in order event; skipping.");
      return;
    }

    const before = event.data.before ? event.data.before.data() : null;
    const after = event.data.after.data();
    const orderId = event.params.orderId;

    const db = getFirestore();
    await processDeliveryEventNotification(db, after, orderId, before);
  }
);

exports.processDeliveryEventNotification = processDeliveryEventNotification;

/**
 * Calculates the next delivery date based on frequency.
 * @param {string} frequency
 * @param {Date} fromDate
 * @returns {Date}
 */
function calculateNextDeliveryDate(frequency, fromDate) {
  const base = new Date(fromDate);
  const freq = String(frequency || "").toLowerCase().trim();
  if (freq === "weekly") {
    base.setDate(base.getDate() + 7);
  } else if (freq === "alternate day" || freq === "alternateday") {
    base.setDate(base.getDate() + 2);
  } else {
    // default daily
    base.setDate(base.getDate() + 1);
  }
  return base;
}

/**
 * Daily Subscription Order Generator
 * Scans active subscriptions, checks due delivery dates and skipped dates,
 * creates daily scheduled orders in the orders collection with deterministic IDs,
 * and advances the subscription's nextDeliveryDate.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{ targetDate?: Date|string, dryRun?: boolean }} [options]
 * @returns {Promise<{ status: string, createdCount: number, skippedCount: number, orderIds: string[] }>}
 */
async function processDailySubscriptionOrders(db, options = {}) {
  const targetDate = options.targetDate ? new Date(options.targetDate) : new Date();
  const year = targetDate.getFullYear();
  const month = String(targetDate.getMonth() + 1).padStart(2, "0");
  const day = String(targetDate.getDate()).padStart(2, "0");
  const dateKey = `${year}${month}${day}`;

  const endOfTargetDay = new Date(targetDate);
  endOfTargetDay.setHours(23, 59, 59, 999);

  const subsSnapshot = await db.collection("subscriptions").get();
  let createdCount = 0;
  let skippedCount = 0;
  const createdOrderIds = [];

  for (const doc of subsSnapshot.docs) {
    const sub = doc.data() || {};
    const subId = doc.id;

    // 1. Status check: only process Active subscriptions (respects Paused and Cancelled)
    const status = String(sub.status || "").toLowerCase().trim();
    if (status !== "active") {
      skippedCount++;
      continue;
    }

    // 2. Next delivery date check
    let nextDeliveryDate = null;
    if (sub.nextDeliveryDate) {
      if (typeof sub.nextDeliveryDate.toDate === "function") {
        nextDeliveryDate = sub.nextDeliveryDate.toDate();
      } else if (sub.nextDeliveryDate instanceof Date) {
        nextDeliveryDate = sub.nextDeliveryDate;
      } else {
        nextDeliveryDate = new Date(sub.nextDeliveryDate);
      }
    }

    // If nextDeliveryDate is in the future beyond target date, skip
    if (nextDeliveryDate && nextDeliveryDate > endOfTargetDay) {
      skippedCount++;
      continue;
    }

    // 3. End date check
    if (sub.endDate) {
      const endDate = typeof sub.endDate.toDate === "function" ? sub.endDate.toDate() : new Date(sub.endDate);
      if (targetDate > endDate) {
        skippedCount++;
        continue;
      }
    }

    const userId = String(sub.userId || sub.uid || "").trim();
    if (!userId) {
      skippedCount++;
      continue;
    }

    // 4. Check customer skipped dates
    try {
      const skipDoc = await db.collection("users").doc(userId).collection("skipped_dates").doc(dateKey).get();
      if (skipDoc && skipDoc.exists) {
        // Advance next delivery date and skip order
        const advanceNext = calculateNextDeliveryDate(sub.frequency, targetDate);
        if (!options.dryRun) {
          await db.collection("subscriptions").doc(subId).update({
            nextDeliveryDate: advanceNext,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        skippedCount++;
        continue;
      }
    } catch (_) {}

    // 5. Deterministic deduplication check: sub_{subId}_{YYYYMMDD}
    const orderDocId = `sub_${subId}_${dateKey}`;
    const orderRef = db.collection("orders").doc(orderDocId);
    const existingOrder = await orderRef.get();
    if (existingOrder.exists) {
      skippedCount++;
      continue;
    }

    // 6. Resolve customer info and delivery address
    let customerName = "Subscription Customer";
    let customerPhone = "";
    let addressMap = {
      id: `sub_addr_${subId}`,
      label: "Home",
      fullName: customerName,
      mobileNumber: customerPhone,
      houseFlat: "",
      streetArea: "",
      city: "",
      state: "",
      pinCode: "",
      fullAddressText: "",
    };

    if (sub.deliveryAddress && typeof sub.deliveryAddress === "object") {
      addressMap = { ...addressMap, ...sub.deliveryAddress };
      if (addressMap.fullName) customerName = addressMap.fullName;
      if (addressMap.mobileNumber) customerPhone = addressMap.mobileNumber;
    } else {
      try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (userDoc && userDoc.exists) {
          const udata = userDoc.data();
          if (udata.name) customerName = udata.name;
          if (udata.phone) customerPhone = udata.phone;
          addressMap.fullName = customerName;
          addressMap.mobileNumber = customerPhone;
          if (udata.address) {
            addressMap.fullAddressText = udata.address;
            addressMap.streetArea = udata.address;
          }
        }
      } catch (_) {}
    }

    const product = sub.product || {};
    const quantity = Number(sub.quantity) > 0 ? Number(sub.quantity) : 1;
    const price = Number(sub.productPrice != null ? sub.productPrice : product.price) || 0;
    const discountRate = Number(sub.discountRate != null ? sub.discountRate : 0.10);
    const subtotal = Math.round(price * quantity * 100) / 100;
    const discount = Math.round(subtotal * discountRate * 100) / 100;
    const totalAmount = Math.max(0, Math.round((subtotal - discount) * 100) / 100);
    const deliverySlot = sub.deliverySlot || sub.deliveryTimeSlot || "Morning (6:00 AM - 9:00 AM)";

    const codeSuffix = Math.floor(100 + Math.random() * 900);
    const orderCode = `SUB${codeSuffix}`;

    const orderData = {
      id: orderDocId,
      orderCode: orderCode,
      userId: userId,
      customerName: customerName,
      customerPhone: customerPhone,
      status: "Pending",
      orderType: "subscription",
      subscriptionId: subId,
      deliverySlot: deliverySlot,
      estimatedDeliveryTime: deliverySlot,
      items: [
        {
          productId: sub.productId || product.id || `prod_${subId}`,
          title: sub.productTitle || sub.productName || product.title || "Fresh Dairy Product",
          productName: sub.productTitle || sub.productName || product.title || "Fresh Dairy Product",
          name: sub.productTitle || sub.productName || product.title || "Fresh Dairy Product",
          unit: sub.productUnit || product.unit || "1L",
          price: price,
          quantity: quantity,
          totalPrice: subtotal,
          imageUrl: sub.productImageUrl || product.imageUrl || "",
          image: sub.productImageUrl || product.imageUrl || "",
          categoryId: sub.productCategoryId || product.categoryId || "",
          categoryName: sub.productCategoryName || product.categoryName || "",
        },
      ],
      subtotal: subtotal,
      deliveryCharge: 0.0,
      discount: discount,
      totalAmount: totalAmount,
      deliveryAddress: addressMap,
      paymentMethod: "Subscription",
      paymentStatus: "Paid",
      deliveryDate: targetDate,
      createdAt: FieldValue.serverTimestamp(),
    };

    if (!options.dryRun) {
      await orderRef.set(orderData);
      const nextDate = calculateNextDeliveryDate(sub.frequency, targetDate);
      await db.collection("subscriptions").doc(subId).update({
        nextDeliveryDate: nextDate,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    createdCount++;
    createdOrderIds.push(orderDocId);
  }

  return {
    status: "success",
    createdCount,
    skippedCount,
    orderIds: createdOrderIds,
  };
}

/**
 * Admin Global FCM Broadcast Processor
 * Dispatches announcements or promotional push notifications to target audiences
 * (all, customers, or delivery agents), safely handles stale tokens,
 * and records in-app notifications in user notification subcollections.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {object} messaging - Firebase Messaging instance
 * @param {object} broadcastData
 * @returns {Promise<{ status: string, targetedUsers: number, sentCount: number, failureCount: number }>}
 */
async function processAdminBroadcast(db, messaging, broadcastData) {
  if (!broadcastData) {
    return { status: "skipped", reason: "missing_payload" };
  }

  const title = broadcastData.title || "Sawariya Dairy Announcement";
  const body = broadcastData.body || "";
  const audience = String(broadcastData.audience || "all").toLowerCase().trim();
  const broadcastId = broadcastData.broadcastId || `bc_${Date.now()}`;
  const adminUid = broadcastData.adminUid || broadcastData.createdBy || "admin";
  const route = broadcastData.route || "/home";

  // If adminUid provided, verify privileges
  if (adminUid && adminUid !== "admin" && adminUid !== "system") {
    const adminDoc = await db.collection("users").doc(adminUid).get();
    if (adminDoc && adminDoc.exists) {
      const role = String(adminDoc.data().role || "").toLowerCase().trim();
      if (!["admin", "superadmin", "owner"].includes(role)) {
        console.warn(`Unauthorized broadcast attempt by user ${adminUid}`);
        return { status: "skipped", reason: "unauthorized" };
      }
    }
  }

  // Resolve target users by audience
  let query = db.collection("users");
  if (audience === "customers" || audience === "customer") {
    query = query.where("role", "==", "customer");
  } else if (audience === "delivery" || audience === "riders") {
    query = query.where("role", "==", "delivery");
  }

  const usersSnapshot = await query.get();
  let targetedUsers = 0;
  let sentCount = 0;
  let failureCount = 0;
  const staleTokensByUser = new Map();

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data() || {};
    const userId = userDoc.id;
    targetedUsers++;

    let tokens = [];
    if (Array.isArray(userData.fcmTokens)) {
      tokens = userData.fcmTokens.filter((t) => typeof t === "string" && t.trim().length > 0);
    } else if (userData.fcmToken && typeof userData.fcmToken === "string") {
      tokens = [userData.fcmToken.trim()];
    }

    tokens = [...new Set(tokens)];

    for (const token of tokens) {
      const message = {
        token: token,
        notification: { title, body },
        data: {
          broadcastId: String(broadcastId),
          userId: String(userId),
          route: route,
          type: "promotional",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "order_alerts",
            icon: "ic_launcher",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              alert: { title, body },
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
        await messaging.send(message);
        sentCount++;
      } catch (err) {
        failureCount++;
        if (
          err.code === "messaging/invalid-registration-token" ||
          err.code === "messaging/registration-token-not-registered"
        ) {
          if (!staleTokensByUser.has(userId)) {
            staleTokensByUser.set(userId, []);
          }
          staleTokensByUser.get(userId).push(token);
        }
      }
    }

    // Write deterministic in-app notification to users/{userId}/notifications/broadcast_{broadcastId}
    const notifRef = db.collection("users").doc(userId).collection("notifications").doc(`broadcast_${broadcastId}`);
    try {
      await notifRef.set({
        id: `broadcast_${broadcastId}`,
        title: title,
        body: body,
        type: "promotional",
        isRead: false,
        isActionable: false,
        route: route,
        broadcastId: broadcastId,
        createdBy: adminUid,
        userId: userId,
        timestamp: FieldValue.serverTimestamp(),
      }, { merge: true });
    } catch (_) {}
  }

  // Prune invalid/stale tokens
  for (const [uid, staleTokens] of staleTokensByUser.entries()) {
    try {
      await db.collection("users").doc(uid).update({
        fcmTokens: FieldValue.arrayRemove(...staleTokens),
      });
    } catch (_) {}
  }

  return {
    status: "completed",
    targetedUsers,
    sentCount,
    failureCount,
  };
}

/**
 * Scheduled Cloud Function: Daily at 04:00 AM IST (22:30 UTC previous day)
 */
exports.generateDailySubscriptionOrders = onSchedule(
  {
    schedule: "0 4 * * *",
    timeZone: "Asia/Kolkata",
    region: "asia-south2",
  },
  async () => {
    const db = getFirestore();
    const result = await processDailySubscriptionOrders(db);
    console.log(`[Scheduled Subscriptions] Completed: ${JSON.stringify(result)}`);
  }
);

/**
 * Cloud Firestore Trigger: onDocumentCreated for broadcasts/{broadcastId}
 */
exports.onAdminBroadcastCreated = onDocumentCreated(
  {
    region: "asia-south2",
    document: "broadcasts/{broadcastId}",
  },
  async (event) => {
    if (!event.data) return;
    const db = getFirestore();
    const messaging = getMessaging();
    const broadcastData = event.data.data() || {};
    broadcastData.broadcastId = event.params.broadcastId;
    const result = await processAdminBroadcast(db, messaging, broadcastData);
    console.log(`[Admin Broadcast] Result: ${JSON.stringify(result)}`);
  }
);

exports.processDailySubscriptionOrders = processDailySubscriptionOrders;
exports.processAdminBroadcast = processAdminBroadcast;
exports.calculateNextDeliveryDate = calculateNextDeliveryDate;
