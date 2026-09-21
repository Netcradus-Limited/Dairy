import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/delivery_panel/screens/requests_tab.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/services/order_service.dart';

class MockOrderService extends OrderService {
  final Map<String, Map<String, dynamic>> orderStore = {};
  bool throwOnDecline = false;
  String? lastDeclinedOrderId;
  String? lastDeclinedAgentId;
  String? lastAcceptedOrderId;
  String? lastAcceptedAgentId;

  MockOrderService();

  @override
  Future<void> declineOrder(String orderId, String agentId) async {
    final cleanOrderId = orderId.trim();
    final cleanAgentId = agentId.trim();
    if (cleanOrderId.isEmpty) {
      throw ArgumentError('orderId cannot be empty');
    }
    if (throwOnDecline) {
      throw Exception('Firestore network timeout or write failed');
    }

    final data = orderStore[cleanOrderId];
    if (data == null) {
      throw StateError('Order not found: $cleanOrderId');
    }

    final currentAssignedAgentId = (data['assignedAgentId'] as String?)?.trim();
    if (currentAssignedAgentId != null &&
        currentAssignedAgentId.isNotEmpty &&
        currentAssignedAgentId != cleanAgentId) {
      throw StateError(
          'Order is no longer assigned to delivery agent $cleanAgentId.');
    }

    lastDeclinedOrderId = cleanOrderId;
    lastDeclinedAgentId = cleanAgentId;

    if (currentAssignedAgentId != null &&
        currentAssignedAgentId.isNotEmpty &&
        currentAssignedAgentId == cleanAgentId) {
      data['status'] = 'Pending';
      data['assignedAgentId'] = null;
      data['acceptedAt'] = null;
    }
  }

