import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/delivery_panel/screens/orders_tab.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/order.dart' as model;
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/providers/delivery_provider.dart';

void main() {
  group('Task 8: Delivery Panel History Cleanup', () {
    test('deliveryHistoryStreamProvider includes completed & cancelled orders and excludes active & pending', () async {
      final now = DateTime.now();

      final orders = [
        DeliveryOrder(
          id: 'ord_completed',
          orderId: 'ord_completed',
          orderCode: 'DEL-101',
          customerName: 'Completed Customer',
          customerPhone: '9876543210',
          customerAddress: 'Address 1',
          pickupLocation: 'Hub 1',
          pickupPhone: '1111111111',
          items: ['Cow Milk 1L x2'],
          amount: 120.0,
          deliveryFee: 20.0,
          status: DeliveryOrderStatus.delivered,
          orderTime: now.subtract(const Duration(hours: 3)),
          deliveredTime: now.subtract(const Duration(hours: 2)),
          distance: '2.0 km',
          estimatedTime: '15 mins',
        ),
        DeliveryOrder(
          id: 'ord_cancelled',
          orderId: 'ord_cancelled',
          orderCode: 'DEL-102',
          customerName: 'Cancelled Customer',
          customerPhone: '9876543211',
          customerAddress: 'Address 2',
          pickupLocation: 'Hub 1',
          pickupPhone: '1111111111',
          items: ['Paneer 200g x1'],
          amount: 90.0,
          deliveryFee: 15.0,
          status: DeliveryOrderStatus.cancelled,
          cancellationReason: 'Customer unreachable at door',
          orderTime: now.subtract(const Duration(hours: 2)),
          distance: '3.0 km',
          estimatedTime: '20 mins',
        ),
        DeliveryOrder(
          id: 'ord_pending',
          orderId: 'ord_pending',
          orderCode: 'DEL-103',
          customerName: 'Pending Customer',
          customerPhone: '9876543212',
          customerAddress: 'Address 3',
          pickupLocation: 'Hub 1',
          pickupPhone: '1111111111',
          items: ['Curd 500g x1'],
          amount: 50.0,
          deliveryFee: 10.0,
          status: DeliveryOrderStatus.pendingAcceptance,
          orderTime: now.subtract(const Duration(minutes: 30)),
          distance: '1.5 km',
          estimatedTime: '10 mins',
        ),
        DeliveryOrder(
          id: 'ord_accepted',
          orderId: 'ord_accepted',
          orderCode: 'DEL-104',
          customerName: 'Accepted Customer',
          customerPhone: '9876543213',
          customerAddress: 'Address 4',
          pickupLocation: 'Hub 1',
          pickupPhone: '1111111111',
          items: ['Ghee 1L x1'],
          amount: 650.0,
          deliveryFee: 25.0,
          status: DeliveryOrderStatus.accepted,
          orderTime: now.subtract(const Duration(minutes: 20)),
          distance: '4.0 km',
          estimatedTime: '25 mins',
        ),
        DeliveryOrder(
          id: 'ord_pickup',
          orderId: 'ord_pickup',
          orderCode: 'DEL-105',
          customerName: 'Pickup Customer',
          customerPhone: '9876543214',
          customerAddress: 'Address 5',
          pickupLocation: 'Hub 1',
          pickupPhone: '1111111111',
          items: ['Butter 500g x1'],
          amount: 250.0,
          deliveryFee: 15.0,
          status: DeliveryOrderStatus.pickup,
          orderTime: now.subtract(const Duration(minutes: 15)),
          distance: '2.5 km',
          estimatedTime: '18 mins',
        ),
        DeliveryOrder(
          id: 'ord_out_for_delivery',
          orderId: 'ord_out_for_delivery',
          orderCode: 'DEL-106',
          customerName: 'Active Customer',
          customerPhone: '9876543215',
          customerAddress: 'Address 6',
          pickupLocation: 'Hub 1',
          pickupPhone: '1111111111',
          items: ['Milk 1L x1'],
          amount: 60.0,
          deliveryFee: 15.0,
          status: DeliveryOrderStatus.outForDelivery,
          orderTime: now.subtract(const Duration(minutes: 10)),
          distance: '1.0 km',
          estimatedTime: '8 mins',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          deliveryOrdersStreamProvider.overrideWith((ref) => Stream.value(orders)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deliveryOrdersStreamProvider.future);

      final historyAsync = container.read(deliveryHistoryStreamProvider);
      expect(historyAsync.hasValue, isTrue);

      final history = historyAsync.value!;
      // Must only contain DEL-101 and DEL-102
      expect(history.length, equals(2));
      final codes = history.map((o) => o.orderCode).toList();
      expect(codes, containsAll(['DEL-101', 'DEL-102']));
      expect(codes, isNot(contains('DEL-103')));
      expect(codes, isNot(contains('DEL-104')));
      expect(codes, isNot(contains('DEL-105')));
      expect(codes, isNot(contains('DEL-106')));
    });

    test('deliveryHistoryStreamProvider removes duplicates by orderId', () async {
      final now = DateTime.now();
      final duplicateOrders = [
        DeliveryOrder(
          id: 'ord_dup',
          orderId: 'ord_dup',
          orderCode: 'DEL-DUP',
          customerName: 'Customer A',
          customerPhone: '9876543210',
          customerAddress: 'Address 1',
          pickupLocation: 'Hub 1',
          pickupPhone: '1111111111',
          items: ['Milk 1L x1'],
          amount: 60.0,
          deliveryFee: 15.0,
          status: DeliveryOrderStatus.delivered,
          orderTime: now.subtract(const Duration(hours: 1)),
          distance: '1.0 km',
          estimatedTime: '10 mins',
        ),
        DeliveryOrder(
          id: 'ord_dup',
          orderId: 'ord_dup',
          orderCode: 'DEL-DUP',
          customerName: 'Customer A (Duplicate)',
          customerPhone: '9876543210',
          customerAddress: 'Address 1',
          pickupLocation: 'Hub 1',
          pickupPhone: '1111111111',
          items: ['Milk 1L x1'],
          amount: 60.0,
          deliveryFee: 15.0,
          status: DeliveryOrderStatus.delivered,
          orderTime: now.subtract(const Duration(hours: 1)),
          distance: '1.0 km',
          estimatedTime: '10 mins',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          deliveryOrdersStreamProvider.overrideWith((ref) => Stream.value(duplicateOrders)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deliveryOrdersStreamProvider.future);
      final history = container.read(deliveryHistoryStreamProvider).value!;

      expect(history.length, equals(1));
      expect(history.first.orderId, equals('ord_dup'));
    });

    test('deliveryHistoryStreamProvider sorts descending by most relevant delivery date', () async {
      final now = DateTime.now();

      final oOldOrderDeliveredRecently = DeliveryOrder(
        id: 'ord_old_order_new_delivery',
        orderId: 'ord_old_order_new_delivery',
        orderCode: 'NEWEST-DELIVERY',
        customerName: 'Customer 1',
        customerPhone: '111',
        customerAddress: 'A',
        pickupLocation: 'Hub',
        pickupPhone: '222',
        items: ['Milk x1'],
        amount: 50.0,
        deliveryFee: 10.0,
        status: DeliveryOrderStatus.delivered,
        orderTime: now.subtract(const Duration(days: 3)), // Ordered 3 days ago
        deliveredTime: now.subtract(const Duration(minutes: 10)), // Delivered 10 mins ago
        distance: '1 km',
        estimatedTime: '5 mins',
      );

      final oNewOrderDeliveredEarlier = DeliveryOrder(
        id: 'ord_new_order_old_delivery',
        orderId: 'ord_new_order_old_delivery',
        orderCode: 'OLDER-DELIVERY',
        customerName: 'Customer 2',
        customerPhone: '333',
        customerAddress: 'B',
        pickupLocation: 'Hub',
        pickupPhone: '444',
        items: ['Milk x1'],
        amount: 50.0,
        deliveryFee: 10.0,
        status: DeliveryOrderStatus.delivered,
        orderTime: now.subtract(const Duration(days: 1)), // Ordered 1 day ago
        deliveredTime: now.subtract(const Duration(hours: 5)), // Delivered 5 hours ago
        distance: '1 km',
        estimatedTime: '5 mins',
      );

      final container = ProviderContainer(
        overrides: [
          deliveryOrdersStreamProvider.overrideWith(
            (ref) => Stream.value([oNewOrderDeliveredEarlier, oOldOrderDeliveredRecently]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deliveryOrdersStreamProvider.future);
      final history = container.read(deliveryHistoryStreamProvider).value!;

      // NEWEST-DELIVERY should be first because its deliveredTime is most recent
      expect(history.first.orderCode, equals('NEWEST-DELIVERY'));
      expect(history.last.orderCode, equals('OLDER-DELIVERY'));
    });

    test('deliveryOrderFromOrder maps acceptedAt and deliveredAt correctly', () {
      final now = DateTime.now();
      final accepted = now.subtract(const Duration(hours: 1));
      final delivered = now.subtract(const Duration(minutes: 15));

      final testOrder = model.Order(
        id: 'model_ord_1',
        orderCode: 'MAP-001',
        items: [
          const CartItem(
            product: Product(
              id: 'p1',
              title: 'Buffalo Milk',
              categoryId: 'milk',
              categoryName: 'Milk',
              imageUrl: '',
              price: 70.0,
              unit: '1L',
            ),
            quantity: 2,
          ),
        ],
        subtotal: 140.0,
        deliveryCharge: 20.0,
        discount: 0.0,
        totalAmount: 160.0,
        status: model.OrderStatus.delivered,
        orderDate: now.subtract(const Duration(hours: 2)),
        deliveryDate: now,
        deliveryAddress: const Address(
          id: 'a1',
          fullName: 'Suresh Raina',
          mobileNumber: '9988776655',
          houseFlat: '101',
          streetArea: 'MG Road',
          city: 'Indore',
          state: 'MP',
          pinCode: '452001',
        ),
        paymentMethod: 'UPI',
        paymentStatus: 'paid',
        assignedAgentId: 'agent_123',
        acceptedAt: accepted,
        deliveredAt: delivered,
        orderType: 'subscription',
        subscriptionId: 'sub_999',
        deliverySlot: '6:00 AM - 8:00 AM',
        cancellationReason: null,
      );

      final deliveryOrder = deliveryOrderFromOrder(testOrder);

      expect(deliveryOrder.id, equals('model_ord_1'));
      expect(deliveryOrder.orderCode, equals('MAP-001'));
      expect(deliveryOrder.status, equals(DeliveryOrderStatus.delivered));
      expect(deliveryOrder.acceptedTime, equals(accepted));
      expect(deliveryOrder.deliveredTime, equals(delivered));
      expect(deliveryOrder.isSubscription, isTrue);
      expect(deliveryOrder.subscriptionId, equals('sub_999'));
      expect(deliveryOrder.deliverySlot, equals('6:00 AM - 8:00 AM'));
      expect(deliveryOrder.paymentStatus, equals('paid'));
      expect(deliveryOrder.assignedAgentId, equals('agent_123'));
    });

    testWidgets('OrdersTab renders cancelled order with red status and cancellation reason', (tester) async {
      final cancelledOrder = DeliveryOrder(
        id: 'ord_cancel_view',
        orderId: 'ord_cancel_view',
        orderCode: 'CNC-555',
        customerName: 'Pooja Sharma',
        customerPhone: '9988998899',
        customerAddress: 'A-42 Scheme 54',
        pickupLocation: 'Hub Indore',
        pickupPhone: '0731400100',
        items: ['Cow Ghee 1L x1'],
        amount: 550.0,
        deliveryFee: 30.0,
        status: DeliveryOrderStatus.cancelled,
        cancellationReason: 'Gate locked, customer not picking phone',
        orderTime: DateTime.now().subtract(const Duration(hours: 4)),
        distance: '4.5 km',
        estimatedTime: '25 mins',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryHistoryStreamProvider.overrideWithValue(
              AsyncValue.data([cancelledOrder]),
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
      expect(find.text('Order #CNC-555'), findsOneWidget);
      expect(find.text('Pooja Sharma'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Reason: Gate locked, customer not picking phone'), findsOneWidget);
    });

    testWidgets('OrdersTab renders subscription badge and delivery slot on historical deliveries', (tester) async {
      final subOrder = DeliveryOrder(
        id: 'ord_sub_history',
        orderId: 'ord_sub_history',
        orderCode: 'SUB-777',
        customerName: 'Neha Joshi',
        customerPhone: '9123456780',
        customerAddress: 'B-12 Vijay Nagar',
        pickupLocation: 'Hub Central',
        pickupPhone: '0731400200',
        items: ['Taaza Milk 500ml x2'],
        amount: 54.0,
        deliveryFee: 15.0,
        status: DeliveryOrderStatus.delivered,
        orderTime: DateTime.now().subtract(const Duration(hours: 5)),
        deliveredTime: DateTime.now().subtract(const Duration(hours: 3)),
        distance: '2.1 km',
        estimatedTime: '15 mins',
        orderType: 'subscription',
        subscriptionId: 'sub_active_123',
        deliverySlot: 'Morning (6:30 AM - 8:00 AM)',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryHistoryStreamProvider.overrideWithValue(
              AsyncValue.data([subOrder]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(),
            ),
          ),
        ),
      );

      expect(find.text('Order #SUB-777'), findsOneWidget);
      expect(find.text('Subscription'), findsOneWidget);
      expect(find.text('Morning (6:30 AM - 8:00 AM)'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('OrdersTab renders empty state with correct messaging when history is empty', (tester) async {
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
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('OrdersTab renders error state when stream fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryHistoryStreamProvider.overrideWithValue(
              AsyncValue.error(Exception('Firestore connection timeout'), StackTrace.empty),
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
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    test('deliveryOrdersStreamProvider and deliveryHistoryStreamProvider isolate by agent ID', () async {
      final now = DateTime.now();
      final allOrders = [
        DeliveryOrder(
          id: 'ord_agent_A',
          orderId: 'ord_agent_A',
          orderCode: 'AGENT-A',
          customerName: 'Customer A',
          customerPhone: '111',
          customerAddress: 'Addr',
          pickupLocation: 'Hub',
          pickupPhone: '222',
          items: ['Milk 1L x1'],
          amount: 60.0,
          deliveryFee: 15.0,
          status: DeliveryOrderStatus.delivered,
          orderTime: now,
          distance: '1 km',
          estimatedTime: '10 mins',
          assignedAgentId: 'agent_A',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          deliveryOrdersStreamProvider.overrideWith((ref) => Stream.value(allOrders)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deliveryOrdersStreamProvider.future);
      final history = container.read(deliveryHistoryStreamProvider).value!;

      expect(history.length, equals(1));
      expect(history.first.assignedAgentId, equals('agent_A'));
    });
  });
}

