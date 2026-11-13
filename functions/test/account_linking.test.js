const test = require("node:test");
const assert = require("node:assert");

const {
  normalizeIndianPhone,
  generatePhoneVariants,
  ALLOWED_STAFF_ROLES,
  ALLOWED_DELIVERY_ROLES,
  ALLOWED_STATUSES,
  processLinkStaffAccount,
  processLinkDeliveryAgentAccount,
} = require("../index.js");

// Mock in-memory Firestore with transaction support
function createMockFirestore(initialData = {}) {
  const store = new Map();

  // Populate initial store
  for (const [coll, docs] of Object.entries(initialData)) {
    for (const [id, data] of Object.entries(docs)) {
      store.set(`${coll}/${id}`, JSON.parse(JSON.stringify(data)));
    }
  }

  function getDocRef(coll, id) {
    return {
      id,
      path: `${coll}/${id}`,
      ref: { id, path: `${coll}/${id}` },
    };
  }

  return {
    _store: store,
    collection(collName) {
      return {
        doc(docId) {
          return {
            id: docId,
            path: `${collName}/${docId}`,
          };
        },
        where(field, op, val) {
          return {
            where() {
              return this;
            },
            limit() {
              return this;
            },
            async get() {
              const matched = [];
              for (const [key, valData] of store.entries()) {
                if (!key.startsWith(`${collName}/`)) continue;
                const id = key.substring(collName.length + 1);
                if (op === "==" && valData[field] === val) {
                  matched.push({ id, ref: getDocRef(collName, id), data: () => ({ ...valData }) });
                } else if (op === "in" && Array.isArray(val) && val.includes(valData[field])) {
                  matched.push({ id, ref: getDocRef(collName, id), data: () => ({ ...valData }) });
                }
              }
              return { empty: matched.length === 0, docs: matched };
            },
          };
        },
      };
    },
    async runTransaction(updateFunction) {
      const pendingWrites = [];

      const transaction = {
        async get(refOrQuery) {
          if (refOrQuery.where) {
            // Query inside transaction
            return await refOrQuery.get();
          }
          const path = refOrQuery.path;
          const data = store.get(path);
          return {
            exists: !!data,
            id: refOrQuery.id,
            ref: refOrQuery,
            data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined),
          };
        },
        set(ref, data, options = {}) {
          pendingWrites.push(() => {
            const path = ref.path;
            if (options.merge && store.has(path)) {
              store.set(path, { ...store.get(path), ...data });
            } else {
              store.set(path, { ...data });
            }
          });
        },
        update(ref, data) {
          pendingWrites.push(() => {
            const path = ref.path;
            if (!store.has(path)) {
              throw new Error(`Document ${path} not found for update`);
            }
            store.set(path, { ...store.get(path), ...data });
          });
        },
      };

      const result = await updateFunction(transaction);
      // Commit writes atomically
      for (const w of pendingWrites) {
        w();
      }
      return result;
    },
  };
}

test("1. Phone Normalization correctly extracts 10 digits and variants", () => {
  assert.strictEqual(normalizeIndianPhone("+919876543210"), "9876543210");
  assert.strictEqual(normalizeIndianPhone("9876543210"), "9876543210");
  assert.strictEqual(normalizeIndianPhone("+91 98765 43210"), "9876543210");
  assert.strictEqual(normalizeIndianPhone("09876543210"), "9876543210");
  assert.strictEqual(normalizeIndianPhone("919876543210"), "9876543210");
  assert.strictEqual(normalizeIndianPhone(""), "");
  assert.strictEqual(normalizeIndianPhone(null), "");

  const variants = generatePhoneVariants("+919876543210");
  assert.ok(variants.includes("+919876543210"));
  assert.ok(variants.includes("9876543210"));
  assert.ok(variants.includes("919876543210"));
  assert.ok(variants.includes("09876543210"));
});

test("2. Staff Linking: First-time legitimate admin linking succeeds", async () => {
  const db = createMockFirestore({
    admins: {
      "9876543210": {
        name: "Admin User",
        email: "admin@sawariya.com",
        phone: "+919876543210",
        role: "admin",
        roleTitle: "Super Admin",
        permissions: ["viewDashboard", "manageStaff", "manageProducts"],
        status: "Active",
      },
    },
    users: {
      auth_admin_123: {
        uid: "auth_admin_123",
        role: "customer",
      },
    },
  });

  const res = await processLinkStaffAccount(db, {
    uid: "auth_admin_123",
    phoneNumber: "+919876543210",
  });

  assert.strictEqual(res.status, "linked");
  assert.strictEqual(res.role, "admin");
  assert.strictEqual(res.roleTitle, "Super Admin");
  assert.deepStrictEqual(res.permissions, ["viewDashboard", "manageStaff", "manageProducts"]);

  // Verify DB state
  const adminDoc = db._store.get("admins/auth_admin_123");
  assert.ok(adminDoc);
  assert.strictEqual(adminDoc.role, "admin");
  assert.strictEqual(adminDoc.uid, "auth_admin_123");
  assert.strictEqual(adminDoc.isLinked, true);

  const userDoc = db._store.get("users/auth_admin_123");
  assert.ok(userDoc);
  assert.strictEqual(userDoc.role, "admin");
  assert.strictEqual(userDoc.isAdmin, true);

  // Verify reservation claim
  const claimDoc = db._store.get("_staff_phone_claims/9876543210");
  assert.ok(claimDoc);
  assert.strictEqual(claimDoc.uid, "auth_admin_123");
});

