import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:dairy_app/features/delivery_panel/widgets/gps_status_warning_banner.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_live_location_provider.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/services/location_service.dart';

// ─── Test Doubles ─────────────────────────────────────────────────────────────

class _MockLocationService extends LocationService {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  bool backgroundGranted = true;
  final StreamController<Position> positionController =
      StreamController<Position>.broadcast();

  int openLocationSettingsCount = 0;
  int openAppSettingsCount = 0;
  int checkPermissionCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCount++;
    return permission;
  }

  @override
  Future<bool> requestLocationPermission() async {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Future<bool> requestBackgroundLocationPermission() async => backgroundGranted;

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCount++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCount++;
    return true;
  }

  @override
  Stream<Position> getPositionStream() => positionController.stream;

  @override
  Future<Position?> getCurrentPosition() async => null;

  void emitPosition(double lat, double lng) {
    positionController.add(
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

  void emitError(dynamic error) {
    positionController.addError(error);
  }

  void dispose() {
    positionController.close();
  }
}

class _TestUserNotifier extends StateNotifier<User> implements UserNotifier {
  _TestUserNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CapturingTrackingService extends DeliveryTrackingService {
  final writes = <({String agentId, double lat, double lng, String? orderId})>[];

  _CapturingTrackingService() : super(FakeFirebaseFirestore());

  @override
  Future<void> updateAgentLocation(
    String agentId,
    double latitude,
    double longitude, {
    String? orderId,
  }) async {
    if (!DeliveryTrackingService.isValidCoordinates(latitude, longitude)) return;
    writes.add((agentId: agentId, lat: latitude, lng: longitude, orderId: orderId));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLocationService mockLocation;
  late _CapturingTrackingService mockTrackingService;
  late ProviderContainer container;

  setUp(() {
    mockLocation = _MockLocationService();
    mockTrackingService = _CapturingTrackingService();

    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(mockLocation),
        deliveryTrackingServiceProvider.overrideWithValue(mockTrackingService),
        deliveryActiveOrdersStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        userProvider.overrideWith(
          (ref) => _TestUserNotifier(
            const User(
              id: 'agent_test_4',
              name: 'Real Driver',
              phone: '9876543210',
              role: 'delivery',
            ),
          ),
        ),
      ],
    );
  });

  tearDown(() {
    mockLocation.dispose();
    container.dispose();
  });

  group('GPS Permission & Availability State Machine Tests', () {
    test('startTracking fails and sets servicesDisabled when device GPS is off', () async {
      mockLocation.serviceEnabled = false;

      final trackingNotifier = container.read(agentLiveLocationProvider.notifier);
      await trackingNotifier.startTracking();

      expect(trackingNotifier.state, isFalse);
      expect(
        container.read(gpsTrackingStatusProvider),
        equals(GpsTrackingStatus.servicesDisabled),
      );
    });

    test('startTracking fails and sets permissionDeniedForever when permanently denied', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.deniedForever;

      final trackingNotifier = container.read(agentLiveLocationProvider.notifier);
      await trackingNotifier.startTracking();

      expect(trackingNotifier.state, isFalse);
      expect(
        container.read(gpsTrackingStatusProvider),
        equals(GpsTrackingStatus.permissionDeniedForever),
      );
    });

    test('startTracking fails and sets permissionDenied when user denies permission', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.denied;

      final trackingNotifier = container.read(agentLiveLocationProvider.notifier);
      await trackingNotifier.startTracking();

      expect(trackingNotifier.state, isFalse);
      expect(
        container.read(gpsTrackingStatusProvider),
        equals(GpsTrackingStatus.permissionDenied),
      );
    });

    test('startTracking succeeds and sets active when permissions and GPS are granted', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.always;

      final trackingNotifier = container.read(agentLiveLocationProvider.notifier);
      await trackingNotifier.startTracking();

      expect(trackingNotifier.state, isTrue);
      expect(
        container.read(gpsTrackingStatusProvider),
        equals(GpsTrackingStatus.active),
      );

      // Emits location
      mockLocation.emitPosition(22.7196, 75.8577);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(mockTrackingService.writes.length, equals(1));
      expect(mockTrackingService.writes.first.lat, equals(22.7196));
      expect(mockTrackingService.writes.first.lng, equals(75.8577));
    });
  });

  group('Stream Error & Auto-Recovery Tests', () {
    test('GPS service disabled mid-stream sets servicesDisabled status', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.always;

      final trackingNotifier = container.read(agentLiveLocationProvider.notifier);
      await trackingNotifier.startTracking();
      expect(trackingNotifier.state, isTrue);

      // Simulate GPS turned off while driving
      mockLocation.emitError(const LocationServiceDisabledException());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        container.read(gpsTrackingStatusProvider),
        equals(GpsTrackingStatus.servicesDisabled),
      );
    });

    test('refreshStatus recovers tracking when GPS is turned back on while on-duty', () async {
      // 1. Initial state: GPS was disabled
      mockLocation.serviceEnabled = false;

      // Set agent on-duty
      container.read(deliveryAgentProvider.notifier).state =
          container.read(deliveryAgentProvider).copyWith(status: DeliveryStatus.onDuty);

      final trackingNotifier = container.read(agentLiveLocationProvider.notifier);
      await trackingNotifier.startTracking();
      expect(trackingNotifier.state, isFalse);
      expect(
        container.read(gpsTrackingStatusProvider),
        equals(GpsTrackingStatus.servicesDisabled),
      );

      // 2. User turns GPS back on in device settings and returns to app
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.always;

      await trackingNotifier.refreshStatus();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(trackingNotifier.state, isTrue);
      expect(
        container.read(gpsTrackingStatusProvider),
        equals(GpsTrackingStatus.active),
      );
    });

    test('stopTracking cleans up subscription, buffers, and sets status to idle', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.always;

      final trackingNotifier = container.read(agentLiveLocationProvider.notifier);
      await trackingNotifier.startTracking();
      expect(trackingNotifier.state, isTrue);

      trackingNotifier.stopTracking();
      expect(trackingNotifier.state, isFalse);
      expect(
        container.read(gpsTrackingStatusProvider),
        equals(GpsTrackingStatus.idle),
      );
    });
  });

  group('GpsStatusWarningBanner Widget Tests', () {
    testWidgets('Banner is invisible when agent is offline or GPS is active/idle', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GpsStatusWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.byType(GpsStatusWarningBanner), findsOneWidget);
      expect(find.text('GPS is Turned Off'), findsNothing);
      expect(find.text('Location Permission Required'), findsNothing);
    });

    testWidgets('Banner renders GPS is Turned Off and calls openLocationSettings on action', (tester) async {
      // Set agent on duty
      container.read(deliveryAgentProvider.notifier).state =
          container.read(deliveryAgentProvider).copyWith(status: DeliveryStatus.onDuty);
      container.read(gpsTrackingStatusProvider.notifier).setStatus(GpsTrackingStatus.servicesDisabled);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GpsStatusWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.text('GPS is Turned Off'), findsOneWidget);
      expect(
        find.textContaining('Device location services are disabled'),
        findsOneWidget,
      );
      expect(find.text('Turn on GPS'), findsOneWidget);

      await tester.tap(find.text('Turn on GPS'));
      await tester.pump();

      expect(mockLocation.openLocationSettingsCount, equals(1));
    });

    testWidgets('Banner renders Location Permission Disabled and calls openAppSettings', (tester) async {
      container.read(deliveryAgentProvider.notifier).state =
          container.read(deliveryAgentProvider).copyWith(status: DeliveryStatus.onDuty);
      container.read(gpsTrackingStatusProvider.notifier).setStatus(GpsTrackingStatus.permissionDeniedForever);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GpsStatusWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Location Permission Disabled'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();

      expect(mockLocation.openAppSettingsCount, equals(1));
    });

    testWidgets('Dismiss button hides banner for current error state', (tester) async {
      container.read(deliveryAgentProvider.notifier).state =
          container.read(deliveryAgentProvider).copyWith(status: DeliveryStatus.onDuty);
      container.read(gpsTrackingStatusProvider.notifier).setStatus(GpsTrackingStatus.servicesDisabled);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GpsStatusWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.text('GPS is Turned Off'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.text('GPS is Turned Off'), findsNothing);
    });
  });
}
