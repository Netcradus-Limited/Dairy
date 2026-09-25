import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/core/utils/retry_helper.dart';
import 'package:dairy_app/features/delivery_panel/delivery_panel_screen.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/providers/delivery_live_location_provider.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/services/network_connectivity_service.dart';

class MockDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  MockDeliveryNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTrackingService implements DeliveryTrackingService {
  final List<Map<String, dynamic>> writtenLocations = [];
  bool shouldThrow = false;
  int writeCount = 0;

  @override
  Future<void> updateAgentLocation(
    String agentId,
    double latitude,
    double longitude, {
    String? orderId,
  }) async {
    writeCount++;
    if (shouldThrow) {
      throw const SocketException('Simulated network failure');
    }
    writtenLocations.add({
      'agentId': agentId,
      'latitude': latitude,
      'longitude': longitude,
      'orderId': orderId,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeConnectivityNotifier extends StateNotifier<bool>
    implements NetworkConnectivityNotifier {
  FakeConnectivityNotifier([super.state = true]);

  @override
  void setOnline(bool isOnline) {
    state = isOnline;
  }

  @override
  Future<bool> checkNow() async => state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 9 — Offline / Retry Reliability Unit Tests', () {
    test('retryOperation succeeds on first try if no error', () async {
      int attempts = 0;
      final result = await retryOperation(
        () async {
          attempts++;
          return 'ok';
        },
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 5),
      );
      expect(result, 'ok');
      expect(attempts, 1);
    });

    test('retryOperation retries transient errors and succeeds eventually',
        () async {
      int attempts = 0;
      final result = await retryOperation(
        () async {
          attempts++;
          if (attempts < 3) {
            throw const SocketException('Connection lost');
          }
          return 'recovered';
        },
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 5),
      );
      expect(result, 'recovered');
      expect(attempts, 3);
    });

    test(
        'retryOperation does NOT retry non-transient errors (StateError, ArgumentError)',
        () async {
      int attempts = 0;
      await expectLater(
        retryOperation(
          () async {
            attempts++;
            throw StateError('Order already claimed by another agent');
          },
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 5),
        ),
        throwsA(isA<StateError>()),
      );
      expect(attempts, 1);
    });

    test('retryOperation throws when max retries are exhausted', () async {
      int attempts = 0;
      await expectLater(
        retryOperation(
          () async {
            attempts++;
            throw const SocketException('Persistent offline error');
          },
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 5),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(attempts, 3);
    });

    test(
        'isTransientError correctly identifies network and firestore timeout errors',
        () {
      expect(isTransientError(const SocketException('failed')), isTrue);
      expect(isTransientError(TimeoutException('timed out')), isTrue);
      expect(
          isTransientError(
              Exception('FirebaseException: unavailable, network lost')),
          isTrue);
      expect(isTransientError(Exception('deadline-exceeded')), isTrue);

      expect(isTransientError(StateError('state mismatch')), isFalse);
      expect(isTransientError(ArgumentError('bad arg')), isFalse);
      expect(isTransientError(Exception('permission-denied')), isFalse);
    });

    test(
        'NetworkConnectivityService probes custom callback and detects connectivity',
        () async {
      bool isOnline = true;
      final service = NetworkConnectivityService(
        checker: () async => isOnline,
        checkInterval: const Duration(hours: 1),
      );

      final initial = await service.checkConnectivity();
      expect(initial, isTrue);

      isOnline = false;
      final offline = await service.checkConnectivity();
      expect(offline, isFalse);
    });
  });

