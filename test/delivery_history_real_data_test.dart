import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/delivery_panel/screens/orders_tab.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/providers/delivery_provider.dart';

void main() {
  group('Delivery History Mock Data Removal & Firestore Integration', () {
    test('DeliveryHistoryNotifier starts with an empty list and no mock data', () {
      final notifier = DeliveryHistoryNotifier();
      expect(notifier.state, isEmpty);
    });

    test('deliveryHistoryStreamProvider filters delivered and cancelled orders from deliveryOrdersStreamProvider', () async {
      final container = ProviderContainer(
        overrides: [
          deliveryOrdersStreamProvider.overrideWith((ref) => Stream.value([
            DeliveryOrder(
              id: 'ord_1',
              orderId: 'ord_1',
              orderCode: 'REAL-001',
              customerName: 'Real Customer 1',
              customerPhone: '9876543210',
              customerAddress: '123 Real Street',
              pickupLocation: 'Hub',
              pickupPhone: '1234567890',
              items: ['Milk 1L x1'],
              amount: 60.0,
              deliveryFee: 15.0,
              status: DeliveryOrderStatus.delivered,
              orderTime: DateTime(2026, 3, 1, 10, 0),
              distance: '2.5 km',
              estimatedTime: '20 mins',
            ),
            DeliveryOrder(
              id: 'ord_2',
              orderId: 'ord_2',
              orderCode: 'REAL-002',
              customerName: 'Real Customer 2',
              customerPhone: '9876543211',
              customerAddress: '456 Real Avenue',
              pickupLocation: 'Hub',
              pickupPhone: '1234567890',
              items: ['Ghee 500g x1'],
              amount: 350.0,
              deliveryFee: 20.0,
              status: DeliveryOrderStatus.accepted, // Active, not historical
              orderTime: DateTime(2026, 3, 1, 11, 0),
              distance: '1.2 km',
              estimatedTime: '15 mins',
            ),
            DeliveryOrder(
              id: 'ord_3',
              orderId: 'ord_3',
              orderCode: 'REAL-003',
              customerName: 'Real Customer 3',
              customerPhone: '9876543212',
              customerAddress: '789 Real Road',
              pickupLocation: 'Hub',
              pickupPhone: '1234567890',
              items: ['Curd 400g x2'],
              amount: 80.0,
              deliveryFee: 10.0,
              status: DeliveryOrderStatus.cancelled,
              orderTime: DateTime(2026, 3, 1, 12, 0),
              distance: '3.0 km',
              estimatedTime: '25 mins',
            ),
          ])),
        ],
      );

      addTearDown(container.dispose);

      // Wait for the stream to produce data
      await container.read(deliveryOrdersStreamProvider.future);

      // Read deliveryHistoryStreamProvider
      final historyVal = container.read(deliveryHistoryStreamProvider);
      expect(historyVal.hasValue, isTrue);
      final historyOrders = historyVal.value!;
      expect(historyOrders.length, equals(2));
      expect(historyOrders.map((o) => o.orderCode).toList(), containsAll(['REAL-001', 'REAL-003']));
      expect(historyOrders.any((o) => o.orderCode == 'REAL-002'), isFalse);
    });

    testWidgets('OrdersTab renders loading indicator while stream is loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryHistoryStreamProvider.overrideWithValue(
              const AsyncValue.loading(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Rahul Singh'), findsNothing);
      expect(find.text('No Delivery History'), findsNothing);
    });

    testWidgets('OrdersTab renders error state on stream error without fake data fallback', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryHistoryStreamProvider.overrideWithValue(
              AsyncValue.error(Exception('Firestore error'), StackTrace.empty),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(),
            ),
          ),
        ),
      );

      expect(find.text('Could not load history'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.text('Rahul Singh'), findsNothing);
      expect(find.text('Meena Gupta'), findsNothing);
    });

    testWidgets('OrdersTab renders empty state when real history list is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryHistoryStreamProvider.overrideWithValue(
              const AsyncValue.data([]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(),
            ),
          ),
        ),
      );

      expect(find.text('No Delivery History'), findsOneWidget);
      expect(find.text('Completed deliveries will appear here'), findsOneWidget);
      expect(find.text('Rahul Singh'), findsNothing);
      expect(find.text('Meena Gupta'), findsNothing);
    });

    testWidgets('OrdersTab renders real orders with correct status and no mock orders', (tester) async {
      final realOrders = [
        DeliveryOrder(
          id: 'real_doc_101',
          orderId: 'real_doc_101',
          orderCode: 'REAL-999',
          customerName: 'Aarav Patel',
          customerPhone: '9898989898',
          customerAddress: 'Sector 62, Noida',
          pickupLocation: 'Sawariya Dairy Hub',
          pickupPhone: '+91 731 400 5000',
          items: ['Full Cream Milk 1L x2'],
          amount: 130.0,
          deliveryFee: 25.0,
          status: DeliveryOrderStatus.delivered,
          orderTime: DateTime.now().subtract(const Duration(hours: 1)),
          distance: '3.2 km',
          estimatedTime: '20 mins',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryHistoryStreamProvider.overrideWithValue(
              AsyncValue.data(realOrders),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(),
            ),
          ),
        ),
      );

      expect(find.text('Delivery History (1)'), findsOneWidget);
      expect(find.text('Order #REAL-999'), findsOneWidget);
      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('₹25'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('3.2 km'), findsOneWidget);

      // Verify no mock names exist
      expect(find.text('Rahul Singh'), findsNothing);
      expect(find.text('Meena Gupta'), findsNothing);
      expect(find.text('Vikash Kumar'), findsNothing);
      expect(find.text('Anita Devi'), findsNothing);
      expect(find.text('Rohit Sharma'), findsNothing);
    });
  });
}
