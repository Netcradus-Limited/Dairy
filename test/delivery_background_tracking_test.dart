import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/providers/delivery_live_location_provider.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/services/location_service.dart';

// ─── Fakes / Mocks ───────────────────────────────────────────────────────────

/// Fake [LocationService] whose GPS stream is controlled by the test.
/// Counts subscription creation for duplicate-listener assertions.
class _FakeLocationService extends LocationService {
  final _controller = StreamController<Position>.broadcast();
  bool _permissionGranted = true;
  bool _backgroundGranted = true;
  int subscriptionCount = 0;

  set permissionGranted(bool v) => _permissionGranted = v;
  set backgroundGranted(bool v) => _backgroundGranted = v;

  /// Emits a GPS position into the stream.
  void emit(double lat, double lng) {
    _controller.add(
      Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ),
    );
  }

  @override
  Future<bool> requestLocationPermission() async => _permissionGranted;

  @override
  Future<bool> requestBackgroundLocationPermission() async =>
      _backgroundGranted;

  @override
  Stream<Position> getPositionStream() {
    subscriptionCount++;
    return _controller.stream;
  }

  @override
  Future<Position?> getCurrentPosition() async => null;

  void closeStream() => _controller.close();
}

/// Records every successful [updateAgentLocation] call for assertions.
class _CapturingTrackingService extends DeliveryTrackingService {
  final captures =
      <({String agentId, double lat, double lng, String? orderId})>[];

  _CapturingTrackingService() : super(FakeFirebaseFirestore());

  @override
  Future<void> updateAgentLocation(
    String agentId,
    double latitude,
    double longitude, {
    String? orderId,
  }) async {
    // Honour the same validation gate as the real service.
    if (!DeliveryTrackingService.isValidCoordinates(latitude, longitude)) return;
    captures
        .add((agentId: agentId, lat: latitude, lng: longitude, orderId: orderId));
  }
}

/// Throws on every write — used to verify Firestore failures don't crash
/// the GPS stream.
class _ThrowingTrackingService extends DeliveryTrackingService {
  _ThrowingTrackingService() : super(FakeFirebaseFirestore());

  @override
  Future<void> updateAgentLocation(
    String agentId,
    double latitude,
    double longitude, {
    String? orderId,
  }) async {
    throw Exception('Simulated Firestore write failure');
  }
}

/// Mock [DeliveryNotifier] whose agent status can be changed from the test.
class _MockDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  _MockDeliveryNotifier(super.state);

  void setStatus(DeliveryStatus s) => state = state.copyWith(status: s);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _agentId = 'agent_bg_test_01';
const _lat = 22.7255;
const _lng = 75.8800;

DeliveryAgent _agent({DeliveryStatus status = DeliveryStatus.offDuty}) =>
    DeliveryAgent.empty(_agentId).copyWith(
      name: 'Test Agent',
      status: status,
      isLoaded: true,
    );

