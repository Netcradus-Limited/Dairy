const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { processSendPushNotification } = require("../index");

function createMockFirestore() {
  const store = new Map();

  const db = {
    _store: store,
    collection(colName) {
      return {
        doc(docId) {
          const docKey = `${colName}/${docId}`;
          return {
            id: docId,
            async get() {
              const data = store.get(docKey);
              return {
                id: docId,
                exists: data !== undefined,
                data() {
                  return data ? JSON.parse(JSON.stringify(data)) : undefined;
                },
              };
            },
            async set(data, options) {
              const existing = store.get(docKey) || {};
              if (options && options.merge) {
                store.set(docKey, { ...existing, ...JSON.parse(JSON.stringify(data)) });
              } else {
                store.set(docKey, JSON.parse(JSON.stringify(data)));
              }
            },
            async update(data) {
              const existing = store.get(docKey) || {};
              // Handle FieldValue.arrayRemove simulation if needed
              const updated = { ...existing };
              for (const [k, v] of Object.entries(data)) {
                updated[k] = v;
              }
              store.set(docKey, updated);
            },
          };
        },
      };
    },
  };

  return db;
}

function createMockMessaging() {
  const sentMessages = [];
  let failTokens = new Set();
  let failCode = "messaging/invalid-registration-token";

  return {
    sentMessages,
    setFailTokens(tokens, code = "messaging/invalid-registration-token") {
      failTokens = new Set(tokens);
      failCode = code;
    },
    async send(message) {
      if (failTokens.has(message.token)) {
        const error = new Error("Token delivery failed");
        error.code = failCode;
        throw error;
      }
      sentMessages.push(message);
      return `projects/test/messages/${sentMessages.length}`;
    },
  };
}