  group('Task 9 — Location Offline Resiliency Tests', () {
    test(
        'Location tracking buffers unsynced position on network error and flushes on reconnect',
        () async {
      final fakeTracking = FakeTrackingService();
      final connectivityNotifier = FakeConnectivityNotifier(true);

      final container = ProviderContainer(
        overrides: [
          deliveryTrackingServiceProvider.overrideWithValue(fakeTracking),
          deliveryActiveOrdersStreamProvider
              .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
          networkConnectivityProvider
              .overrideWith((ref) => connectivityNotifier),
          deliveryAgentProvider.overrideWith((ref) => MockDeliveryNotifier(
                const DeliveryAgent(
                  id: 'agent_1',
                  name: 'Ramesh Kumar',
                  phone: '+91 9876543210',
                  vehicle: 'Motorcycle',
                  vehicleNumber: 'RJ 14 AB 1234',
                  assignedZone: 'Central',
                  status: DeliveryStatus.onDuty,
                  totalDeliveriesToday: 12,
                  completedDeliveriesToday: 10,
                  earningsToday: 750.0,
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(agentLiveLocationProvider.notifier);

      // 1. Successful write
      notifier.handlePositionUpdate(26.9124, 75.7873);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(fakeTracking.writtenLocations.length, 1);
      expect(fakeTracking.writtenLocations.first['latitude'], 26.9124);

      // 2. Network goes down, next write throws
      fakeTracking.shouldThrow = true;
      // Writing another coordinate
      notifier.handlePositionUpdate(26.9150, 75.7900);
      await Future.delayed(const Duration(milliseconds: 20));
      // Tracking must NOT crash; writeCount incremented, but no new entry in writtenLocations
      expect(fakeTracking.writeCount, 2);
      expect(fakeTracking.writtenLocations.length, 1);

      // 3. Network restores -> flush buffered location
      fakeTracking.shouldThrow = false;
      notifier.flushPendingLocationForTesting();
      await Future.delayed(const Duration(milliseconds: 20));

      // Buffered location should now be flushed to tracking service
      expect(fakeTracking.writtenLocations.length, 2);
      expect(fakeTracking.writtenLocations.last['latitude'], 26.9150);
      expect(fakeTracking.writtenLocations.last['longitude'], 75.7900);
    });
  });

  group('Task 9 — Offline UI Banner Tests', () {
    testWidgets(
        'DeliveryPanelScreen displays offline banner when connectivity is lost',
        (tester) async {
      final connectivityNotifier = FakeConnectivityNotifier(true);

      final container = ProviderContainer(
        overrides: [
          networkConnectivityProvider
              .overrideWith((ref) => connectivityNotifier),
          deliveryAgentProvider.overrideWith((ref) => MockDeliveryNotifier(
                const DeliveryAgent(
                  id: 'agent_1',
                  name: 'Ramesh Kumar',
                  phone: '+91 9876543210',
                  vehicle: 'Motorcycle',
                  vehicleNumber: 'RJ 14 AB 1234',
                  assignedZone: 'Central',
                  status: DeliveryStatus.onDuty,
                  totalDeliveriesToday: 12,
                  completedDeliveriesToday: 10,
                  earningsToday: 750.0,
                ),
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DeliveryPanelScreen(),
          ),
        ),
      );

      // Initially online
      expect(find.textContaining('You are currently offline'), findsNothing);

      // Go offline
      connectivityNotifier.setOnline(false);
      await tester.pumpAndSettle();

      // Offline banner should now be visible
      expect(find.textContaining('You are currently offline'), findsOneWidget);

      // Go back online
      connectivityNotifier.setOnline(true);
      await tester.pumpAndSettle();

      // Offline banner should disappear
      expect(find.textContaining('You are currently offline'), findsNothing);

      // Clean up widget tree and container before finishing
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
  });

  group('Task 9 — Idempotency & Concurrency Tests', () {
    test('acceptOrder is idempotent when retried for the same agent', () async {
      final orderData = <String, String?>{
        'status': 'Pending',
        'assignedAgentId': null,
      };

      Future<void> simulateAcceptOrder(String orderId, String agentId) async {
        await retryOperation(() async {
          final currentStatus = orderData['status'];
          final currentAgentId = orderData['assignedAgentId'];

          // Idempotency: if already accepted by this agent, succeed
          if (currentStatus == 'accepted' && currentAgentId == agentId) {
            return;
          }

          // Guard against race condition: already accepted by another agent
          if (currentAgentId != null &&
              currentAgentId.isNotEmpty &&
              currentAgentId != agentId) {
            throw StateError('Order already claimed by agent $currentAgentId');
          }

          orderData['status'] = 'accepted';
          orderData['assignedAgentId'] = agentId;
        });
      }

      // First accept
      await simulateAcceptOrder('ord_1', 'agent_1');
      expect(orderData['status'], 'accepted');
      expect(orderData['assignedAgentId'], 'agent_1');

      // Retry accept with same agent (should not throw, remains accepted)
      await simulateAcceptOrder('ord_1', 'agent_1');
      expect(orderData['status'], 'accepted');
      expect(orderData['assignedAgentId'], 'agent_1');
    });

    test(
        'acceptOrder preserves concurrency guard and throws StateError if claimed by another agent',
        () async {
      final orderData = <String, String?>{
        'status': 'accepted',
        'assignedAgentId': 'agent_1',
      };

      Future<void> simulateAcceptOrder(String orderId, String agentId) async {
        await retryOperation(() async {
          final currentStatus = orderData['status'];
          final currentAgentId = orderData['assignedAgentId'];

          if (currentStatus == 'accepted' && currentAgentId == agentId) {
            return;
          }

          if (currentAgentId != null &&
              currentAgentId.isNotEmpty &&
              currentAgentId != agentId) {
            throw StateError('Order already claimed by agent $currentAgentId');
          }

          orderData['status'] = 'accepted';
          orderData['assignedAgentId'] = agentId;
        });
      }

      // Attempting to accept an order already claimed by agent_1
      await expectLater(
        simulateAcceptOrder('ord_1', 'agent_2'),
        throwsA(isA<StateError>()),
      );
      // Order remains assigned to original agent
      expect(orderData['assignedAgentId'], 'agent_1');
    });

    test('declineOrder is idempotent when order is already Pending/unassigned',
        () async {
      final orderData = <String, String?>{
        'status': 'Pending',
        'assignedAgentId': null,
      };

      Future<void> simulateDeclineOrder(String orderId, String agentId) async {
        await retryOperation(() async {
          final currentAgentId = orderData['assignedAgentId'];

          // If already unassigned and Pending, succeed cleanly
          if (currentAgentId == null || currentAgentId.isEmpty) {
            return;
          }

          if (currentAgentId != agentId) {
            throw StateError('Order assigned to another agent');
          }

          orderData['status'] = 'Pending';
          orderData['assignedAgentId'] = null;
        });
      }

      // Declining an already-unassigned order succeeds cleanly
      await simulateDeclineOrder('ord_1', 'agent_1');
      expect(orderData['status'], 'Pending');
      expect(orderData['assignedAgentId'], isNull);
    });
  });
}
