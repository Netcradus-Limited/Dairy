const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { processDailySubscriptionOrders, calculateNextDeliveryDate } = require("../index");

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
              store.set(docKey, { ...existing, ...JSON.parse(JSON.stringify(data)) });
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
    },
  };

  return db;
}

describe("Daily Subscription Order Generation Cloud Function Tests", () => {
  let db;
  const testDate = new Date(2026, 8, 22, 4, 0, 0); // 2026-09-22

  beforeEach(() => {
    db = createMockFirestore();
  });

  test("calculateNextDeliveryDate advances correctly for daily, alternateDay, and weekly", () => {
    const base = new Date(2026, 8, 22);

    const dailyNext = calculateNextDeliveryDate("Daily", base);
    assert.equal(dailyNext.getDate(), 23);

    const altNext = calculateNextDeliveryDate("Alternate Day", base);
    assert.equal(altNext.getDate(), 24);

    const weeklyNext = calculateNextDeliveryDate("Weekly", base);
    assert.equal(weeklyNext.getDate(), 29);
  });

  test("Generates order for active daily subscription and advances nextDeliveryDate", async () => {
    await db.collection("subscriptions").doc("sub_001").set({
      id: "sub_001",
      userId: "cust_101",
      status: "Active",
      frequency: "Daily",
      productPrice: 65,
      quantity: 2,
      discountRate: 0.10,
      deliverySlot: "Morning (6:00 AM - 9:00 AM)",
      nextDeliveryDate: testDate,
      product: {
        id: "prod_milk_1",
        title: "Fresh Cow Milk 1L",
        price: 65,
        unit: "1L",
      },
      deliveryAddress: {
        fullName: "Vikram Mehta",
        mobileNumber: "9876543210",
        streetArea: "Sector 18, Noida",
      },
    });

    const result = await processDailySubscriptionOrders(db, { targetDate: testDate });
    assert.equal(result.status, "success");
    assert.equal(result.createdCount, 1);
    assert.equal(result.orderIds.length, 1);
    assert.equal(result.orderIds[0], "sub_sub_001_20260922");

    // Verify created order
    const orderDoc = await db.collection("orders").doc("sub_sub_001_20260922").get();
    assert.equal(orderDoc.exists, true);
    const orderData = orderDoc.data();
    assert.equal(orderData.userId, "cust_101");
    assert.equal(orderData.customerName, "Vikram Mehta");
    assert.equal(orderData.customerPhone, "9876543210");
    assert.equal(orderData.status, "Pending");
    assert.equal(orderData.orderType, "subscription");
    assert.equal(orderData.subscriptionId, "sub_001");
    assert.equal(orderData.subtotal, 130);
    assert.equal(orderData.discount, 13);
    assert.equal(orderData.totalAmount, 117);
    assert.equal(orderData.paymentStatus, "Paid");

    // Verify nextDeliveryDate advanced to 2026-09-23
    const updatedSub = await db.collection("subscriptions").doc("sub_001").get();
    const nextDate = new Date(updatedSub.data().nextDeliveryDate);
    assert.equal(nextDate.getDate(), 23);
  });

  test("Skips paused and cancelled subscriptions", async () => {
    await db.collection("subscriptions").doc("sub_paused").set({
      id: "sub_paused",
      userId: "cust_102",
      status: "Paused",
      frequency: "Daily",
      nextDeliveryDate: testDate,
    });

    await db.collection("subscriptions").doc("sub_cancelled").set({
      id: "sub_cancelled",
      userId: "cust_103",
      status: "Cancelled",
      frequency: "Daily",
      nextDeliveryDate: testDate,
    });

    const result = await processDailySubscriptionOrders(db, { targetDate: testDate });
    assert.equal(result.status, "success");
    assert.equal(result.createdCount, 0);
    assert.equal(result.skippedCount, 2);
  });

  test("Idempotency: running multiple times on the same date does not produce duplicate orders", async () => {
    await db.collection("subscriptions").doc("sub_repeat").set({
      id: "sub_repeat",
      userId: "cust_104",
      status: "Active",
      frequency: "Daily",
      nextDeliveryDate: testDate,
      product: { id: "p1", title: "Milk", price: 60 },
    });

    // First run
    const firstRun = await processDailySubscriptionOrders(db, { targetDate: testDate });
    assert.equal(firstRun.createdCount, 1);

    // Second run (simulating retry or second cron execution on same day)
    const secondRun = await processDailySubscriptionOrders(db, { targetDate: testDate });
    assert.equal(secondRun.createdCount, 0);
    assert.equal(secondRun.skippedCount, 1);
  });

  test("Skips subscriptions scheduled in the future beyond target date", async () => {
    const futureDate = new Date(2026, 8, 25); // 3 days later
    await db.collection("subscriptions").doc("sub_future").set({
      id: "sub_future",
      userId: "cust_105",
      status: "Active",
      frequency: "Daily",
      nextDeliveryDate: futureDate,
      product: { id: "p1", title: "Milk", price: 60 },
    });

    const result = await processDailySubscriptionOrders(db, { targetDate: testDate });
    assert.equal(result.createdCount, 0);
    assert.equal(result.skippedCount, 1);
  });

  test("Respects customer skipped dates by skipping order and advancing nextDeliveryDate", async () => {
    await db.collection("subscriptions").doc("sub_skip_test").set({
      id: "sub_skip_test",
      userId: "cust_skipper",
      status: "Active",
      frequency: "Daily",
      nextDeliveryDate: testDate,
      product: { id: "p1", title: "Milk", price: 60 },
    });

    // Customer skipped 20260922
    await db.collection("users").doc("cust_skipper").collection("skipped_dates").doc("20260922").set({
      date: testDate,
      skippedAt: new Date(),
    });

    const result = await processDailySubscriptionOrders(db, { targetDate: testDate });
    assert.equal(result.createdCount, 0);
    assert.equal(result.skippedCount, 1);

    // Order should NOT exist
    const orderDoc = await db.collection("orders").doc("sub_sub_skip_test_20260922").get();
    assert.equal(orderDoc.exists, false);

    // nextDeliveryDate should still advance
    const updatedSub = await db.collection("subscriptions").doc("sub_skip_test").get();
    const nextDate = new Date(updatedSub.data().nextDeliveryDate);
    assert.equal(nextDate.getDate(), 23);
  });
});