describe("FCM Push Notification Backend Unit Tests", () => {
  let db;
  let messaging;

  beforeEach(() => {
    db = createMockFirestore();
    messaging = createMockMessaging();

    // Seed test users
    db._store.set("users/user_with_token", {
      uid: "user_with_token",
      name: "Aman Sharma",
      fcmToken: "fcm_token_single_123",
    });

    db._store.set("users/user_with_multiple_tokens", {
      uid: "user_with_multiple_tokens",
      name: "Rohit Kumar",
      fcmTokens: ["fcm_token_device_1", "fcm_token_device_2"],
    });

    db._store.set("users/user_with_duplicate_tokens", {
      uid: "user_with_duplicate_tokens",
      name: "Duplicate Tester",
      fcmTokens: ["fcm_token_dup_1", "fcm_token_dup_1", "fcm_token_dup_1"],
    });

    db._store.set("users/user_no_tokens", {
      uid: "user_no_tokens",
      name: "Guest User",
    });
  });

  test("Dispatches FCM notification to single token user successfully", async () => {
    const notifData = {
      title: "Order Placed 🥛",
      body: "Your order #ORD-501 has been received.",
      orderId: "ORD-501",
      type: "order",
      isActionable: true,
    };

    const result = await processSendPushNotification(
      db,
      messaging,
      notifData,
      "user_with_token",
      "notif_001"
    );

    assert.equal(result.status, "sent");
    assert.equal(result.successCount, 1);
    assert.equal(result.failureCount, 0);
    assert.equal(messaging.sentMessages.length, 1);

    const sent = messaging.sentMessages[0];
    assert.equal(sent.token, "fcm_token_single_123");
    assert.equal(sent.notification.title, "Order Placed 🥛");
    assert.equal(sent.notification.body, "Your order #ORD-501 has been received.");
    assert.equal(sent.data.orderId, "ORD-501");
    assert.equal(sent.data.order_id, "ORD-501");
    assert.equal(sent.data.route, "/orders/ORD-501");
    assert.equal(sent.data.type, "order");
    assert.equal(sent.data.notificationId, "notif_001");
    assert.equal(sent.android.notification.channelId, "order_alerts");
  });

  test("Dispatches FCM notifications to multi-device user successfully", async () => {
    const notifData = {
      title: "Morning Dispatch 🚚",
      body: "Fresh milk batch is on its way to your neighborhood.",
      type: "delivery",
    };

    const result = await processSendPushNotification(
      db,
      messaging,
      notifData,
      "user_with_multiple_tokens",
      "notif_002"
    );

    assert.equal(result.status, "sent");
    assert.equal(result.successCount, 2);
    assert.equal(result.failureCount, 0);
    assert.equal(messaging.sentMessages.length, 2);
    assert.equal(messaging.sentMessages[0].token, "fcm_token_device_1");
    assert.equal(messaging.sentMessages[1].token, "fcm_token_device_2");
  });

  test("Deduplicates repeated token entries for same user", async () => {
    const notifData = {
      title: "Subscription Renewal Notice",
      body: "Your dairy subscription renews tomorrow.",
      type: "subscription",
    };

    const result = await processSendPushNotification(
      db,
      messaging,
      notifData,
      "user_with_duplicate_tokens",
      "notif_dup_test"
    );

    assert.equal(result.status, "sent");
    assert.equal(result.successCount, 1);
    assert.equal(messaging.sentMessages.length, 1);
    assert.equal(messaging.sentMessages[0].token, "fcm_token_dup_1");
  });

  test("Correctly passes delivery agent ID and route in delivery payload", async () => {
    const notifData = {
      title: "Order Assigned",
      body: "Order #ORD-777 assigned to agent",
      type: "delivery",
      orderId: "ORD-777",
      assignedAgentId: "agent_42",
      route: "/orders/ORD-777",
    };

    const result = await processSendPushNotification(
      db,
      messaging,
      notifData,
      "user_with_token",
      "notif_deliv_1"
    );

    assert.equal(result.status, "sent");
    assert.equal(messaging.sentMessages.length, 1);
    const sent = messaging.sentMessages[0];
    assert.equal(sent.data.assignedAgentId, "agent_42");
    assert.equal(sent.data.orderId, "ORD-777");
    assert.equal(sent.data.order_id, "ORD-777");
    assert.equal(sent.data.type, "delivery");
  });

  test("Correctly supports snake_case order_id in payload input", async () => {
    const notifData = {
      title: "Order Out for Delivery",
      body: "Driver is 5 mins away",
      type: "order",
      order_id: "ORD-SNAKE-999",
    };

    const result = await processSendPushNotification(
      db,
      messaging,
      notifData,
      "user_with_token",
      "notif_snake_1"
    );

    assert.equal(result.status, "sent");
    const sent = messaging.sentMessages[0];
    assert.equal(sent.data.orderId, "ORD-SNAKE-999");
    assert.equal(sent.data.order_id, "ORD-SNAKE-999");
    assert.equal(sent.data.route, "/orders/ORD-SNAKE-999");
  });

  test("Gracefully skips users with no registered FCM tokens", async () => {
    const notifData = {
      title: "Welcome",
      body: "Welcome to Sawariya Dairy",
    };

    const result = await processSendPushNotification(
      db,
      messaging,
      notifData,
      "user_no_tokens",
      "notif_003"
    );

    assert.equal(result.status, "skipped");
    assert.equal(result.reason, "no_fcm_tokens");
    assert.equal(messaging.sentMessages.length, 0);
  });

  test("Gracefully skips non-existent target users", async () => {
    const notifData = { title: "Test", body: "Test" };
    const result = await processSendPushNotification(
      db,
      messaging,
      notifData,
      "non_existent_uid",
      "notif_004"
    );

    assert.equal(result.status, "skipped");
    assert.equal(result.reason, "user_not_found");
  });

  test("Handles invalid/expired tokens and logs failure count", async () => {
    messaging.setFailTokens(["fcm_token_single_123"]);

    const notifData = {
      title: "Special Offer",
      body: "Get 20% off on Pure Ghee",
      type: "promotional",
    };

    const result = await processSendPushNotification(
      db,
      messaging,
      notifData,
      "user_with_token",
      "notif_005"
    );

    assert.equal(result.status, "sent");
    assert.equal(result.successCount, 0);
    assert.equal(result.failureCount, 1);
  });
});
