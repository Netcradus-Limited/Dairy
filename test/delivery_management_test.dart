import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dairy_app/models/delivery_model.dart';
import 'package:dairy_app/providers/admin_provider.dart';
import 'package:dairy_app/screens/delivery/delivery_management_screen.dart';

class MockDeliveryAdminProvider extends ChangeNotifier
    implements AdminProvider {
  List<DeliveryCorridor> _corridors = [];
  bool _corridorsLoading = false;
  String? _corridorsError;

  List<DeliveryBatch> _deliveryBatches = [];
  bool _deliveryBatchesLoading = false;
  String? _deliveryBatchesError;

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

  void setMockData({
    List<DeliveryCorridor>? corridors,
    List<DeliveryBatch>? batches,
  }) {
    _corridors = corridors ?? [];
    _corridorsLoading = false;
    _corridorsError = null;

    _deliveryBatches = batches ?? [];
    _deliveryBatchesLoading = false;
    _deliveryBatchesError = null;

    notifyListeners();
  }

  void setLoading(bool loading) {
    _corridorsLoading = loading;
    _deliveryBatchesLoading = loading;
    notifyListeners();
  }

  void setError({String? corridorsErr, String? batchesErr}) {
    _corridorsError = corridorsErr;
    _deliveryBatchesError = batchesErr;
    _corridorsLoading = false;
    _deliveryBatchesLoading = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('P0.2 — Delivery Management Model Tests', () {
    test('1. DeliveryBatch fromFirestore and toFirestore serialization', () {
      final now = DateTime(2026, 9, 17, 6, 0);
      final rawData = <String, dynamic>{
        'id': 'batch_101',
        'name': 'Morning Dispatch Batch #1',
        'deliveryId': '#DLV1001',
        'deliveryDate': Timestamp.fromDate(now),
        'agentId': 'agent_rajesh',
        'agentName': 'Rajesh Kumar',
        'staffName': 'Rajesh Kumar',
        'status': 'On Route',
        'totalOrders': 20,
        'completedOrders': 15,
        'pendingOrders': 5,
        'zone': 'Vijay Nagar Zone',
        'routeId': 'route_vijay_nagar',
        'orderIds': ['ord_1', 'ord_2'],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final batch = DeliveryBatch.fromFirestore(rawData, 'batch_101');
      expect(batch.id, 'batch_101');
      expect(batch.name, 'Morning Dispatch Batch #1');
      expect(batch.deliveryId, '#DLV1001');
      expect(batch.staffName, 'Rajesh Kumar');
      expect(batch.status, 'On Route');
      expect(batch.totalOrders, 20);
      expect(batch.completedOrders, 15);
      expect(batch.pendingOrders, 5);
      expect(batch.assignedCount, 20);
      expect(batch.completedCount, 15);
      expect(batch.completionPercentage, 0.75);
      expect(batch.zone, 'Vijay Nagar Zone');
      expect(batch.orderIds, ['ord_1', 'ord_2']);

      final mapped = batch.toFirestore();
      expect(mapped['id'], 'batch_101');
      expect(mapped['name'], 'Morning Dispatch Batch #1');
      expect(mapped['status'], 'On Route');
      expect(mapped['totalOrders'], 20);
      expect(mapped['completedOrders'], 15);
      expect(mapped['pendingOrders'], 5);
      expect(mapped['zone'], 'Vijay Nagar Zone');
    });

    test('2. DeliveryBatch safe defaults when fields are missing or null', () {
      final batch = DeliveryBatch.fromFirestore({}, 'batch_fallback');
      expect(batch.id, 'batch_fallback');
      expect(batch.staffName, 'Delivery Partner');
      expect(batch.status, 'Pending');
      expect(batch.totalOrders, 0);
      expect(batch.completedOrders, 0);
      expect(batch.pendingOrders, 0);
      expect(batch.completionPercentage, 0.0);
      expect(batch.zone, 'Standard Zone');
      expect(batch.orderIds, isEmpty);
    });

    test('3. DeliveryCorridor fromFirestore and toFirestore serialization', () {
      final now = DateTime(2026, 9, 17, 5, 30);
      final rawData = <String, dynamic>{
        'id': 'route_north_1',
        'routeName': 'Route 1 — North Zone',
        'zone': 'North Zone Corridor',
        'riderName': 'Vikram Singh',
        'agentId': 'agent_vikram',
        'subscribersCount': 42,
        'completedOrders': 30,
        'timing': '05:00 AM - 07:00 AM',
        'vehicleType': 'Electric Van',
        'status': 'Active',
        'orderIds': ['ord_10', 'ord_11'],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final corridor = DeliveryCorridor.fromFirestore(rawData, 'route_north_1');
      expect(corridor.id, 'route_north_1');
      expect(corridor.routeName, 'Route 1 — North Zone');
      expect(corridor.zone, 'North Zone Corridor');
      expect(corridor.riderName, 'Vikram Singh');
      expect(corridor.agentId, 'agent_vikram');
      expect(corridor.subscribersCount, 42);
      expect(corridor.totalOrders, 42);
      expect(corridor.completedOrders, 30);
      expect(corridor.timing, '05:00 AM - 07:00 AM');
      expect(corridor.vehicleType, 'Electric Van');
      expect(corridor.status, 'Active');
      expect(corridor.orderIds, ['ord_10', 'ord_11']);

      final mapped = corridor.toFirestore();
      expect(mapped['id'], 'route_north_1');
      expect(mapped['name'], 'Route 1 — North Zone');
      expect(mapped['subscribersCount'], 42);
      expect(mapped['vehicleType'], 'Electric Van');
    });

    test('4. DeliveryCorridor safe defaults when fields are missing', () {
      final corridor = DeliveryCorridor.fromFirestore({}, 'fallback_route');
      expect(corridor.id, 'fallback_route');
      expect(corridor.routeName, 'fallback_route');
      expect(corridor.zone, 'Standard Zone');
      expect(corridor.riderName, 'Unassigned');
      expect(corridor.subscribersCount, 0);
      expect(corridor.timing, '05:00 AM - 07:00 AM');
      expect(corridor.vehicleType, 'Delivery Vehicle');
      expect(corridor.status, 'Active');
    });
  });

  group('P0.2 — Delivery Management Screen UI Tests', () {
    Widget buildTestScreen(MockDeliveryAdminProvider provider) {
      return MaterialApp(
        home: ChangeNotifierProvider<AdminProvider>.value(
          value: provider,
          child: const Scaffold(
            body: DeliveryManagementScreen(),
          ),
        ),
      );
    }

    testWidgets('5. Renders empty states when Firestore collections are empty',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final provider = MockDeliveryAdminProvider();
      provider.setMockData(corridors: [], batches: []);

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pump();

      expect(find.text('Delivery Routes & Dispatch'), findsOneWidget);
      expect(find.text('Active Delivery Corridors'), findsOneWidget);
      expect(
          find.text('No active delivery corridors registered yet.'),
          findsOneWidget);
      expect(
          find.text("Today's Batch Deliveries Progress"), findsOneWidget);
      expect(find.text('No delivery batches dispatched today.'), findsOneWidget);
    });

    testWidgets('6. Renders loading state correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final provider = MockDeliveryAdminProvider();
      provider.setLoading(true);

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('7. Renders error state correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final provider = MockDeliveryAdminProvider();
      provider.setError(
        corridorsErr: 'Failed to load delivery routes: permission denied',
        batchesErr: 'Failed to load delivery batches: timeout',
      );

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pump();

      expect(
          find.text('Failed to load delivery routes: permission denied'),
          findsOneWidget);
      expect(
          find.text('Failed to load delivery batches: timeout'),
          findsOneWidget);
    });

    testWidgets(
        '8. Renders real Firestore corridors and batches dynamically',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final provider = MockDeliveryAdminProvider();
      provider.setMockData(
        corridors: const [
          DeliveryCorridor(
            id: 'corridor_1',
            routeName: 'Route 1 — Vijay Nagar',
            zone: 'Vijay Nagar',
            riderName: 'Rajesh Kumar',
            agentId: 'agent_1',
            subscribersCount: 45,
            completedOrders: 35,
            timing: '05:00 AM - 07:00 AM',
            vehicleType: 'EV Bike',
            status: 'Active',
          ),
          DeliveryCorridor(
            id: 'corridor_2',
            routeName: 'Route 2 — Palasia',
            zone: 'Palasia',
            riderName: 'Vikram Singh',
            agentId: 'agent_2',
            subscribersCount: 30,
            completedOrders: 20,
            timing: '05:30 AM - 07:30 AM',
            vehicleType: 'Delivery Van',
            status: 'Active',
          ),
        ],
        batches: const [
          DeliveryBatch(
            id: 'batch_1',
            deliveryId: '#DLV1001',
            name: 'Batch #1 - Morning Milk',
            staffName: 'Rajesh Kumar',
            agentId: 'agent_1',
            totalOrders: 45,
            completedOrders: 35,
            pendingOrders: 10,
            status: 'On Route',
            zone: 'Vijay Nagar',
          ),
          DeliveryBatch(
            id: 'batch_2',
            deliveryId: '#DLV1002',
            name: 'Batch #2 - Palasia Express',
            staffName: 'Vikram Singh',
            agentId: 'agent_2',
            totalOrders: 30,
            completedOrders: 30,
            pendingOrders: 0,
            status: 'Completed',
            zone: 'Palasia',
          ),
        ],
      );

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pump();

      // Corridors verification
      expect(find.text('Route 1 — Vijay Nagar'), findsOneWidget);
      expect(find.text('Route 2 — Palasia'), findsOneWidget);
      expect(find.text('45 Subscriptions'), findsOneWidget);
      expect(find.text('30 Subscriptions'), findsOneWidget);
      expect(find.text('EV Bike'), findsOneWidget);
      expect(find.text('Delivery Van'), findsOneWidget);

      // Batches verification
      expect(find.text('#DLV1001'), findsOneWidget);
      expect(find.text('#DLV1002'), findsOneWidget);
      expect(find.text('35 / 45 Delivered'), findsOneWidget);
      expect(find.text('30 / 30 Delivered'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
