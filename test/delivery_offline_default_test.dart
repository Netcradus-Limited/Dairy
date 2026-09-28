import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/delivery_staff_model.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/features/delivery_panel/delivery_panel_screen.dart';
import 'package:dairy_app/services/network_connectivity_service.dart';

class _TestUserNotifier extends StateNotifier<User> implements UserNotifier {
  _TestUserNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  _StaticDeliveryNotifier(super.state);

  @override
  Future<void> toggleDuty() async {
    final isOnline = state.status != DeliveryStatus.onDuty;
    state = state.copyWith(
      status: isOnline ? DeliveryStatus.onDuty : DeliveryStatus.offDuty,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNetworkNotifier extends StateNotifier<bool>
    implements NetworkConnectivityNotifier {
  _MockNetworkNotifier([bool initial = true]) : super(initial);

  @override
  void setOnline(bool isOnline) => state = isOnline;

  @override
  Future<bool> checkNow() async => state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Delivery Boy Offline Default & Explicit Duty Status Tests', () {
    test('1. New delivery agent model defaults strictly to OFFLINE / offDuty', () {
      final emptyAgent = DeliveryAgent.empty('test_rider_1');
      expect(emptyAgent.status, equals(DeliveryStatus.offDuty));
      expect(emptyAgent.status == DeliveryStatus.onDuty, isFalse);

      final emptyFromMap = DeliveryAgent.fromMap({
        'name': 'Devendra Yadav',
        'phone': '+91 98260 12345',
        'status': 'Active', // Account status is active, but duty status is not online
      }, 'test_rider_1');
      expect(emptyFromMap.status, equals(DeliveryStatus.offDuty));
      expect(emptyFromMap.status == DeliveryStatus.onDuty, isFalse);
    });

    test('2. DeliveryRider model defaults isOnline to false even if status is Active', () {
      const rider = DeliveryRider(
        id: 'RDR-101',
        name: 'Rider One',
        phone: '+91 99999 11111',
        vehicle: 'Motorcycle',
        assignedZone: 'Zone A',
        totalDeliveriesToday: 0,
        pendingDeliveries: 0,
        status: 'Active',
      );
      expect(rider.isOnline, isFalse);
      expect(rider.status, equals('Active'));
    });

    test('3. Login / Firestore hydration without isOnline field defaults to OFFLINE', () {
      final firestoreDoc = {
        'uid': 'auth_uid_123',
        'name': 'Rider Doc',
        'phone': '+91 98765 43210',
        'role': 'delivery',
        'status': 'Active', // Account is active, should NOT force isOnline
        // isOnline and isOnDuty are omitted
      };

      final agent = DeliveryAgent.fromMap(firestoreDoc, 'auth_uid_123');
      expect(agent.status, equals(DeliveryStatus.offDuty));
    });

    test('4. Firestore document with isOnline: false preserves OFFLINE state', () {
      final firestoreDoc = {
        'uid': 'auth_uid_123',
        'name': 'Rider Doc',
        'phone': '+91 98765 43210',
        'status': 'Active',
        'isOnline': false,
        'isOnDuty': false,
      };

      final agent = DeliveryAgent.fromMap(firestoreDoc, 'auth_uid_123');
      expect(agent.status, equals(DeliveryStatus.offDuty));
    });

    test('5. Persisted explicit ONLINE state in Firestore document is properly restored', () {
      final firestoreDoc = {
        'uid': 'auth_uid_123',
        'name': 'Rider Doc',
        'phone': '+91 98765 43210',
        'status': 'Active',
        'isOnline': true,
        'isOnDuty': true,
      };

      final agent = DeliveryAgent.fromMap(firestoreDoc, 'auth_uid_123');
      expect(agent.status, equals(DeliveryStatus.onDuty));
    });

    test('6. DeliveryNotifier initializes to offDuty state by default', () {
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith(
            (ref) => _TestUserNotifier(
              const User(
                id: 'agent_user_1',
                name: 'Agent User',
                phone: '+91 98765 43210',
                role: 'delivery',
                status: 'Active',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final agent = container.read(deliveryAgentProvider);
      expect(agent.status, equals(DeliveryStatus.offDuty));
    });

    test('7. Explicit toggle changes OFFLINE -> ONLINE and ONLINE -> OFFLINE', () async {
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith(
            (ref) => _TestUserNotifier(
              const User(
                id: 'agent_user_1',
                name: 'Agent User',
                phone: '+91 98765 43210',
                role: 'delivery',
                status: 'Active',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deliveryAgentProvider.notifier);
      expect(container.read(deliveryAgentProvider).status, equals(DeliveryStatus.offDuty));

      // Explicit user action to go online
      await notifier.toggleDuty();
      expect(container.read(deliveryAgentProvider).status, equals(DeliveryStatus.onDuty));

      // Explicit user action to go offline
      await notifier.toggleDuty();
      expect(container.read(deliveryAgentProvider).status, equals(DeliveryStatus.offDuty));
    });

    testWidgets('8. Delivery panel startup with offline agent does NOT automatically set online',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const agent = DeliveryAgent(
        id: 'agent_desktop_1',
        name: 'Suresh Kumar',
        phone: '+91 98260 12345',
        vehicle: 'Motorcycle',
        vehicleNumber: 'MP 09 AB 1234',
        assignedZone: 'Indore Central',
        status: DeliveryStatus.offDuty, // Starts OFFLINE
        totalDeliveriesToday: 0,
        completedDeliveriesToday: 0,
        earningsToday: 0.0,
      );

      final container = ProviderContainer(
        overrides: [
          deliveryAgentProvider.overrideWith((ref) => _StaticDeliveryNotifier(agent)),
          networkConnectivityProvider.overrideWith((ref) => _MockNetworkNotifier(true)),
          deliveryActiveOrdersStreamProvider.overrideWith((ref) => Stream.value([])),
          deliveryRequestsStreamProvider.overrideWithValue(const <DeliveryOrder>[]),
          deliveryHistoryStreamProvider.overrideWithValue(const AsyncValue.data(<DeliveryOrder>[])),
          deliveryAgentLocationStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DeliveryPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar badge must show Offline
      expect(find.text('Offline'), findsWidgets);
      expect(find.text('Online'), findsNothing);

      // Verify status remained offDuty throughout panel startup
      expect(container.read(deliveryAgentProvider).status, equals(DeliveryStatus.offDuty));
    });

    testWidgets('9. Re-render / refresh does not change OFFLINE to ONLINE',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const agent = DeliveryAgent(
        id: 'agent_desktop_1',
        name: 'Suresh Kumar',
        phone: '+91 98260 12345',
        vehicle: 'Motorcycle',
        vehicleNumber: 'MP 09 AB 1234',
        assignedZone: 'Indore Central',
        status: DeliveryStatus.offDuty,
        totalDeliveriesToday: 0,
        completedDeliveriesToday: 0,
        earningsToday: 0.0,
      );

      final container = ProviderContainer(
        overrides: [
          deliveryAgentProvider.overrideWith((ref) => _StaticDeliveryNotifier(agent)),
          networkConnectivityProvider.overrideWith((ref) => _MockNetworkNotifier(true)),
          deliveryActiveOrdersStreamProvider.overrideWith((ref) => Stream.value([])),
          deliveryRequestsStreamProvider.overrideWithValue(const <DeliveryOrder>[]),
          deliveryHistoryStreamProvider.overrideWithValue(const AsyncValue.data(<DeliveryOrder>[])),
          deliveryAgentLocationStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DeliveryPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger a rebuild (simulating state notification/refresh)
      tester.binding.scheduleFrame();
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsWidgets);
      expect(find.text('Online'), findsNothing);
      expect(container.read(deliveryAgentProvider).status, equals(DeliveryStatus.offDuty));
    });

    testWidgets('10. Clicking desktop top bar Online/Offline pill explicitly toggles duty status',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const agent = DeliveryAgent(
        id: 'agent_desktop_2',
        name: 'Suresh Kumar',
        phone: '+91 98260 12345',
        vehicle: 'Motorcycle',
        vehicleNumber: 'MP 09 AB 1234',
        assignedZone: 'Indore Central',
        status: DeliveryStatus.offDuty,
        totalDeliveriesToday: 0,
        completedDeliveriesToday: 0,
        earningsToday: 0.0,
      );

      final staticNotifier = _StaticDeliveryNotifier(agent);
      final container = ProviderContainer(
        overrides: [
          deliveryAgentProvider.overrideWith((ref) => staticNotifier),
          networkConnectivityProvider.overrideWith((ref) => _MockNetworkNotifier(true)),
          deliveryActiveOrdersStreamProvider.overrideWith((ref) => Stream.value([])),
          deliveryRequestsStreamProvider.overrideWithValue(const <DeliveryOrder>[]),
          deliveryHistoryStreamProvider.overrideWithValue(const AsyncValue.data(<DeliveryOrder>[])),
          deliveryAgentLocationStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DeliveryPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Offline initially
      expect(find.text('Offline'), findsWidgets);

      // Tap the desktop top bar badge
      await tester.tap(find.text('Offline').first);
      await tester.pumpAndSettle();

      // Now it's explicitly online
      expect(staticNotifier.state.status, equals(DeliveryStatus.onDuty));
      expect(find.text('Online'), findsWidgets);
    });
  });
}
