import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_app/models/earning_model.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/services/earnings_service.dart';

class TestUserNotifier extends StateNotifier<User> implements UserNotifier {
  TestUserNotifier(super.state);

  @override
  Future<void> clearSession() async {
    state = const User(id: '', name: '', phone: '', email: '');
  }

  @override
  Future<void> setSession(User user) async {
    state = user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake [EarningsService] to test multi-agent stream switching and isolation
/// without touching live Firebase singletons.
class FakeEarningsService implements EarningsService {
  final Map<String, StreamController<List<EarningModel>>> _controllers = {};
  final List<String> requestedAgentIds = [];

  StreamController<List<EarningModel>> controllerFor(String agentId) {
    return _controllers.putIfAbsent(
        agentId, () => StreamController<List<EarningModel>>.broadcast());
  }

  @override
  Stream<List<EarningModel>> getAgentEarnings(String agentId) {
    requestedAgentIds.add(agentId);
    if (agentId.trim().isEmpty) {
      return Stream.value(const []);
    }
    return controllerFor(agentId).stream;
  }

  @override
  Future<double> getTotalEarnings(
    String agentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (agentId.trim().isEmpty) {
      return 0.0;
    }
    return 100.0;
  }

  @override
  Future<void> logEarning(EarningModel earning) async {}

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }
}

void main() {
  group('Task 4 — Delivery Earnings Auth Binding Tests', () {
    late FakeEarningsService fakeEarningsService;

    setUp(() {
      fakeEarningsService = FakeEarningsService();
    });

    tearDown(() {
      fakeEarningsService.dispose();
    });

    test('1. EarningsService returns empty stream immediately for empty agent ID',
        () async {
      final stream = fakeEarningsService.getAgentEarnings('');
      final result = await stream.first;
      expect(result, isEmpty);

      final total = await fakeEarningsService.getTotalEarnings('   ');
      expect(total, 0.0);
    });

    test('2. Authenticated Agent A receives Agent A earnings only', () async {
      final container = ProviderContainer(
        overrides: [
          earningsServiceProvider.overrideWithValue(fakeEarningsService),
          userProvider.overrideWith((ref) => TestUserNotifier(
                const User(
                  id: 'agent_A',
                  name: 'Ramesh Agent',
                  phone: '+919999900001',
                  email: 'ramesh@sawariya.com',
                  role: 'delivery',
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      // Verify deliveryEarningsProvider reads initially empty state
      final initialEarnings = container.read(deliveryEarningsProvider);
      expect(initialEarnings, isEmpty);

      final now = DateTime.now();
      final agentAEarnings = [
        EarningModel(
          id: 'earn_a1',
          agentId: 'agent_A',
          orderId: 'order_1',
          amountEarned: 50.0,
          tipAmount: 10.0,
          deliveryFee: 30.0,
          timestamp: now,
          status: EarningStatus.paid,
        ),
      ];

      // Emit earnings for Agent A
      fakeEarningsService.controllerFor('agent_A').add(agentAEarnings);
      await pumpEventQueue();

      final updatedEarnings = container.read(deliveryEarningsProvider);
      expect(updatedEarnings.length, 1);
      expect(updatedEarnings.first.total, 60.0);
      expect(updatedEarnings.first.baseEarnings, 50.0);
      expect(updatedEarnings.first.tips, 10.0);
      expect(updatedEarnings.first.deliveriesCount, 1);

      final notifier = container.read(deliveryEarningsProvider.notifier);
      expect(notifier.todayTotal, 60.0);
      expect(notifier.todayDeliveries, 1);
      expect(notifier.weekTotal, 60.0);
      expect(notifier.weekDeliveries, 1);
    });

    test('3. Authenticated Agent B receives Agent B earnings only', () async {
      final container = ProviderContainer(
        overrides: [
          earningsServiceProvider.overrideWithValue(fakeEarningsService),
          userProvider.overrideWith((ref) => TestUserNotifier(
                const User(
                  id: 'agent_B',
                  name: 'Suresh Agent',
                  phone: '+919999900002',
                  email: 'suresh@sawariya.com',
                  role: 'delivery',
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      // Actively listen like a mounted UI widget
      container.listen(deliveryEarningsProvider, (_, __) {});

      final now = DateTime.now();
      final agentBEarnings = [
        EarningModel(
          id: 'earn_b1',
          agentId: 'agent_B',
          orderId: 'order_2',
          amountEarned: 120.0,
          tipAmount: 25.0,
          deliveryFee: 30.0,
          timestamp: now,
          status: EarningStatus.paid,
        ),
      ];

      fakeEarningsService.controllerFor('agent_B').add(agentBEarnings);
      await pumpEventQueue();

      final earnings = container.read(deliveryEarningsProvider);
      expect(earnings.length, 1);
      expect(earnings.first.total, 145.0);
      expect(earnings.first.baseEarnings, 120.0);
      expect(earnings.first.tips, 25.0);
      expect(container.read(deliveryEarningsProvider.notifier).todayTotal, 145.0);
    });

    test('4. Cross-agent isolation: Agent A stream ignores Agent B emissions',
        () async {
      final container = ProviderContainer(
        overrides: [
          earningsServiceProvider.overrideWithValue(fakeEarningsService),
          userProvider.overrideWith((ref) => TestUserNotifier(
                const User(
                  id: 'agent_A',
                  name: 'Ramesh Agent',
                  phone: '+919999900001',
                  email: 'ramesh@sawariya.com',
                  role: 'delivery',
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      container.listen(deliveryEarningsProvider, (_, __) {});

      final now = DateTime.now();
      // Emit data for Agent B
      fakeEarningsService.controllerFor('agent_B').add([
        EarningModel(
          id: 'earn_b_secret',
          agentId: 'agent_B',
          orderId: 'order_secret',
          amountEarned: 5000.0,
          timestamp: now,
        ),
      ]);
      await pumpEventQueue();

      // Agent A's earnings must still be empty!
      final earningsA = container.read(deliveryEarningsProvider);
      expect(earningsA, isEmpty);
    });

    test('5. Unauthenticated / empty agent ID yields safe empty earnings list',
        () async {
      final container = ProviderContainer(
        overrides: [
          earningsServiceProvider.overrideWithValue(fakeEarningsService),
          userProvider.overrideWith((ref) => TestUserNotifier(
                const User(id: '', name: '', phone: '', email: ''),
              )),
        ],
      );
      addTearDown(container.dispose);

      container.listen(deliveryEarningsProvider, (_, __) {});

      final earnings = container.read(deliveryEarningsProvider);
      expect(earnings, isEmpty);

      final notifier = container.read(deliveryEarningsProvider.notifier);
      expect(notifier.todayTotal, 0.0);
      expect(notifier.todayDeliveries, 0);
      expect(notifier.weekTotal, 0.0);
      expect(notifier.weekDeliveries, 0);
    });

    test('6. Logout clears previous agent earnings immediately', () async {
      final userNotifier = TestUserNotifier(
        const User(
          id: 'agent_A',
          name: 'Ramesh Agent',
          phone: '+919999900001',
          email: 'ramesh@sawariya.com',
          role: 'delivery',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          earningsServiceProvider.overrideWithValue(fakeEarningsService),
          userProvider.overrideWith((ref) => userNotifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(deliveryEarningsProvider, (_, __) {});

      final now = DateTime.now();
      fakeEarningsService.controllerFor('agent_A').add([
        EarningModel(
          id: 'earn_a1',
          agentId: 'agent_A',
          orderId: 'order_1',
          amountEarned: 75.0,
          timestamp: now,
        ),
      ]);
      await pumpEventQueue();

      expect(container.read(deliveryEarningsProvider).length, 1);
      expect(container.read(deliveryEarningsProvider.notifier).todayTotal, 75.0);

      // Trigger logout
      await userNotifier.clearSession();
      await pumpEventQueue();

      // Earnings must be completely reset to empty
      final loggedOutEarnings = container.read(deliveryEarningsProvider);
      expect(loggedOutEarnings, isEmpty);
      expect(
          container.read(deliveryEarningsProvider.notifier).todayTotal, 0.0);
    });

    test('7. Agent switch: Agent A logout -> Agent B login rebinds earnings to Agent B',
        () async {
      final userNotifier = TestUserNotifier(
        const User(
          id: 'agent_A',
          name: 'Ramesh Agent',
          phone: '+919999900001',
          email: 'ramesh@sawariya.com',
          role: 'delivery',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          earningsServiceProvider.overrideWithValue(fakeEarningsService),
          userProvider.overrideWith((ref) => userNotifier),
        ],
      );
      addTearDown(container.dispose);

      container.listen(deliveryEarningsProvider, (_, __) {});

      final now = DateTime.now();
      fakeEarningsService.controllerFor('agent_A').add([
        EarningModel(
          id: 'earn_a1',
          agentId: 'agent_A',
          orderId: 'order_1',
          amountEarned: 80.0,
          timestamp: now,
        ),
      ]);
      await pumpEventQueue();
      expect(container.read(deliveryEarningsProvider.notifier).todayTotal, 80.0);

      // Agent A logs out
      await userNotifier.clearSession();
      await pumpEventQueue();
      expect(container.read(deliveryEarningsProvider), isEmpty);

      // Agent B logs in
      await userNotifier.setSession(const User(
        id: 'agent_B',
        name: 'Suresh Agent',
        phone: '+919999900002',
        email: 'suresh@sawariya.com',
        role: 'delivery',
      ));
      await pumpEventQueue();

      fakeEarningsService.controllerFor('agent_B').add([
        EarningModel(
          id: 'earn_b1',
          agentId: 'agent_B',
          orderId: 'order_2',
          amountEarned: 150.0,
          timestamp: now,
        ),
      ]);
      await pumpEventQueue();

      final agentBEarnings = container.read(deliveryEarningsProvider);
      expect(agentBEarnings.length, 1);
      expect(agentBEarnings.first.baseEarnings, 150.0);
      expect(
          container.read(deliveryEarningsProvider.notifier).todayTotal, 150.0);
    });

    test('8. Stream error resets state to empty to prevent cross-agent or stale leakage',
        () async {
      final container = ProviderContainer(
        overrides: [
          earningsServiceProvider.overrideWithValue(fakeEarningsService),
          userProvider.overrideWith((ref) => TestUserNotifier(
                const User(
                  id: 'agent_A',
                  name: 'Ramesh Agent',
                  phone: '+919999900001',
                  email: 'ramesh@sawariya.com',
                  role: 'delivery',
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      container.listen(deliveryEarningsProvider, (_, __) {});

      final now = DateTime.now();
      fakeEarningsService.controllerFor('agent_A').add([
        EarningModel(
          id: 'earn_a1',
          agentId: 'agent_A',
          orderId: 'order_1',
          amountEarned: 60.0,
          timestamp: now,
        ),
      ]);
      await pumpEventQueue();
      expect(container.read(deliveryEarningsProvider).length, 1);

      // Emit permission error (e.g. permission-denied from Firestore security rules)
      fakeEarningsService
          .controllerFor('agent_A')
          .addError(Exception('permission-denied: insufficient permissions'));
      await pumpEventQueue();

      // State must be wiped on error
      expect(container.read(deliveryEarningsProvider), isEmpty);
    });

    test('9. Local addEarnings accurately appends completed delivery and aggregates',
        () async {
      final container = ProviderContainer(
        overrides: [
          earningsServiceProvider.overrideWithValue(fakeEarningsService),
          userProvider.overrideWith((ref) => TestUserNotifier(
                const User(
                  id: 'agent_A',
                  name: 'Ramesh Agent',
                  phone: '+919999900001',
                  email: 'ramesh@sawariya.com',
                  role: 'delivery',
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deliveryEarningsProvider.notifier);
      expect(notifier.todayTotal, 0.0);

      notifier.addEarnings(DeliveryEarnings(
        date: DateTime.now(),
        baseEarnings: 30.0,
        tips: 10.0,
        bonuses: 5.0,
        deliveriesCount: 1,
        total: 45.0,
      ));

      final state = container.read(deliveryEarningsProvider);
      expect(state.length, 1);
      expect(state.first.total, 45.0);
      expect(notifier.todayTotal, 45.0);
      expect(notifier.todayDeliveries, 1);
      expect(notifier.weekTotal, 45.0);
      expect(notifier.weekDeliveries, 1);
    });
  });
}
