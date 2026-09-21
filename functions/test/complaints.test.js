const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { processComplaintCreatedNotification } = require("../index");

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
            collection(subColName) {
              return {
                doc(subDocId) {
                  const subDocKey = `${docKey}/${subColName}/${subDocId}`;
                  return {
                    id: subDocId,
                    async set(data, options) {
                      const existing = store.get(subDocKey) || {};
                      if (options && options.merge) {
                        store.set(subDocKey, { ...existing, ...JSON.parse(JSON.stringify(data)) });
                      } else {
                        store.set(subDocKey, JSON.parse(JSON.stringify(data)));
                      }
                    },
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
                  };
                },
              };
            },
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
          };
        },
        where(field, op, value) {
          return {
            async get() {
              const docs = [];
              for (const [key, val] of store.entries()) {
                if (key.startsWith(`${colName}/`) && key.split("/").length === 2) {
                  const docId = key.split("/")[1];
                  if (op === "in" && Array.isArray(value) && value.includes(val[field])) {
                    docs.push({
                      id: docId,
                      data() {
                        return val;
                      },
                    });
                  } else if (op === "==" && val[field] === value) {
                    docs.push({
                      id: docId,
                      data() {
                        return val;
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

describe("Complaint Notification Backend Unit Tests", () => {
  let db;

  beforeEach(() => {
    db = createMockFirestore();

    // Real admin accounts with Firebase Auth UIDs
    db._store.set("users/real_admin_uid_101", {
      uid: "real_admin_uid_101",
      role: "admin",
      name: "Main Admin",
    });

    db._store.set("users/real_owner_uid_202", {
      uid: "real_owner_uid_202",
      role: "owner",
      name: "Store Owner",
    });

    db._store.set("users/real_superadmin_uid_303", {
      uid: "real_superadmin_uid_303",
      role: "superadmin",
      name: "Super Admin",
    });

    // Customer accounts (must NOT receive admin notifications)
    db._store.set("users/cust_user_404", {
      uid: "cust_user_404",
      role: "customer",
      name: "Rahul Customer",
    });

    // Delivery agent accounts (must NOT receive admin notifications)
    db._store.set("users/deliv_user_505", {
      uid: "deliv_user_505",
      role: "delivery",
      name: "Delivery Driver",
    });
  });

  test("1: New complaint triggers notification creation for all valid Admin accounts", async () => {
    const complaintId = "cmp_test_12345";
    const complaintData = {
      customerId: "cust_user_404",
      customerName: "Rahul Sharma",
      subject: "Milk pouch damaged",
      description: "Received leaking milk packet today morning",
      category: "Quality",
      orderId: "ORD-999",
      ticketId: "CMP-012345",
    };

    const result = await processComplaintCreatedNotification(db, complaintData, complaintId);

    assert.equal(result.status, "created");
    assert.equal(result.count, 3);
    assert.equal(result.notificationId, `complaint_${complaintId}`);
    assert.ok(result.adminUids.includes("real_admin_uid_101"));
    assert.ok(result.adminUids.includes("real_owner_uid_202"));
    assert.ok(result.adminUids.includes("real_superadmin_uid_303"));
  });

  test("2: Real admin UIDs are used, never literal role strings as UIDs", async () => {
    const complaintId = "cmp_real_uid_check";
    const complaintData = {
      customerId: "cust_user_404",
      customerName: "Priya",
      description: "Order delayed",
    };

    await processComplaintCreatedNotification(db, complaintData, complaintId);

    // Literal role strings must NEVER exist as notification paths
    assert.equal(db._store.get(`users/admin/notifications/complaint_${complaintId}`), undefined);
    assert.equal(db._store.get(`users/owner/notifications/complaint_${complaintId}`), undefined);
    assert.equal(db._store.get(`users/superadmin/notifications/complaint_${complaintId}`), undefined);

    // Real UIDs MUST exist
    assert.ok(db._store.get(`users/real_admin_uid_101/notifications/complaint_${complaintId}`));
    assert.ok(db._store.get(`users/real_owner_uid_202/notifications/complaint_${complaintId}`));
  });

  test("3: Notification payload contains correct support type, isRead=false, isActionable=true, and route=/support", async () => {
    const complaintId = "cmp_payload_check";
    const complaintData = {
      customerId: "cust_user_404",
      customerName: "Amit Verma",
      subject: "Wrong item delivered",
      description: "Received curd instead of paneer",
      category: "Wrong Item",
      orderId: "ORD-789",
      ticketId: "CMP-888999",
    };

    await processComplaintCreatedNotification(db, complaintData, complaintId);

    const notif = db._store.get(`users/real_admin_uid_101/notifications/complaint_${complaintId}`);
    assert.ok(notif);
    assert.equal(notif.type, "support");
    assert.equal(notif.title, "New Customer Complaint");
    assert.equal(notif.body, "Amit Verma: Received curd instead of paneer");
    assert.equal(notif.isRead, false);
    assert.equal(notif.isActionable, true);
    assert.equal(notif.route, "/support");
    assert.equal(notif.createdBy, "cust_user_404");
    assert.equal(notif.userId, "real_admin_uid_101");
    assert.equal(notif.orderId, "ORD-789");
    assert.equal(notif.metadata.source, "complaint");
    assert.equal(notif.metadata.complaintId, complaintId);
    assert.equal(notif.metadata.ticketId, "CMP-888999");
    assert.equal(notif.metadata.category, "Wrong Item");
    assert.equal(notif.metadata.customerId, "cust_user_404");
  });

  test("4: Idempotency: Deterministic notification ID prevents duplicate notifications on retry", async () => {
    const complaintId = "cmp_retry_test";
    const complaintData = {
      customerId: "cust_user_404",
      customerName: "Amit",
      description: "Leaking milk packet",
    };

    // First trigger invocation
    const res1 = await processComplaintCreatedNotification(db, complaintData, complaintId);
    assert.equal(res1.status, "created");
    assert.equal(res1.notificationId, "complaint_cmp_retry_test");

    // Second trigger invocation (e.g. Cloud Function retry)
    const res2 = await processComplaintCreatedNotification(db, complaintData, complaintId);
    assert.equal(res2.status, "created");
    assert.equal(res2.notificationId, "complaint_cmp_retry_test");

    // Verify exactly one notification document exists per admin
    const notifPath = "users/real_admin_uid_101/notifications/complaint_cmp_retry_test";
    assert.ok(db._store.get(notifPath));
  });

  test("5: Gracefully skips when no complaint data or complaintId is provided", async () => {
    const res1 = await processComplaintCreatedNotification(db, null, "cmp_123");
    assert.equal(res1.status, "skipped");
    assert.equal(res1.reason, "no_data");

    const res2 = await processComplaintCreatedNotification(db, {}, "");
    assert.equal(res2.status, "skipped");
    assert.equal(res2.reason, "missing_complaint_id");
  });

  test("6: Gracefully skips when no admin users exist in system", async () => {
    const emptyDb = createMockFirestore();
    emptyDb._store.set("users/regular_user", { role: "customer" });

    const result = await processComplaintCreatedNotification(emptyDb, { description: "Test" }, "cmp_no_admin");
    assert.equal(result.status, "skipped");
    assert.equal(result.reason, "no_admins_found");
    assert.equal(result.count, 0);
  });
});
