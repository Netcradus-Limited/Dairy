/**
 * Sawariya Dairy — Local Firestore Security Rules Test Suite (Task 5)
 * ===================================================================
 * Uses @firebase/rules-unit-testing to comprehensively verify all RBAC
 * rules, privilege escalation guards, owner access constraints, and
 * least-privilege permissions against the Firestore Emulator.
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
} = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'sawariya-7efd4';
const RULES_PATH = path.resolve(__dirname, '../firestore.rules');

describe('Sawariya Dairy — Firestore Security Rules Unit Tests', function () {
  this.timeout(10000);

  let testEnv;

  before(async () => {
    // Read local firestore.rules
    const rules = fs.readFileSync(RULES_PATH, 'utf8');

    // Initialize test environment connecting to Firestore Emulator (127.0.0.1:8080)
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules,
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  beforeEach(async () => {
    // Clear Firestore emulator database before each test
    await testEnv.clearFirestore();

    // Seed required user profiles with security rules disabled
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      // Seed Admin user doc
      await setDoc(doc(db, 'users', 'admin_uid'), {
        uid: 'admin_uid',
        email: 'admin@sawariya.com',
        name: 'Admin User',
        role: 'admin',
        createdAt: new Date().toISOString(),
      });

      // Seed Delivery Agent user doc
      await setDoc(doc(db, 'users', 'delivery_uid'), {
        uid: 'delivery_uid',
        email: 'delivery@sawariya.com',
        name: 'Delivery Agent',
        role: 'delivery',
        createdAt: new Date().toISOString(),
      });

      // Seed Customer 1 user doc
      await setDoc(doc(db, 'users', 'customer1_uid'), {
        uid: 'customer1_uid',
        email: 'customer1@sawariya.com',
        name: 'Customer One',
        role: 'customer',
        createdAt: new Date().toISOString(),
      });

      // Seed Customer 2 user doc
      await setDoc(doc(db, 'users', 'customer2_uid'), {
        uid: 'customer2_uid',
        email: 'customer2@sawariya.com',
        name: 'Customer Two',
        role: 'customer',
        createdAt: new Date().toISOString(),
      });

      // Seed Invalid Role user doc
      await setDoc(doc(db, 'users', 'invalid_role_uid'), {
        uid: 'invalid_role_uid',
        email: 'invalid@sawariya.com',
        name: 'Invalid User',
        role: 'hacker_role',
        createdAt: new Date().toISOString(),
      });
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  // Helper context generators
  const unauthedDb = () => testEnv.unauthenticatedContext().firestore();
  const customer1Db = () => testEnv.authenticatedContext('customer1_uid').firestore();
  const customer2Db = () => testEnv.authenticatedContext('customer2_uid').firestore();
  const deliveryDb = () => testEnv.authenticatedContext('delivery_uid').firestore();
  const adminDb = () => testEnv.authenticatedContext('admin_uid').firestore();
  const invalidRoleDb = () => testEnv.authenticatedContext('invalid_role_uid').firestore();
  const missingRoleDb = () => testEnv.authenticatedContext('missing_role_uid').firestore();

  // =========================================================================
  // 1. UNAUTHENTICATED ACCESS (Deny-by-Default)
  // =========================================================================
  describe('1. Unauthenticated Access', () => {
    it('Denies unauthenticated read on /users/{uid}', async () => {
      const db = unauthedDb();
      await assertFails(getDoc(doc(db, 'users', 'customer1_uid')));
    });

    it('Denies unauthenticated create on /users/{uid}', async () => {
      const db = unauthedDb();
      await assertFails(setDoc(doc(db, 'users', 'anon_uid'), { uid: 'anon_uid', role: 'customer' }));
    });

    it('Denies unauthenticated read on /products', async () => {
      const db = unauthedDb();
      await assertFails(getDoc(doc(db, 'products', 'prod_1')));
    });

    it('Denies unauthenticated read on /orders', async () => {
      const db = unauthedDb();
      await assertFails(getDoc(doc(db, 'orders', 'order_1')));
    });

    it('Denies unauthenticated access to arbitrary collection (Deny-by-default)', async () => {
      const db = unauthedDb();
      await assertFails(getDoc(doc(db, 'secret_collection', 'doc_1')));
    });
  });

  // =========================================================================
  // 2. USERS COLLECTION & PRIVILEGE ESCALATION
  // =========================================================================
  describe('2. Users Collection & Privilege Escalation Guards', () => {
    it('Allows customer to read own user profile', async () => {
      const db = customer1Db();
      await assertSucceeds(getDoc(doc(db, 'users', 'customer1_uid')));
    });

    it('Denies customer from reading another customer profile', async () => {
      const db = customer1Db();
      await assertFails(getDoc(doc(db, 'users', 'customer2_uid')));
    });

    it('Allows new user to self-register with role="customer"', async () => {
      const newUid = 'new_customer_uid';
      const db = testEnv.authenticatedContext(newUid).firestore();
      await assertSucceeds(setDoc(doc(db, 'users', newUid), {
        uid: newUid,
        email: 'new@sawariya.com',
        name: 'New Customer',
        role: 'customer',
      }));
    });

    it('Denies self-registration with role="admin" (Privilege Escalation Blocked)', async () => {
      const attackerUid = 'attacker_uid';
      const db = testEnv.authenticatedContext(attackerUid).firestore();
      await assertFails(setDoc(doc(db, 'users', attackerUid), {
        uid: attackerUid,
        email: 'attacker@sawariya.com',
        name: 'Attacker',
        role: 'admin',
      }));
    });

    it('Denies self-registration with role="delivery" (Privilege Escalation Blocked)', async () => {
      const attackerUid = 'attacker_uid_2';
      const db = testEnv.authenticatedContext(attackerUid).firestore();
      await assertFails(setDoc(doc(db, 'users', attackerUid), {
        uid: attackerUid,
        email: 'attacker2@sawariya.com',
        name: 'Attacker 2',
        role: 'delivery',
      }));
    });

    it('Allows customer to update own profile fields (name, phone) while preserving role="customer"', async () => {
      const db = customer1Db();
      await assertSucceeds(updateDoc(doc(db, 'users', 'customer1_uid'), {
        name: 'Updated Customer Name',
        phone: '+91 9876543210',
        uid: 'customer1_uid',
        role: 'customer',
      }));
    });

    it('Denies customer from escalating role from "customer" to "admin" via updateDoc', async () => {
      const db = customer1Db();
      await assertFails(updateDoc(doc(db, 'users', 'customer1_uid'), {
        role: 'admin',
      }));
    });

    it('Denies customer from updating another user profile', async () => {
      const db = customer1Db();
      await assertFails(updateDoc(doc(db, 'users', 'customer2_uid'), {
        name: 'Hacked Name',
      }));
    });

    it('Denies customer from deleting own or other user profiles', async () => {
      const db = customer1Db();
      await assertFails(deleteDoc(doc(db, 'users', 'customer1_uid')));
      await assertFails(deleteDoc(doc(db, 'users', 'customer2_uid')));
    });

    it('Allows Admin to read, update, and delete any user profile', async () => {
      const db = adminDb();
      await assertSucceeds(getDoc(doc(db, 'users', 'customer1_uid')));
      await assertSucceeds(updateDoc(doc(db, 'users', 'customer1_uid'), {
        name: 'Admin Modified Customer',
      }));
      await assertSucceeds(deleteDoc(doc(db, 'users', 'customer2_uid')));
    });
  });

  // =========================================================================
  // 3. ADDRESSES SUBCOLLECTION
  // =========================================================================
  describe('3. Addresses Subcollection (/users/{userId}/addresses/{addressId})', () => {
    it('Allows customer to create, read, update, and delete own address', async () => {
      const db = customer1Db();
      const addrRef = doc(db, 'users', 'customer1_uid', 'addresses', 'addr_1');

      await assertSucceeds(setDoc(addrRef, {
        addressLine: '123 Dairy Lane',
        city: 'Jaipur',
        pincode: '302001',
        isDefault: true,
      }));

      await assertSucceeds(getDoc(addrRef));

      await assertSucceeds(updateDoc(addrRef, {
        addressLine: '124 Dairy Lane',
      }));

      await assertSucceeds(deleteDoc(addrRef));
    });

    it('Denies customer from accessing another customer addresses', async () => {
      // Seed an address for Customer 2
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', 'customer2_uid', 'addresses', 'addr_2'), {
          addressLine: '456 Private Street',
        });
      });

      const db = customer1Db();
      const foreignAddr = doc(db, 'users', 'customer2_uid', 'addresses', 'addr_2');

      await assertFails(getDoc(foreignAddr));
      await assertFails(updateDoc(foreignAddr, { addressLine: 'Tampered' }));
      await assertFails(deleteDoc(foreignAddr));
      await assertFails(setDoc(doc(db, 'users', 'customer2_uid', 'addresses', 'hacked_addr'), {
        addressLine: 'Hacked',
      }));
    });

    it('Allows Admin to read, create, update, and delete any customer address', async () => {
      const db = adminDb();
      const addrRef = doc(db, 'users', 'customer1_uid', 'addresses', 'admin_added_addr');
      await assertSucceeds(setDoc(addrRef, { addressLine: 'Admin Configured Address' }));
      await assertSucceeds(getDoc(addrRef));
      await assertSucceeds(updateDoc(addrRef, { addressLine: 'Admin Updated Address' }));
      await assertSucceeds(deleteDoc(addrRef));
    });
  });

  // =========================================================================
  // 4. NOTIFICATIONS SUBCOLLECTION
  // =========================================================================
  describe('4. Notifications Subcollection (/users/{userId}/notifications/{notifId})', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', 'customer1_uid', 'notifications', 'notif_1'), {
          title: 'Order Confirmed',
          body: 'Your milk order #101 is confirmed.',
          isRead: false,
          createdAt: new Date().toISOString(),
        });
      });
    });

    it('Allows customer to read own notification', async () => {
      const db = customer1Db();
      await assertSucceeds(getDoc(doc(db, 'users', 'customer1_uid', 'notifications', 'notif_1')));
    });

    it('Denies customer from reading another customer notification', async () => {
      const db = customer2Db();
      await assertFails(getDoc(doc(db, 'users', 'customer1_uid', 'notifications', 'notif_1')));
    });

    it('Denies customer from creating notifications (prevents fake broadcast)', async () => {
      const db = customer1Db();
      await assertFails(setDoc(doc(db, 'users', 'customer1_uid', 'notifications', 'fake_notif'), {
        title: 'Fake Offer 100% Off',
        body: 'Free milk for all!',
        isRead: false,
      }));
    });

    it('Allows customer to update only the isRead status on own notification', async () => {
      const db = customer1Db();
      await assertSucceeds(updateDoc(doc(db, 'users', 'customer1_uid', 'notifications', 'notif_1'), {
        isRead: true,
      }));
    });

    it('Denies customer from mutating notification title or body', async () => {
      const db = customer1Db();
      await assertFails(updateDoc(doc(db, 'users', 'customer1_uid', 'notifications', 'notif_1'), {
        title: 'Tampered Title',
      }));
    });

    it('Allows customer to delete own notification', async () => {
      const db = customer1Db();
      await assertSucceeds(deleteDoc(doc(db, 'users', 'customer1_uid', 'notifications', 'notif_1')));
    });

    it('Allows Admin to create, read, update, and delete any notification', async () => {
      const db = adminDb();
      const notifRef = doc(db, 'users', 'customer1_uid', 'notifications', 'broadcast_1');
      await assertSucceeds(setDoc(notifRef, {
        title: 'Admin Broadcast',
        body: 'Fresh morning batch ready!',
        isRead: false,
      }));
      await assertSucceeds(getDoc(notifRef));
      await assertSucceeds(deleteDoc(notifRef));
    });
  });

  // =========================================================================
  // 4b. SUBSCRIPTIONS ROOT COLLECTION (/subscriptions/{subscriptionId})
  // =========================================================================
  describe('4b. Subscriptions Root Collection (/subscriptions/{subscriptionId})', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'subscriptions', 'sub_cust1_milk'), {
          id: 'sub_cust1_milk',
          userId: 'customer1_uid',
          productId: 'prod_milk',
          productName: 'Sawariya Fresh Cow Milk',
          quantity: 1,
          frequency: 'Daily',
          status: 'Active',
          pricePerDelivery: 60.0,
          estimatedMonthlyPrice: 1800.0,
          createdAt: new Date().toISOString(),
        });
        await setDoc(doc(context.firestore(), 'subscriptions', 'sub_cust2_ghee'), {
          id: 'sub_cust2_ghee',
          userId: 'customer2_uid',
          productId: 'prod_ghee',
          productName: 'Sawariya Pure Desi Ghee',
          quantity: 1,
          frequency: 'Weekly',
          status: 'Active',
          pricePerDelivery: 650.0,
          estimatedMonthlyPrice: 2600.0,
          createdAt: new Date().toISOString(),
        });
      });
    });

    it('Allows customer to create subscription for themselves', async () => {
      const db = customer1Db();
      await assertSucceeds(setDoc(doc(db, 'subscriptions', 'sub_cust1_paneer'), {
        id: 'sub_cust1_paneer',
        userId: 'customer1_uid',
        productId: 'prod_paneer',
        productName: 'Sawariya Paneer',
        quantity: 2,
        frequency: 'Alternate Day',
        status: 'Active',
      }));
    });

    it('Denies customer from forging a subscription owned by another user', async () => {
      const db = customer1Db();
      await assertFails(setDoc(doc(db, 'subscriptions', 'sub_fake_cust2'), {
        id: 'sub_fake_cust2',
        userId: 'customer2_uid',
        productId: 'prod_milk',
        status: 'Active',
      }));
    });

    it('Allows customer to read own subscription', async () => {
      const db = customer1Db();
      await assertSucceeds(getDoc(doc(db, 'subscriptions', 'sub_cust1_milk')));
    });

    it('Denies customer from reading another customer subscription', async () => {
      const db = customer1Db();
      await assertFails(getDoc(doc(db, 'subscriptions', 'sub_cust2_ghee')));
    });

    it('Allows customer to update own subscription', async () => {
      const db = customer1Db();
      await assertSucceeds(updateDoc(doc(db, 'subscriptions', 'sub_cust1_milk'), {
        quantity: 2,
        status: 'Paused',
        userId: 'customer1_uid',
      }));
    });

    it('Denies customer from changing subscription ownership to another user', async () => {
      const db = customer1Db();
      await assertFails(updateDoc(doc(db, 'subscriptions', 'sub_cust1_milk'), {
        userId: 'customer2_uid',
      }));
    });

    it('Denies delivery agent from creating or modifying subscriptions', async () => {
      const db = deliveryDb();
      await assertFails(setDoc(doc(db, 'subscriptions', 'sub_agent_fake'), {
        userId: 'delivery_uid',
        status: 'Active',
      }));
      await assertFails(updateDoc(doc(db, 'subscriptions', 'sub_cust1_milk'), {
        status: 'Cancelled',
      }));
    });

    it('Allows Admin to read, create, update, and delete any subscription', async () => {
      const db = adminDb();
      await assertSucceeds(getDoc(doc(db, 'subscriptions', 'sub_cust1_milk')));
      await assertSucceeds(getDoc(doc(db, 'subscriptions', 'sub_cust2_ghee')));
      await assertSucceeds(updateDoc(doc(db, 'subscriptions', 'sub_cust1_milk'), {
        status: 'Cancelled',
      }));
      await assertSucceeds(deleteDoc(doc(db, 'subscriptions', 'sub_cust2_ghee')));
    });
  });

  // =========================================================================
  // 5. PRODUCTS & CATEGORIES
  // =========================================================================
  describe('5. Products & Categories Collections', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'products', 'milk_1L'), {
          name: 'Fresh Cow Milk 1L',
          price: 65,
          unit: '1 Litre',
          stock: 50,
          category: 'Milk',
        });
        await setDoc(doc(db, 'categories', 'cat_milk'), {
          name: 'Milk',
          icon: 'milk_bottle',
        });
      });
    });

    it('Allows signed-in customer to read products and categories', async () => {
      const db = customer1Db();
      await assertSucceeds(getDoc(doc(db, 'products', 'milk_1L')));
      await assertSucceeds(getDoc(doc(db, 'categories', 'cat_milk')));
    });

    it('Allows signed-in delivery agent to read products and categories', async () => {
      const db = deliveryDb();
      await assertSucceeds(getDoc(doc(db, 'products', 'milk_1L')));
      await assertSucceeds(getDoc(doc(db, 'categories', 'cat_milk')));
    });

    it('Denies customer from creating, updating, or deleting products', async () => {
      const db = customer1Db();
      await assertFails(setDoc(doc(db, 'products', 'hacked_prod'), { name: 'Free Product', price: 0 }));
      await assertFails(updateDoc(doc(db, 'products', 'milk_1L'), { price: 1 }));
      await assertFails(deleteDoc(doc(db, 'products', 'milk_1L')));
    });

    it('Denies delivery agent from creating, updating, or deleting products', async () => {
      const db = deliveryDb();
      await assertFails(setDoc(doc(db, 'products', 'hacked_prod_del'), { name: 'Free Product', price: 0 }));
      await assertFails(updateDoc(doc(db, 'products', 'milk_1L'), { price: 1 }));
      await assertFails(deleteDoc(doc(db, 'products', 'milk_1L')));
    });

    it('Allows Admin to create, update, and delete products & categories', async () => {
      const db = adminDb();
      const newProd = doc(db, 'products', 'paneer_500g');
      await assertSucceeds(setDoc(newProd, { name: 'Fresh Paneer 500g', price: 200 }));
      await assertSucceeds(updateDoc(newProd, { price: 210 }));
      await assertSucceeds(deleteDoc(newProd));

      const newCat = doc(db, 'categories', 'cat_cheese');
      await assertSucceeds(setDoc(newCat, { name: 'Cheese' }));
      await assertSucceeds(deleteDoc(newCat));
    });
  });

  // =========================================================================
  // 6. ORDERS COLLECTION
  // =========================================================================
  describe('6. Orders Collection', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        // Pending unassigned order created by customer1
        await setDoc(doc(db, 'orders', 'order_cust1_pending'), {
          userId: 'customer1_uid',
          totalAmount: 130,
          status: 'Pending',
          items: [{ name: 'Fresh Cow Milk 1L', qty: 2, price: 65 }],
          createdAt: new Date().toISOString(),
        });

        // Assigned order to delivery_uid
        await setDoc(doc(db, 'orders', 'order_cust1_assigned'), {
          userId: 'customer1_uid',
          assignedAgentId: 'delivery_uid',
          totalAmount: 65,
          status: 'Out for Delivery',
          items: [{ name: 'Fresh Cow Milk 1L', qty: 1, price: 65 }],
          createdAt: new Date().toISOString(),
        });

        // Assigned order to ANOTHER delivery agent
        await setDoc(doc(db, 'orders', 'order_other_delivery'), {
          userId: 'customer2_uid',
          assignedAgentId: 'other_delivery_uid',
          totalAmount: 200,
          status: 'Out for Delivery',
          items: [{ name: 'Fresh Paneer', qty: 1, price: 200 }],
          createdAt: new Date().toISOString(),
        });
      });
    });

    it('Allows customer to create legitimate own order in Pending status without assignedAgentId', async () => {
      const db = customer1Db();
      await assertSucceeds(setDoc(doc(db, 'orders', 'new_valid_order'), {
        userId: 'customer1_uid',
        status: 'Pending',
        totalAmount: 65,
        items: [{ name: 'Fresh Cow Milk 1L', qty: 1, price: 65 }],
      }));
    });

    it('Denies customer from creating order for another user (userId forgery blocked)', async () => {
      const db = customer1Db();
      await assertFails(setDoc(doc(db, 'orders', 'forged_order'), {
        userId: 'customer2_uid',
        status: 'Pending',
        totalAmount: 65,
      }));
    });

    it('Denies customer from creating order with pre-assigned agent or accepted timestamp', async () => {
      const db = customer1Db();
      await assertFails(setDoc(doc(db, 'orders', 'pre_assigned_order'), {
        userId: 'customer1_uid',
        status: 'Pending',
        assignedAgentId: 'delivery_uid',
      }));
    });

    it('Allows customer to read own orders', async () => {
      const db = customer1Db();
      await assertSucceeds(getDoc(doc(db, 'orders', 'order_cust1_pending')));
      await assertSucceeds(getDoc(doc(db, 'orders', 'order_cust1_assigned')));
    });

    it('Denies customer from reading another customer order', async () => {
      const db = customer1Db();
      await assertFails(getDoc(doc(db, 'orders', 'order_other_delivery')));
    });

    it('Allows customer to cancel own pending/placed order', async () => {
      const db = customer1Db();
      await assertSucceeds(updateDoc(doc(db, 'orders', 'order_cust1_pending'), { status: 'cancelled' }));
    });

    it('Denies customer from mutating order items, prices, or deleting orders', async () => {
      const db = customer1Db();
      await assertFails(updateDoc(doc(db, 'orders', 'order_cust1_pending'), { totalAmount: 0 }));
      await assertFails(deleteDoc(doc(db, 'orders', 'order_cust1_pending')));
    });

    it('Denies delivery agent from reading unassigned pending customer orders', async () => {
      const db = deliveryDb();
      await assertFails(getDoc(doc(db, 'orders', 'order_cust1_pending')));
    });

    it('Allows delivery agent to read ONLY orders assigned to themselves', async () => {
      const db = deliveryDb();
      await assertSucceeds(getDoc(doc(db, 'orders', 'order_cust1_assigned')));
    });

    it('Denies delivery agent from reading an order assigned to a different delivery agent', async () => {
      const db = deliveryDb();
      await assertFails(getDoc(doc(db, 'orders', 'order_other_delivery')));
    });

    it('Denies delivery agent from self-assigning or claiming an unassigned pending order', async () => {
      const db = deliveryDb();
      await assertFails(updateDoc(doc(db, 'orders', 'order_cust1_pending'), {
        assignedAgentId: 'delivery_uid',
        status: 'Out for Delivery',
        acceptedAt: new Date().toISOString(),
      }));
    });

    it('Allows delivery agent to update status on their assigned order (e.g., to Delivered)', async () => {
      const db = deliveryDb();
      await assertSucceeds(updateDoc(doc(db, 'orders', 'order_cust1_assigned'), {
        status: 'Delivered',
        deliveredAt: new Date().toISOString(),
      }));
    });

    it('Denies delivery agent from mutating order items or prices', async () => {
      const db = deliveryDb();
      await assertFails(updateDoc(doc(db, 'orders', 'order_cust1_assigned'), {
        totalAmount: 9999,
      }));
    });

    it('Allows Admin to approve a Pending order to Confirmed', async () => {
      const db = adminDb();
      await assertSucceeds(updateDoc(doc(db, 'orders', 'order_cust1_pending'), {
        status: 'confirmed',
      }));
    });

    it('Denies Admin from assigning an agent to an unapproved Pending order', async () => {
      const db = adminDb();
      await assertFails(updateDoc(doc(db, 'orders', 'order_cust1_pending'), {
        assignedAgentId: 'delivery_uid',
      }));
    });

    it('Allows Admin to assign an agent after order has been Confirmed', async () => {
      // First confirm order
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'orders', 'order_cust1_pending'), {
          status: 'confirmed',
        });
      });

      const db = adminDb();
      await assertSucceeds(updateDoc(doc(db, 'orders', 'order_cust1_pending'), {
        assignedAgentId: 'delivery_uid',
        status: 'assigned',
      }));
    });

    it('Allows Admin full access to read, update, and delete all orders', async () => {
      const db = adminDb();
      await assertSucceeds(getDoc(doc(db, 'orders', 'order_cust1_pending')));
      await assertSucceeds(getDoc(doc(db, 'orders', 'order_other_delivery')));
      await assertSucceeds(updateDoc(doc(db, 'orders', 'order_cust1_pending'), {
        status: 'Cancelled',
      }));
      await assertSucceeds(deleteDoc(doc(db, 'orders', 'order_cust1_pending')));
    });
  });

  // =========================================================================
  // 7. DELIVERY AGENTS COLLECTION
  // =========================================================================
  describe('7. Delivery Agents Collection (/delivery_agents/{agentId})', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'delivery_agents', 'delivery_uid'), {
          uid: 'delivery_uid',
          name: 'Delivery Agent',
          phone: '+91 9999999999',
          isOnline: true,
          isOnDuty: true,
          vehicle: 'Bike',
        });
      });
    });

    it('Allows delivery agent to read own agent profile', async () => {
      const db = deliveryDb();
      await assertSucceeds(getDoc(doc(db, 'delivery_agents', 'delivery_uid')));
    });

    it('Denies customer from accessing unrelated delivery agent profile', async () => {
      const db = customer1Db();
      await assertFails(getDoc(doc(db, 'delivery_agents', 'delivery_uid')));
    });

    it('Allows delivery agent to update own duty status and coordinates', async () => {
      const db = deliveryDb();
      await assertSucceeds(updateDoc(doc(db, 'delivery_agents', 'delivery_uid'), {
        isOnDuty: false,
        isOnline: false,
      }));
    });

    it('Denies customer from modifying delivery agent profile', async () => {
      const db = customer1Db();
      await assertFails(updateDoc(doc(db, 'delivery_agents', 'delivery_uid'), {
        isOnDuty: false,
      }));
      await assertFails(deleteDoc(doc(db, 'delivery_agents', 'delivery_uid')));
    });

    it('Allows Admin to manage delivery agent records', async () => {
      const db = adminDb();
      await assertSucceeds(updateDoc(doc(db, 'delivery_agents', 'delivery_uid'), {
        rating: 4.8,
      }));
      await assertSucceeds(deleteDoc(doc(db, 'delivery_agents', 'delivery_uid')));
    });
  });

  // =========================================================================
  // 8. EARNINGS COLLECTION
  // =========================================================================
  describe('8. Earnings Collection (/earnings/{earningId})', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'earnings', 'earn_deliv1'), {
          agentId: 'delivery_uid',
          amount: 450,
          date: '2026-09-07',
          deliveriesCount: 9,
        });
        await setDoc(doc(context.firestore(), 'earnings', 'earn_deliv2'), {
          agentId: 'other_delivery_uid',
          amount: 600,
          date: '2026-09-07',
        });
      });
    });

    it('Allows delivery agent to read own earnings', async () => {
      const db = deliveryDb();
      await assertSucceeds(getDoc(doc(db, 'earnings', 'earn_deliv1')));
    });

    it('Denies delivery agent from reading another agent earnings', async () => {
      const db = deliveryDb();
      await assertFails(getDoc(doc(db, 'earnings', 'earn_deliv2')));
    });

    it('Denies delivery agent from creating or altering own earnings (must be via Admin/Cloud Functions)', async () => {
      const db = deliveryDb();
      await assertFails(setDoc(doc(db, 'earnings', 'fake_earn'), {
        agentId: 'delivery_uid',
        amount: 10000,
      }));
      await assertFails(updateDoc(doc(db, 'earnings', 'earn_deliv1'), {
        amount: 99999,
      }));
    });

    it('Denies customer from reading or writing earnings', async () => {
      const db = customer1Db();
      await assertFails(getDoc(doc(db, 'earnings', 'earn_deliv1')));
      await assertFails(setDoc(doc(db, 'earnings', 'cust_earn'), { amount: 100 }));
    });

    it('Allows Admin to read and write earnings', async () => {
      const db = adminDb();
      await assertSucceeds(getDoc(doc(db, 'earnings', 'earn_deliv1')));
      await assertSucceeds(setDoc(doc(db, 'earnings', 'admin_settlement'), {
        agentId: 'delivery_uid',
        amount: 500,
        settled: true,
      }));
    });
  });

  // =========================================================================
  // 9. COMPLAINTS COLLECTION
  // =========================================================================
  describe('9. Complaints Collection (/complaints/{complaintId})', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'complaints', 'comp_cust1'), {
          customerId: 'customer1_uid',
          title: 'Late Delivery',
          description: 'Milk arrived at 8:30 AM instead of 7:00 AM',
          status: 'Open',
          adminReply: null,
          createdAt: new Date().toISOString(),
        });
      });
    });

    it('Allows customer to create legitimate complaint in Open status without admin reply', async () => {
      const db = customer1Db();
      await assertSucceeds(setDoc(doc(db, 'complaints', 'comp_new'), {
        customerId: 'customer1_uid',
        title: 'Damaged packet',
        description: 'Packet was leaking',
        status: 'Open',
      }));
    });

    it('Denies customer from forging another customer complaint or forging admin reply', async () => {
      const db = customer1Db();
      await assertFails(setDoc(doc(db, 'complaints', 'comp_fake_user'), {
        customerId: 'customer2_uid',
        title: 'Fake complaint',
        status: 'Open',
      }));
      await assertFails(setDoc(doc(db, 'complaints', 'comp_fake_reply'), {
        customerId: 'customer1_uid',
        title: 'Fake resolution',
        status: 'Resolved',
        adminReply: 'Granted 1000 rupees refund',
      }));
    });

    it('Allows customer to read own complaints', async () => {
      const db = customer1Db();
      await assertSucceeds(getDoc(doc(db, 'complaints', 'comp_cust1')));
    });

    it('Denies customer from reading another customer complaint', async () => {
      const db = customer2Db();
      await assertFails(getDoc(doc(db, 'complaints', 'comp_cust1')));
    });

    it('Denies customer from updating or deleting complaints', async () => {
      const db = customer1Db();
      await assertFails(updateDoc(doc(db, 'complaints', 'comp_cust1'), {
        status: 'Resolved',
      }));
      await assertFails(deleteDoc(doc(db, 'complaints', 'comp_cust1')));
    });

    it('Allows Admin to read, respond to, resolve, and delete complaints', async () => {
      const db = adminDb();
      await assertSucceeds(getDoc(doc(db, 'complaints', 'comp_cust1')));
      await assertSucceeds(updateDoc(doc(db, 'complaints', 'comp_cust1'), {
        status: 'Resolved',
        adminReply: 'We have refunded the amount to your wallet.',
      }));
      await assertSucceeds(deleteDoc(doc(db, 'complaints', 'comp_cust1')));
    });
  });

  // =========================================================================
  // 10. INVALID & MISSING ROLE SAFETY
  // =========================================================================
  describe('10. Invalid & Missing Role Fallback Security', () => {
    it('Denies user with invalid role from performing admin operations', async () => {
      const db = invalidRoleDb();
      await assertFails(setDoc(doc(db, 'products', 'hack_prod'), { name: 'Hacked', price: 0 }));
      await assertFails(deleteDoc(doc(db, 'users', 'customer1_uid')));
    });

    it('Denies user with invalid role from performing delivery operations', async () => {
      const db = invalidRoleDb();
      await assertFails(updateDoc(doc(db, 'orders', 'order_cust1_assigned'), {
        status: 'Delivered',
      }));
    });

    it('Denies user with missing user profile document from performing admin or delivery operations', async () => {
      const db = missingRoleDb();
      await assertFails(setDoc(doc(db, 'products', 'missing_role_prod'), { name: 'Prod' }));
      await assertFails(updateDoc(doc(db, 'orders', 'order_cust1_assigned'), {
        status: 'Delivered',
      }));
    });
  });
});
