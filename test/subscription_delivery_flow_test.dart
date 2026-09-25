import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/order_model.dart' as admin_order;
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/subscription.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/services/order_service.dart';
import 'package:dairy_app/services/subscription_service.dart';

void main() {
  group('Task 9 - Subscription Delivery Integration Complete Flow Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SubscriptionService subscriptionService;
    late OrderService orderService;

    const testProduct = Product(
      id: 'prod_milk_1l',
      title: 'Fresh Cow Milk 1L',
      price: 65.0,
      originalPrice: 70.0,
      description: 'Farm fresh pasteurized cow milk',
      imageUrl: 'https://cdn.sawariya.com/milk1l.png',
      categoryId: 'milk',
      categoryName: 'Milk',
      unit: '1L',
      inStock: true,
      rating: 4.9,
      reviewCount: 240,
      isFreshDeal: true,
    );

    const testAddress = Address(
      id: 'addr_1',
      label: 'Home',
      fullName: 'Rahul Sharma',
      mobileNumber: '+91 9876543210',
      houseFlat: 'Flat 402, Green Heights',
      streetArea: 'Scheme No 54, Vijay Nagar',
      city: 'Indore',
      state: 'Madhya Pradesh',
      pinCode: '452010',
      latitude: 22.7533,
      longitude: 75.8937,
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      subscriptionService = SubscriptionService(fakeFirestore);
      orderService = OrderService(firestore: fakeFirestore);
    });

    test('1. Customer creates subscription and persists to Firestore correctly',
        () async {
      final now = DateTime(2026, 9, 18);
      final sub = Subscription(
        id: 'sub_cust_001',
        product: testProduct,
        quantity: 2,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        deliveryTimeSlot: 'Morning (6:00 AM - 9:00 AM)',
        discountRate: 0.10,
        planId: 'plan_cow_milk_daily',
        planName: 'Daily Cow Milk 1L',
        autoRenew: true,
      );

      final createdSub =
          await subscriptionService.createSubscription('user_123', sub);

      expect(createdSub.id, 'sub_cust_001');
      expect(createdSub.isActive, true);
      expect(createdSub.nextDeliveryDate, isNotNull);

      // Verify Firestore storage at users/user_123/subscription/current
      final docSnap = await fakeFirestore
          .collection('users')
          .doc('user_123')
          .collection('subscription')
          .doc('current')
          .get();

      expect(docSnap.exists, true);
      final data = docSnap.data()!;
      expect(data['productId'], 'prod_milk_1l');
      expect(data['quantity'], 2);
      expect(data['frequency'], 'Daily');
      expect(data['status'], 'Active');
      expect(data['deliveryTimeSlot'], 'Morning (6:00 AM - 9:00 AM)');
    });

    test(
        '2. Scheduled subscription delivery order generation contains all required fields',
        () async {
      final now = DateTime(2026, 9, 18, 6, 30);
      final sub = Subscription(
        id: 'sub_cust_001',
        product: testProduct,
        quantity: 2,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        nextDeliveryDate: now,
        deliveryTimeSlot: 'Morning (6:00 AM - 9:00 AM)',
        discountRate: 0.10,
      );

      final genOrder = await subscriptionService.generateOrderForSubscription(
        'user_123',
        sub,
        targetDate: now,
        deliveryAddress: testAddress,
        customerName: 'Rahul Sharma',
        customerPhone: '+91 9876543210',
        paymentMethod: 'Subscription',
        paymentStatus: 'Paid',
      );

      // Check all required fields on generated order
      expect(genOrder.id, startsWith('sub_sub_cust_001_'));
      expect(genOrder.subscriptionId, 'sub_cust_001');
      expect(genOrder.userId, 'user_123');
      expect(genOrder.orderType, 'subscription');
      expect(genOrder.isSubscription, true);
      expect(genOrder.deliveryAddress.fullName, 'Rahul Sharma');
      expect(genOrder.deliveryAddress.mobileNumber, '+91 9876543210');
      expect(genOrder.deliveryAddress.houseFlat, 'Flat 402, Green Heights');
      expect(genOrder.items.length, 1);
      expect(genOrder.items.first.product.id, 'prod_milk_1l');
      expect(genOrder.items.first.quantity, 2);
      expect(genOrder.deliverySlot, 'Morning (6:00 AM - 9:00 AM)');
      expect(genOrder.paymentMethod, 'Subscription');
      expect(genOrder.paymentStatus, 'Paid');
      expect(genOrder.status, OrderStatus.placed);

      // Verify stored in Firestore 'orders' collection
      final orderSnap =
          await fakeFirestore.collection('orders').doc(genOrder.id).get();
      expect(orderSnap.exists, true);
      final orderData = orderSnap.data()!;
      expect(orderData['orderType'], 'subscription');
      expect(orderData['subscriptionId'], 'sub_cust_001');
      expect(orderData['productName'], 'Fresh Cow Milk 1L');
      expect(orderData['quantity'], 2);
    });

    test(
        '3. Duplicate delivery order prevention on same subscriptionId + deliveryDate',
        () async {
      final targetDate = DateTime(2026, 9, 18);
      final sub = Subscription(
        id: 'sub_cust_002',
        product: testProduct,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: targetDate,
        nextDeliveryDate: targetDate,
      );

      // First generation
      final order1 = await subscriptionService.generateOrderForSubscription(
        'user_456',
        sub,
        targetDate: targetDate,
        deliveryAddress: testAddress,
      );

      // Second generation attempt on identical date
      final order2 = await subscriptionService.generateOrderForSubscription(
        'user_456',
        sub,
        targetDate: targetDate,
        deliveryAddress: testAddress,
      );

      expect(order1.id, order2.id);

      // Check that only ONE order document exists in orders collection
      final allOrdersSnap = await fakeFirestore
          .collection('orders')
          .where('subscriptionId', isEqualTo: 'sub_cust_002')
          .get();
      expect(allOrdersSnap.docs.length, 1);
    });

    test('4. Delivery panel mapping provides Subscription badge and metadata',
        () async {
      final targetDate = DateTime(2026, 9, 18);
      final normalOrder = Order(
        id: 'ord_normal_001',
        orderCode: 'NOR123',
        items: const [CartItem(product: testProduct, quantity: 1)],
        subtotal: 65.0,
        totalAmount: 65.0,
        status: OrderStatus.placed,
        orderDate: targetDate,
        deliveryAddress: testAddress,
        orderType: 'normal',
      );

      final subOrder = Order(
        id: 'sub_ord_001',
        orderCode: 'SUB123',
        items: const [CartItem(product: testProduct, quantity: 2)],
        subtotal: 117.0,
        totalAmount: 117.0,
        status: OrderStatus.placed,
        orderDate: targetDate,
        deliveryAddress: testAddress,
        orderType: 'subscription',
        subscriptionId: 'sub_123',
        deliverySlot: 'Morning (6:00 AM - 9:00 AM)',
        paymentMethod: 'Subscription',
        paymentStatus: 'Paid',
      );

      final deliveryNormal = deliveryOrderFromOrder(normalOrder);
      final deliverySub = deliveryOrderFromOrder(subOrder);

      expect(deliveryNormal.isSubscription, false);
      expect(deliverySub.isSubscription, true);
      expect(deliverySub.subscriptionId, 'sub_123');
      expect(deliverySub.deliverySlot, 'Morning (6:00 AM - 9:00 AM)');
      expect(deliverySub.paymentStatus, 'Paid');
      expect(deliverySub.customerName, 'Rahul Sharma');
      expect(deliverySub.customerPhone, '+91 9876543210');
      expect(deliverySub.productImageUrl, isNotNull);
    });

    test(
        '5. Delivery agent workflow: Accepted -> Out for Delivery -> Delivered advances nextDeliveryDate while keeping subscription Active',
        () async {
      final targetDate = DateTime(2026, 9, 18);
      final sub = Subscription(
        id: 'sub_cust_flow',
        product: testProduct,
        quantity: 2,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: targetDate,
        nextDeliveryDate: targetDate,
        deliveryTimeSlot: 'Morning (6:00 AM - 9:00 AM)',
      );

      // 1. Create subscription
      await subscriptionService.createSubscription('user_flow', sub);

      // 2. Generate scheduled delivery order
      final genOrder = await subscriptionService.generateOrderForSubscription(
        'user_flow',
        sub,
        targetDate: targetDate,
        deliveryAddress: testAddress,
      );

      // 3. Admin approves and assigns order to Raghav, then Driver accepts order
      await orderService.approveAndAssignOrder(genOrder.id, 'agent_raghav');
      await orderService.acceptOrder(genOrder.id, 'agent_raghav');
      var orderSnap =
          await fakeFirestore.collection('orders').doc(genOrder.id).get();
      expect(orderSnap.data()!['status'], 'accepted');
      expect(orderSnap.data()!['assignedAgentId'], 'agent_raghav');

      // 4. Driver transitions to out for delivery
      await orderService.updateOrderStatus(
          genOrder.id, OrderStatus.outForDelivery);
      orderSnap =
          await fakeFirestore.collection('orders').doc(genOrder.id).get();
      expect(orderSnap.data()!['status'], 'outForDelivery');

      // 5. Driver marks Delivered
      await subscriptionService.completeSubscriptionDelivery(
        genOrder.id,
        agentId: 'agent_raghav',
      );

      // Verify order status and deliveredAt timestamp
      orderSnap =
          await fakeFirestore.collection('orders').doc(genOrder.id).get();
      expect(orderSnap.data()!['status'], 'delivered');
      expect(orderSnap.data()!['deliveredAt'], isNotNull);
      expect(orderSnap.data()!['subscriptionId'], 'sub_cust_flow');

      // Verify delivery record in user subcollection
      final recSnap = await fakeFirestore
          .collection('users')
          .doc('user_flow')
          .collection('delivery_records')
          .doc(genOrder.id)
          .get();
      expect(recSnap.exists, true);
      expect(recSnap.data()!['status'], 'Delivered');

      // CRITICAL: Parent subscription MUST remain Active and nextDeliveryDate advanced by 1 day (daily)
      final currentSub =
          await subscriptionService.getCurrentSubscription('user_flow');
      expect(currentSub, isNotNull);
      expect(currentSub!.status, SubscriptionStatus.active);
      expect(currentSub.isActive, true);
      expect(currentSub.nextDeliveryDate!.day,
          targetDate.add(const Duration(days: 1)).day);
    });

    test(
        '6. Skip Next Delivery advances nextDeliveryDate without creating skipped order',
        () async {
      final initialDate = DateTime(2026, 9, 18);
      final sub = Subscription(
        id: 'sub_skip_test',
        product: testProduct,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: initialDate,
        nextDeliveryDate: initialDate,
      );

      await subscriptionService.createSubscription('user_skip', sub);

      // Customer chooses to skip next delivery
      final updatedSub =
          await subscriptionService.skipNextDelivery('user_skip');

      // nextDeliveryDate advanced to 2026-09-19
      expect(updatedSub.nextDeliveryDate!.day,
          initialDate.add(const Duration(days: 1)).day);

      // Ensure NO order document was generated for the skipped date (2026-09-18)
      final dateKey = SubscriptionService.formatOrderDateKey(initialDate);
      final skippedOrderSnap = await fakeFirestore
          .collection('orders')
          .doc('sub_sub_skip_test_$dateKey')
          .get();
      expect(skippedOrderSnap.exists, false);

      // Verify skipped_dates record created
      final skippedRecord = await fakeFirestore
          .collection('users')
          .doc('user_skip')
          .collection('skipped_dates')
          .doc(dateKey)
          .get();
      expect(skippedRecord.exists, true);
    });

    test(
        '7. Pause stops future delivery generation, Resume recalculates next valid date',
        () async {
      final now = DateTime(2026, 9, 18);
      final sub = Subscription(
        id: 'sub_pause_test',
        product: testProduct,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        nextDeliveryDate: now,
      );

      await subscriptionService.createSubscription('user_pause', sub);

      // Pause subscription
      final pausedSub =
          await subscriptionService.pauseSubscription('user_pause');
      expect(pausedSub.status, SubscriptionStatus.paused);
      expect(pausedSub.isPaused, true);

      // Order generation should fail for paused subscription
      expect(
        () => subscriptionService.generateOrderForSubscription(
            'user_pause', pausedSub),
        throwsA(isA<StateError>()),
      );

      // Resume subscription
      final resumedSub =
          await subscriptionService.resumeSubscription('user_pause');
      expect(resumedSub.status, SubscriptionStatus.active);
      expect(resumedSub.isActive, true);
      expect(resumedSub.nextDeliveryDate, isNotNull);
    });

    test(
        '8. Alternate-day (+2 days) and Weekly (+7 days) frequency calculations',
        () {
      final baseDate = DateTime(2026, 9, 18);

      final nextDaily = subscriptionService.calculateNextDeliveryDate(
        SubscriptionFrequency.daily,
        fromDate: baseDate,
      );
      expect(nextDaily.difference(baseDate).inDays, 1);

      final nextAlt = subscriptionService.calculateNextDeliveryDate(
        SubscriptionFrequency.alternateDay,
        fromDate: baseDate,
      );
      expect(nextAlt.difference(baseDate).inDays, 2);

      final nextWeekly = subscriptionService.calculateNextDeliveryDate(
        SubscriptionFrequency.weekly,
        fromDate: baseDate,
      );
      expect(nextWeekly.difference(baseDate).inDays, 7);
    });

    test('9. Delivery failure states: Customer unavailable & Unable to deliver',
        () async {
      final order = await orderService.placeOrder(
        userId: 'user_fail_test',
        items: const [CartItem(product: testProduct, quantity: 1)],
        deliveryAddress: testAddress,
      );

      await orderService.failDelivery(order.id, 'Customer unavailable');

      final failedOrderSnap =
          await fakeFirestore.collection('orders').doc(order.id).get();
      expect(failedOrderSnap.data()!['status'], 'cancelled');
      expect(failedOrderSnap.data()!['cancellationReason'],
          'Customer unavailable');

      final failedPaymentSnap = await fakeFirestore
          .collection('payments')
          .doc('PAY_${order.id}')
          .get();
      expect(failedPaymentSnap.data()!['status'], 'Cancelled');
    });

    test('10. Admin DairyOrder correctly reflects orderType and subscriptionId',
        () {
      const dairyOrder = admin_order.DairyOrder(
        id: 'ord_admin_test',
        orderCode: 'SUB999',
        customerName: 'Rahul',
        customerPhone: '9876543210',
        itemsSummary: 'Milk 1L x2',
        amount: 130.0,
        status: admin_order.OrderStatus.pending,
        deliverySlot: 'Morning (6:00 AM - 9:00 AM)',
        address: 'Vijay Nagar',
        time: '06:00 AM',
        paymentMode: 'Subscription',
        orderType: 'subscription',
        subscriptionId: 'sub_admin_123',
      );

      expect(dairyOrder.isSubscription, true);
      expect(dairyOrder.subscriptionId, 'sub_admin_123');
      expect(dairyOrder.orderType, 'subscription');
    });

    test(
        '11. Complete Multi-Subscription Flow: Create 3, Edit Ghee, Pause Milk, Cancel Paneer, Admin Oversight',
        () async {
      const milkProd = Product(
        id: 'prod_milk',
        title: 'Sawariya Milk 1L',
        price: 60.0,
        categoryId: 'cat_milk',
        categoryName: 'Milk',
        unit: '1 L',
        imageUrl: 'assets/images/nnd.png',
      );
      const gheeProd = Product(
        id: 'prod_ghee',
        title: 'Sawariya Pure Desi Ghee',
        price: 650.0,
        categoryId: 'cat_ghee',
        categoryName: 'Pure Ghee',
        unit: '1 L',
        imageUrl: 'assets/images/nng.png',
      );
      const paneerProd = Product(
        id: 'prod_paneer',
        title: 'Sawariya Paneer',
        price: 95.0,
        categoryId: 'cat_paneer',
        categoryName: 'Paneer',
        unit: '200 g',
        imageUrl: 'assets/images/nnp.png',
      );

      final now = DateTime(2026, 9, 18);
      const customerId = 'user_multi_test';

      // ── Step 1: Create 3 Subscriptions ─────────────────────────────────
      // 1. Milk - Daily - Qty 1
      final subMilk = Subscription(
        id: 'SUB_MILK_01',
        product: milkProd,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
      );
      await subscriptionService.createSubscription(customerId, subMilk);

      // 2. Ghee - Weekly - Qty 1
      final subGhee = Subscription(
        id: 'SUB_GHEE_01',
        product: gheeProd,
        quantity: 1,
        frequency: SubscriptionFrequency.weekly,
        status: SubscriptionStatus.active,
        startDate: now,
      );
      await subscriptionService.createSubscription(customerId, subGhee);

      // 3. Paneer - Alternate Day - Qty 2
      final subPaneer = Subscription(
        id: 'SUB_PANEER_01',
        product: paneerProd,
        quantity: 2,
        frequency: SubscriptionFrequency.alternateDay,
        status: SubscriptionStatus.active,
        startDate: now,
      );
      await subscriptionService.createSubscription(customerId, subPaneer);

      // ── Step 2: Verify Firestore contains 3 separate documents ─────────
      final snapMilk = await fakeFirestore
          .collection('subscriptions')
          .doc('SUB_MILK_01')
          .get();
      final snapGhee = await fakeFirestore
          .collection('subscriptions')
          .doc('SUB_GHEE_01')
          .get();
      final snapPaneer = await fakeFirestore
          .collection('subscriptions')
          .doc('SUB_PANEER_01')
          .get();

      expect(snapMilk.exists, true);
      expect(snapGhee.exists, true);
      expect(snapPaneer.exists, true);

      expect(snapMilk.data()!['productTitle'], 'Sawariya Milk 1L');
      expect(snapGhee.data()!['productTitle'], 'Sawariya Pure Desi Ghee');
      expect(snapPaneer.data()!['productTitle'], 'Sawariya Paneer');

      // ── Step 3: Verify My Subscriptions query retrieves all THREE ─────
      final allUserSubs =
          await subscriptionService.getSubscriptionsForUser(customerId);
      expect(allUserSubs.length, 3);
      final titles = allUserSubs.map((s) => s.product.title).toSet();
      expect(titles.contains('Sawariya Milk 1L'), true);
      expect(titles.contains('Sawariya Pure Desi Ghee'), true);
      expect(titles.contains('Sawariya Paneer'), true);

      // ── Step 4: Edit Ghee (quantity 1 -> 3) ─────────────────────────────
      final gheeDoc = await subscriptionService
          .getCurrentSubscription(customerId, subscriptionId: 'SUB_GHEE_01');
      expect(gheeDoc, isNotNull);
      final updatedGhee = gheeDoc!.copyWith(
          quantity: 3, deliveryTimeSlot: 'Evening (5:00 PM - 8:00 PM)');
      await subscriptionService.updateSubscription(customerId, updatedGhee);

      final freshGhee = await subscriptionService
          .getCurrentSubscription(customerId, subscriptionId: 'SUB_GHEE_01');
      expect(freshGhee!.quantity, 3);
      expect(freshGhee.deliveryTimeSlot, 'Evening (5:00 PM - 8:00 PM)');

      // Verify Milk and Paneer remain unchanged
      final freshMilk = await subscriptionService
          .getCurrentSubscription(customerId, subscriptionId: 'SUB_MILK_01');
      final freshPaneer = await subscriptionService
          .getCurrentSubscription(customerId, subscriptionId: 'SUB_PANEER_01');
      expect(freshMilk!.quantity, 1);
      expect(freshPaneer!.quantity, 2);

      // ── Step 5: Pause Milk ─────────────────────────────────────────────
      await subscriptionService.pauseSubscription(customerId,
          subscriptionId: 'SUB_MILK_01');
      final pausedMilk = await subscriptionService
          .getCurrentSubscription(customerId, subscriptionId: 'SUB_MILK_01');
      final activeGhee = await subscriptionService
          .getCurrentSubscription(customerId, subscriptionId: 'SUB_GHEE_01');
      final activePaneer = await subscriptionService
          .getCurrentSubscription(customerId, subscriptionId: 'SUB_PANEER_01');

      expect(pausedMilk!.isPaused, true);
      expect(activeGhee!.isActive, true);
      expect(activePaneer!.isActive, true);

      // ── Step 6: Cancel Paneer (preserves doc) ──────────────────────────
      await subscriptionService.cancelSubscription(customerId,
          subscriptionId: 'SUB_PANEER_01');
      final docPaneerAfterCancel = await fakeFirestore
          .collection('subscriptions')
          .doc('SUB_PANEER_01')
          .get();
      expect(docPaneerAfterCancel.exists, true);
      expect(docPaneerAfterCancel.data()!['status'], 'Cancelled');

      final subsAfterCancel =
          await subscriptionService.getSubscriptionsForUser(customerId);
      expect(subsAfterCancel.length, 3);
      final cancelledPaneer =
          subsAfterCancel.firstWhere((s) => s.id == 'SUB_PANEER_01');
      expect(cancelledPaneer.isCancelled, true);

      // ── Step 7: Admin Oversight ────────────────────────────────────────
      final allAdminSubs = await subscriptionService.getAllSubscriptions();
      expect(allAdminSubs.length >= 3, true);

      // ── Step 8: Unique Subscription ID on Generated Delivery Order ─────
      final orderGhee = await subscriptionService.generateOrderForSubscription(
        customerId,
        activeGhee,
        targetDate: now,
        deliveryAddress: testAddress,
      );
      expect(orderGhee.subscriptionId, 'SUB_GHEE_01');
      expect(orderGhee.id, startsWith('sub_SUB_GHEE_01_'));
    });

    test('12. Quantity integer validation and pricing consistency', () {
      final mapData = {
        'id': 'sub_qty_test',
        'productId': 'prod_milk',
        'productTitle': 'Sawariya Milk',
        'productPrice': 60.0,
        'quantity': 1,
        'frequency': 'Daily',
        'status': 'Active',
      };

      final sub1 = Subscription.fromMap(mapData);
      expect(sub1.quantity, 1);
      expect(sub1.pricePerDelivery, 60.0);

      // String quantity simulation (e.g. from raw form)
      final stringMap = Map<String, dynamic>.from(mapData)..['quantity'] = '2';
      final sub2 = Subscription.fromMap(stringMap);
      expect(sub2.quantity, 2);
      expect(sub2.pricePerDelivery, 120.0);
    });
  });
}
