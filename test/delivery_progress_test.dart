import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/delivery_model.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/order_model.dart' as order_model;
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/providers/admin_provider.dart';
import 'package:dairy_app/screens/delivery/delivery_management_screen.dart';
import 'package:dairy_app/services/delivery_management_service.dart';

class MockProgressAdminProvider extends ChangeNotifier
    implements AdminProvider {
  TodaysDeliveryProgress _todaysDeliveryProgress = TodaysDeliveryProgress.empty;
  bool _todaysDeliveryProgressLoading = false;
  String? _todaysDeliveryProgressError;

  final List<DeliveryCorridor> _corridors = const [];
  final bool _corridorsLoading = false;
  final String? _corridorsError = null;

  final List<DeliveryBatch> _deliveryBatches = const [];
  final bool _deliveryBatchesLoading = false;
  final String? _deliveryBatchesError = null;

  @override
  TodaysDeliveryProgress get todaysDeliveryProgress => _todaysDeliveryProgress;

  @override
  bool get todaysDeliveryProgressLoading => _todaysDeliveryProgressLoading;

  @override
  String? get todaysDeliveryProgressError => _todaysDeliveryProgressError;

  @override
  int get todaysTotalDeliveries => _todaysDeliveryProgress.total;

  @override
  int get todaysCompletedDeliveries => _todaysDeliveryProgress.completed;

  @override
  int get todaysPendingDeliveries => _todaysDeliveryProgress.pending;

  @override
  int get todaysCancelledDeliveries => _todaysDeliveryProgress.cancelled;

  @override
  double get todaysCompletionPercentage =>
      _todaysDeliveryProgress.completionPercentage;

  @override
  List<DeliveryCorridor> get corridors => _corridors;

  @override
  bool get corridorsLoading => _corridorsLoading;

  @override
  String? get corridorsError => _corridorsError;

  @override
  List<DeliveryBatch> get deliveryBatches => _deliveryBatches;

  @override
  bool get deliveryBatchesLoading => _deliveryBatchesLoading;

  @override
  String? get deliveryBatchesError => _deliveryBatchesError;

  @override
  List<order_model.DairyOrder> get orders => [];

  void setMockProgress(TodaysDeliveryProgress progress) {
    _todaysDeliveryProgress = progress;
    _todaysDeliveryProgressLoading = false;
    _todaysDeliveryProgressError = null;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _todaysDeliveryProgressLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _todaysDeliveryProgressError = error;
    _todaysDeliveryProgressLoading = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Order createTestOrder({
  required String id,
  required OrderStatus status,
  DateTime? orderDate,
  DateTime? deliveryDate,
}) {
  final now = DateTime.now();
  return Order(
    id: id,
    orderCode: 'ORD001',
    items: const [
      CartItem(
        product: Product(
          id: 'p1',
          title: 'Fresh Cow Milk',
          price: 60.0,
          unit: '1L',
          imageUrl: 'assets/images/nnd.png',
          categoryId: 'cat_milk',
          categoryName: 'Milk',
        ),
        quantity: 2,
      ),
    ],
    subtotal: 120.0,
    totalAmount: 120.0,
    status: status,
    orderDate: orderDate ?? now,
    deliveryDate: deliveryDate,
    deliveryAddress: const Address(
      id: 'addr1',
      label: 'Home',
      fullName: 'Rahul Sharma',
      mobileNumber: '+91 9876543210',
      houseFlat: 'Flat 101',
      streetArea: 'Sector 62',
      city: 'Noida',
      state: 'Uttar Pradesh',
      pinCode: '201301',
    ),
  );
}

void main() {
  group('P0.3 — DeliveryDate & Real-Time Today\'s Progress Calculation Tests', () {
    final today = DateTime(2026, 9, 17, 10, 30);
    final yesterday = DateTime(2026, 9, 16, 18, 0);
    final tomorrow = DateTime(2026, 9, 18, 7, 0);

    test('1. deliveryDate serialization to Firestore Timestamp', () {
      final order = createTestOrder(
        id: 'ord_serialize_1',
        status: OrderStatus.placed,
        deliveryDate: today,
      );

      final map = order.toFirestore();
      expect(map['deliveryDate'], isA<Timestamp>());
      expect((map['deliveryDate'] as Timestamp).toDate(), today);

      final toMapResult = order.toMap();
      expect(toMapResult['deliveryDate'], isA<Timestamp>());
    });

    test('2. deliveryDate deserialization from Firestore Timestamp and String', () {
      final docMapTimestamp = {
        'status': 'pending',
        'createdAt': Timestamp.fromDate(today),
        'deliveryDate': Timestamp.fromDate(today),
        'totalAmount': 100.0,
        'items': [],
      };
      final orderFromTs = Order.fromFirestore(docMapTimestamp, 'ord_ts');
      expect(orderFromTs.deliveryDate, equals(today));

      final docMapString = {
        'status': 'delivered',
        'createdAt': today.toIso8601String(),
        'deliveryDate': today.toIso8601String(),
        'totalAmount': 150.0,
        'items': [],
      };
      final orderFromStr = Order.fromFirestore(docMapString, 'ord_str');
      expect(orderFromStr.deliveryDate, equals(today));
    });

    test('3. missing deliveryDate safely defaults to null and does not crash', () {
      final docMapEmpty = {
        'status': 'placed',
        'createdAt': Timestamp.fromDate(today),
        'totalAmount': 200.0,
        'items': [],
      };
      final order = Order.fromFirestore(docMapEmpty, 'ord_missing_date');
      expect(order.deliveryDate, isNull);
      expect(order.id, 'ord_missing_date');
      expect(order.status, OrderStatus.placed);
    });

    test('4. today\'s order filtering includes only today\'s boundaries', () {
      final orders = [
        createTestOrder(
          id: 'o_today_start',
          status: OrderStatus.placed,
          deliveryDate: DateTime(2026, 9, 17, 0, 0, 0),
        ),
        createTestOrder(
          id: 'o_today_mid',
          status: OrderStatus.confirmed,
          deliveryDate: DateTime(2026, 9, 17, 12, 0, 0),
        ),
        createTestOrder(
          id: 'o_today_end',
          status: OrderStatus.delivered,
          deliveryDate: DateTime(2026, 9, 17, 23, 59, 59),
        ),
      ];

      final progress = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );

      expect(progress.total, 3);
      expect(progress.completed, 1);
      expect(progress.pending, 2);
    });

    test('5. yesterday\'s orders are excluded from today\'s progress', () {
      final orders = [
        createTestOrder(
          id: 'o_yesterday',
          status: OrderStatus.delivered,
          deliveryDate: yesterday,
        ),
        createTestOrder(
          id: 'o_today',
          status: OrderStatus.placed,
          deliveryDate: today,
        ),
      ];

      final progress = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );

      expect(progress.total, 1);
      expect(progress.completed, 0);
      expect(progress.pending, 1);
    });

    test('6. tomorrow\'s orders are excluded from today\'s progress', () {
      final orders = [
        createTestOrder(
          id: 'o_tomorrow',
          status: OrderStatus.confirmed,
          deliveryDate: tomorrow,
        ),
        createTestOrder(
          id: 'o_today',
          status: OrderStatus.delivered,
          deliveryDate: today,
        ),
      ];

      final progress = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );

      expect(progress.total, 1);
      expect(progress.completed, 1);
      expect(progress.pending, 0);
    });

    test('7. completed deliveries calculation (delivered status)', () {
      final orders = [
        createTestOrder(
          id: 'o1',
          status: OrderStatus.delivered,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o2',
          status: OrderStatus.delivered,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o3',
          status: OrderStatus.placed,
          deliveryDate: today,
        ),
      ];

      final progress = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );

      expect(progress.completed, 2);
    });

    test('8. pending deliveries calculation (placed, confirmed, preparing, outForDelivery)', () {
      final orders = [
        createTestOrder(
          id: 'o1',
          status: OrderStatus.placed,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o2',
          status: OrderStatus.confirmed,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o3',
          status: OrderStatus.preparing,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o4',
          status: OrderStatus.outForDelivery,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o5',
          status: OrderStatus.delivered,
          deliveryDate: today,
        ),
      ];

      final progress = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );

      expect(progress.pending, 4);
      expect(progress.completed, 1);
      expect(progress.total, 5);
    });

    test('9. cancelled deliveries calculation is separated from active pending', () {
      final orders = [
        createTestOrder(
          id: 'o1',
          status: OrderStatus.cancelled,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o2',
          status: OrderStatus.cancelled,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o3',
          status: OrderStatus.placed,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o4',
          status: OrderStatus.delivered,
          deliveryDate: today,
        ),
      ];

      final progress = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );

      expect(progress.cancelled, 2);
      expect(progress.pending, 1);
      expect(progress.completed, 1);
      expect(progress.total, 2); // Non-cancelled active orders
    });

    test('10. zero deliveries handles empty state gracefully without division by zero', () {
      final progress = DeliveryManagementService.calculateTodaysProgress(
        [],
        targetDate: today,
      );

      expect(progress.total, 0);
      expect(progress.completed, 0);
      expect(progress.pending, 0);
      expect(progress.cancelled, 0);
      expect(progress.completionPercentage, 0.0);
      expect(progress.progressFraction, 0.0);
    });

    test('11. completion percentage calculation', () {
      final orders = [
        createTestOrder(
          id: 'o1',
          status: OrderStatus.delivered,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o2',
          status: OrderStatus.delivered,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o3',
          status: OrderStatus.placed,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o4',
          status: OrderStatus.outForDelivery,
          deliveryDate: today,
        ),
      ];

      final progress = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );

      expect(progress.total, 4);
      expect(progress.completed, 2);
      expect(progress.completionPercentage, 50.0);
      expect(progress.progressFraction, 0.5);
    });

    test('12. status transition from pending to delivered updates progress dynamically', () {
      var orders = [
        createTestOrder(
          id: 'o1',
          status: OrderStatus.placed,
          deliveryDate: today,
        ),
        createTestOrder(
          id: 'o2',
          status: OrderStatus.outForDelivery,
          deliveryDate: today,
        ),
      ];

      var progressBefore = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );
      expect(progressBefore.completed, 0);
      expect(progressBefore.pending, 2);
      expect(progressBefore.completionPercentage, 0.0);

      // Transition o1 from placed to delivered
      orders = [
        orders[0].copyWith(status: OrderStatus.delivered),
        orders[1],
      ];

      var progressAfter = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );
      expect(progressAfter.completed, 1);
      expect(progressAfter.pending, 1);
      expect(progressAfter.completionPercentage, 50.0);

      // Transition o2 to cancelled
      orders = [
        orders[0],
        orders[1].copyWith(status: OrderStatus.cancelled),
      ];

      var progressFinal = DeliveryManagementService.calculateTodaysProgress(
        orders,
        targetDate: today,
      );
      expect(progressFinal.completed, 1);
      expect(progressFinal.pending, 0);
      expect(progressFinal.cancelled, 1);
      expect(progressFinal.total, 1);
      expect(progressFinal.completionPercentage, 100.0);
    });
  });

  group('P0.3 — DeliveryManagementScreen UI Real-Time Progress Tests', () {
    Widget buildTestScreen(MockProgressAdminProvider provider) {
      return MaterialApp(
        home: ChangeNotifierProvider<AdminProvider>.value(
          value: provider,
          child: const Scaffold(
            body: DeliveryManagementScreen(),
          ),
        ),
      );
    }

    testWidgets('13. Renders Today\'s Delivery Progress cards with real data and percentage',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final provider = MockProgressAdminProvider();
      provider.setMockProgress(
        const TodaysDeliveryProgress(
          total: 20,
          completed: 15,
          pending: 5,
          cancelled: 2,
          completionPercentage: 75.0,
        ),
      );

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pump();

      expect(find.text("Today's Delivery Progress"), findsOneWidget);
      expect(find.text('Real-Time Dispatch Status'), findsOneWidget);
      expect(find.text('15 of 20 deliveries fulfilled'), findsOneWidget);
      expect(find.text('75% Completed'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('14. Renders Today\'s Delivery Progress zero/empty state cleanly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final provider = MockProgressAdminProvider();
      provider.setMockProgress(TodaysDeliveryProgress.empty);

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pump();

      expect(find.text("Today's Delivery Progress"), findsOneWidget);
      expect(find.text('0% Completed'), findsOneWidget);
      expect(find.text('0 of 0 deliveries fulfilled'), findsOneWidget);
      expect(find.text('No deliveries scheduled for today yet.'), findsOneWidget);
    });

    testWidgets('15. Renders Today\'s Delivery Progress loading and error states',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final provider = MockProgressAdminProvider();
      provider.setLoading(true);

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      provider.setError('Failed to load orders: network timeout');
      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pump();

      expect(find.text('Failed to load orders: network timeout'), findsOneWidget);
    });
  });
}