/// Builds a [ProviderContainer] with faked location and tracking services.
/// The agent starts OFFLINE by default (tracking must be started manually).
ProviderContainer _makeContainer({
  required _FakeLocationService loc,
  required DeliveryTrackingService tracking,
  _MockDeliveryNotifier? mockDelivery,
}) {
  final delivery = mockDelivery ?? _MockDeliveryNotifier(_agent());
  return ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(loc),
    deliveryTrackingServiceProvider.overrideWithValue(tracking),
    deliveryAgentProvider.overrideWith((_) => delivery),
    deliveryActiveOrdersStreamProvider
        .overrideWith((_) => Stream.value(const [])),
  ]);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('Task 7 — Android Background Location Tracking', () {
    late _FakeLocationService loc;
    late _CapturingTrackingService tracking;

    setUp(() {
      loc = _FakeLocationService();
      tracking = _CapturingTrackingService();
    });

    tearDown(() => loc.closeStream());

    // ── Test 1 ───────────────────────────────────────────────────────────────
    test('1. startTracking() sets state to true', () async {
      final container = _makeContainer(loc: loc, tracking: tracking);
      addTearDown(container.dispose);

      expect(container.read(agentLiveLocationProvider), isFalse,
          reason: 'Tracking must be off before startTracking()');

      await container.read(agentLiveLocationProvider.notifier).startTracking();

      expect(container.read(agentLiveLocationProvider), isTrue,
          reason: 'Tracking must be on after startTracking()');
    });

    // ── Test 2 ───────────────────────────────────────────────────────────────
    test('2. stopTracking() sets state to false', () async {
      final container = _makeContainer(loc: loc, tracking: tracking);
      addTearDown(container.dispose);

      final notifier = container.read(agentLiveLocationProvider.notifier);
      await notifier.startTracking();
      expect(container.read(agentLiveLocationProvider), isTrue);

      notifier.stopTracking();
      expect(container.read(agentLiveLocationProvider), isFalse,
          reason: 'Tracking must be off after stopTracking()');
    });

    // ── Test 3 ───────────────────────────────────────────────────────────────
    test('3. Calling startTracking() twice creates only one stream subscription',
        () async {
      final container = _makeContainer(loc: loc, tracking: tracking);
      addTearDown(container.dispose);

      final notifier = container.read(agentLiveLocationProvider.notifier);
      await notifier.startTracking();
      await notifier.startTracking(); // second call — duplicate guard must fire

      expect(loc.subscriptionCount, 1,
          reason: 'getPositionStream() must be called exactly once; '
              'if (state) return guard must prevent a second subscription');
    });

    // ── Test 4 ───────────────────────────────────────────────────────────────
    test('4. Calling stopTracking() twice does not throw', () async {
      final container = _makeContainer(loc: loc, tracking: tracking);
      addTearDown(container.dispose);

      final notifier = container.read(agentLiveLocationProvider.notifier);
      await notifier.startTracking();
      notifier.stopTracking();

      expect(() => notifier.stopTracking(), returnsNormally,
          reason: 'Second stopTracking() must be a safe no-op');
      expect(container.read(agentLiveLocationProvider), isFalse);
    });

    // ── Test 5 ───────────────────────────────────────────────────────────────
    test('5. GPS positions are written using the authenticated agent ID', () async {
      final container = _makeContainer(loc: loc, tracking: tracking);
      addTearDown(container.dispose);

      await container.read(agentLiveLocationProvider.notifier).startTracking();
      loc.emit(_lat, _lng);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(tracking.captures, isNotEmpty,
          reason: 'At least one Firestore write must occur after a position emit');
      final write = tracking.captures.last;
      expect(write.agentId, equals(_agentId),
          reason: 'Write must target the authenticated agent — never another agent');
      expect(write.lat, closeTo(_lat, 1e-6));
      expect(write.lng, closeTo(_lng, 1e-6));
    });

    // ── Test 6 ───────────────────────────────────────────────────────────────
    test('6. Container disposal (logout / provider teardown) cleans up notifier',
        () async {
      final container = _makeContainer(loc: loc, tracking: tracking);

      final notifier = container.read(agentLiveLocationProvider.notifier);
      await notifier.startTracking();
      expect(container.read(agentLiveLocationProvider), isTrue);

      // Simulate logout / app teardown
      container.dispose();

      expect(notifier.mounted, isFalse,
          reason: 'Notifier must be unmounted after container disposal');
    });

    // ── Test 7 ───────────────────────────────────────────────────────────────
    test('7. Agent going offDuty (delivery completed) stops tracking', () async {
      final mockDelivery = _MockDeliveryNotifier(_agent());
      final container =
          _makeContainer(loc: loc, tracking: tracking, mockDelivery: mockDelivery);
      addTearDown(container.dispose);

      final notifier = container.read(agentLiveLocationProvider.notifier);
      await notifier.startTracking();
      expect(container.read(agentLiveLocationProvider), isTrue);

      // Delivery completed → agent goes offline
      mockDelivery.setStatus(DeliveryStatus.offDuty);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(container.read(agentLiveLocationProvider), isFalse,
          reason: 'Tracking must stop when agent transitions to offDuty');
    });

    // ── Test 8 ───────────────────────────────────────────────────────────────
    test('8. Agent on breakTime (delivery cancelled / failed) stops tracking',
        () async {
      final mockDelivery = _MockDeliveryNotifier(_agent());
      final container =
          _makeContainer(loc: loc, tracking: tracking, mockDelivery: mockDelivery);
      addTearDown(container.dispose);

      final notifier = container.read(agentLiveLocationProvider.notifier);
      await notifier.startTracking();
      expect(container.read(agentLiveLocationProvider), isTrue);

      // Cancelled / failed delivery can put the agent on breakTime
      mockDelivery.setStatus(DeliveryStatus.breakTime);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(container.read(agentLiveLocationProvider), isFalse,
          reason: 'Tracking must stop when agent is not onDuty '
              '(breakTime covers cancelled / failed scenarios)');
    });

    // ── Test 9 ───────────────────────────────────────────────────────────────
    test('9. Invalid GPS coordinates (0,0 / out-of-range) are silently ignored',
        () async {
      final container = _makeContainer(loc: loc, tracking: tracking);
      addTearDown(container.dispose);

      await container.read(agentLiveLocationProvider.notifier).startTracking();

      // Emit zero-placeholder coordinates (invalid sentinel)
      loc.emit(0.0, 0.0);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        tracking.captures.where((c) => c.lat == 0.0 && c.lng == 0.0),
        isEmpty,
        reason: '(0, 0) placeholder must never be written to Firestore; '
            'DeliveryTrackingService.isValidCoordinates must gate the write',
      );
    });

    // ── Test 10 ──────────────────────────────────────────────────────────────
    test('10. A Firestore write failure does not crash GPS stream or tracking state',
        () async {
      final throwingService = _ThrowingTrackingService();
      final container = _makeContainer(loc: loc, tracking: throwingService);
      addTearDown(container.dispose);

      final notifier = container.read(agentLiveLocationProvider.notifier);
      await notifier.startTracking();

      // Emit a valid position — write will throw inside the service.
      // The .catchError in _write() must swallow the failure.
      loc.emit(_lat, _lng);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(agentLiveLocationProvider), isTrue,
          reason: 'state must remain true after a Firestore error — '
              'GPS stream must continue despite write failures');
    });

    // ── Test 11 ──────────────────────────────────────────────────────────────
    test('11. Foreground toggle (stop → start) continues tracking cleanly',
        () async {
      final container = _makeContainer(loc: loc, tracking: tracking);
      addTearDown(container.dispose);

      final notifier = container.read(agentLiveLocationProvider.notifier);

      // Cycle: start → stop → start (pattern used by the delivery map screen)
      await notifier.startTracking();
      expect(container.read(agentLiveLocationProvider), isTrue);
      notifier.stopTracking();
      expect(container.read(agentLiveLocationProvider), isFalse);

      await notifier.startTracking();
      expect(container.read(agentLiveLocationProvider), isTrue);

      // Two startTracking() calls create two subscriptions (one per session)
      expect(loc.subscriptionCount, 2,
          reason: 'A fresh subscription must be opened on the second start');

      // Positions after resume must still be written correctly
      loc.emit(_lat + 0.01, _lng + 0.01);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(tracking.captures, isNotEmpty);
    });

    // ── Test 12 ──────────────────────────────────────────────────────────────
    test(
        '12. Coordinate deduplication: identical consecutive positions are not '
        'written twice to Firestore', () async {
      final container = _makeContainer(loc: loc, tracking: tracking);
      addTearDown(container.dispose);

      await container.read(agentLiveLocationProvider.notifier).startTracking();

      // Emit the same coordinates twice in a row
      loc.emit(_lat, _lng);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      loc.emit(_lat, _lng); // duplicate — should be swallowed by dedup guard
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Only one write for the identical coordinate pair
      final dupeWrites =
          tracking.captures.where((c) => c.lat == _lat && c.lng == _lng);
      expect(dupeWrites.length, equals(1),
          reason: '_lastWrittenLat/_lastWrittenLng deduplication guard '
              'must prevent writing the same coordinates twice');

      // A genuinely new position must still pass through
      loc.emit(_lat + 0.002, _lng + 0.002);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(tracking.captures.length, equals(2),
          reason: 'A new position must be written after a duplicate was skipped');
    });

    // ── Coordinate Validation Contract (used by every test above) ───────────
    test('Coordinate validation contract used by background tracking', () {
      // These are the validation rules exercised by DeliveryTrackingService
      // before every Firestore write, in both foreground and background modes.
      expect(DeliveryTrackingService.isValidCoordinates(22.7255, 75.88), isTrue);
      expect(DeliveryTrackingService.isValidCoordinates(-33.8688, 151.2093), isTrue);
      expect(DeliveryTrackingService.isValidCoordinates(0.0, 0.0), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(null, null), isFalse);
      expect(
          DeliveryTrackingService.isValidCoordinates(double.nan, 75.88), isFalse);
      expect(
          DeliveryTrackingService.isValidCoordinates(double.infinity, 75.88),
          isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(95.0, 75.88), isFalse);
      expect(
          DeliveryTrackingService.isValidCoordinates(22.7255, -185.0), isFalse);
    });
  });
}
