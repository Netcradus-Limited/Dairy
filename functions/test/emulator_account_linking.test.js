process.env.GCLOUD_PROJECT = "sawariya-7efd4";
process.env.GOOGLE_CLOUD_PROJECT = "sawariya-7efd4";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8088";

const test = require("node:test");
const assert = require("node:assert");
const { spawn } = require("node:child_process");
const http = require("node:http");
const path = require("node:path");
const admin = require("firebase-admin");

const {
  processLinkStaffAccount,
  processLinkDeliveryAgentAccount,
} = require("../index.js");

const EMULATOR_PORT = 8088;
const EMULATOR_HOST = `127.0.0.1:${EMULATOR_PORT}`;
const PROJECT_ID = "sawariya-7efd4";
const EMULATOR_JAR = "C:\\Users\\Dell\\.cache\\firebase\\emulators\\cloud-firestore-emulator-v1.22.0.jar";
const RULES_PATH = path.resolve(__dirname, "../../firestore.rules");

let emulatorProc = null;
let db = null;

// Helper to wait for emulator port readiness
async function waitForEmulator(timeoutMs = 15000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      await new Promise((resolve, reject) => {
        const req = http.get(`http://${EMULATOR_HOST}/`, (res) => {
          resolve(res.statusCode);
        });
        req.on("error", reject);
        req.setTimeout(1000, () => {
          req.destroy();
          reject(new Error("Timeout"));
        });
      });
      return true;
    } catch (_) {
      await new Promise((r) => setTimeout(r, 400));
    }
  }
  throw new Error("Firestore Emulator failed to start in time");
}

// Helper to clear emulator database between test scenarios
async function clearEmulatorData() {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
      { method: "DELETE" },
      (res) => {
        resolve(res.statusCode);
      }
    );
    req.on("error", reject);
    req.end();
  });
}

