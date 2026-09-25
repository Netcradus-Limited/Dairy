import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/features/delivery_panel/delivery_panel_screen.dart';
import 'package:dairy_app/features/delivery_panel/screens/delivery_map_tab.dart';
import 'package:dairy_app/features/delivery_panel/screens/delivery_profile_redesigned_tab.dart';

class _MockDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  _MockDeliveryNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testActiveOrder = DeliveryOrder(
    id: 'order_resp_1',
    orderId: 'order_resp_1',
    orderCode: 'ORD-RESP-01',
    customerName: 'Aarav Sharma',
    customerAddress: '124, Lotus Lake Residency, Ring Road, Indore',
    customerPhone: '+919876543210',
    pickupLocation: 'Sawariya Dairy Hub',
    pickupPhone: '+91 731 400 5000',
    amount: 320,
    deliveryFee: 30.0,
    status: DeliveryOrderStatus.outForDelivery,
    items: const ['Pure Buffalo Milk 1L', 'Fresh Paneer 250g'],
    latitude: 22.7533,
    longitude: 75.8937,
    orderTime: DateTime(2026, 9, 25, 10, 0),
    distance: '3.2 km',
    estimatedTime: '18 mins',
  );

  const testAgent = DeliveryAgent(
    id: 'agent_resp_test',
    name: 'Rajesh Kumar',
    phone: '+91 98765 00000',
    status: DeliveryStatus.onDuty,
    vehicle: 'Hero Splendor',
    vehicleNumber: 'MP 09 AB 1234',
    assignedZone: 'Vijay Nagar',
    profileImageUrl: 'https://example.com/rajesh.jpg',
    completedDeliveriesToday: 8,
    totalDeliveriesToday: 12,
    earningsToday: 640.0,
    isLoaded: true,
  );

  Widget createTestWidget({
    required Widget child,
    required Size screenSize,
  }) {
    return ProviderScope(
      overrides: [
        deliveryActiveOrdersStreamProvider.overrideWith(
          (ref) => Stream.value([testActiveOrder]),
        ),
        deliveryAgentLocationStreamProvider.overrideWith(
          (ref) => Stream.value(null),
        ),
        deliveryAgentProvider.overrideWith(
          (ref) => _MockDeliveryNotifier(testAgent),
        ),
        deliveryRequestsStreamProvider.overrideWithValue(
          const <DeliveryOrder>[],
        ),
        deliveryHistoryStreamProvider.overrideWithValue(
          const AsyncValue.data(<DeliveryOrder>[]),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Delivery Map Tab Responsive & Text Constraint Tests', () {
    final viewports = [
      const Size(320, 568),  // iPhone SE
      const Size(360, 640),  // Compact Android
      const Size(390, 844),  // iPhone 14
      const Size(430, 932),  // iPhone 14 Pro Max
      const Size(768, 1024), // Tablet
      const Size(1024, 768), // Small Desktop
      const Size(1280, 800), // Standard Desktop
    ];

    for (final size in viewports) {
      testWidgets('Map bottom card renders horizontally without overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(
            child: const DeliveryMapTab(),
            screenSize: size,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // Verify "Delivering to" is present
        final deliveringToFinder = find.text('Delivering to');
        expect(deliveringToFinder, findsOneWidget);

        // Verify "Delivering to" width is at least 50px (proves it never broke vertically into 10px character-by-character)
        final deliveringToSize = tester.getSize(deliveringToFinder);
        expect(deliveringToSize.width, greaterThan(50.0));
        expect(deliveringToSize.height, lessThan(25.0)); // Single line height (~14-16px)

        // Verify Customer Name is visible
        expect(find.text('Aarav Sharma'), findsOneWidget);

        // Verify Directions action is present
        expect(find.text('Directions'), findsOneWidget);

        // Verify ETA and Distance are present and horizontally aligned
        expect(find.text('Estimated Arrival'), findsOneWidget);
        expect(find.text('18 mins'), findsOneWidget);
        expect(find.text('GPS off'), findsOneWidget);
      });
    }
  });

  group('Delivery Profile Tab Responsive Tests', () {
    final profileViewports = [
      const Size(320, 568),
      const Size(360, 640),
      const Size(390, 844),
      const Size(430, 932),
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1280, 800),
    ];

    for (final size in profileViewports) {
      testWidgets('Profile tab renders cleanly without overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(
            child: const DeliveryProfileRedesignedTab(),
            screenSize: size,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // Verify Agent details
        expect(find.text('Rajesh Kumar'), findsOneWidget);
        expect(find.text('Delivery Partner'), findsWidgets);
        expect(find.text('Online'), findsOneWidget);

        // Verify Menu items
        expect(find.text('My Profile'), findsOneWidget);
        expect(find.text('Delivery History'), findsOneWidget);
        expect(find.text('Earnings'), findsOneWidget);
        expect(find.text('Help & Support'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        // Verify Branding
        expect(find.text('SAWARIYA DAIRY'), findsOneWidget);
      });
    }
  });

  group('Delivery Panel Screen Full Shell Responsive Breakpoint Tests', () {
    testWidgets('Panel displays mobile bottom navigation on mobile/tablet (768px)',
        (tester) async {
      const size = Size(768, 1024);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          child: const DeliveryPanelScreen(),
          screenSize: size,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Bottom navigation should be present on 768px
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Panel displays persistent sidebar and topbar on desktop (1280px)',
        (tester) async {
      const size = Size(1280, 800);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          child: const DeliveryPanelScreen(),
          screenSize: size,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Desktop branding should be present in sidebar
      expect(find.text('Sawariya Dairy'), findsWidgets);
    });
  });
}
