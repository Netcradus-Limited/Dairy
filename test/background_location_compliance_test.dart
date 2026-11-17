// Google Play "Prominent Disclosure and Consent" compliance guard.
//
// Sawariya Dairy does NOT declare or request ACCESS_BACKGROUND_LOCATION.
// Delivery-partner live tracking runs inside geolocator's
// GeolocatorLocationService, a foreground service declared with
// android:foregroundServiceType="location", which is always started while the
// app is visible after an explicit in-app action. On Android 10+ such a service
// keeps receiving GPS while the app is minimised or the screen is locked using
// foreground permission alone.
//
// These tests exist to stop the permission (or any code that requests it) from
// being reintroduced and triggering another policy violation.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/core/auth/app_role.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_live_location_provider.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/services/battery_optimization_service.dart';
import 'package:dairy_app/services/location_service.dart';
import 'package:dairy_app/services/network_connectivity_service.dart';

// --- Fakes ------------------------------------------------------------------

class _FakeConnectivityNotifier extends StateNotifier<bool>
    implements NetworkConnectivityNotifier {
  _FakeConnectivityNotifier([super.initial = true]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  _FakeDeliveryNotifier(super.state);

  @override
  Future<void> setDuty(bool isOnline) async {
    state = state.copyWith(
      status: isOnline ? DeliveryStatus.onDuty : DeliveryStatus.offDuty,
    );
  }

  @override
  Future<void> toggleDuty() => setDuty(state.status != DeliveryStatus.onDuty);

  @override
  void startBreak() => state = state.copyWith(status: DeliveryStatus.breakTime);

  @override
  void endBreak() => state = state.copyWith(status: DeliveryStatus.onDuty);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserNotifier extends StateNotifier<User> implements UserNotifier {
  _FakeUserNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBatteryService extends BatteryOptimizationService {
  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;
}

class _FakeLocationService extends LocationService {
  bool serviceEnabled = true;
  AndroidLocationPermissionState snapshot;
  LocationPermission geolocatorPerm;
  final List<String> callLog = <String>[];
  final StreamController<Position> positionController =
      StreamController<Position>.broadcast();

  _FakeLocationService({
    required this.snapshot,
    this.geolocatorPerm = LocationPermission.denied,
  }) : super(platformOverride: TargetPlatform.android);

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    callLog.add('checkPermission');
    return geolocatorPerm;
  }

  @override
  Future<AndroidLocationPermissionState> getPermissionSnapshot() async {
    callLog.add('getPermissionSnapshot');
    return snapshot;
  }

  @override
  Future<LocationResultStatus> requestForegroundLocationOnly() async {
    callLog.add('requestForegroundLocationOnly');
    snapshot = AndroidLocationPermissionState(
      sdkInt: snapshot.sdkInt,
      fineGranted: true,
      coarseGranted: true,
      foregroundGranted: true,
      notificationGranted: snapshot.notificationGranted,
    );
    geolocatorPerm = LocationPermission.whileInUse;
    return LocationResultStatus.success;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    callLog.add('requestNotificationPermission');
    return true;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;

  @override
  Future<Position?> getCurrentPositionAlreadyPermitted() async => null;

  @override
  Stream<Position> getPositionStream() {
    callLog.add('getPositionStream');
    return positionController.stream;
  }

  void dispose() => positionController.close();
}

// --- Helpers ----------------------------------------------------------------

String _read(String relativePath) => File(relativePath).readAsStringSync();

/// Every Dart source file under lib/.
List<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Returns every non-comment line under lib/ containing any of [needles]
/// (case-insensitive), formatted as "path: line".
List<String> _scanLib(List<String> needles) {
  final hits = <String>[];
  for (final file in _libDartFiles()) {
    for (final line in const LineSplitter().convert(file.readAsStringSync())) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//')) continue;
      final lower = trimmed.toLowerCase();
      for (final needle in needles) {
        if (lower.contains(needle)) {
          hits.add('${file.path}: $trimmed');
          break;
        }
      }
    }
  }
  return hits;
}

ProviderContainer _container(
  _FakeLocationService loc,
  _FakeDeliveryNotifier delivery,
) {
  return ProviderContainer(
    overrides: [
      locationServiceProvider.overrideWithValue(loc),
      deliveryAgentProvider.overrideWith((ref) => delivery),
      userProvider.overrideWith(
        (ref) => _FakeUserNotifier(
          const User(
            id: 'driver_uid_01',
            name: 'Rider Test',
            phone: '+919876500001',
            role: UserRole.deliveryValue,
            isRoleServerVerified: true,
          ),
        ),
      ),
      batteryOptimizationServiceProvider
          .overrideWithValue(_FakeBatteryService()),
      networkConnectivityProvider
          .overrideWith((ref) => _FakeConnectivityNotifier(true)),
    ],
  );
}

const _foregroundGranted = AndroidLocationPermissionState(
  sdkInt: 34,
  fineGranted: true,
  coarseGranted: true,
  foregroundGranted: true,
  notificationGranted: true,
);

const _nothingGranted = AndroidLocationPermissionState(
  sdkInt: 34,
  fineGranted: false,
  coarseGranted: false,
  foregroundGranted: false,
  notificationGranted: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // --------------------------------------------------------------------------
  group('Android manifest declares no background location', () {
    const manifestPath = 'android/app/src/main/AndroidManifest.xml';

    test('ACCESS_BACKGROUND_LOCATION is never declared as an active permission',
        () {
      final manifest = _read(manifestPath);

      // The only permitted mention is the tools:node="remove" guard.
      final activeDeclaration = RegExp(
        r'<uses-permission\s+android:name="android\.permission\.ACCESS_BACKGROUND_LOCATION"\s*/>',
      );
      expect(
        activeDeclaration.hasMatch(manifest),
        isFalse,
        reason: 'ACCESS_BACKGROUND_LOCATION must not be declared. It caused a '
            'Google Play "Missing Prominent Disclosure" violation.',
      );
    });

    test('a tools:node="remove" guard blocks dependency reintroduction', () {
      final manifest = _read(manifestPath);
      expect(manifest, contains('xmlns:tools='));
      expect(
        manifest.replaceAll(RegExp(r'\s+'), ' '),
        contains(
          '<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" tools:node="remove" />',
        ),
        reason: 'The removal guard keeps any merged library manifest from '
            'reintroducing the permission into the final APK.',
      );
    });

    test('foreground location and foreground-service permissions are retained',
        () {
      final manifest = _read(manifestPath);
      for (final permission in const [
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_LOCATION',
      ]) {
        expect(
          manifest,
          contains('<uses-permission android:name="$permission" />'),
          reason: '$permission is required for delivery tracking.',
        );
      }
    });

    test('no background-location or background-task plugin is depended on', () {
      final pubspec = _read('pubspec.yaml');
      for (final banned in const [
        'background_locator',
        'flutter_background_geolocation',
        'workmanager',
        'flutter_background_service',
      ]) {
        expect(
          pubspec,
          isNot(contains(banned)),
          reason: '$banned would reintroduce background location collection.',
        );
      }
    });
  });

  // --------------------------------------------------------------------------
  group('No source path can request background location', () {
    // Comparing against LocationPermission.always is fine: that is reading the
    // status geolocator reports, not requesting the permission. Only calls that
    // would actually ask the OS for background location are banned here.
    test('no Dart source requests ACCESS_BACKGROUND_LOCATION', () {
      final offenders = <String>[];
      for (final file in _libDartFiles()) {
        final src = file.readAsStringSync();
        // Ignore explanatory comment lines; flag real code.
        for (final line in src.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('//')) continue;
          if (trimmed.contains('requestBackgroundLocationPermission') ||
              trimmed.contains('requestBackgroundLocationOnly') ||
              trimmed.contains('ACCESS_BACKGROUND_LOCATION')) {
            offenders.add('${file.path}: $trimmed');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Background location must never be requested:\n'
            '${offenders.join('\n')}',
      );
    });

    test('LocationService exposes no background permission API', () {
      final src = _read('lib/services/location_service.dart');
      expect(
        src,
        isNot(contains('Future<bool> requestBackgroundLocationPermission')),
      );
      expect(
        src,
        contains('foregroundNotificationConfig'),
        reason: 'The location foreground service is what replaces background '
            'location; it must stay configured.',
      );
    });

    test('MainActivity never requests the background permission', () {
      final src = _read(
          'android/app/src/main/kotlin/com/sawariyassarkar/app/MainActivity.kt');
      expect(src, isNot(contains('requestBackgroundLocationOnly')));
      expect(
        src,
        isNot(
            contains('arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION)')),
      );
    });
  });

  // --------------------------------------------------------------------------
  group('Foreground service notification and disclosure accuracy', () {
    test('tracking notification is configured as ongoing', () {
      final src = _read('lib/services/location_service.dart');
      expect(
        src,
        contains('setOngoing: true'),
        reason: 'The foreground-service notification must be marked ongoing '
            'so it is not swiped away while location is still being shared.',
      );
    });

    test('no user-facing text claims an undismissable notification', () {
      final offenders = _scanLib(const [
        'non-dismissible',
        'permanent notification',
        'cannot dismiss',
      ]);
      expect(
        offenders,
        isEmpty,
        reason: 'Android 13+ lets users dismiss foreground-service '
            'notifications, so the app must not claim otherwise.',
      );
    });

    test('no user-facing text claims location only while the app is open', () {
      final offenders = _scanLib(const [
        'only while the app is open',
        'only while you are using the app',
      ]);
      expect(
        offenders,
        isEmpty,
        reason: 'Tracking continues while minimised, so claiming otherwise '
            'understates collection.',
      );
    });
  });

  // --------------------------------------------------------------------------
  group('Tracking behaviour with foreground permission only', () {
    test('tracking starts and stays active with "while in use" permission',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final loc = _FakeLocationService(
          snapshot: _foregroundGranted,
          geolocatorPerm: LocationPermission.whileInUse,
        );
        addTearDown(loc.dispose);
        final delivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_01')
              .copyWith(status: DeliveryStatus.offDuty),
        );
        final container = _container(loc, delivery);
        addTearDown(container.dispose);

        await container
            .read(agentLiveLocationProvider.notifier)
            .startTracking(explicitUserAction: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(agentLiveLocationProvider), isTrue,
            reason: 'Foreground permission alone must be enough to track.');
        expect(container.read(gpsTrackingStatusProvider),
            equals(GpsTrackingStatus.active));
        expect(loc.callLog, contains('getPositionStream'));
        expect(
            loc.callLog, isNot(contains('requestBackgroundLocationPermission')));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('denied location permission degrades cleanly without crashing',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final loc = _FakeLocationService(
          snapshot: _nothingGranted,
          geolocatorPerm: LocationPermission.denied,
        );
        addTearDown(loc.dispose);
        final delivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_01')
              .copyWith(status: DeliveryStatus.offDuty),
        );
        final container = _container(loc, delivery);
        addTearDown(container.dispose);

        await container
            .read(agentLiveLocationProvider.notifier)
            .startTracking(explicitUserAction: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(container.read(gpsTrackingStatusProvider),
            equals(GpsTrackingStatus.permissionDenied));
        expect(loc.callLog, isNot(contains('getPositionStream')));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('GPS turned off surfaces servicesDisabled rather than tracking',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final loc = _FakeLocationService(
          snapshot: _foregroundGranted,
          geolocatorPerm: LocationPermission.whileInUse,
        )..serviceEnabled = false;
        addTearDown(loc.dispose);
        final delivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_01')
              .copyWith(status: DeliveryStatus.offDuty),
        );
        final container = _container(loc, delivery);
        addTearDown(container.dispose);

        await container
            .read(agentLiveLocationProvider.notifier)
            .startTracking(explicitUserAction: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(container.read(gpsTrackingStatusProvider),
            equals(GpsTrackingStatus.servicesDisabled));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('cold-start hydration never silently starts location collection',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final loc = _FakeLocationService(
          snapshot: _foregroundGranted,
          geolocatorPerm: LocationPermission.whileInUse,
        );
        addTearDown(loc.dispose);
        final delivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_01')
              .copyWith(status: DeliveryStatus.offDuty),
        );
        final container = _container(loc, delivery);
        addTearDown(container.dispose);

        // Instantiate the tracking notifier so it observes the duty change.
        expect(container.read(agentLiveLocationProvider), isFalse);

        // Firestore restores a persisted "on duty" state with no user action.
        await delivery.setDuty(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(agentLiveLocationProvider), isFalse,
            reason: 'Location must never be collected without an explicit '
                'in-app action in this session.');
        expect(loc.callLog, isNot(contains('getPositionStream')));
        expect(loc.callLog, isNot(contains('requestForegroundLocationOnly')));
        expect(container.read(gpsTrackingStatusProvider),
            equals(GpsTrackingStatus.consentRequired));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('stopTracking ends the stream and the foreground service', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final loc = _FakeLocationService(
          snapshot: _foregroundGranted,
          geolocatorPerm: LocationPermission.whileInUse,
        );
        addTearDown(loc.dispose);
        final delivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_01')
              .copyWith(status: DeliveryStatus.offDuty),
        );
        final container = _container(loc, delivery);
        addTearDown(container.dispose);

        final notifier = container.read(agentLiveLocationProvider.notifier);
        await notifier.startTracking(explicitUserAction: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(container.read(agentLiveLocationProvider), isTrue);

        notifier.stopTracking();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(container.read(agentLiveLocationProvider), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