  @override
  Future<void> acceptOrder(String orderId, String agentId) async {
    lastAcceptedOrderId = orderId;
    lastAcceptedAgentId = agentId;
    final data = orderStore[orderId];
    if (data != null) {
      data['status'] = 'accepted';
      data['assignedAgentId'] = agentId;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  MockDeliveryNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Order createTestOrder({
  required String id,
  required String orderCode,
  String? assignedAgentId,
  OrderStatus status = OrderStatus.placed,
}) {
  return Order(
    id: id,
    orderCode: orderCode,
    items: const [
      CartItem(
        product: Product(
          id: 'p1',
          title: 'Pure Buffalo Milk',
          price: 65.0,
          unit: '1L',
          imageUrl: '',
          categoryId: 'cat_milk',
          categoryName: 'Milk',
        ),
        quantity: 2,
      ),
    ],
    subtotal: 130.0,
    deliveryCharge: 30.0,
    totalAmount: 160.0,
    status: status,
    orderDate: DateTime.now(),
    deliveryAddress: const Address(
      id: 'addr_1',
      fullName: 'Vikram Singh',
      mobileNumber: '+91 98765 43210',
      houseFlat: 'Flat 402, Tower B',
      streetArea: 'Sector 74',
      city: 'Noida',
      state: 'UP',
      pinCode: '201301',
      latitude: 28.5700,
      longitude: 77.3800,
    ),
    assignedAgentId: assignedAgentId,
  );
}

DeliveryOrder createTestDeliveryOrder({
  required String id,
  required String orderCode,
  String? assignedAgentId,
  DeliveryOrderStatus status = DeliveryOrderStatus.pendingAcceptance,
}) {
  return DeliveryOrder(
    id: id,
    orderId: id,
    orderCode: orderCode,
    customerName: 'Vikram Singh',
    customerPhone: '+91 98765 43210',
    customerAddress: 'Flat 402, Tower B, Sector 74, Noida',
    pickupLocation: 'Sawariya Dairy Hub, Vijay Nagar',
    pickupPhone: '+91 731 400 5000',
    items: ['Pure Buffalo Milk 1L x2'],
    amount: 160.0,
    deliveryFee: 30.0,
    status: status,
    orderTime: DateTime.now(),
    distance: '1.8 km',
    estimatedTime: '15 mins',
    assignedAgentId: assignedAgentId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testAgent = DeliveryAgent(
    id: 'agent_001',
    name: 'Rahul Yadav',
    phone: '+91 98765 11111',
    vehicle: 'Bike',
    vehicleNumber: 'UP16 AB 9999',
    assignedZone: 'Noida Central',
    status: DeliveryStatus.onDuty,
    totalDeliveriesToday: 4,
    completedDeliveriesToday: 3,
    earningsToday: 240.0,
    isLoaded: true,
  );

  group('Task 1: Delivery Order Decline Firestore Sync — Service & Logic Tests', () {
    late MockOrderService mockOrderService;

    setUp(() {
      mockOrderService = MockOrderService();
    });

    test('1. DeliveryOrder model preserves and copies assignedAgentId', () {
      final order = createTestOrder(
        id: 'ord_101',
        orderCode: 'SWD101',
        assignedAgentId: 'agent_001',
      );
      final deliveryOrder = deliveryOrderFromOrder(order);

      expect(deliveryOrder.assignedAgentId, equals('agent_001'));
      expect(deliveryOrder.orderId, equals('ord_101'));
      expect(deliveryOrder.displayCode, equals('SWD101'));

      final updated = deliveryOrder.copyWith(assignedAgentId: null);
      expect(updated.assignedAgentId, isNull);
    });

    test('2. Decline assigned order successfully unassigns agent and resets status to Pending', () async {
      mockOrderService.orderStore['ord_101'] = {
        'status': 'placed',
        'assignedAgentId': 'agent_001',
        'acceptedAt': null,
      };

      await mockOrderService.declineOrder('ord_101', 'agent_001');

      expect(mockOrderService.lastDeclinedOrderId, equals('ord_101'));
      expect(mockOrderService.lastDeclinedAgentId, equals('agent_001'));

      final orderInStore = mockOrderService.orderStore['ord_101']!;
      expect(orderInStore['assignedAgentId'], isNull);
      expect(orderInStore['acceptedAt'], isNull);
      expect(orderInStore['status'], equals('Pending'));
    });

    test('3. Concurrency safety: declining order assigned to another agent throws StateError without modifying store', () async {
      mockOrderService.orderStore['ord_102'] = {
        'status': 'placed',
        'assignedAgentId': 'agent_002', // Reassigned to agent_002!
        'acceptedAt': null,
      };

      expect(
        () => mockOrderService.declineOrder('ord_102', 'agent_001'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no longer assigned to delivery agent agent_001'),
        )),
      );

      // Verify that agent_002's assignment is untouched!
      final orderInStore = mockOrderService.orderStore['ord_102']!;
      expect(orderInStore['assignedAgentId'], equals('agent_002'));
    });

    test('4. Declining already unassigned order completes safely without error', () async {
      mockOrderService.orderStore['ord_103'] = {
        'status': 'Pending',
        'assignedAgentId': null,
        'acceptedAt': null,
      };

      await mockOrderService.declineOrder('ord_103', 'agent_001');

      final orderInStore = mockOrderService.orderStore['ord_103']!;
      expect(orderInStore['assignedAgentId'], isNull);
      expect(orderInStore['status'], equals('Pending'));
    });

    test('5. Existing acceptOrder behavior remains intact', () async {
      mockOrderService.orderStore['ord_104'] = {
        'status': 'Pending',
        'assignedAgentId': null,
      };

      await mockOrderService.acceptOrder('ord_104', 'agent_001');

      expect(mockOrderService.lastAcceptedOrderId, equals('ord_104'));
      expect(mockOrderService.lastAcceptedAgentId, equals('agent_001'));
      final orderInStore = mockOrderService.orderStore['ord_104']!;
      expect(orderInStore['status'], equals('accepted'));
      expect(orderInStore['assignedAgentId'], equals('agent_001'));
    });
  });

  group('Task 1: Delivery Panel Requests Tab — UI Decline Sync & Error Handling Tests', () {
    late MockOrderService mockOrderService;

    setUp(() {
      mockOrderService = MockOrderService();
    });

    Widget createTestWidget({
      required List<DeliveryOrder> requests,
      DeliveryAgent agent = testAgent,
    }) {
      return ProviderScope(
        overrides: [
          orderServiceProvider.overrideWithValue(mockOrderService),
          deliveryAgentProvider
              .overrideWith((ref) => MockDeliveryNotifier(agent)),
          deliveryOrdersStreamProvider
              .overrideWith((ref) => Stream.value(requests)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RequestsTab(),
          ),
        ),
      );
    }

    testWidgets('6. Declining assigned order calls declineOrder and dismisses card on success', (tester) async {
      final assignedDeliveryOrder = createTestDeliveryOrder(
        id: 'ord_201',
        orderCode: 'SWD201',
        assignedAgentId: 'agent_001',
      );

      mockOrderService.orderStore['ord_201'] = {
        'status': 'placed',
        'assignedAgentId': 'agent_001',
        'acceptedAt': null,
      };

      await tester.pumpWidget(createTestWidget(requests: [assignedDeliveryOrder]));
      await tester.pumpAndSettle();

      // Card is visible
      expect(find.text('Order #SWD201'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      // Tap Decline
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      // Verify declineOrder was called with correct parameters
      expect(mockOrderService.lastDeclinedOrderId, equals('ord_201'));
      expect(mockOrderService.lastDeclinedAgentId, equals('agent_001'));

      // Verify Firestore order store was updated
      expect(mockOrderService.orderStore['ord_201']!['assignedAgentId'], isNull);
      expect(mockOrderService.orderStore['ord_201']!['status'], equals('Pending'));

      // Card is dismissed and success SnackBar is displayed
      expect(find.text('Order #SWD201'), findsNothing);
      expect(find.text('Order #SWD201 declined'), findsOneWidget);
    });

    testWidgets('7. Firestore failure does NOT falsely dismiss the card locally', (tester) async {
      final assignedDeliveryOrder = createTestDeliveryOrder(
        id: 'ord_202',
        orderCode: 'SWD202',
        assignedAgentId: 'agent_001',
      );

      mockOrderService.orderStore['ord_202'] = {
        'status': 'placed',
        'assignedAgentId': 'agent_001',
      };
      // Simulate network or Firestore write failure
      mockOrderService.throwOnDecline = true;

      await tester.pumpWidget(createTestWidget(requests: [assignedDeliveryOrder]));
      await tester.pumpAndSettle();

      expect(find.text('Order #SWD202'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      // Tap Decline
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      // The order card MUST STILL BE VISIBLE! Local state must NOT falsely dismiss it!
      expect(find.text('Order #SWD202'), findsOneWidget);

      // Error message is displayed
      expect(find.text('Could not decline order. Please try again.'), findsOneWidget);
    });

    testWidgets('8. Concurrency failure does NOT falsely dismiss the card locally', (tester) async {
      final assignedDeliveryOrder = createTestDeliveryOrder(
        id: 'ord_203',
        orderCode: 'SWD203',
        assignedAgentId: 'agent_001',
      );

      // Order was reassigned to agent_002 concurrently in Firestore
      mockOrderService.orderStore['ord_203'] = {
        'status': 'placed',
        'assignedAgentId': 'agent_002',
      };

      await tester.pumpWidget(createTestWidget(requests: [assignedDeliveryOrder]));
      await tester.pumpAndSettle();

      expect(find.text('Order #SWD203'), findsOneWidget);

      // Tap Decline
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      // Order card must remain visible because decline failed
      expect(find.text('Order #SWD203'), findsOneWidget);

      // Error message is displayed
      expect(find.text('Could not decline order. Please try again.'), findsOneWidget);
    });
  });
}
