import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dairy_app/models/delivery_staff_model.dart';
import 'package:dairy_app/models/order_model.dart';
import 'package:dairy_app/providers/admin_provider.dart';
import 'package:dairy_app/screens/orders/orders_screen.dart';

class MockAdminProvider extends ChangeNotifier implements AdminProvider {
  List<DairyOrder> _mockOrders = [];
  List<DeliveryRider> _mockRiders = [];
  String? lastAssignedOrderId;
  String? lastAssignedAgentId;
  String? lastAssignedAgentName;
  String _searchQuery = '';

  @override
  List<DairyOrder> get orders => _mockOrders;

  void setMockOrders(List<DairyOrder> orders) {
    _mockOrders = orders;
    notifyListeners();
  }

  @override
  List<DeliveryRider> get riders => _mockRiders;

  void setMockRiders(List<DeliveryRider> riders) {
    _mockRiders = riders;
    notifyListeners();
  }

  @override
  bool get ordersLoading => false;

  @override
  String? get ordersError => null;

  @override
  String get searchQuery => _searchQuery;

  @override
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  @override
  Future<void> assignDeliveryAgent(
    String orderId,
    String? agentId, {
    String? agentName,
  }) async {
    lastAssignedOrderId = orderId;
    lastAssignedAgentId = agentId;
    lastAssignedAgentName = agentName;

    // Update in-memory order to simulate real-time Firestore sync
    final idx = _mockOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _mockOrders[idx] = _mockOrders[idx].copyWith(
        assignedAgentId: agentId,
        assignedAgentName: agentName,
      );
      notifyListeners();
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final idx = _mockOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _mockOrders[idx] = _mockOrders[idx].copyWith(status: newStatus);
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testRider1 = DeliveryRider(
    id: 'agent_001',
    name: 'Amit Kumar',
    phone: '+91 98765 00001',
    email: 'amit@sawariyadairy.com',
    vehicle: 'Electric Bike',
    vehicleNumber: 'UP16 AB 1234',
    assignedZone: 'Sector 74 Hub',
    totalDeliveriesToday: 12,
    pendingDeliveries: 1,
    status: 'Active',
    isOnline: true,
  );

  const testRider2 = DeliveryRider(
    id: 'agent_002',
    name: 'Rajesh Sharma',
    phone: '+91 98765 00002',
    email: 'rajesh@sawariyadairy.com',
    vehicle: 'Cargo Van',
    vehicleNumber: 'UP16 CD 5678',
    assignedZone: 'Sector 50 Hub',
    totalDeliveriesToday: 8,
    pendingDeliveries: 0,
    status: 'Offline',
    isOnline: false,
  );

  const unassignedOrder = DairyOrder(
    id: 'ord_101',
    orderCode: 'SWD101',
    customerName: 'Rahul Verma',
    customerPhone: '+91 99999 11111',
    itemsSummary: 'Cow Milk (2 L), Pure Ghee (1 kg)',
    amount: 650.0,
    status: OrderStatus.confirmed,
    deliverySlot: 'Morning (06:00 AM - 07:30 AM)',
    address: 'Flat 402, Tower A, Gaur City 2, Noida',
    time: '06:15 AM',
    paymentMode: 'Online (UPI)',
    assignedAgentId: null,
    assignedAgentName: null,
  );

  const assignedOrder = DairyOrder(
    id: 'ord_102',
    orderCode: 'SWD102',
    customerName: 'Pooja Singh',
    customerPhone: '+91 99999 22222',
    itemsSummary: 'Fresh Paneer (500g)',
    amount: 180.0,
    status: OrderStatus.preparing,
    deliverySlot: 'Morning (06:00 AM - 07:30 AM)',
    address: 'Villa 12, Sector 50, Noida',
    time: '06:30 AM',
    paymentMode: 'Cash on Delivery',
    assignedAgentId: 'agent_001',
    assignedAgentName: 'Amit Kumar',
  );

  Widget createOrdersScreenTestWidget(MockAdminProvider provider) {
    return ChangeNotifierProvider<AdminProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(
          body: OrdersScreen(),
        ),
      ),
    );
  }

  group('Task 4 — Admin Delivery Assignment Tests', () {
    test('1. DairyOrder model handles assignedAgentId and isAssigned getter',
        () {
      expect(unassignedOrder.isAssigned, isFalse);
      expect(unassignedOrder.assignedAgentId, isNull);

      expect(assignedOrder.isAssigned, isTrue);
      expect(assignedOrder.assignedAgentId, equals('agent_001'));
      expect(assignedOrder.assignedAgentName, equals('Amit Kumar'));

      final updated = unassignedOrder.copyWith(
        assignedAgentId: 'agent_002',
        assignedAgentName: 'Rajesh Sharma',
      );
      expect(updated.isAssigned, isTrue);
      expect(updated.assignedAgentId, equals('agent_002'));
      expect(updated.assignedAgentName, equals('Rajesh Sharma'));
    });

    testWidgets('2. Unassigned order displays "Assign Agent" button',
        (tester) async {
      final mockProvider = MockAdminProvider()
        ..setMockOrders([unassignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      expect(find.text('Order #SWD101'), findsOneWidget);
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Assign Agent'), findsOneWidget);
      expect(find.text('Tap to reassign'), findsNothing);
    });

    testWidgets(
        '3. Assigned order displays current agent name and reassign affordance',
        (tester) async {
      final mockProvider = MockAdminProvider()
        ..setMockOrders([assignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      expect(find.text('Order #SWD102'), findsOneWidget);
      expect(find.text('Pooja Singh'), findsOneWidget);
      expect(find.text('Amit Kumar'), findsOneWidget);
      expect(find.text('Tap to reassign'), findsOneWidget);
    });

    testWidgets(
        '4. Tapping "Assign Agent" opens assignment dialog with available riders',
        (tester) async {
      final mockProvider = MockAdminProvider()
        ..setMockOrders([unassignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      // Click "Assign Agent"
      await tester.tap(find.text('Assign Agent'));
      await tester.pumpAndSettle();

      expect(find.text('Assign Delivery Agent'), findsOneWidget);
      expect(find.text('Order #SWD101 • Rahul Verma'), findsOneWidget);
      expect(find.text('Amit Kumar'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.textContaining('Sector 74 Hub'), findsOneWidget);
      expect(find.textContaining('Sector 50 Hub'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('5. Admin selects a rider and confirms assignment',
        (tester) async {
      final mockProvider = MockAdminProvider()
        ..setMockOrders([unassignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Assign Agent'));
      await tester.pumpAndSettle();

      // Select Amit Kumar
      await tester.tap(find.text('Amit Kumar'));
      await tester.pumpAndSettle();

      // Click confirm
      await tester.tap(find.text('Assign Agent').last);
      await tester.pumpAndSettle();

      expect(mockProvider.lastAssignedOrderId, equals('ord_101'));
      expect(mockProvider.lastAssignedAgentId, equals('agent_001'));
      expect(mockProvider.lastAssignedAgentName, equals('Amit Kumar'));

      // Status should remain confirmed (preserved)
      expect(mockProvider.orders.first.status, equals(OrderStatus.confirmed));
      expect(mockProvider.orders.first.isAssigned, isTrue);
    });

    testWidgets(
        '6. Admin can reassign an already assigned order to another rider',
        (tester) async {
      final mockProvider = MockAdminProvider()
        ..setMockOrders([assignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      // Tap on assigned agent tile
      await tester.tap(find.text('Amit Kumar'));
      await tester.pumpAndSettle();

      expect(find.text('Reassign Delivery Agent'), findsOneWidget);

      // Select Rajesh Sharma
      await tester.tap(find.text('Rajesh Sharma'));
      await tester.pumpAndSettle();

      // Confirm reassignment
      await tester.tap(find.text('Confirm Reassignment'));
      await tester.pumpAndSettle();

      expect(mockProvider.lastAssignedOrderId, equals('ord_102'));
      expect(mockProvider.lastAssignedAgentId, equals('agent_002'));
      expect(mockProvider.lastAssignedAgentName, equals('Rajesh Sharma'));
      // Preserved preparing status
      expect(mockProvider.orders.first.status, equals(OrderStatus.preparing));
    });

    testWidgets('7. Admin can unassign a delivery agent from an assigned order',
        (tester) async {
      final mockProvider = MockAdminProvider()
        ..setMockOrders([assignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      // Tap on assigned agent tile
      await tester.tap(find.text('Amit Kumar'));
      await tester.pumpAndSettle();

      expect(find.text('Unassign'), findsOneWidget);

      // Tap Unassign
      await tester.tap(find.text('Unassign'));
      await tester.pumpAndSettle();

      expect(mockProvider.lastAssignedOrderId, equals('ord_102'));
      expect(mockProvider.lastAssignedAgentId, isNull);
      expect(mockProvider.orders.first.isAssigned, isFalse);
    });

    testWidgets('8. Search input in assignment dialog filters delivery agents',
        (tester) async {
      final mockProvider = MockAdminProvider()
        ..setMockOrders([unassignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assign Agent'));
      await tester.pumpAndSettle();

      expect(find.text('Amit Kumar'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'Rajesh');
      await tester.pumpAndSettle();

      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('Amit Kumar'), findsNothing);
    });

    testWidgets(
        '9. Desktop viewport renders Orders table without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockProvider = MockAdminProvider()
        ..setMockOrders([unassignedOrder, assignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order #SWD101'), findsOneWidget);
      expect(find.text('Order #SWD102'), findsOneWidget);
    });

    testWidgets(
        '10. Mobile viewport renders Orders list without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockProvider = MockAdminProvider()
        ..setMockOrders([unassignedOrder, assignedOrder])
        ..setMockRiders([testRider1, testRider2]);

      await tester.pumpWidget(createOrdersScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order #SWD101'), findsOneWidget);
      expect(find.text('Order #SWD102'), findsOneWidget);
    });
  });
}
