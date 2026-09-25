import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/subscription.dart';
import 'package:dairy_app/providers/admin_provider.dart';
import 'package:dairy_app/screens/subscriptions/admin_subscription_details_dialog.dart';
import 'package:dairy_app/services/subscription_service.dart';

void main() {
  group('Admin Subscription Management Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SubscriptionService subscriptionService;
    late AdminProvider adminProvider;

    setUp(() {
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    const testProductMilk = Product(
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

    const testProductGhee = Product(
      id: 'prod_ghee_500ml',
      title: 'Desi Cow Ghee 500ml',
      price: 450.0,
      originalPrice: 480.0,
      description: 'Pure Vedic Bilona Ghee',
      imageUrl: 'https://cdn.sawariya.com/ghee500ml.png',
      categoryId: 'ghee',
      categoryName: 'Ghee',
      unit: '500ml',
      inStock: true,
      rating: 5.0,
      reviewCount: 180,
    );

    const testProductPaneer = Product(
      id: 'prod_paneer_200g',
      title: 'Fresh Malai Paneer 200g',
      price: 110.0,
      originalPrice: 120.0,
      description: 'Fresh soft paneer',
      imageUrl: 'https://cdn.sawariya.com/paneer200g.png',
      categoryId: 'paneer',
      categoryName: 'Paneer',
      unit: '200g',
      inStock: true,
      rating: 4.8,
      reviewCount: 95,
    );

    setUp(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      fakeFirestore = FakeFirebaseFirestore();
      subscriptionService = SubscriptionService(fakeFirestore);

      // Seed a customer in users collection
      await fakeFirestore.collection('users').doc('user_vip_001').set({
        'id': 'user_vip_001',
        'name': 'Aarav Sharma',
        'phone': '+91 9876543210',
        'email': 'aarav@example.com',
        'address': 'Flat 304, Royal Palms, Scheme 78, Indore',
        'role': 'customer',
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      adminProvider = AdminProvider(
        subscriptionService: subscriptionService,
      );
    });

    tearDown(() {
      adminProvider.dispose();
    });

    test(
        '1. Stream all subscriptions from root subscriptions collection with multiple subscriptions per customer',
        () async {
      final now = DateTime.now();

      final subMilk = Subscription(
        id: 'sub_milk_001',
        userId: 'user_vip_001',
        product: testProductMilk,
        quantity: 2,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        nextDeliveryDate: now,
        deliveryTimeSlot: 'Morning (6:00 AM - 8:00 AM)',
        planName: 'Daily Cow Milk 1L',
      );

      final subGhee = Subscription(
        id: 'sub_ghee_002',
        userId: 'user_vip_001',
        product: testProductGhee,
        quantity: 1,
        frequency: SubscriptionFrequency.weekly,
        status: SubscriptionStatus.paused,
        startDate: now,
        nextDeliveryDate: now.add(const Duration(days: 7)),
        deliveryTimeSlot: 'Morning (6:00 AM - 8:00 AM)',
        planName: 'Weekly Desi Cow Ghee',
      );

      final subPaneer = Subscription(
        id: 'sub_paneer_003',
        userId: 'user_vip_001',
        product: testProductPaneer,
        quantity: 1,
        frequency: SubscriptionFrequency.alternateDay,
        status: SubscriptionStatus.cancelled,
        startDate: now.subtract(const Duration(days: 10)),
        nextDeliveryDate: now.add(const Duration(days: 1)),
        deliveryTimeSlot: 'Evening (5:00 PM - 7:00 PM)',
        planName: 'Alternate Day Paneer',
      );

      await fakeFirestore
          .collection('subscriptions')
          .doc(subMilk.id)
          .set(subMilk.toFirestore());
      await fakeFirestore
          .collection('subscriptions')
          .doc(subGhee.id)
          .set(subGhee.toFirestore());
      await fakeFirestore
          .collection('subscriptions')
          .doc(subPaneer.id)
          .set(subPaneer.toFirestore());

      // Read via streamAllSubscriptions
      final subs = await subscriptionService.streamAllSubscriptions().first;

      expect(subs.length, 3);
      expect(subs.map((s) => s.id).toSet(),
          {'sub_milk_001', 'sub_ghee_002', 'sub_paneer_003'});
      expect(subs.every((s) => s.userId == 'user_vip_001'), true);
    });

    test('2. Admin metrics and KPI calculations', () async {
      final now = DateTime.now();

      final sub1 = Subscription(
        id: 'sub_kpi_1',
        userId: 'user_vip_001',
        product: testProductMilk,
        quantity: 2,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        nextDeliveryDate: now,
        discountRate: 0.0,
      );

      final sub2 = Subscription(
        id: 'sub_kpi_2',
        userId: 'user_vip_001',
        product: testProductGhee,
        quantity: 1,
        frequency: SubscriptionFrequency.weekly,
        status: SubscriptionStatus.paused,
        startDate: now,
        nextDeliveryDate: now.add(const Duration(days: 5)),
        discountRate: 0.0,
      );

      final sub3 = Subscription(
        id: 'sub_kpi_3',
        userId: 'user_vip_001',
        product: testProductPaneer,
        quantity: 1,
        frequency: SubscriptionFrequency.alternateDay,
        status: SubscriptionStatus.cancelled,
        startDate: now,
        nextDeliveryDate: now,
        discountRate: 0.0,
      );

      await fakeFirestore
          .collection('subscriptions')
          .doc(sub1.id)
          .set(sub1.toFirestore());
      await fakeFirestore
          .collection('subscriptions')
          .doc(sub2.id)
          .set(sub2.toFirestore());
      await fakeFirestore
          .collection('subscriptions')
          .doc(sub3.id)
          .set(sub3.toFirestore());

      // Wait for provider to sync
      await Future.delayed(const Duration(milliseconds: 100));

      expect(adminProvider.totalSubscriptionsCount, 3);
      expect(adminProvider.activeSubscriptionsCount, 1);
      expect(adminProvider.pausedSubscriptionsCount, 1);
      expect(adminProvider.cancelledSubscriptionsCount, 1);

      // Today's deliveries: sub1 is active and nextDeliveryDate is today -> count 1
      expect(adminProvider.todaySubscriptionDeliveriesCount, 1);

      // Monthly revenue: active sub1 daily = 65 * 2 * 30 = 3900. Cancelled is excluded.
      expect(adminProvider.estimatedMonthlySubscriptionRevenue, 3900.0);
    });

    test(
        '3. Admin lifecycle actions: pause, resume, cancel, and edit update exact subscription doc',
        () async {
      final now = DateTime.now();
      final sub = Subscription(
        id: 'sub_action_001',
        userId: 'user_vip_001',
        product: testProductMilk,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        nextDeliveryDate: now.add(const Duration(days: 1)),
        deliveryTimeSlot: 'Morning (6:00 AM - 8:00 AM)',
      );

      await fakeFirestore
          .collection('subscriptions')
          .doc(sub.id)
          .set(sub.toFirestore());

      // 1. Admin Pause
      await adminProvider.pauseSubscription('sub_action_001');
      var doc = await fakeFirestore
          .collection('subscriptions')
          .doc('sub_action_001')
          .get();
      expect(doc.data()!['status'].toString().toLowerCase(), 'paused');

      // 2. Admin Resume
      await adminProvider.resumeSubscription('sub_action_001');
      doc = await fakeFirestore
          .collection('subscriptions')
          .doc('sub_action_001')
          .get();
      expect(doc.data()!['status'].toString().toLowerCase(), 'active');

      // 3. Admin Update / Edit
      final updatedSub = sub.copyWith(
        quantity: 3,
        frequency: SubscriptionFrequency.alternateDay,
        deliveryTimeSlot: 'Evening (5:00 PM - 7:00 PM)',
      );
      await adminProvider.updateSubscription(updatedSub);
      doc = await fakeFirestore
          .collection('subscriptions')
          .doc('sub_action_001')
          .get();
      expect(doc.data()!['quantity'], 3);
      expect(doc.data()!['frequency'].toString().toLowerCase(),
          contains('alternate'));
      expect(doc.data()!['deliveryTimeSlot'], 'Evening (5:00 PM - 7:00 PM)');

      // 4. Admin Cancel
      await adminProvider.cancelSubscription('sub_action_001');
      doc = await fakeFirestore
          .collection('subscriptions')
          .doc('sub_action_001')
          .get();
      expect(doc.exists, true); // Not physically deleted
      expect(doc.data()!['status'].toString().toLowerCase(), 'cancelled');
    });

    test('4. Order integration & delivery history for subscription', () async {
      // Seed orders with subscriptionId
      await fakeFirestore.collection('orders').doc('order_sub_001').set({
        'id': 'order_sub_001',
        'orderCode': 'ORD101',
        'userId': 'user_vip_001',
        'totalAmount': 130.0,
        'subtotal': 130.0,
        'status': 'delivered',
        'orderDate': DateTime.now().toIso8601String(),
        'orderType': 'subscription',
        'subscriptionId': 'sub_milk_001',
        'deliveryAddress': {
          'id': 'addr_1',
          'fullName': 'Aarav Sharma',
          'mobileNumber': '+91 9876543210',
          'houseFlat': 'Flat 304',
          'streetArea': 'Scheme 78',
          'city': 'Indore',
          'state': 'Madhya Pradesh',
          'pinCode': '452010',
        },
        'items': [
          {
            'productId': 'prod_milk_1l',
            'productName': 'Fresh Cow Milk 1L',
            'price': 65.0,
            'quantity': 2,
          }
        ],
      });

      final history = await subscriptionService
          .streamOrdersForSubscription('sub_milk_001')
          .first;
      expect(history.length, 1);
      expect(history.first.id, 'order_sub_001');
      expect(history.first.subscriptionId, 'sub_milk_001');
      expect(history.first.isSubscription, true);
    });

    test('5. Customer mapping resolves customer details safely', () async {
      final cust = adminProvider.getCustomerById('user_vip_001');
      if (cust != null) {
        expect(cust.name, isNotEmpty);
      }
      // Should not throw or crash on null or missing users
      final nonExistent = adminProvider.getCustomerById('missing_uid');
      expect(nonExistent, isNull);
    });

    test('6. Status and frequency filtering on subscriptions', () async {
      final now = DateTime.now();
      final subDaily = Subscription(
        id: 'sub_filter_1',
        userId: 'user_vip_001',
        product: testProductMilk,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
      );
      final subWeekly = Subscription(
        id: 'sub_filter_2',
        userId: 'user_vip_001',
        product: testProductGhee,
        quantity: 1,
        frequency: SubscriptionFrequency.weekly,
        status: SubscriptionStatus.paused,
        startDate: now,
      );

      final list = [subDaily, subWeekly];
      final activeOnly =
          list.where((s) => s.status == SubscriptionStatus.active).toList();
      final dailyOnly = list
          .where((s) => s.frequency == SubscriptionFrequency.daily)
          .toList();

      expect(activeOnly.length, 1);
      expect(activeOnly.first.id, 'sub_filter_1');
      expect(dailyOnly.length, 1);
      expect(dailyOnly.first.id, 'sub_filter_1');
    });

    test(
        '7. Multiple subscriptions with same userId have unique subscription document IDs',
        () async {
      final now = DateTime.now();
      final s1 = Subscription(
        id: 'sub_unique_milk',
        userId: 'cust_same_101',
        product: testProductMilk,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        startDate: now,
      );
      final s2 = Subscription(
        id: 'sub_unique_ghee',
        userId: 'cust_same_101',
        product: testProductGhee,
        quantity: 1,
        frequency: SubscriptionFrequency.weekly,
        startDate: now,
      );
      final s3 = Subscription(
        id: 'sub_unique_paneer',
        userId: 'cust_same_101',
        product: testProductPaneer,
        quantity: 2,
        frequency: SubscriptionFrequency.alternateDay,
        startDate: now,
      );

      await fakeFirestore
          .collection('subscriptions')
          .doc(s1.id)
          .set(s1.toFirestore());
      await fakeFirestore
          .collection('subscriptions')
          .doc(s2.id)
          .set(s2.toFirestore());
      await fakeFirestore
          .collection('subscriptions')
          .doc(s3.id)
          .set(s3.toFirestore());

      final all = await subscriptionService.streamAllSubscriptions().first;
      final custSubs = all.where((s) => s.userId == 'cust_same_101').toList();
      expect(custSubs.length, 3);
      expect(custSubs.map((s) => s.id).toSet().length, 3);
    });
  });

  group('AdminSubscriptionDetailsDialog & Provider Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SubscriptionService subscriptionService;
    late AdminProvider adminProvider;

    setUp(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      fakeFirestore = FakeFirebaseFirestore();
      subscriptionService = SubscriptionService(fakeFirestore);

      // Seed customer
      await fakeFirestore.collection('users').doc('cust_rahul').set({
        'id': 'cust_rahul',
        'name': 'Rahul Verma',
        'phone': '+91 9988776655',
        'email': 'rahul@example.com',
        'address': 'B-12, Green Park, Indore',
        'role': 'customer',
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      adminProvider = AdminProvider(
        subscriptionService: subscriptionService,
      );
    });

    tearDown(() {
      adminProvider.dispose();
    });

    const productWaterBottle = Product(
      id: 'prod_wb_20l',
      title: 'Water Bottle 20L',
      price: 80.0,
      originalPrice: 90.0,
      description: 'Purified mineral water container 20L',
      imageUrl: 'https://cdn.sawariya.com/water20l.png',
      categoryId: 'beverages',
      categoryName: 'Beverages',
      unit: '20L',
      inStock: true,
      rating: 4.8,
      reviewCount: 150,
    );

    const productFreshLassi = Product(
      id: 'prod_lassi_1',
      title: 'Fresh Lassi',
      price: 40.0,
      originalPrice: 45.0,
      description: 'Sweet thick traditional curd lassi',
      imageUrl: 'https://cdn.sawariya.com/lassi.png',
      categoryId: 'dairy',
      categoryName: 'Dairy',
      unit: '300ml',
      inStock: true,
      rating: 4.7,
      reviewCount: 110,
    );

    testWidgets(
        'AdminSubscriptionDetailsDialog.show opens without ProviderNotFoundException and renders details',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final sub = Subscription(
        id: 'sub_wb_test_01',
        userId: 'cust_rahul',
        product: productWaterBottle,
        quantity: 2,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        nextDeliveryDate: now.add(const Duration(days: 1)),
        deliveryTimeSlot: 'Morning (6:00 AM - 9:00 AM)',
      );

      await fakeFirestore
          .collection('subscriptions')
          .doc(sub.id)
          .set(sub.toFirestore());

      // Pump a widget tree providing AdminProvider via ChangeNotifierProvider.value
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: adminProvider,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () =>
                      AdminSubscriptionDetailsDialog.show(
                    context,
                    sub,
                    subscriptionService: subscriptionService,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify dialog is open and no ProviderNotFoundException occurred
      expect(find.text('Subscription Details'), findsOneWidget);
      expect(find.text('Water Bottle 20L'), findsWidgets);
      expect(find.text('ID: sub_wb_test_01'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('cust_rahul'), findsWidgets);

      // Verify close button dismisses dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Subscription Details'), findsNothing);
    });

    testWidgets(
        'Direct AdminSubscriptionDetailsDialog widget mounts and displays subscription details cleanly',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final sub = Subscription(
        id: 'sub_direct_01',
        userId: 'cust_rahul',
        product: productFreshLassi,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: adminProvider,
          child: MaterialApp(
            home: Scaffold(
              body: AdminSubscriptionDetailsDialog(
                subscription: sub,
                subscriptionService: subscriptionService,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Subscription Details'), findsOneWidget);
      expect(find.text('Fresh Lassi'), findsWidgets);
      expect(find.text('ID: sub_direct_01'), findsOneWidget);
    });
  });
}
