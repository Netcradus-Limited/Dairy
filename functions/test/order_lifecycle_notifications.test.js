const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const {
  processOrderCreatedNotification,
  processDeliveryEventNotification,
} = require("../index");

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

describe("Order Lifecycle Notifications Suite", () => {
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

    db._store.set("users/agent_ramesh", {
      uid: "agent_ramesh",
      name: "Ramesh Delivery",
      role: "delivery",
    });

    db._store.set("users/customer_sunil", {
      uid: "customer_sunil",
      name: "Sunil Verma",
      role: "customer",
    });
  });

  test("1: Customer places new order -> creates Admin notification with order details", async () => {
    const orderData = {
      orderCode: "ORD-9988",
      customerName: "Sunil Verma",
      customerId: "customer_sunil",
      totalAmount: 450,
      paymentMethod: "COD",
    };

    const result = await processOrderCreatedNotification(db, orderData, "order_abc_123");

    assert.equal(result.status, "created");
    assert.equal(result.notificationId, "order_order_abc_123_created");
    assert.equal(result.count, 2); // Both admin and owner

    const adminNotif = db._store.get("users/admin_uid_01/notifications/order_order_abc_123_created");
    assert.ok(adminNotif);
    assert.equal(adminNotif.title, "New Order Received 🛒");
    assert.ok(adminNotif.body.includes("ORD-9988"));
    assert.ok(adminNotif.body.includes("Sunil Verma"));
    assert.ok(adminNotif.body.includes("₹450"));
    assert.ok(adminNotif.body.includes("COD"));
    assert.equal(adminNotif.route, "/admin/orders");
    assert.equal(adminNotif.orderId, "order_abc_123");
    assert.equal(adminNotif.isRead, false);
    assert.equal(adminNotif.isActionable, true);
  });

  test("2: Customer places new order idempotency -> duplicate call does not duplicate", async () => {
    const orderData = {
      orderCode: "ORD-9988",
      customerName: "Sunil Verma",
      customerId: "customer_sunil",
      totalAmount: 450,
      paymentMethod: "Online",
    };

    const r1 = await processOrderCreatedNotification(db, orderData, "order_abc_123");
    const r2 = await processOrderCreatedNotification(db, orderData, "order_abc_123");

    assert.equal(r1.notificationId, r2.notificationId);
    assert.equal(r1.count, r2.count);
  });

  test("3: Delivery agent accepts order -> Admin notification includes agent name", async () => {
    const orderData = {
      status: "accepted",
      assignedAgentId: "agent_ramesh",
      customerName: "Sunil Verma",
      customerId: "customer_sunil",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "order_abc_123",
      "pending"
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "orderAccepted");

    const adminNotif = db._store.get("users/admin_uid_01/notifications/delivery_order_abc_123_orderAccepted");
    assert.ok(adminNotif);
    assert.ok(adminNotif.body.includes("Ramesh Delivery"));
    assert.ok(adminNotif.body.includes("order_abc_123"));
    assert.equal(adminNotif.assignedAgentId, "agent_ramesh");
  });

  test("4: Delivery agent starts delivery -> Admin and Customer both receive out-for-delivery notifications", async () => {
    const orderData = {
      status: "outForDelivery",
      orderCode: "ORD-9988",
      assignedAgentId: "agent_ramesh",
      customerName: "Sunil Verma",
      customerId: "customer_sunil",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "order_abc_123",
      "preparing"
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "deliveryStarted");

    // Admin notification
    const adminNotif = db._store.get("users/admin_uid_01/notifications/delivery_order_abc_123_deliveryStarted");
    assert.ok(adminNotif);
    assert.ok(adminNotif.body.includes("Order #order_abc_123 is now out for delivery."));

    // Customer notification
    const custNotif = db._store.get("users/customer_sunil/notifications/order_order_abc_123_outForDelivery");
    assert.ok(custNotif, "Customer should receive outForDelivery notification");
    assert.equal(custNotif.route, "/orders/order_abc_123");
    assert.ok(custNotif.body.includes("ORD-9988"));
  });

  test("5: Delivery agent marks delivered -> Admin and Customer both receive delivered notifications", async () => {
    const orderData = {
      status: "delivered",
      orderCode: "ORD-9988",
      assignedAgentId: "agent_ramesh",
      customerName: "Sunil Verma",
      customerId: "customer_sunil",
    };

    const result = await processDeliveryEventNotification(
      db,
      orderData,
      "order_abc_123",
      "outForDelivery"
    );

    assert.equal(result.status, "created");
    assert.equal(result.eventType, "deliveryConfirmed");

    // Admin notification
    const adminNotif = db._store.get("users/admin_uid_01/notifications/delivery_order_abc_123_deliveryConfirmed");
    assert.ok(adminNotif);
    assert.ok(adminNotif.body.includes("Order #order_abc_123 has been delivered."));
    assert.equal(adminNotif.route, "/admin/orders");

    // Customer notification
    const custNotif = db._store.get("users/customer_sunil/notifications/order_order_abc_123_delivered");
    assert.ok(custNotif, "Customer should receive delivered notification");
    assert.equal(custNotif.route, "/orders/order_abc_123");
    assert.ok(custNotif.body.includes("ORD-9988"));
  });

  test("6: Missing order data or orderId skips safely", async () => {
    const res1 = await processOrderCreatedNotification(db, null, "order_1");
    assert.equal(res1.status, "skipped");
    assert.equal(res1.reason, "no_data");

    const res2 = await processOrderCreatedNotification(db, {}, "");
    assert.equal(res2.status, "skipped");
    assert.equal(res2.reason, "missing_order_id");
  });
});
