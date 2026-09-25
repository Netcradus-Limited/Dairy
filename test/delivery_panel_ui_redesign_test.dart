import 'dart:ui';

import 'package:dairy_app/features/delivery_panel/theme/delivery_theme.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_bottom_nav.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_header.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_order_card.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_promo_banner.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_status_chip.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_summary_card.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 6 — Delivery Panel UI Redesign Theme & Component Unit Tests', () {
    test('DeliveryTheme color palette and tokens match reference green design',
        () {
      expect(DeliveryTheme.primary, const Color(0xFF43A047));
      expect(DeliveryTheme.primaryLight, const Color(0xFF66BB6A));
      expect(DeliveryTheme.primaryDark, const Color(0xFF2E7D32));
      expect(DeliveryTheme.primaryMint, const Color(0xFFE8F5E9));
      expect(DeliveryTheme.primarySurface, const Color(0xFFF4F8F4));
      expect(DeliveryTheme.background, const Color(0xFFF7FAF7));
      expect(DeliveryTheme.statusNextBg, const Color(0xFFE8F5E9));
      expect(DeliveryTheme.statusProgressBg, const Color(0xFFFFF3E0));
      expect(DeliveryTheme.statusPendingBg, const Color(0xFFFFEBEE));
      expect(DeliveryTheme.cardRadius, 16.0);
      expect(DeliveryTheme.buttonRadius, 24.0);
    });

    test('DeliveryStatusChip.fromStatus maps statuses accurately', () {
      final nextChip = DeliveryStatusChip.fromStatus('accepted');
      expect(nextChip.label, 'Next');
      expect(nextChip.type, DeliveryChipType.next);

      final inProgChip = DeliveryStatusChip.fromStatus('outForDelivery');
      expect(inProgChip.label, 'In Progress');
      expect(inProgChip.type, DeliveryChipType.inProgress);

      final deliveredChip = DeliveryStatusChip.fromStatus('delivered');
      expect(deliveredChip.label, 'Delivered');
      expect(deliveredChip.type, DeliveryChipType.delivered);

      final cancelChip = DeliveryStatusChip.fromStatus('cancelled');
      expect(cancelChip.label, 'Cancelled');
      expect(cancelChip.type, DeliveryChipType.cancelled);
    });

    test('BotanicalLeafPainter paints without error', () {
      const painter = BotanicalLeafPainter(leafColor: Color(0x1F4CAF50));
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 200));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      expect(painter.shouldRepaint(painter), isFalse);
    });
  });

  group('Task 6 — UI Redesign Widget Tests', () {
    testWidgets(
        'DeliveryStatusChip renders corresponding chip labels and colors',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DeliveryStatusChip(
                  label: 'Next',
                  type: DeliveryChipType.next,
                ),
                DeliveryStatusChip(
                  label: 'In Progress',
                  type: DeliveryChipType.inProgress,
                ),
                DeliveryStatusChip(
                  label: 'Pending',
                  type: DeliveryChipType.pending,
                ),
                DeliveryStatusChip(
                  label: 'Delivered',
                  type: DeliveryChipType.delivered,
                ),
                DeliveryStatusChip(
                  label: 'Cancelled',
                  type: DeliveryChipType.cancelled,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Next'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('DeliverySummaryCard renders count, label, and handles tap',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliverySummaryCard(
              count: '24',
              label: "Today's Orders",
              icon: Icons.assignment_outlined,
              iconColor: DeliveryTheme.metricOrdersIcon,
              iconBgColor: DeliveryTheme.metricOrdersBg,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('24'), findsOneWidget);
      expect(find.text("Today's Orders"), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);

      await tester.tap(find.byType(DeliverySummaryCard));
      expect(tapped, isTrue);
    });

    testWidgets('DeliveryPromoBanner renders title, subtitle, and leaf icon',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryPromoBanner(),
          ),
        ),
      );

      expect(find.text('Fresh Milk\nHappier Homes'), findsOneWidget);
      expect(find.text('Thank you for being\nour delivery partner! ♡'),
          findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
        'DeliveryOrderCard renders details and responds to interactions',
        (tester) async {
      final dummyOrder = DeliveryOrder(
        id: 'ord_101',
        orderId: 'ORD-9872',
        orderCode: 'SW-9872',
        customerName: 'Aarav Sharma',
        customerPhone: '+91 9876543210',
        customerAddress: 'Flat 402, Green Meadows, Vijay Nagar',
        pickupLocation: 'Sawariya Dairy Processing Center',
        pickupPhone: '+91 9826012345',
        items: ['Farm Fresh Cow Milk 1L x 2', 'Organic Ghee 500g x 1'],
        amount: 340.0,
        deliveryFee: 20.0,
        status: DeliveryOrderStatus.outForDelivery,
        orderTime: DateTime.now(),
        distance: '2.4 km',
        estimatedTime: '15 mins',
      );

      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryOrderCard(
              order: dummyOrder,
              onTap: () => cardTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Flat 402, Green Meadows, Vijay Nagar'), findsOneWidget);
      expect(find.text('2 items • ₹340'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);

      await tester.tap(find.text('Aarav Sharma'));
      expect(cardTapped, isTrue);
    });

    testWidgets('DeliveryBottomNav renders 5 items and notifies selection',
        (tester) async {
      int selectedIdx = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DeliveryBottomNav(
              currentIndex: 0,
              onTabSelected: (idx) => selectedIdx = idx,
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Orders'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.text('Map'));
      expect(selectedIdx, 2);

      await tester.tap(find.text('Earnings'));
      expect(selectedIdx, 3);
    });

    testWidgets(
        'DeliveryStandardHeader renders title, leading, and action buttons',
        (tester) async {
      bool backPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryStandardHeader(
              title: 'Order Details',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => backPressed = true,
              ),
              actions: const [
                Icon(Icons.phone),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Order Details'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backPressed, isTrue);
    });
  });

  group('Task 6 — Responsive Layout & No RenderFlex Overflow Verification', () {
    testWidgets(
        'Summary cards render 2x2 grid cleanly on narrow viewport (320px)',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DeliverySummaryCard(
                          count: '18',
                          label: "Today's Orders",
                          icon: Icons.assignment_outlined,
                          iconColor: DeliveryTheme.metricOrdersIcon,
                          iconBgColor: DeliveryTheme.metricOrdersBg,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DeliverySummaryCard(
                          count: '12',
                          label: 'Delivered',
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: DeliveryTheme.metricDeliveredIcon,
                          iconBgColor: DeliveryTheme.metricDeliveredBg,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DeliverySummaryCard(
                          count: '4',
                          label: 'In Progress',
                          icon: Icons.delivery_dining_outlined,
                          iconColor: DeliveryTheme.metricProgressIcon,
                          iconBgColor: DeliveryTheme.metricProgressBg,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DeliverySummaryCard(
                          count: '2',
                          label: 'Pending',
                          icon: Icons.access_time_rounded,
                          iconColor: DeliveryTheme.metricPendingIcon,
                          iconBgColor: DeliveryTheme.metricPendingBg,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("Today's Orders"), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets(
        'DeliveryOrderCard renders on 320px narrow device without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyOrder = DeliveryOrder(
        id: 'ord_narrow',
        orderId: 'ORD-1234',
        orderCode: 'SW-1234',
        customerName: 'Very Long Customer Name For Narrow Screen Testing',
        customerPhone: '+91 9999999999',
        customerAddress:
            'House 123, Sector 9, Very Long Street Address That Wraps Cleanly',
        pickupLocation: 'Sawariya Dairy Indore',
        pickupPhone: '+91 9826012345',
        items: [
          'Farm Fresh Cow Milk 1L x 2',
          'Paneer 500g x 1',
          'Curd 1kg x 1'
        ],
        amount: 520.0,
        deliveryFee: 0.0,
        status: DeliveryOrderStatus.accepted,
        orderTime: DateTime.now(),
        distance: '3.1 km',
        estimatedTime: '20 mins',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeliveryOrderCard(order: dummyOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Very Long Customer Name For Narrow Screen Testing'),
          findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });
  });
}
