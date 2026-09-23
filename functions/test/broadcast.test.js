const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { processAdminBroadcast } = require("../index");

function createMockFirestore() {
  const store = new Map();

  const db = {
    _store: store,
    collection(colName) {
      let filterField = null;
      let filterVal = null;

      const colObj = {
        where(field, op, val) {
          filterField = field;
          filterVal = val;
          return colObj;
        },
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
              const updated = { ...existing };
              for (const [k, v] of Object.entries(data)) {
                // simulate FieldValue.arrayRemove if present
                if (v && v._methodName === "arrayRemove") {
                  const currentArr = Array.isArray(existing[k]) ? [...existing[k]] : [];
                  const toRemove = new Set(v._elements || []);
                  updated[k] = currentArr.filter((item) => !toRemove.has(item));
                } else {
                  updated[k] = v;
                }
              }
              store.set(docKey, updated);
            },
            collection(subColName) {
              return {
                doc(subDocId) {
                  const subKey = `${colName}/${docId}/${subColName}/${subDocId}`;
                  return {
                    id: subDocId,
                    async get() {
                      const data = store.get(subKey);
                      return {
                        id: subDocId,
                        exists: data !== undefined,
                        data() {
                          return data ? JSON.parse(JSON.stringify(data)) : undefined;
                        },
                      };
                    },
                    async set(data) {
                      store.set(subKey, JSON.parse(JSON.stringify(data)));
                    },
                  };
                },
              };
            },
          };
        },
        async get() {
          const docs = [];
          for (const [key, value] of store.entries()) {
            if (key.startsWith(`${colName}/`) && key.split("/").length === 2) {
              const docId = key.split("/")[1];
              if (filterField && value[filterField] !== filterVal) {
                continue;
              }
              docs.push({
                id: docId,
                exists: true,
                data() {
                  return JSON.parse(JSON.stringify(value));
                },
              });
            }
          }
          return { docs, empty: docs.length === 0, size: docs.length };
        },
      };

      return colObj;
    },
  };

  return db;
}

function createMockMessaging() {
  const sentMessages = [];
  const failTokens = new Set();

  return {
    sentMessages,
    setFailTokens(tokens) {
      for (const t of tokens) failTokens.add(t);
    },
    async send(message) {
      if (failTokens.has(message.token)) {
        const err = new Error("Invalid token");
        err.code = "messaging/invalid-registration-token";
        throw err;
      }
      sentMessages.push(message);
      return `projects/sawariya/messages/${Date.now()}`;
    },
  };
}

describe("Admin Global FCM Broadcast Cloud Function Tests", () => {
  let db;
  let messaging;

  beforeEach(() => {
    db = createMockFirestore();
    messaging = createMockMessaging();
  });

  test("Rejects unauthorized broadcast attempt from non-admin user", async () => {
    await db.collection("users").doc("cust_intruder").set({
      role: "customer",
    });

    const result = await processAdminBroadcast(db, messaging, {
      title: "Malicious Broadcast",
      body: "Spam message",
      adminUid: "cust_intruder",
    });

    assert.equal(result.status, "skipped");
    assert.equal(result.reason, "unauthorized");
    assert.equal(messaging.sentMessages.length, 0);
  });

  test("Dispatches broadcast to all users and creates in-app notifications", async () => {
    // Seed users
    await db.collection("users").doc("admin_1").set({ role: "admin" });
    await db.collection("users").doc("user_cust_1").set({
      role: "customer",
      fcmTokens: ["tok_cust_1"],
    });
    await db.collection("users").doc("user_rider_1").set({
      role: "delivery",
      fcmTokens: ["tok_rider_1"],
    });

    const result = await processAdminBroadcast(db, messaging, {
      title: "Special Festival Discount!",
      body: "Get 20% off pure cow ghee today!",
      audience: "all",
      adminUid: "admin_1",
      broadcastId: "bc_diwali_2026",
      route: "/shop",
    });

    assert.equal(result.status, "completed");
    assert.equal(result.sentCount, 2);
    assert.equal(result.failureCount, 0);

    // Verify FCM message contents
    const tokensSent = messaging.sentMessages.map((m) => m.token);
    assert.ok(tokensSent.includes("tok_cust_1"));
    assert.ok(tokensSent.includes("tok_rider_1"));

    // Verify in-app notifications created
    const custNotif = await db.collection("users").doc("user_cust_1").collection("notifications").doc("broadcast_bc_diwali_2026").get();
    assert.equal(custNotif.exists, true);
    assert.equal(custNotif.data().title, "Special Festival Discount!");
    assert.equal(custNotif.data().route, "/shop");
    assert.equal(custNotif.data().type, "promotional");
  });

  test("Audience filtering: only dispatches to delivery agents when audience is 'delivery'", async () => {
    await db.collection("users").doc("admin_1").set({ role: "admin" });
    await db.collection("users").doc("user_cust_1").set({
      role: "customer",
      fcmTokens: ["tok_cust_1"],
    });
    await db.collection("users").doc("user_rider_1").set({
      role: "delivery",
      fcmTokens: ["tok_rider_1"],
    });

    const result = await processAdminBroadcast(db, messaging, {
      title: "Weather Alert",
      body: "Heavy rain expected in Sector 62. Drive safely.",
      audience: "delivery",
      adminUid: "admin_1",
      broadcastId: "bc_weather_01",
    });

    assert.equal(result.sentCount, 1);
    assert.equal(messaging.sentMessages[0].token, "tok_rider_1");
  });

  test("Safely handles invalid/stale tokens and prunes them from user profile", async () => {
    await db.collection("users").doc("admin_1").set({ role: "admin" });
    await db.collection("users").doc("user_bad_token").set({
      role: "customer",
      fcmTokens: ["tok_valid", "tok_expired_99"],
    });

    messaging.setFailTokens(["tok_expired_99"]);

    const result = await processAdminBroadcast(db, messaging, {
      title: "Fresh Deals",
      body: "A2 Paneer is freshly made!",
      audience: "customers",
      adminUid: "admin_1",
      broadcastId: "bc_paneer_01",
    });

    assert.equal(result.sentCount, 1);
    assert.equal(result.failureCount, 1);
  });
});
