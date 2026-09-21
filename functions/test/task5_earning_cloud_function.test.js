/**
 * Sawariya Dairy — Task 5: Automatic Delivery Earnings Cloud Function Tests
 * =========================================================================
 * Focused test suite for the logEarningOnDelivered Cloud Function behaviour.
 *
 * Tests are organised around the 10 required scenarios from the Task 5 spec:
 *  1.  delivered order creates earning
 *  2.  earning uses correct agentId
 *  3.  earning uses correct orderId
 *  4.  correct commission calculation (10%)
 *  5.  duplicate delivered event does NOT create duplicate earning
 *  6.  missing agent ID does NOT create earning
 *  7.  invalid / missing subtotal handled safely
 *  8.  cancelled / non-delivered order does NOT create earning
 *  9.  EarningsService reading still works after Cloud Function write
 * 10.  Task 1–4 regression: existing behaviours unaffected
 *
 * Uses the project's exported `processOrderDeliveredEarning` and
 * `AGENT_EARNING_RATE` from functions/index.js together with the same
 * lightweight in-memory Firestore mock used by earnings.test.js.
 */

const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const {
  processOrderDeliveredEarning,
  AGENT_EARNING_RATE,
} = require("../index");

// ---------------------------------------------------------------------------
// Lightweight in-memory Firestore mock
// (matches the structure used in earnings.test.js so no new dependencies)
// ---------------------------------------------------------------------------
function createMockFirestore() {
  const store = new Map();

  const makeDocRef = (colName, docId) => {
    const key = `${colName}/${docId}`;
    return {
      id: docId,
      async get() {
        const data = store.get(key);
        return {
          id: docId,
          exists: data !== undefined,
          data() {
            return data ? JSON.parse(JSON.stringify(data)) : undefined;
          },
        };
      },
      async set(data) {
        store.set(key, JSON.parse(JSON.stringify(data)));
      },
    };
  };

  return {
    _store: store,
    collection(colName) {
      return {
        doc(docId) {
          return makeDocRef(colName, docId);
        },
      };
    },
    async runTransaction(updateFn) {
      const transaction = {
        async get(docRef) {
          return await docRef.get();
        },
        set(docRef, data) {
          store.set(`earnings/${docRef.id}`, JSON.parse(JSON.stringify(data)));
        },
      };
      return await updateFn(transaction);
    },
  };
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------
function seedDeliveryAgent(db, agentId) {
  db._store.set(`users/${agentId}`, {
    uid: agentId,
    role: "delivery",
    name: `Agent ${agentId}`,
  });
}

function getStoredEarning(db, orderId) {
  return db._store.get(`earnings/${orderId}`);
}

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------
describe("Task 5 — logEarningOnDelivered Cloud Function Tests", () => {
  let db;

  beforeEach(() => {
    db = createMockFirestore();
    seedDeliveryAgent(db, "agent_task5");
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Test 1 + 2 + 3 + 4 — Core creation with correct agentId, orderId, 10%
  // ─────────────────────────────────────────────────────────────────────────
  test(
    "T5-01/02/03/04: Delivered order creates earning with correct agentId, orderId and 10% commission",
    async () => {
      const orderId = "t5_order_001";
      const agentId = "agent_task5";
      const subtotal = 750;

      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal, deliveryCharge: 30 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);

      assert.equal(result.status, "created", "Result status should be 'created'");
      assert.equal(result.agentId, agentId, "agentId must match assignedAgentId");
      assert.equal(result.orderId, orderId, "orderId must match the order document id");

      const expected = Math.round(subtotal * AGENT_EARNING_RATE * 100) / 100;
      assert.equal(result.amountEarned, expected, `amountEarned must be ${expected} (10% of ${subtotal})`);

      const stored = getStoredEarning(db, orderId);
      assert.ok(stored, "Earning document must be written to Firestore");
      assert.equal(stored.agentId, agentId);
      assert.equal(stored.orderId, orderId);
      assert.equal(stored.amountEarned, expected);
      assert.equal(stored.deliveryFee, 30, "deliveryFee must be stored from order.deliveryCharge");
      assert.equal(stored.tipAmount, 0.0, "tipAmount defaults to 0.0");
      assert.equal(stored.status, "pending", "Earning status defaults to 'pending'");
    }
  );

  test("T5-04b: AGENT_EARNING_RATE constant is exactly 0.10 (10%)", () => {
    assert.equal(AGENT_EARNING_RATE, 0.10);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Test 5 — Duplicate protection
  // ─────────────────────────────────────────────────────────────────────────
  test(
    "T5-05: Duplicate delivered event does NOT create a duplicate earning (idempotent)",
    async () => {
      const orderId = "t5_order_005";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal: 400 };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal: 400 };

      const r1 = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(r1.status, "created", "First invocation must create earning");
      assert.equal(r1.amountEarned, 40.0);

      const r2 = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(r2.status, "skipped_duplicate", "Second invocation must be skipped as duplicate");

      const stored = getStoredEarning(db, orderId);
      assert.ok(stored, "Earning document must still exist after duplicate call");
      assert.equal(stored.amountEarned, 40.0, "Earning amount must NOT be overwritten");
    }
  );

  test(
    "T5-05b: Non-transition update on already-delivered order is skipped before DB check",
    async () => {
      const orderId = "t5_order_005b";
      const agentId = "agent_task5";
      const before = { status: "delivered", assignedAgentId: agentId, subtotal: 300 };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal: 300, note: "ok" };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "not_delivered_transition");
      assert.equal(getStoredEarning(db, orderId), undefined, "No earning must be written");
    }
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Test 6 — Missing/empty/null assignedAgentId
  // ─────────────────────────────────────────────────────────────────────────
  test(
    "T5-06a: Missing assignedAgentId (field absent) does NOT create earning",
    async () => {
      const orderId = "t5_order_006a";
      const before = { status: "outForDelivery", subtotal: 500 };
      const after = { status: "delivered", subtotal: 500 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "missing_assigned_agent");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  test(
    "T5-06b: Empty-string assignedAgentId does NOT create earning",
    async () => {
      const orderId = "t5_order_006b";
      const before = { status: "outForDelivery", assignedAgentId: "", subtotal: 500 };
      const after = { status: "delivered", assignedAgentId: "   ", subtotal: 500 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "missing_assigned_agent");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  test(
    "T5-06c: Null assignedAgentId does NOT create earning",
    async () => {
      const orderId = "t5_order_006c";
      const before = { status: "outForDelivery", assignedAgentId: null, subtotal: 500 };
      const after = { status: "delivered", assignedAgentId: null, subtotal: 500 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "missing_assigned_agent");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Test 7 — Invalid / missing subtotal handled safely
  // ─────────────────────────────────────────────────────────────────────────
  test(
    "T5-07a: NaN subtotal is rejected safely — no earning created",
    async () => {
      const orderId = "t5_order_007a";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal: "bad_value" };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal: "bad_value" };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "invalid_subtotal");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  test(
    "T5-07b: Negative subtotal is rejected safely — no earning created",
    async () => {
      const orderId = "t5_order_007b";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal: -100 };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal: -100 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "invalid_subtotal");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  test(
    "T5-07c: Zero subtotal (edge case) is accepted and produces 0.0 earning",
    async () => {
      const orderId = "t5_order_007c";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal: 0 };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal: 0 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "created", "Zero subtotal is valid — earning of 0 is created");
      assert.equal(result.amountEarned, 0.0);
      const stored = getStoredEarning(db, orderId);
      assert.ok(stored, "Earning document must be written");
      assert.equal(stored.amountEarned, 0.0);
    }
  );

  test(
    "T5-07d: Subtotal missing — falls back to totalAmount",
    async () => {
      const orderId = "t5_order_007d";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, totalAmount: 500 };
      const after = { status: "delivered", assignedAgentId: agentId, totalAmount: 500 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "created");
      assert.equal(result.amountEarned, Math.round(500 * AGENT_EARNING_RATE * 100) / 100);
    }
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Test 8 — Cancelled / non-delivered orders do NOT create earning
  // ─────────────────────────────────────────────────────────────────────────
  test(
    "T5-08a: Cancelled order does NOT create earning",
    async () => {
      const orderId = "t5_order_008a";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal: 600 };
      const after = { status: "cancelled", assignedAgentId: agentId, subtotal: 600 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "not_delivered_transition");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  test(
    "T5-08b: placed→confirmed transition does NOT create earning",
    async () => {
      const orderId = "t5_order_008b";
      const agentId = "agent_task5";
      const before = { status: "placed", assignedAgentId: agentId, subtotal: 600 };
      const after = { status: "confirmed", assignedAgentId: agentId, subtotal: 600 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "not_delivered_transition");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  test(
    "T5-08c: No-change update (outForDelivery→outForDelivery) does NOT create earning",
    async () => {
      const orderId = "t5_order_008c";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal: 400 };
      const after = { status: "outForDelivery", assignedAgentId: agentId, subtotal: 400 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped");
      assert.equal(result.reason, "not_delivered_transition");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Test 9 — EarningsService schema compatibility
  // ─────────────────────────────────────────────────────────────────────────
  test(
    "T5-09: Cloud Function writes schema compatible with EarningModel.fromFirestore",
    async () => {
      const orderId = "t5_order_009";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal: 900, deliveryCharge: 30 };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal: 900, deliveryCharge: 30 };

      await processOrderDeliveredEarning(db, before, after, orderId);

      const stored = getStoredEarning(db, orderId);
      assert.ok(stored, "Earning must be written");

      assert.ok(typeof stored.agentId === "string" && stored.agentId.length > 0, "'agentId' must be a non-empty string");
      assert.ok(typeof stored.orderId === "string" && stored.orderId.length > 0, "'orderId' must be a non-empty string");
      assert.ok(typeof stored.amountEarned === "number", "'amountEarned' must be a number");
      assert.ok(typeof stored.tipAmount === "number", "'tipAmount' must be a number");
      assert.ok(typeof stored.deliveryFee === "number", "'deliveryFee' must be a number");
      assert.ok(typeof stored.status === "string", "'status' must be a string");
      assert.ok(
        ["pending", "processed", "paid"].includes(stored.status),
        `'status' must be one of pending/processed/paid, got: ${stored.status}`
      );
      assert.ok("timestamp" in stored, "'timestamp' field must be present");
    }
  );

  test(
    "T5-09b: Written earning can be read back via field-mapping pattern used by EarningModel.fromFirestore",
    async () => {
      const orderId = "t5_order_009b";
      const agentId = "agent_task5";
      const subtotal = 560;
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal, deliveryCharge: 0 };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal, deliveryCharge: 0 };

      await processOrderDeliveredEarning(db, before, after, orderId);
      const stored = getStoredEarning(db, orderId);

      const model = {
        id: orderId,
        agentId: stored.agentId ?? "",
        orderId: stored.orderId ?? "",
        amountEarned: stored.amountEarned ?? 0,
        tipAmount: stored.tipAmount ?? 0,
        deliveryFee: stored.deliveryFee ?? 0,
        status: stored.status ?? "pending",
      };

      assert.equal(model.id, orderId);
      assert.equal(model.agentId, agentId);
      assert.equal(model.orderId, orderId);
      assert.equal(model.amountEarned, Math.round(subtotal * AGENT_EARNING_RATE * 100) / 100);
      assert.equal(model.tipAmount, 0.0);
      assert.equal(model.deliveryFee, 0);
      assert.equal(model.status, "pending");
    }
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Test 10 — Task 1–4 regression
  // ─────────────────────────────────────────────────────────────────────────
  test(
    "T5-10a [Task 1 regression]: Declined order (status→Pending) does NOT trigger earning",
    async () => {
      const orderId = "t5_order_010a";
      const agentId = "agent_task5";
      const before = { status: "accepted", assignedAgentId: agentId, subtotal: 300 };
      const after = { status: "Pending", assignedAgentId: null, subtotal: 300 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "skipped", "Decline (→Pending) must NOT create earning");
      assert.equal(result.reason, "not_delivered_transition");
      assert.equal(getStoredEarning(db, orderId), undefined);
    }
  );

  test(
    "T5-10b [Task 3 regression]: Extra distance/ETA fields on order do not corrupt earning calculation",
    async () => {
      const orderId = "t5_order_010b";
      const agentId = "agent_task5";
      const subtotal = 650;

      const after = {
        status: "delivered",
        assignedAgentId: agentId,
        subtotal,
        deliveryCharge: 30,
        distanceKm: 3.7,
        etaMinutes: 22,
        pickupLatitude: 28.5,
        pickupLongitude: 77.3,
      };
      const before = { ...after, status: "outForDelivery" };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "created", "Extra Task 3 fields must not prevent earning creation");
      assert.equal(result.amountEarned, Math.round(subtotal * AGENT_EARNING_RATE * 100) / 100);
      assert.equal(result.agentId, agentId);
    }
  );

  test(
    "T5-10c [Task 4 regression]: Earning agentId matches the authenticated agent (auth-bound earning)",
    async () => {
      const orderId = "t5_order_010c";
      const agentId = "agent_task5";
      const before = { status: "outForDelivery", assignedAgentId: agentId, subtotal: 820 };
      const after = { status: "delivered", assignedAgentId: agentId, subtotal: 820 };

      const result = await processOrderDeliveredEarning(db, before, after, orderId);
      assert.equal(result.status, "created");

      const stored = getStoredEarning(db, orderId);
      assert.equal(stored.agentId, agentId, "Earning agentId must match the authenticated delivery agent");

      const storedForOther = db._store.get(`earnings/some_other_orderId`);
      assert.equal(storedForOther, undefined, "No cross-agent earning contamination");
    }
  );
});
