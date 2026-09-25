import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dairy_app/features/delivery_panel/widgets/battery_optimization_warning_banner.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/battery_optimization_provider.dart';
import 'package:dairy_app/providers/delivery_live_location_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/services/battery_optimization_service.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/services/location_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

// ─── Test Doubles ─────────────────────────────────────────────────────────────

class _MockBatteryOptimizationService extends BatteryOptimizationService {
  bool isIgnoring = true;
  bool openSettingsResult = true;
  int checkCount = 0;
  int openSettingsCount = 0;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    checkCount++;
    return isIgnoring;
  }

  @override
  Future<bool> openBatteryOptimizationSettings() async {
    openSettingsCount++;
    return openSettingsResult;
  }
}

class _ThrowingBatteryOptimizationService extends BatteryOptimizationService {
  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    throw Exception('Simulated platform exception');
  }

  @override
  Future<bool> openBatteryOptimizationSettings() async {
    throw Exception('Simulated settings open error');
  }
}

class _TestUserNotifier extends StateNotifier<User> implements UserNotifier {
  _TestUserNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocationService extends LocationService {
  final _controller = StreamController<Position>.broadcast();
  bool permissionGranted = true;
  bool backgroundGranted = true;

  @override
  Future<bool> requestLocationPermission() async => permissionGranted;

  @override
  Future<bool> requestBackgroundLocationPermission() async => backgroundGranted;

  @override
  Stream<Position> getPositionStream() => _controller.stream;

  @override
  Future<Position?> getCurrentPosition() async => null;

  void close() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BatteryOptimizationService Unit Tests', () {
    const channelName = 'com.example.dairy_app/battery_optimization';
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(channelName),
        (MethodCall call) async {
          methodCalls.add(call);
          if (call.method == 'isIgnoringBatteryOptimizations') {
            return false; // App is NOT ignoring (i.e. is restricted)
          } else if (call.method == 'openBatteryOptimizationSettings') {
            return true;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), null);
    });

    test(
        'isIgnoringBatteryOptimizations and isBatteryOptimizationRestricted via MethodChannel on Android',
        () async {
      final service = BatteryOptimizationService(
          targetPlatformOverride: TargetPlatform.android);
      final isIgnoring = await service.isIgnoringBatteryOptimizations();
      expect(isIgnoring, isFalse); // Mock channel returned false

      final isRestricted = await service.isBatteryOptimizationRestricted();
      expect(isRestricted, isTrue);
      expect(
          methodCalls.any((c) => c.method == 'isIgnoringBatteryOptimizations'),
          isTrue);
    });

    test(
        'isIgnoringBatteryOptimizations safe fallback on non-Android platform (e.g. iOS / Web / Desktop)',
        () async {
      final service = BatteryOptimizationService(
          targetPlatformOverride: TargetPlatform.iOS);
      final isIgnoring = await service.isIgnoringBatteryOptimizations();
      expect(isIgnoring, isTrue);

      final isRestricted = await service.isBatteryOptimizationRestricted();
      expect(isRestricted, isFalse);
    });

    test('openBatteryOptimizationSettings invokes channel on Android',
        () async {
      final service = BatteryOptimizationService(
          targetPlatformOverride: TargetPlatform.android);
      final opened = await service.openBatteryOptimizationSettings();
      expect(opened, isTrue);
      expect(
          methodCalls.any((c) => c.method == 'openBatteryOptimizationSettings'),
          isTrue);
    });

    test(
        'openBatteryOptimizationSettings safe fallback on non-Android platform',
        () async {
      final service = BatteryOptimizationService(
          targetPlatformOverride: TargetPlatform.iOS);
      final opened = await service.openBatteryOptimizationSettings();
      expect(opened, isFalse);
    });
  });

  group('BatteryOptimizationState & Notifier Tests', () {
    test('Initial state is unrestricted and not dismissed', () {
      const state = BatteryOptimizationState();
      expect(state.isRestricted, isFalse);
      expect(state.isDismissed, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.shouldShowWarning, isFalse);
    });

    test('checkStatus updates isRestricted flag correctly', () async {
      final mockService = _MockBatteryOptimizationService()..isIgnoring = false;
      final notifier = BatteryOptimizationNotifier(mockService);

      expect(notifier.state.isRestricted, isFalse);
      await notifier.checkStatus();
      expect(notifier.state.isRestricted, isTrue);
      expect(notifier.state.shouldShowWarning, isTrue);
      expect(mockService.checkCount, equals(1));

      // User fixes setting in system settings -> becomes unrestricted
      mockService.isIgnoring = true;
      await notifier.checkStatus();
      expect(notifier.state.isRestricted, isFalse);
      expect(notifier.state.shouldShowWarning, isFalse);
      expect(mockService.checkCount, equals(2));
    });

    test('dismiss hides warning without altering restriction state', () async {
      final mockService = _MockBatteryOptimizationService()..isIgnoring = false;
      final notifier = BatteryOptimizationNotifier(mockService);

      await notifier.checkStatus();
      expect(notifier.state.shouldShowWarning, isTrue);

      notifier.dismiss();
      expect(notifier.state.isDismissed, isTrue);
      expect(notifier.state.isRestricted, isTrue);
      expect(notifier.state.shouldShowWarning, isFalse);

      notifier.resetDismissal();
      expect(notifier.state.isDismissed, isFalse);
      expect(notifier.state.shouldShowWarning, isTrue);
    });

    test('fixSettings delegates to BatteryOptimizationService', () async {
      final mockService = _MockBatteryOptimizationService();
      final notifier = BatteryOptimizationNotifier(mockService);

      final result = await notifier.fixSettings();
      expect(result, isTrue);
      expect(mockService.openSettingsCount, equals(1));
    });

    test(
        'checkStatus gracefully handles exceptions without throwing or crashing',
        () async {
      final throwingService = _ThrowingBatteryOptimizationService();
      final notifier = BatteryOptimizationNotifier(throwingService);

      expect(notifier.state.isLoading, isFalse);
      // Must not throw
      await expectLater(notifier.checkStatus(), completes);
      expect(notifier.state.isLoading, isFalse);
    });
  });

  group('BatteryOptimizationWarningBanner Widget Tests', () {
    testWidgets('Banner is invisible when shouldShowWarning is false',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          batteryOptimizationProvider.overrideWith(
            (ref) => BatteryOptimizationNotifier(
              _MockBatteryOptimizationService()..isIgnoring = true,
              initial: const BatteryOptimizationState(
                isRestricted: false,
                isDismissed: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: BatteryOptimizationWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.byType(BatteryOptimizationWarningBanner), findsOneWidget);
      expect(find.text('Background Location Warning'), findsNothing);
      expect(find.text('Fix Battery Settings'), findsNothing);
    });

    testWidgets(
        'Banner is visible and actionable when shouldShowWarning is true',
        (tester) async {
      final mockService = _MockBatteryOptimizationService()..isIgnoring = false;
      final container = ProviderContainer(
        overrides: [
          batteryOptimizationProvider.overrideWith(
            (ref) => BatteryOptimizationNotifier(
              mockService,
              initial: const BatteryOptimizationState(
                isRestricted: true,
                isDismissed: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: BatteryOptimizationWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Background Location Warning'), findsOneWidget);
      expect(
        find.textContaining(
            'Battery optimization may limit background location'),
        findsOneWidget,
      );
      expect(find.text('Fix Battery Settings'), findsOneWidget);

      // Tap Fix Battery Settings
      await tester.tap(find.text('Fix Battery Settings'));
      await tester.pump();
      expect(mockService.openSettingsCount, equals(1));

      // Tap Dismiss button
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();

      // Banner should disappear after dismissal
      expect(find.text('Background Location Warning'), findsNothing);
      expect(container.read(batteryOptimizationProvider).isDismissed, isTrue);
    });

    testWidgets('Banner responsive layout adjusts cleanly for narrow viewports',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          batteryOptimizationProvider.overrideWith(
            (ref) => BatteryOptimizationNotifier(
              _MockBatteryOptimizationService()..isIgnoring = false,
              initial: const BatteryOptimizationState(
                isRestricted: true,
                isDismissed: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Narrow screen: width 360 (small Android phone)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: BatteryOptimizationWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Background Location Warning'), findsOneWidget);
      expect(find.text('Fix Battery Settings'), findsOneWidget);
    });
  });

  group('Tracking Session Start Battery Check Integration', () {
    test('startTracking triggers checkStatus on batteryOptimizationProvider',
        () async {
      final mockBatteryService = _MockBatteryOptimizationService()
        ..isIgnoring = false;
      final fakeLocationService = _FakeLocationService();
      addTearDown(fakeLocationService.close);

      final container = ProviderContainer(
        overrides: [
          batteryOptimizationServiceProvider
              .overrideWithValue(mockBatteryService),
          locationServiceProvider.overrideWithValue(fakeLocationService),
          deliveryTrackingServiceProvider.overrideWithValue(
            DeliveryTrackingService(FakeFirebaseFirestore()),
          ),
          userProvider.overrideWith(
            (ref) => _TestUserNotifier(
              const User(
                id: 'agent_123',
                name: 'Test Driver',
                phone: '9876543210',
                role: 'delivery',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final trackingNotifier =
          container.read(agentLiveLocationProvider.notifier);
      expect(mockBatteryService.checkCount, equals(0));

      await trackingNotifier.startTracking();

      // Give async microtask a moment to run checkStatus
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(trackingNotifier.state, isTrue);
      expect(mockBatteryService.checkCount, equals(1));
      expect(container.read(batteryOptimizationProvider).isRestricted, isTrue);

      trackingNotifier.stopTracking();
      expect(trackingNotifier.state, isFalse);
    });
  });
}
