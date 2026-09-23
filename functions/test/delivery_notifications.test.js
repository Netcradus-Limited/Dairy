const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { processDeliveryEventNotification } = require("../index");

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
              store.set(docKey, { ...existing, ...data });
            },
            collection(subColName) {
              return {
                doc(subDocId) {
                  const subDocKey = `${colName}/${docId}/${subColName}/${subDocId}`;
                  return {
                    id: subDocId,
                    async get() {
                      const data = store.get(subDocKey);
                      return {
                        id: subDocId,
                        exists: data !== undefined,
                        data() {
                          return data ? JSON.parse(JSON.stringify(data)) : undefined;
                        },
                      };
                    },
                    async set(data, options) {
                      const existing = store.get(subDocKey) || {};
                      if (options && options.merge) {
                        store.set(subDocKey, { ...existing, ...JSON.parse(JSON.stringify(data)) });
                      } else {
                        store.set(subDocKey, JSON.parse(JSON.stringify(data)));
                      }
                    },
                  };
                },
              };
            },
          };
        },
        where(field, op, val) {
          return {
            async get() {
              const docs = [];
              for (const [key, docData] of store.entries()) {
                if (key.startsWith(`${colName}/`) && key.split("/").length === 2) {
                  const id = key.split("/")[1];
                  let matches = false;
                  if (op === "==" && docData[field] === val) matches = true;
                  if (op === "in" && Array.isArray(val) && val.includes(docData[field])) matches = true;
                  if (matches) {
                    docs.push({
                      id,
                      data() {
                        return JSON.parse(JSON.stringify(docData));
                      },
                    });
                  }
                }
              }
              return { docs };
            },
          };
        },
      };
    },
  };

  return db;
}

