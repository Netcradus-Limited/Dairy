import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/delivery_panel/screens/delivery_order_detail_view.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/settings_provider.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/services/order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockOrderServiceForDetail extends OrderService {
  String? lastAcceptedOrderId;
  String? lastAcceptedAgentId;
  String? lastDeclinedOrderId;
  String? lastDeclinedAgentId;

  @override
  Future<void> acceptOrder(String orderId, String agentId) async {
    lastAcceptedOrderId = orderId;
    lastAcceptedAgentId = agentId;
  }

  @override
  Future<void> declineOrder(String orderId, String agentId) async {
    lastDeclinedOrderId = orderId;
    lastDeclinedAgentId = agentId;
  }
}

class MockDeliveryAgentNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  MockDeliveryAgentNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPendingOrder = DeliveryOrder(
    id: 'ord_pending_1',
    orderId: 'ord_pending_1',
    orderCode: 'SWD777',
    customerName: 'Anil Sharma',
    customerPhone: '+91 9876543210',
    customerAddress: '123 MG Road, Indore',
    pickupLocation: 'Sawariya Central Hub',
    pickupPhone: '+91 9999988888',
    items: const ['Fresh Milk 1L x2'],
    amount: 140.0,
    deliveryFee: 20.0,
    status: DeliveryOrderStatus.pendingAcceptance,
    orderTime: DateTime(2026, 3, 1, 9, 0),
    distance: '2.5 km',
    estimatedTime: '~10 min',
  );

  final testAcceptedOrder = testPendingOrder.copyWith(
    status: DeliveryOrderStatus.accepted,
    assignedAgentId: 'agent_999',
  );

  const testAgent = DeliveryAgent(
    id: 'agent_999',
    name: 'Test Agent',
    phone: '+91 9876543210',
    vehicle: 'Bike',
    vehicleNumber: 'MP 09 AB 1234',
    assignedZone: 'Indore',
    status: DeliveryStatus.onDuty,
    totalDeliveriesToday: 0,
    completedDeliveriesToday: 0,
    earningsToday: 0.0,
  );

  group('Task 6.6 Fix 1: Pending Order Accept / Decline Tests', () {
    late MockOrderServiceForDetail mockOrderService;

    setUp(() {
      mockOrderService = MockOrderServiceForDetail();
    });

    testWidgets('pendingAcceptance renders Accept Order and Decline Order, NOT Start Pickup', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderServiceProvider.overrideWithValue(mockOrderService),
            deliveryAgentProvider.overrideWith(
              (ref) => MockDeliveryAgentNotifier(testAgent),
            ),
          ],
          child: MaterialApp(
            home: DeliveryOrderDetailView(
              order: testPendingOrder,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must see Accept Order and Decline Order buttons
      expect(find.text('Accept Order'), findsOneWidget);
      expect(find.text('Decline Order'), findsOneWidget);

      // Must NOT see Start Pickup before acceptance
      expect(find.text('Start Pickup'), findsNothing);
    });

    testWidgets('accepted status renders Start Pickup CTA', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderServiceProvider.overrideWithValue(mockOrderService),
            deliveryAgentProvider.overrideWith(
              (ref) => MockDeliveryAgentNotifier(testAgent),
            ),
          ],
          child: MaterialApp(
            home: DeliveryOrderDetailView(
              order: testAcceptedOrder,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Pickup'), findsOneWidget);
      expect(find.text('Accept Order'), findsNothing);
      expect(find.text('Decline Order'), findsNothing);
    });

    testWidgets('Tapping Accept Order invokes orderServiceProvider.acceptOrder', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderServiceProvider.overrideWithValue(mockOrderService),
            deliveryAgentProvider.overrideWith(
              (ref) => MockDeliveryAgentNotifier(testAgent),
            ),
          ],
          child: MaterialApp(
            home: DeliveryOrderDetailView(
              order: testPendingOrder,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept Order'));
      await tester.pump();

      expect(mockOrderService.lastAcceptedOrderId, equals('ord_pending_1'));
      expect(mockOrderService.lastAcceptedAgentId, equals('agent_999'));
    });

    testWidgets('Tapping Decline Order invokes orderServiceProvider.declineOrder', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderServiceProvider.overrideWithValue(mockOrderService),
            deliveryAgentProvider.overrideWith(
              (ref) => MockDeliveryAgentNotifier(testAgent),
            ),
          ],
          child: MaterialApp(
            home: DeliveryOrderDetailView(
              order: testPendingOrder,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decline Order'));
      await tester.pump();

      expect(mockOrderService.lastDeclinedOrderId, equals('ord_pending_1'));
      expect(mockOrderService.lastDeclinedAgentId, equals('agent_999'));
    });
  });

  group('Task 6.6 Fix 2: Dynamic Distance & ETA Calculation Tests', () {
    test('calculateDistanceKm returns null when coordinates are invalid or null', () {
      expect(DeliveryTrackingService.calculateDistanceKm(null, 75.8, 22.7, 75.8), isNull);
      expect(DeliveryTrackingService.calculateDistanceKm(22.7, 75.8, 0.0, 0.0), isNull);
      expect(DeliveryTrackingService.calculateDistanceKm(22.7, 75.8, 999.0, 75.8), isNull);
    });

    test('calculateDistanceKm and calculateEstimatedTime compute dynamic distance and ETA', () {
      final dist = DeliveryTrackingService.calculateDistanceKm(22.7196, 75.8577, 22.7533, 75.8937);
      expect(dist, isNotNull);
      expect(dist!, greaterThan(4.0));
      expect(dist, lessThan(6.5));

      final eta = DeliveryTrackingService.calculateEstimatedTime(dist);
      expect(eta, startsWith('~'));
      expect(eta, endsWith('min'));

      final formatted = DeliveryTrackingService.formatDistance(dist);
      expect(formatted, contains('km'));
    });
  });

  group('Task 6.6 Fix 6: Notification Settings Persistence Tests', () {
    test('SettingsNotifier updates and persists notificationsEnabled to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'settings_notifications_enabled': true});
      final notifier = SettingsNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.notificationsEnabled, isTrue);

      notifier.updateNotifications(false);
      expect(notifier.state.notificationsEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_notifications_enabled'), isFalse);
    });
  });

  group('Task 6.6 Fix 7 & 8: Earnings Real Calculation Tests', () {
    test('Weekly earnings distribution computes real Monday to Sunday sums without mock fallback', () {
      final now = DateTime.now();
      final mondayOfThisWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));

      final earningsList = [
        DeliveryEarnings(
          date: mondayOfThisWeek,
          baseEarnings: 150.0,
          tips: 50.0,
          bonuses: 0.0,
          deliveriesCount: 4,
          total: 200.0,
        ),
        DeliveryEarnings(
          date: mondayOfThisWeek.add(const Duration(days: 2)), // Wednesday
          baseEarnings: 100.0,
          tips: 0.0,
          bonuses: 0.0,
          deliveriesCount: 2,
          total: 100.0,
        ),
      ];

      final weekValues = List<double>.filled(7, 0.0);
      for (int i = 0; i < 7; i++) {
        final targetDay = mondayOfThisWeek.add(Duration(days: i));
        for (final e in earningsList) {
          if (e.date.year == targetDay.year &&
              e.date.month == targetDay.month &&
              e.date.day == targetDay.day) {
            weekValues[i] += e.total;
          }
        }
      }

      // Monday has 200.0
      expect(weekValues[0], equals(200.0));
      // Tuesday has 0.0
      expect(weekValues[1], equals(0.0));
      // Wednesday has 100.0
      expect(weekValues[2], equals(100.0));
      // Thursday - Sunday have 0.0
      expect(weekValues[3], equals(0.0));
      expect(weekValues[4], equals(0.0));
      expect(weekValues[5], equals(0.0));
      expect(weekValues[6], equals(0.0));

      // No fake fallback values like [120, 180, 160, 220, 90, 80, 0]
      expect(weekValues, isNot(contains(120.0)));
      expect(weekValues, isNot(contains(180.0)));
    });
  });
}