// REST helper to test Firestore Rules as an authenticated user
async function queryAsUser(tokenObj, pathStr, method = "GET", bodyData = null) {
  return new Promise((resolve) => {
    // Generate an unsigned mock token for Firestore Emulator (sub = uid)
    const header = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString("base64url");
    const payload = Buffer.from(
      JSON.stringify({
        sub: tokenObj.uid,
        user_id: tokenObj.uid,
        phone_number: tokenObj.phone_number || "",
        ...tokenObj,
        iss: `https://securetoken.google.com/${PROJECT_ID}`,
        aud: PROJECT_ID,
        auth_time: Math.floor(Date.now() / 1000),
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 3600,
      })
    ).toString("base64url");
    const mockJwt = `${header}.${payload}.`;

    const options = {
      hostname: "127.0.0.1",
      port: EMULATOR_PORT,
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${pathStr}`,
      method: method,
      headers: {
        Authorization: `Bearer ${mockJwt}`,
        "Content-Type": "application/json",
      },
    };

    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        let json = null;
        try {
          json = JSON.parse(data);
        } catch (_) {}
        resolve({ status: res.statusCode, data: json });
      });
    });
    req.on("error", (err) => resolve({ status: 500, error: err }));
    if (bodyData) {
      req.write(JSON.stringify(bodyData));
    }
    req.end();
  });
}

test.before(async () => {
  console.log(`[Emulator Test] Starting Cloud Firestore Emulator on port ${EMULATOR_PORT}...`);
  emulatorProc = spawn(
    "java",
    [
      "-jar",
      EMULATOR_JAR,
      "--host",
      "127.0.0.1",
      "--port",
      String(EMULATOR_PORT),
      "--rules",
      RULES_PATH,
    ],
    { stdio: "ignore" }
  );

  await waitForEmulator();
  console.log("[Emulator Test] Firestore Emulator is UP and listening with production firestore.rules.");

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  db = admin.firestore();
});

test.after(async () => {
  if (emulatorProc) {
    console.log("[Emulator Test] Shutting down Firestore Emulator...");
    emulatorProc.kill();
  }
});

test("BUG-004 Official Firebase Emulator Suite: 17 Concurrency & Security Tests", async (t) => {
  t.beforeEach(async () => {
    await clearEmulatorData();
  });

  // TEST 1: Two separate UIDs attempting to claim the same staff record concurrently
  await t.test("1. Two separate UIDs attempting to claim the same staff record concurrently", async () => {
    const phone = "+919876500001";
    await db.collection("admins").doc("pre_admin_01").set({
      phone: phone,
      name: "Concurrent Admin",
      role: "admin",
      status: "Active",
      isLinked: false,
    });

    const results = await Promise.allSettled([
      processLinkStaffAccount(db, { uid: "uid_staff_alpha", phoneNumber: phone }),
      processLinkStaffAccount(db, { uid: "uid_staff_beta", phoneNumber: phone }),
    ]);

    const fulfilled = results.filter((r) => r.status === "fulfilled");
    const rejected = results.filter((r) => r.status === "rejected");

    assert.strictEqual(fulfilled.length, 1, "Exactly ONE concurrent claim must succeed");
    assert.strictEqual(rejected.length, 1, "The competing concurrent claim must be rejected");
    assert.match(rejected[0].reason.message, /already-exists|already linked/i);

    // Verify reservation claim
    const claimDoc = await db.collection("_staff_phone_claims").doc("9876500001").get();
    assert.strictEqual(claimDoc.exists, true);
    assert.strictEqual(claimDoc.data().uid, fulfilled[0].value ? claimDoc.data().uid : null);
  });

  // TEST 2: Two separate UIDs attempting to claim the same delivery-agent record concurrently
  await t.test("2. Two separate UIDs attempting to claim the same delivery-agent record concurrently", async () => {
    const phone = "+919876500002";
    await db.collection("delivery_agents").doc("pre_del_01").set({
      phone: phone,
      name: "Rider One",
      role: "delivery",
      status: "Active",
      isLinked: false,
    });

    const results = await Promise.allSettled([
      processLinkDeliveryAgentAccount(db, { uid: "uid_rider_alpha", phoneNumber: phone }),
      processLinkDeliveryAgentAccount(db, { uid: "uid_rider_beta", phoneNumber: phone }),
    ]);

    const fulfilled = results.filter((r) => r.status === "fulfilled");
    const rejected = results.filter((r) => r.status === "rejected");

    assert.strictEqual(fulfilled.length, 1, "Exactly ONE delivery claim must succeed");
    assert.strictEqual(rejected.length, 1, "The competing delivery claim must be rejected");
  });

  // TEST 3: Admin and delivery-agent records with the same normalized phone (Cross-role conflict)
  await t.test("3. Admin and delivery-agent records with the same normalized phone", async () => {
    const phone = "+919876500003";
    await db.collection("admins").doc("pre_admin_03").set({
      phone: phone,
      role: "admin",
      status: "Active",
    });
    // Staff claims first
    await processLinkStaffAccount(db, { uid: "uid_staff_03", phoneNumber: phone });

    // Competing delivery agent with different UID attempts to claim same phone
    await db.collection("delivery_agents").doc("pre_del_03").set({
      phone: phone,
      role: "delivery",
      status: "Active",
    });

    await assert.rejects(
      async () => {
        await processLinkDeliveryAgentAccount(db, { uid: "uid_intruder_del", phoneNumber: phone });
      },
      /already claimed by a staff account/i
    );
  });

  // TEST 4: Duplicate provisioning records (Ambiguity prevention)
  await t.test("4. Duplicate provisioning records with conflicting roles", async () => {
    const phone = "+919876500004";
    await db.collection("admins").doc("prov_1").set({
      phone: phone,
      role: "manager",
      status: "Active",
    });
    await db.collection("admins").doc("prov_2").set({
      phone: phone,
      role: "dispatcher",
      status: "Active",
    });

    await assert.rejects(
      async () => {
        await processLinkStaffAccount(db, { uid: "uid_user_04", phoneNumber: phone });
      },
      /Ambiguous staff provisioning records/i
    );
  });

  // TEST 5: Existing claim owned by another UID (UID takeover rejection)
  await t.test("5. Existing claim owned by another UID rejects takeover", async () => {
    const phone = "+919876500005";
    await db.collection("_staff_phone_claims").doc("9876500005").set({
      uid: "legitimate_owner_uid",
      phone: "9876500005",
    });

    await assert.rejects(
      async () => {
        await processLinkStaffAccount(db, { uid: "attacker_uid", phoneNumber: phone });
      },
      /UID takeover rejected/i
    );
  });

  // TEST 6: Revoked account retry (rejects deactivated/suspended staff)
  await t.test("6. Revoked account retry rejects deactivated staff", async () => {
    const phone = "+919876500006";
    await db.collection("admins").doc("revoked_staff").set({
      phone: phone,
      role: "admin",
      status: "Inactive",
    });

    await assert.rejects(
      async () => {
        await processLinkStaffAccount(db, { uid: "revoked_uid", phoneNumber: phone });
      },
      /not active/i
    );
  });

  // TEST 7: Inactive account
  await t.test("7. Inactive delivery agent account is rejected", async () => {
    const phone = "+919876500007";
    await db.collection("delivery_agents").doc("del_inactive").set({
      phone: phone,
      role: "delivery",
      status: "Suspended",
    });

    await assert.rejects(
      async () => {
        await processLinkDeliveryAgentAccount(db, { uid: "uid_07", phoneNumber: phone });
      },
      /not active/i
    );
  });

  // TEST 8: Invalid role rejection
  await t.test("8. Invalid or escalated role in provisioning doc is rejected", async () => {
    const phone = "+919876500008";
    await db.collection("admins").doc("bad_role").set({
      phone: phone,
      role: "database_root",
      status: "Active",
    });

    await assert.rejects(
      async () => {
        await processLinkStaffAccount(db, { uid: "uid_08", phoneNumber: phone });
      },
      /Unauthorized role/i
    );
  });

  // TEST 9: Missing phone claim
  await t.test("9. Missing phone claim from Auth is rejected", async () => {
    await assert.rejects(
      async () => {
        await processLinkStaffAccount(db, { uid: "uid_no_phone", phoneNumber: "" });
      },
      /verified phone number claim/i
    );
  });

  // TEST 10: Client-supplied phone spoofing (empty/invalid normalized phone)
  await t.test("10. Malformed or unverified phone number is rejected", async () => {
    await assert.rejects(
      async () => {
        await processLinkStaffAccount(db, { uid: "uid_10", phoneNumber: "abc123" });
      },
      /Invalid phone number format/i
    );
  });

  // TEST 11: Retry after successful commit (Idempotent retry)
  await t.test("11. Retry after successful commit returns existing role without errors", async () => {
    const phone = "+919876500011";
    await db.collection("admins").doc("prov_11").set({
      phone: phone,
      role: "dispatcher",
      roleTitle: "Route Dispatcher",
      status: "Active",
    });

    const res1 = await processLinkStaffAccount(db, { uid: "uid_11", phoneNumber: phone });
    assert.strictEqual(res1.status, "linked");
    assert.strictEqual(res1.role, "dispatcher");

    const res2 = await processLinkStaffAccount(db, { uid: "uid_11", phoneNumber: phone });
    assert.strictEqual(res2.status, "already_linked");
    assert.strictEqual(res2.role, "dispatcher");
  });

  // TEST 12: Firestore customer enumeration denial (Rule: allow list: if isSuperAdmin() || hasPermission('manageStaff'))
  await t.test("12. Ordinary customer cannot list or enumerate admins collection", async () => {
    // Seed an admin record
    await db.collection("admins").doc("adm_secret").set({
      name: "Secret Admin",
      phone: "+919999999999",
      role: "admin",
    });

    // Customer attempts to list admins collection
    const res = await queryAsUser({ uid: "customer_intruder", role: "customer" }, "admins");
    assert.strictEqual(res.status, 403, "Customer must be denied listing admins (HTTP 403 Permission Denied)");
  });

  // TEST 13: Unauthorized privileged document reads
  await t.test("13. Ordinary customer cannot read arbitrary admin document", async () => {
    await db.collection("admins").doc("adm_target").set({
      name: "Target Admin",
      phone: "+919999999999",
      role: "superadmin",
    });

    const res = await queryAsUser({ uid: "customer_intruder", role: "customer" }, "admins/adm_target");
    assert.strictEqual(res.status, 403, "Customer cannot read arbitrary admin document");
  });

  // TEST 14: Unauthorized role modification on users collection
  await t.test("14. Customer cannot escalate own role to admin on users profile", async () => {
    const uid = "cust_attacker";
    await db.collection("users").doc(uid).set({
      uid: uid,
      role: "customer",
      name: "Attacker",
    });

    // Attempt PATCH mutating 'role' to 'admin'
    const patchPayload = {
      fields: {
        role: { stringValue: "admin" },
      },
    };
    const res = await queryAsUser(
      { uid: uid, role: "customer" },
      `users/${uid}?updateMask.fieldPaths=role`,
      "PATCH",
      patchPayload
    );
    assert.strictEqual(res.status, 403, "Customer mutating role must be rejected by rules");
  });

  // TEST 15: Valid admin access to own admin document
  await t.test("15. Verified admin can read their own admin document", async () => {
    const uid = "real_admin_uid";
    await db.collection("admins").doc(uid).set({
      uid: uid,
      role: "admin",
      status: "Active",
    });

    const res = await queryAsUser({ uid: uid, role: "admin" }, `admins/${uid}`);
    assert.strictEqual(res.status, 200, "Admin can read own admin record (HTTP 200)");
  });

  // TEST 16: Valid delivery-agent access
  await t.test("16. Delivery agent can read own profile document", async () => {
    const uid = "real_driver_uid";
    await db.collection("users").doc(uid).set({ uid: uid, role: "delivery" });
    await db.collection("delivery_agents").doc(uid).set({
      uid: uid,
      role: "delivery",
      status: "Active",
    });

    const res = await queryAsUser({ uid: uid, role: "delivery" }, `delivery_agents/${uid}`);
    assert.strictEqual(res.status, 200, "Delivery agent can read own profile (HTTP 200)");
  });

  // TEST 17: Assigned-order access restriction
  await t.test("17. Unrelated customer cannot read delivery agent private profile", async () => {
    const driverUid = "driver_private_uid";
    await db.collection("users").doc(driverUid).set({ uid: driverUid, role: "delivery" });
    await db.collection("delivery_agents").doc(driverUid).set({
      uid: driverUid,
      role: "delivery",
      status: "Active",
    });

    // Customer without active assigned order attempts to read driver
    const res = await queryAsUser({ uid: "unrelated_customer", role: "customer" }, `delivery_agents/${driverUid}`);
    assert.strictEqual(res.status, 403, "Unrelated customer cannot read delivery agent doc");
  });
});