describe("Delivery Agent -> Admin Notification Backend Unit Tests", () => {
  let db;

  beforeEach(() => {
    db = createMockFirestore();

    // Seed test users: Admin, Delivery Agent, Customer
    db._store.set("users/admin_uid_01", {
      uid: "admin_uid_01",
      name: "Admin User",
      role: "admin",
      isAdmin: true,
    });

    db._store.set("users/owner_uid_02", {
      uid: "owner_uid_02",
      name: "Dairy Owner",
      role: "owner",
    });

    db._store.set("users/agent_valid_01", {
      uid: "agent_valid_01",
      name: "Suresh Delivery",
      role: "delivery",
    });

    db._store.set("users/customer_invalid_agent", {
      uid: "customer_invalid_agent",
      name: "Sneha Customer",
      role: "customer",
    });
  });

  test("1: Accept order -> creates exactly one Admin notification with orderAccepted", async () => {
    const orderData = {
      status: "accepted",
      assignedAgentId: "agent_valid_01",
      customerName: "Rahul Sharma",
      customerId: "cust_100",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-ACCEPT-1",
      "pending"
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "orderAccepted");
    assert.equal(result.notificationId, "delivery_ORD-ACCEPT-1_orderAccepted");
    assert.equal(result.count, 2); // 2 admins discovered dynamically

    const notif = db._store.get("users/admin_uid_01/notifications/delivery_ORD-ACCEPT-1_orderAccepted");
    assert.ok(notif, "Notification should exist under admin's notification collection");
    assert.equal(notif.notificationId, "delivery_ORD-ACCEPT-1_orderAccepted");
    assert.equal(notif.type, "delivery");
    assert.equal(notif.isRead, false);
    assert.equal(notif.isActionable, true);
    assert.equal(notif.orderId, "ORD-ACCEPT-1");
    assert.equal(notif.assignedAgentId, "agent_valid_01");
    assert.equal(notif.eventType, "orderAccepted");
    assert.equal(notif.route, "/delivery");
    assert.ok(notif.title.includes("Accepted"));
    assert.ok(notif.metadata);
    assert.equal(notif.metadata.orderId, "ORD-ACCEPT-1");
    assert.equal(notif.metadata.agentId, "agent_valid_01");
    assert.equal(notif.metadata.eventType, "orderAccepted");
  });

  test("2: Decline order -> creates Admin notification with orderDeclined", async () => {
    const beforeData = {
      status: "accepted",
      assignedAgentId: "agent_valid_01",
    };
    const orderData = {
      status: "pending",
      assignedAgentId: null,
      customerName: "Rahul Sharma",
      customerId: "cust_100",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-DECLINE-1",
      beforeData
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "orderDeclined");
    assert.equal(result.notificationId, "delivery_ORD-DECLINE-1_orderDeclined");

    const notif = db._store.get("users/admin_uid_01/notifications/delivery_ORD-DECLINE-1_orderDeclined");
    assert.ok(notif);
    assert.equal(notif.assignedAgentId, "agent_valid_01");
    assert.equal(notif.eventType, "orderDeclined");
    assert.ok(notif.title.includes("Declined"));
  });

  test("3: Pickup started -> creates Admin notification with pickupStarted", async () => {
    const orderData = {
      status: "preparing",
      assignedAgentId: "agent_valid_01",
      customerName: "Anita Verma",
      customerId: "cust_101",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-PICKUP-1",
      "accepted"
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "pickupStarted");
    assert.equal(result.notificationId, "delivery_ORD-PICKUP-1_pickupStarted");

    const notif = db._store.get("users/admin_uid_01/notifications/delivery_ORD-PICKUP-1_pickupStarted");
    assert.ok(notif);
    assert.ok(notif.title.includes("Pickup Started"));
  });

  test("4: Delivery started -> creates Admin notification with deliveryStarted", async () => {
    const orderData = {
      status: "outForDelivery",
      assignedAgentId: "agent_valid_01",
      customerName: "Vikas Patel",
      customerId: "cust_102",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-DISPATCH-1",
      "preparing"
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "deliveryStarted");
    assert.equal(result.notificationId, "delivery_ORD-DISPATCH-1_deliveryStarted");

    const notif = db._store.get("users/admin_uid_01/notifications/delivery_ORD-DISPATCH-1_deliveryStarted");
    assert.ok(notif);
    assert.ok(notif.title.includes("Delivery Started"));
    assert.equal(notif.route, "/delivery");
  });

  test("5: Delivery confirmed -> creates Admin notification with deliveryConfirmed and route /admin/orders", async () => {
    const orderData = {
      status: "delivered",
      assignedAgentId: "agent_valid_01",
      customerName: "Kavita Rao",
      customerId: "cust_103",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-DELIVER-1",
      "outForDelivery"
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "deliveryConfirmed");
    assert.equal(result.notificationId, "delivery_ORD-DELIVER-1_deliveryConfirmed");

    const notif = db._store.get("users/admin_uid_01/notifications/delivery_ORD-DELIVER-1_deliveryConfirmed");
    assert.ok(notif);
    assert.ok(notif.title.includes("Delivery Confirmed"));
    assert.equal(notif.route, "/admin/orders");
  });

  test("6: Delivery failed/cancelled -> creates Admin notification with deliveryFailed", async () => {
    const orderData = {
      status: "cancelled",
      assignedAgentId: "agent_valid_01",
      customerName: "Sunil Joshi",
      customerId: "cust_104",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-FAIL-1",
      "outForDelivery"
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "deliveryFailed");
    assert.equal(result.notificationId, "delivery_ORD-FAIL-1_deliveryFailed");

    const notif = db._store.get("users/admin_uid_01/notifications/delivery_ORD-FAIL-1_deliveryFailed");
    assert.ok(notif);
    assert.ok(notif.title.includes("Delivery Failed"));
    assert.equal(notif.route, "/admin/orders");
  });

  test("7: Idempotency: Duplicate executions produce identical doc ID and no duplicates", async () => {
    const orderData = {
      status: "accepted",
      assignedAgentId: "agent_valid_01",
      customerName: "Rahul Sharma",
    };

    const r1 = await processDeliveryEventNotification(db, orderData, "ORD-IDEMPOTENT-1", "pending");
    const r2 = await processDeliveryEventNotification(db, orderData, "ORD-IDEMPOTENT-1", "pending");

    assert.equal(r1.notificationId, r2.notificationId);
    assert.equal(r1.notificationId, "delivery_ORD-IDEMPOTENT-1_orderAccepted");
  });

  test("8: Status unchanged (e.g. notes or location update) -> skips notification", async () => {
    const orderData = {
      status: "outForDelivery",
      assignedAgentId: "agent_valid_01",
      notes: "Updated delivery note",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-UNCHANGED-1",
      "outForDelivery"
    );

    assert.equal(result.status, "skipped");
    assert.equal(result.reason, "status_not_changed");
  });

  test("9: Invalid delivery agent (customer role) -> rejected safely", async () => {
    const orderData = {
      status: "accepted",
      assignedAgentId: "customer_invalid_agent",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-INVALID-AGENT",
      "pending"
    );

    assert.equal(result.status, "skipped");
    assert.equal(result.reason, "invalid_delivery_agent");
  });

  test("10: Missing assigned agent -> rejected safely", async () => {
    const orderData = {
      status: "accepted",
      assignedAgentId: "",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-NO-AGENT",
      "pending"
    );

    assert.equal(result.status, "skipped");
    assert.equal(result.reason, "no_assigned_agent");
  });

  test("11: Invalid transition (e.g. cancelled -> delivered) -> rejected safely", async () => {
    const orderData = {
      status: "delivered",
      assignedAgentId: "agent_valid_01",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "ORD-INVALID-TRANS",
      "cancelled"
    );

    assert.equal(result.status, "skipped");
    assert.equal(result.reason, "not_a_delivery_event");
  });
});