test("3. Staff Linking: Idempotent retry returns existing role without errors", async () => {
  const db = createMockFirestore({
    _staff_phone_claims: {
      "9876543210": {
        uid: "auth_admin_123",
        phone: "9876543210",
      },
    },
    admins: {
      auth_admin_123: {
        uid: "auth_admin_123",
        role: "dispatcher",
        roleTitle: "Route Dispatcher",
        permissions: ["viewOrders", "assignDeliveryAgent"],
        status: "Active",
      },
    },
  });

  const res = await processLinkStaffAccount(db, {
    uid: "auth_admin_123",
    phoneNumber: "+919876543210",
  });

  assert.strictEqual(res.status, "already_linked");
  assert.strictEqual(res.role, "dispatcher");
  assert.strictEqual(res.roleTitle, "Route Dispatcher");
});

test("4. Staff Linking: Rejects UID takeover when phone is claimed by another user", async () => {
  const db = createMockFirestore({
    _staff_phone_claims: {
      "9876543210": {
        uid: "legitimate_admin_uid",
        phone: "9876543210",
      },
    },
  });

  await assert.rejects(
    async () => {
      await processLinkStaffAccount(db, {
        uid: "attacker_uid_999",
        phoneNumber: "+919876543210",
      });
    },
    (err) => {
      assert.strictEqual(err.code, "already-exists");
      assert.match(err.message, /UID takeover rejected/);
      return true;
    }
  );
});

test("5. Staff Linking: Rejects inactive or suspended staff records", async () => {
  const db = createMockFirestore({
    admins: {
      "9876543210": {
        phone: "+919876543210",
        role: "admin",
        status: "Suspended",
      },
    },
  });

  await assert.rejects(
    async () => {
      await processLinkStaffAccount(db, {
        uid: "auth_admin_123",
        phoneNumber: "+919876543210",
      });
    },
    (err) => {
      assert.strictEqual(err.code, "permission-denied");
      return true;
    }
  );
});

test("6. Staff Linking: Rejects unauthorized role in provisioning document", async () => {
  const db = createMockFirestore({
    admins: {
      "9876543210": {
        phone: "+919876543210",
        role: "hacker_superuser",
        status: "Active",
      },
    },
  });

  await assert.rejects(
    async () => {
      await processLinkStaffAccount(db, {
        uid: "auth_admin_123",
        phoneNumber: "+919876543210",
      });
    },
    (err) => {
      assert.strictEqual(err.code, "invalid-argument");
      return true;
    }
  );
});

test("7. Staff Linking: Normal customer without admin record returns not_staff", async () => {
  const db = createMockFirestore({});

  const res = await processLinkStaffAccount(db, {
    uid: "customer_uid_555",
    phoneNumber: "+919123456789",
  });

  assert.strictEqual(res.status, "not_staff");
  assert.strictEqual(res.role, "customer");
});

test("8. Delivery Agent Linking: First-time legitimate delivery linking succeeds", async () => {
  const db = createMockFirestore({
    delivery_agents: {
      "RDR-1700000000": {
        name: "Ramesh Rider",
        email: "ramesh@sawariya.com",
        phone: "+919876543211",
        vehicle: "Hero Electric",
        vehicleNumber: "RJ14DE1234",
        assignedZone: "Mansarovar",
        rating: 4.8,
        status: "Active",
      },
    },
    users: {
      auth_rider_456: {
        uid: "auth_rider_456",
        role: "customer",
      },
    },
  });

  const res = await processLinkDeliveryAgentAccount(db, {
    uid: "auth_rider_456",
    phoneNumber: "+919876543211",
  });

  assert.strictEqual(res.status, "linked");
  assert.strictEqual(res.role, "delivery");

  // Verify delivery_agents record
  const agentDoc = db._store.get("delivery_agents/auth_rider_456");
  assert.ok(agentDoc);
  assert.strictEqual(agentDoc.role, "delivery");
  assert.strictEqual(agentDoc.uid, "auth_rider_456");
  assert.strictEqual(agentDoc.vehicle, "Hero Electric");
  assert.strictEqual(agentDoc.assignedZone, "Mansarovar");
  assert.strictEqual(agentDoc.rating, 4.8);
  assert.strictEqual(agentDoc.isOnline, false);
  assert.strictEqual(agentDoc.isOnDuty, false);

  // Verify user record
  const userDoc = db._store.get("users/auth_rider_456");
  assert.ok(userDoc);
  assert.strictEqual(userDoc.role, "delivery");
  assert.strictEqual(userDoc.isAdmin, false);
});

test("9. Delivery Agent Linking: Rejects UID takeover when claimed by another user", async () => {
  const db = createMockFirestore({
    _delivery_phone_claims: {
      "9876543211": {
        uid: "original_rider_uid",
        phone: "9876543211",
      },
    },
  });

  await assert.rejects(
    async () => {
      await processLinkDeliveryAgentAccount(db, {
        uid: "intruder_uid",
        phoneNumber: "+919876543211",
      });
    },
    (err) => {
      assert.strictEqual(err.code, "already-exists");
      assert.match(err.message, /UID takeover rejected/);
      return true;
    }
  );
});

test("10. Delivery Agent Linking: Non-rider returns not_delivery with customer role", async () => {
  const db = createMockFirestore({});

  const res = await processLinkDeliveryAgentAccount(db, {
    uid: "customer_uid_777",
    phoneNumber: "+919123456789",
  });

  assert.strictEqual(res.status, "not_delivery");
  assert.strictEqual(res.role, "customer");
});
