import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dairy_app/core/auth/app_role.dart';
import 'package:dairy_app/features/delivery_panel/screens/active_delivery_tab.dart';
import 'package:dairy_app/features/delivery_panel/screens/delivery_profile_redesigned_tab.dart';
import 'package:dairy_app/features/delivery_panel/screens/requests_tab.dart';
import 'package:dairy_app/features/delivery_panel/services/delivery_location_coordinator.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_location_disclosure_dialog.dart';
import 'package:dairy_app/features/delivery_panel/widgets/gps_status_warning_banner.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_live_location_provider.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/services/battery_optimization_service.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/services/location_service.dart';
import 'package:dairy_app/services/network_connectivity_service.dart';

class _FakeConnectivityNotifier extends StateNotifier<bool>
    implements NetworkConnectivityNotifier {
  _FakeConnectivityNotifier([super.initial = true]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  int setDutyTrueCount = 0;
  int setDutyFalseCount = 0;

  _FakeDeliveryNotifier(super.state);

  @override
  Future<void> setDuty(bool isOnline) async {
    if (isOnline) {
      setDutyTrueCount++;
    } else {
      setDutyFalseCount++;
    }
    state = state.copyWith(
      status: isOnline ? DeliveryStatus.onDuty : DeliveryStatus.offDuty,
    );
  }

  @override
  Future<void> toggleDuty() => setDuty(state.status != DeliveryStatus.onDuty);

  @override
  void startBreak() {
    state = state.copyWith(status: DeliveryStatus.breakTime);
  }

  @override
  void endBreak() {
    state = state.copyWith(status: DeliveryStatus.onDuty);
  }

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
  bool notificationRequestResult = true;
  AndroidLocationPermissionState snapshot;
  LocationPermission geolocatorPerm;
  final List<String> callLog = [];
  int openNotificationSettingsCount = 0;
  int openAppSettingsCount = 0;
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
      backgroundGranted: snapshot.backgroundGranted,
      notificationGranted: snapshot.notificationGranted,
    );
    geolocatorPerm = LocationPermission.whileInUse;
    return LocationResultStatus.success;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    callLog.add('requestNotificationPermission');
    if (notificationRequestResult) {
      snapshot = AndroidLocationPermissionState(
        sdkInt: snapshot.sdkInt,
        fineGranted: snapshot.fineGranted,
        coarseGranted: snapshot.coarseGranted,
        foregroundGranted: snapshot.foregroundGranted,
        backgroundGranted: snapshot.backgroundGranted,
        notificationGranted: true,
      );
    }
    return notificationRequestResult;
  }

  @override
  Future<bool> openNotificationSettings() async {
    openNotificationSettingsCount++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCount++;
    return true;
  }

  void emitError(Object err) => positionController.addError(err);

  Future<void> closeStream() => positionController.close();

  @override
  Future<bool> requestBackgroundLocationPermission() async {
    callLog.add('requestBackgroundLocationPermission');
    snapshot = AndroidLocationPermissionState(
      sdkInt: snapshot.sdkInt,
      fineGranted: snapshot.fineGranted,
      coarseGranted: snapshot.coarseGranted,
      foregroundGranted: snapshot.foregroundGranted,
      backgroundGranted: true,
      notificationGranted: snapshot.notificationGranted,
    );
    geolocatorPerm = LocationPermission.always;
    return true;
  }

  @override
  Future<Position?> getCurrentPositionAlreadyPermitted() async => null;

  @override
  Stream<Position> getPositionStream() => positionController.stream;

  void dispose() {
    positionController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Option A: Google Play Background Location Compliance Tests', () {
    // 1. Customer login/address lookup never requests background location
    test('1. Customer foreground location never invokes background permission',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final List<String> invokedMethods = [];
        const channel =
            MethodChannel('com.sawariyassarkar.app/location_permissions');

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          invokedMethods.add(call.method);
          if (call.method == 'getLocationPermissionState') {
            return {
              'sdkInt': 34,
              'fineGranted': false,
              'coarseGranted': false,
              'foregroundGranted': false,
              'backgroundGranted': false,
              'notificationGranted': true,
            };
          }
          if (call.method == 'requestForegroundLocationOnly') {
            return {
              'sdkInt': 34,
              'fineGranted': true,
              'coarseGranted': true,
              'foregroundGranted': true,
              'backgroundGranted': false,
              'notificationGranted': true,
            };
          }
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final service = LocationService(
          permissionChannel: channel,
          platformOverride: TargetPlatform.android,
        );

        final fgStatus = await service.requestForegroundLocationOnly();
        expect(fgStatus, LocationResultStatus.success);
        expect(
            invokedMethods, isNot(contains('requestBackgroundLocationOnly')));

        final checkRes = await service.checkAndRequestPermissions();
        expect(checkRes, LocationResultStatus.success);
        expect(
            invokedMethods, isNot(contains('requestBackgroundLocationOnly')));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 2 & 11. Cold-start hydration with persisted isOnline=true NEVER prompts permissions or bypasses consent
    test(
        '2 & 11. Cold-start persisted isOnline=true does not request permissions or start tracking',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 34,
            fineGranted: false,
            coarseGranted: false,
            foregroundGranted: false,
            backgroundGranted: false,
            notificationGranted: false,
          ),
          geolocatorPerm: LocationPermission.denied,
        );
        addTearDown(fakeLoc.dispose);

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_01').copyWith(
            status: DeliveryStatus.offDuty,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(agentLiveLocationProvider), isFalse);

        // Simulate Firestore cold-start restoration setting status=onDuty
        await fakeDelivery.setDuty(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Verify tracking did NOT start and NO runtime permission dialogs were triggered
        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(
            fakeLoc.callLog, isNot(contains('requestForegroundLocationOnly')));
        expect(fakeLoc.callLog,
            isNot(contains('requestBackgroundLocationPermission')));
        expect(
          container.read(gpsTrackingStatusProvider),
          equals(GpsTrackingStatus.permissionDenied),
        );

        // Even if foreground was previously granted, persisted isOnline still sets consentRequired!
        fakeLoc.snapshot = const AndroidLocationPermissionState(
          sdkInt: 34,
          fineGranted: true,
          coarseGranted: true,
          foregroundGranted: true,
          backgroundGranted: false,
          notificationGranted: true,
        );
        await fakeDelivery.setDuty(false);
        await fakeDelivery.setDuty(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(
          container.read(gpsTrackingStatusProvider),
          equals(GpsTrackingStatus.consentRequired),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 3, 4 & 5. Online action triggers sequential 4-step flow (Android 11+ never combines FG+BG)
    testWidgets(
        '3, 4 & 5. Explicit Go Online follows Foreground -> Notification -> Disclosure -> Background sequence',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 33, // Android 13 (API 33 >= 30)
            fineGranted: false,
            coarseGranted: false,
            foregroundGranted: false,
            backgroundGranted: false,
            notificationGranted: false,
          ),
        );
        addTearDown(fakeLoc.dispose);

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_seq').copyWith(
            status: DeliveryStatus.offDuty,
          ),
        );

        final fakeUser = _FakeUserNotifier(
          const User(
            id: 'driver_uid_seq',
            name: 'Rider Test',
            phone: '+919876500001',
            role: UserRole.deliveryValue,
            isRoleServerVerified: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            userProvider.overrideWith((ref) => fakeUser),
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: ElevatedButton(
                    key: const Key('test_go_online'),
                    onPressed: () =>
                        DeliveryLocationCoordinator.toggleDutyWithConsent(
                            context, ref),
                    child: const Text('Go Online'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('test_go_online')));
        await tester.pumpAndSettle();

        // Step 1 Rationale shown first; background NOT requested yet
        expect(find.text('Location Needed\nfor Active Deliveries'),
            findsOneWidget);
        expect(fakeLoc.callLog,
            isNot(contains('requestBackgroundLocationPermission')));

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Step 3 Prominent Background Disclosure shown BEFORE background permission
        expect(find.text('Background Location\nfor Delivery Partners'),
            findsOneWidget);
        expect(fakeLoc.callLog,
            isNot(contains('requestBackgroundLocationPermission')));

        await tester.tap(find.byKey(const Key('disclosure_agree_button')));
        await tester.pumpAndSettle();

        // Android 11+ (sdkInt 33) shows "Allow all the time" guide before standalone request
        expect(find.text('Select "Allow all the time"'), findsOneWidget);
        expect(fakeLoc.callLog,
            isNot(contains('requestBackgroundLocationPermission')));

        await tester.tap(find.text('Continue to Settings'));
        await tester.pumpAndSettle();

        // Verify exact separated order & active tracking
        final fgIdx = fakeLoc.callLog.indexOf('requestForegroundLocationOnly');
        final notifIdx =
            fakeLoc.callLog.indexOf('requestNotificationPermission');
        final bgIdx =
            fakeLoc.callLog.indexOf('requestBackgroundLocationPermission');
        expect(fgIdx, greaterThanOrEqualTo(0));
        expect(notifIdx, greaterThan(fgIdx));
        expect(bgIdx, greaterThan(notifIdx));

        expect(
          await DeliveryLocationDisclosureDialog.hasAcknowledgedForAgent(
              'driver_uid_seq'),
          isTrue,
        );
        expect(container.read(deliveryAgentProvider).status,
            DeliveryStatus.onDuty);
        expect(container.read(agentLiveLocationProvider), isTrue);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.active);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 6. Declining disclosure does not start background tracking & falls back safely
    testWidgets(
        '6. Declining disclosure ("Not Now") never requests background permission and sets foregroundOnly fallback',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 34,
            fineGranted: true,
            coarseGranted: true,
            foregroundGranted: true,
            backgroundGranted: false,
            notificationGranted: true,
          ),
          geolocatorPerm: LocationPermission.whileInUse,
        );
        addTearDown(fakeLoc.dispose);

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_decline').copyWith(
            status: DeliveryStatus.offDuty,
          ),
        );

        final fakeUser = _FakeUserNotifier(
          const User(
            id: 'driver_uid_decline',
            name: 'Rider Decline',
            phone: '+919876500002',
            role: UserRole.deliveryValue,
            isRoleServerVerified: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            userProvider.overrideWith((ref) => fakeUser),
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: Column(
                    children: [
                      const GpsStatusWarningBanner(),
                      ElevatedButton(
                        key: const Key('test_go_online_decline'),
                        onPressed: () =>
                            DeliveryLocationCoordinator.toggleDutyWithConsent(
                                context, ref),
                        child: const Text('Go Online'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('test_go_online_decline')));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('disclosure_not_now_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('disclosure_not_now_button')));
        await tester.pumpAndSettle();

        // Background permission MUST NOT be requested after declining!
        expect(fakeLoc.callLog,
            isNot(contains('requestBackgroundLocationPermission')));
        expect(
          await DeliveryLocationDisclosureDialog.hasAcknowledgedForAgent(
              'driver_uid_decline'),
          isFalse,
        );
        expect(
          await DeliveryLocationDisclosureDialog.hasDeclinedForAgent(
              'driver_uid_decline'),
          isTrue,
        );
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.foregroundOnly);
        expect(find.text('Background Tracking Unavailable'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 7 & 8. Revoked permissions, Offline, Break, and Logout stop tracking safely
    test(
        '7 & 8. Revoked permissions, Offline, Break, and StopTracking terminate tracking cleanly',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await DeliveryLocationDisclosureDialog.markAcknowledgedForAgent(
            'driver_uid_life');

        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 34,
            fineGranted: true,
            coarseGranted: true,
            foregroundGranted: true,
            backgroundGranted: true,
            notificationGranted: true,
          ),
          geolocatorPerm: LocationPermission.always,
        );
        addTearDown(fakeLoc.dispose);

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_life').copyWith(
            status: DeliveryStatus.onDuty,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        // Start explicitly
        await container
            .read(agentLiveLocationProvider.notifier)
            .startTracking(explicitUserAction: true);
        expect(container.read(agentLiveLocationProvider), isTrue);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.active);

        // Revoke permission in Settings and refreshStatus()
        fakeLoc.snapshot = const AndroidLocationPermissionState(
          sdkInt: 34,
          fineGranted: false,
          coarseGranted: false,
          foregroundGranted: false,
          backgroundGranted: false,
          notificationGranted: true,
        );
        fakeLoc.geolocatorPerm = LocationPermission.denied;

        await container
            .read(agentLiveLocationProvider.notifier)
            .refreshStatus();
        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.permissionDenied);

        // Re-grant & restart, then test Break -> stops tracking
        fakeLoc.snapshot = const AndroidLocationPermissionState(
          sdkInt: 34,
          fineGranted: true,
          coarseGranted: true,
          foregroundGranted: true,
          backgroundGranted: true,
          notificationGranted: true,
        );
        fakeLoc.geolocatorPerm = LocationPermission.always;
        await container
            .read(agentLiveLocationProvider.notifier)
            .startTracking(explicitUserAction: true);
        expect(container.read(agentLiveLocationProvider), isTrue);

        fakeDelivery.startBreak();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(
            container.read(gpsTrackingStatusProvider), GpsTrackingStatus.idle);

        // Resume & go Offline -> stops tracking
        await fakeDelivery.setDuty(true);
        await container
            .read(agentLiveLocationProvider.notifier)
            .startTracking(explicitUserAction: true);
        expect(container.read(agentLiveLocationProvider), isTrue);

        await fakeDelivery.setDuty(false);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(
            container.read(gpsTrackingStatusProvider), GpsTrackingStatus.idle);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 9 & 10. Completing order clears orderId from delivery_agents doc
    test(
        '9 & 10. Completing orders deletes active orderId from delivery_agents doc',
        () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('delivery_agents').doc('agent_9').set({
        'uid': 'agent_9',
        'location': [22.7255, 75.8800],
        'orderId': 'order_active_1',
        'isOnline': true,
      });

      final trackingService = DeliveryTrackingService(fakeDb);
      await trackingService.clearActiveOrder('agent_9');

      final doc =
          await fakeDb.collection('delivery_agents').doc('agent_9').get();
      expect(doc.data()!.containsKey('orderId'), isFalse);

      await fakeDb
          .collection('delivery_agents')
          .doc('agent_9')
          .update({'orderId': 'order_active_2'});
      await trackingService.updateAgentLocation('agent_9', 22.7300, 75.8850,
          orderId: null);
      final docAfter =
          await fakeDb.collection('delivery_agents').doc('agent_9').get();
      expect(docAfter.data()!.containsKey('orderId'), isFalse);
    });

    // 12. Verify all mobile duty entry points use centralized flow (render + tap smoke check)
    testWidgets(
        '12. Mobile duty entry points trigger disclosure consent instead of bypassing',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 34,
            fineGranted: true,
            coarseGranted: true,
            foregroundGranted: true,
            backgroundGranted: false,
            notificationGranted: true,
          ),
          geolocatorPerm: LocationPermission.whileInUse,
        );
        addTearDown(fakeLoc.dispose);

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_entry_test').copyWith(
            name: 'Entry Tester',
            status: DeliveryStatus.offDuty,
          ),
        );
        final fakeUser = _FakeUserNotifier(
          const User(
            id: 'driver_entry_test',
            name: 'Entry Tester',
            phone: '+919876500009',
            role: UserRole.deliveryValue,
            isRoleServerVerified: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            userProvider.overrideWith((ref) => fakeUser),
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            deliveryRequestsStreamProvider.overrideWithValue(<DeliveryOrder>[]),
            deliveryHistoryStreamProvider
                .overrideWithValue(const AsyncValue.data(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        // Test DeliveryProfileRedesignedTab Online/Offline pill
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: DeliveryProfileRedesignedTab(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('delivery_profile_duty_toggle')));
        await tester.pumpAndSettle();

        expect(find.text('Background Location\nfor Delivery Partners'),
            findsOneWidget);
        await tester.tap(find.byKey(const Key('disclosure_not_now_button')));
        await tester.pumpAndSettle();
        await fakeDelivery.setDuty(false);

        // Clear decline so ActiveDeliveryTab Go Online also triggers disclosure
        await DeliveryLocationDisclosureDialog.clearConsentForAgent(
            'driver_entry_test');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: ActiveDeliveryTab(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go Online'));
        await tester.pumpAndSettle();

        expect(find.text('Background Location\nfor Delivery Partners'),
            findsOneWidget);
        await tester.tap(find.byKey(const Key('disclosure_not_now_button')));
        await tester.pumpAndSettle();
        await fakeDelivery.setDuty(false);

        // Clear decline & test RequestsTab Go Online
        await DeliveryLocationDisclosureDialog.clearConsentForAgent(
            'driver_entry_test');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: RequestsTab(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go Online'));
        await tester.pumpAndSettle();

        expect(find.text('Background Location\nfor Delivery Partners'),
            findsOneWidget);
        await tester.tap(find.byKey(const Key('disclosure_not_now_button')));
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 13. P1 Android 13+ notification denial keeps tracking active, warns UI, and avoids repeat OS prompts
    testWidgets(
        '13. Android 13+ notification denial warns UI without blocking tracking or re-prompting',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await DeliveryLocationDisclosureDialog.markAcknowledgedForAgent(
            'driver_uid_notif_deny');

        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 33,
            fineGranted: true,
            coarseGranted: true,
            foregroundGranted: true,
            backgroundGranted: true,
            notificationGranted: false,
          ),
          geolocatorPerm: LocationPermission.always,
        )..notificationRequestResult = false;
        addTearDown(fakeLoc.dispose);

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_notif_deny').copyWith(
            status: DeliveryStatus.offDuty,
          ),
        );
        final fakeUser = _FakeUserNotifier(
          const User(
            id: 'driver_uid_notif_deny',
            name: 'Rider Notif Deny',
            phone: '+919876500013',
            role: UserRole.deliveryValue,
            isRoleServerVerified: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            userProvider.overrideWith((ref) => fakeUser),
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: Column(
                    children: [
                      const GpsStatusWarningBanner(),
                      ElevatedButton(
                        key: const Key('test_notif_deny_toggle'),
                        onPressed: () =>
                            DeliveryLocationCoordinator.toggleDutyWithConsent(
                                context, ref),
                        child: const Text('Toggle Duty'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap Go Online: notification permission is denied, but location is active.
        await tester.tap(find.byKey(const Key('test_notif_deny_toggle')));
        await tester.pumpAndSettle();

        expect(
          fakeLoc.callLog
              .where((c) => c == 'requestNotificationPermission')
              .length,
          equals(1),
        );
        expect(container.read(agentLiveLocationProvider), isTrue);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.active);
        expect(container.read(notificationPermissionDeniedProvider), isTrue);

        // UI explains restricted notification-drawer visibility + Android settings path
        expect(
            find.text('Tracking Active — Notification Hidden'), findsOneWidget);
        expect(
            find.textContaining('notification-drawer visibility is restricted'),
            findsOneWidget);
        expect(find.textContaining('Apps > Sawariya Dairy > Notifications'),
            findsOneWidget);

        await tester.tap(find.text('Open Settings'));
        await tester.pump();
        expect(fakeLoc.openNotificationSettingsCount, equals(1));

        // Toggle Offline -> Online again: must NOT spam notification permission prompt.
        await tester.tap(find.byKey(const Key('test_notif_deny_toggle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('test_notif_deny_toggle')));
        await tester.pumpAndSettle();

        expect(
          fakeLoc.callLog
              .where((c) => c == 'requestNotificationPermission')
              .length,
          equals(1),
        );
        expect(container.read(notificationPermissionDeniedProvider), isTrue);

        // Simulate user enabling notifications in Android Settings -> app resumes.
        fakeLoc.snapshot = const AndroidLocationPermissionState(
          sdkInt: 33,
          fineGranted: true,
          coarseGranted: true,
          foregroundGranted: true,
          backgroundGranted: true,
          notificationGranted: true,
        );
        await container
            .read(agentLiveLocationProvider.notifier)
            .refreshStatus();
        await tester.pumpAndSettle();

        expect(container.read(notificationPermissionDeniedProvider), isFalse);
        expect(find.text('Tracking Active — Notification Hidden'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 14. P1 Android 13+ notification granted leaves notification warning hidden
    testWidgets(
        '14. Android 13+ notification granted keeps notification denial state and banner clear',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await DeliveryLocationDisclosureDialog.markAcknowledgedForAgent(
            'driver_uid_notif_ok');

        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 33,
            fineGranted: true,
            coarseGranted: true,
            foregroundGranted: true,
            backgroundGranted: true,
            notificationGranted: false,
          ),
          geolocatorPerm: LocationPermission.always,
        )..notificationRequestResult = true;
        addTearDown(fakeLoc.dispose);

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_notif_ok').copyWith(
            status: DeliveryStatus.offDuty,
          ),
        );
        final fakeUser = _FakeUserNotifier(
          const User(
            id: 'driver_uid_notif_ok',
            name: 'Rider Notif OK',
            phone: '+919876500014',
            role: UserRole.deliveryValue,
            isRoleServerVerified: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            userProvider.overrideWith((ref) => fakeUser),
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: Column(
                    children: [
                      const GpsStatusWarningBanner(),
                      ElevatedButton(
                        key: const Key('test_notif_ok_toggle'),
                        onPressed: () =>
                            DeliveryLocationCoordinator.toggleDutyWithConsent(
                                context, ref),
                        child: const Text('Toggle Duty'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('test_notif_ok_toggle')));
        await tester.pumpAndSettle();

        expect(container.read(agentLiveLocationProvider), isTrue);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.active);
        expect(container.read(notificationPermissionDeniedProvider), isFalse);
        expect(find.text('Tracking Active — Notification Hidden'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 15. P2 Stream error revokes cached session authorization so app resume cannot silently restart
    test(
        '15. Stream error resets session authorization so subsequent app resume requires explicit user action',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await DeliveryLocationDisclosureDialog.markAcknowledgedForAgent(
            'driver_uid_err_reset');

        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 33,
            fineGranted: true,
            coarseGranted: true,
            foregroundGranted: true,
            backgroundGranted: true,
            notificationGranted: true,
          ),
          geolocatorPerm: LocationPermission.always,
        );
        addTearDown(fakeLoc.dispose);

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_err_reset').copyWith(
            status: DeliveryStatus.onDuty,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(agentLiveLocationProvider.notifier);
        await notifier.startTracking(explicitUserAction: true);
        expect(container.read(agentLiveLocationProvider), isTrue);

        // Emit stream termination error
        fakeLoc.emitError(const LocationServiceDisabledException());
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.servicesDisabled);

        // Subsequent app resume (refreshStatus) must NOT silently restart tracking
        await notifier.refreshStatus();
        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.consentRequired);

        // Explicit user action can restart cleanly
        await notifier.startTracking(explicitUserAction: true);
        expect(container.read(agentLiveLocationProvider), isTrue);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.active);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 16. P2 Stream completion (onDone / Task Manager stop) and provider disposal revoke authorization
    test(
        '16. Stream completion (onDone) revokes authorization across app resume and disposal cancels cleanly',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await DeliveryLocationDisclosureDialog.markAcknowledgedForAgent(
            'driver_uid_done_reset');

        final fakeLoc = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 33,
            fineGranted: true,
            coarseGranted: true,
            foregroundGranted: true,
            backgroundGranted: true,
            notificationGranted: true,
          ),
          geolocatorPerm: LocationPermission.always,
        );

        final fakeDelivery = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_done_reset').copyWith(
            status: DeliveryStatus.onDuty,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            locationServiceProvider.overrideWithValue(fakeLoc),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );

        final notifier = container.read(agentLiveLocationProvider.notifier);
        await notifier.startTracking(explicitUserAction: true);
        expect(container.read(agentLiveLocationProvider), isTrue);

        // OS terminates stream unexpectedly -> onDone fires
        await fakeLoc.closeStream();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.consentRequired);

        // App resume refresh must NOT silently restart tracking
        await notifier.refreshStatus();
        expect(container.read(agentLiveLocationProvider), isFalse);
        expect(container.read(gpsTrackingStatusProvider),
            GpsTrackingStatus.consentRequired);

        // Separate fresh instance: verify provider disposal cleans up safely
        final fakeLoc2 = _FakeLocationService(
          snapshot: const AndroidLocationPermissionState(
            sdkInt: 33,
            fineGranted: true,
            coarseGranted: true,
            foregroundGranted: true,
            backgroundGranted: true,
            notificationGranted: true,
          ),
          geolocatorPerm: LocationPermission.always,
        );
        addTearDown(fakeLoc2.dispose);
        final fakeDelivery2 = _FakeDeliveryNotifier(
          DeliveryAgent.empty('driver_uid_done_reset').copyWith(
            status: DeliveryStatus.onDuty,
          ),
        );
        final container2 = ProviderContainer(
          overrides: [
            locationServiceProvider.overrideWithValue(fakeLoc2),
            deliveryAgentProvider.overrideWith((ref) => fakeDelivery2),
            deliveryActiveOrdersStreamProvider
                .overrideWith((ref) => Stream.value(<DeliveryOrder>[])),
            batteryOptimizationServiceProvider
                .overrideWithValue(_FakeBatteryService()),
            networkConnectivityProvider
                .overrideWith((ref) => _FakeConnectivityNotifier(true)),
          ],
        );
        final notifier2 = container2.read(agentLiveLocationProvider.notifier);
        await notifier2.startTracking(explicitUserAction: true);
        expect(notifier2.mounted, isTrue);

        container.dispose();
        container2.dispose();
        expect(notifier2.mounted, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
