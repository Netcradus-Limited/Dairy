import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../features/delivery_panel/widgets/delivery_location_disclosure_dialog.dart';
import '../models/delivery_boy_model.dart';
import '../services/delivery_tracking_service.dart';
import '../services/location_service.dart';
import '../services/network_connectivity_service.dart';
import 'battery_optimization_provider.dart';
import 'delivery_provider.dart';

/// Represents the granular health and availability state of device GPS tracking.
enum GpsTrackingStatus {
  /// Actively streaming valid high-accuracy positions with full background capability.
  active,

  /// Actively streaming while app is in foreground only (background location declined or set to "While using").
  foregroundOnly,

  /// Inactive / off-duty / idle.
  idle,

  /// Persisted on-duty state restored on cold start or background consent not yet confirmed.
  /// Never triggers OS permission dialogs silently; awaits explicit user confirmation.
  consentRequired,

  /// Device hardware location services (GPS) are toggled off.
  servicesDisabled,

  /// Location permission was denied by the user.
  permissionDenied,

  /// Location permission was permanently denied ("Never ask again").
  permissionDeniedForever,

  /// General / unrecoverable GPS hardware error.
  error,
}

class GpsTrackingStatusNotifier extends StateNotifier<GpsTrackingStatus> {
  GpsTrackingStatusNotifier([super.initial = GpsTrackingStatus.idle]);

  void setStatus(GpsTrackingStatus status) {
    if (state != status) {
      state = status;
    }
  }
}

/// Provider exposing real-time GPS health/availability status for the Delivery Panel.
final gpsTrackingStatusProvider =
    StateNotifierProvider<GpsTrackingStatusNotifier, GpsTrackingStatus>((ref) {
  return GpsTrackingStatusNotifier();
});

/// Tracks Android 13+ notification permission denial separately from location
/// permission state so UI can warn about restricted drawer visibility without
/// misreporting active foreground-service GPS tracking as failed.
final notificationPermissionDeniedProvider = StateProvider<bool>((ref) => false);

/// Toggles the delivery agent's live GPS tracking. While the agent is explicitly
/// On Duty / Online (with required disclosure consent and permissions), device
/// coordinates are streamed to Firestore so the assigned customer and dispatch
/// admins can monitor active deliveries.
final agentLiveLocationProvider =
    StateNotifierProvider<AgentLiveLocationNotifier, bool>((ref) {
  return AgentLiveLocationNotifier(ref);
});

class AgentLiveLocationNotifier extends StateNotifier<bool> {
  final Ref _ref;
  StreamSubscription<Position>? _subscription;

  // Task 7: Secondary coordinate deduplication guard at the provider level.
  double? _lastWrittenLat;
  double? _lastWrittenLng;

  // Task 9: Buffers unsynced GPS coordinates when Firestore writes fail due
  // to network loss, ensuring the latest position syncs upon reconnection.
  double? _pendingOfflineLat;
  double? _pendingOfflineLng;

  // Compliance guard: Tracks whether the agent explicitly activated tracking
  // in THIS app session (never derived from persisted Firestore `isOnline`).
  bool _explicitSessionTrackingAuthorized = false;
  bool _foregroundOnlyFallback = false;
  int _trackingGeneration = 0;

  AgentLiveLocationNotifier(this._ref) : super(false) {
    // Keep GPS tracking strictly gated by duty state + explicit session consent.
    // Cold-start hydration of `isOnline: true` NEVER triggers permission dialogs.
    _ref.listen<DeliveryAgent>(deliveryAgentProvider, (previous, next) {
      final isOnline = next.status == DeliveryStatus.onDuty;
      if (!isOnline) {
        stopTracking();
      } else {
        unawaited(_evaluateColdStartOrHydratedDuty(next));
      }
    });

    // Task 9: When connectivity returns, safely flush pending offline location
    _ref.listen<bool>(networkConnectivityProvider, (previous, next) {
      if (previous == false && next == true && state) {
        _flushPendingLocation();
      }
    });
  }

  String _resolveAgentUid() {
    final agentId = _ref.read(deliveryAgentProvider).id.trim();
    if (agentId.isNotEmpty) return agentId;
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Evaluates duty state silently (zero OS permission prompts) when `deliveryAgentProvider`
  /// hydrates or updates.
  Future<void> _evaluateColdStartOrHydratedDuty(DeliveryAgent agent) async {
    if (state) return;

    // Do NOT silently start GPS tracking on cold-start hydration without explicit
    // agent action in this session. Instead, verify silent permission state and
    // surface an actionable banner so the rider can confirm/resume safely.
    if (!_explicitSessionTrackingAuthorized) {
      final location = _ref.read(locationServiceProvider);
      final isEnabled = await location.isLocationServiceEnabled();
      if (!mounted) return;
      if (!isEnabled) {
        _ref
            .read(gpsTrackingStatusProvider.notifier)
            .setStatus(GpsTrackingStatus.servicesDisabled);
        return;
      }

      final snapshot = await location.getPermissionSnapshot();
      if (!mounted) return;
      if (!snapshot.foregroundGranted) {
        _ref
            .read(gpsTrackingStatusProvider.notifier)
            .setStatus(GpsTrackingStatus.permissionDenied);
        return;
      }

      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.consentRequired);
      return;
    }

    await startTracking(
      explicitUserAction: true,
      foregroundOnlyFallback: _foregroundOnlyFallback,
    );
  }

  /// Starts streaming GPS coordinates to Firestore ONLY when permissions and
  /// disclosure consent have already been verified by `DeliveryLocationCoordinator`.
  ///
  /// This method NEVER invokes OS runtime permission dialogs directly.
  Future<void> startTracking({
    bool explicitUserAction = false,
    bool foregroundOnlyFallback = false,
  }) async {
    if (explicitUserAction) {
      _explicitSessionTrackingAuthorized = true;
      _foregroundOnlyFallback = foregroundOnlyFallback;
    }

    if (!_explicitSessionTrackingAuthorized) {
      await _evaluateColdStartOrHydratedDuty(_ref.read(deliveryAgentProvider));
      return;
    }

    final location = _ref.read(locationServiceProvider);
    final isEnabled = await location.isLocationServiceEnabled();
    if (!mounted) return;

    if (!isEnabled) {
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.servicesDisabled);
      state = false;
      return;
    }

    final snapshot = await location.getPermissionSnapshot();
    if (!mounted) return;

    if (!snapshot.foregroundGranted) {
      final rawPerm = await location.checkPermission();
      if (!mounted) return;
      _ref.read(gpsTrackingStatusProvider.notifier).setStatus(
            rawPerm == LocationPermission.deniedForever
                ? GpsTrackingStatus.permissionDeniedForever
                : GpsTrackingStatus.permissionDenied,
          );
      state = false;
      return;
    }

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final uid = _resolveAgentUid();
    final hasUidConsent = uid.isEmpty
        ? false
        : await DeliveryLocationDisclosureDialog.hasAcknowledgedForAgent(uid);
    if (!mounted) return;

    if (isAndroid && !snapshot.backgroundGranted) {
      if (!_foregroundOnlyFallback) {
        _ref
            .read(gpsTrackingStatusProvider.notifier)
            .setStatus(GpsTrackingStatus.consentRequired);
        state = false;
        return;
      }
      // Foreground-only fallback explicitly accepted or selected by user.
      _startPositionStream(location, isForegroundOnly: true);
      return;
    }

    if (isAndroid && snapshot.backgroundGranted && !hasUidConsent) {
      // Even if OS already had "Always" granted externally, require explicit
      // in-app disclosure acknowledgment bound to this account UID first.
      if (!_foregroundOnlyFallback) {
        _ref
            .read(gpsTrackingStatusProvider.notifier)
            .setStatus(GpsTrackingStatus.consentRequired);
        state = false;
        return;
      }
      _startPositionStream(location, isForegroundOnly: true);
      return;
    }

    _startPositionStream(location, isForegroundOnly: false);
  }

  void _startPositionStream(
    LocationService location, {
    required bool isForegroundOnly,
  }) {
    if (state && _subscription != null) {
      _ref.read(gpsTrackingStatusProvider.notifier).setStatus(
            isForegroundOnly
                ? GpsTrackingStatus.foregroundOnly
                : GpsTrackingStatus.active,
          );
      return;
    }

    // Check battery optimization status silently when tracking starts
    unawaited(_ref.read(batteryOptimizationProvider.notifier).checkStatus());

    final generation = ++_trackingGeneration;
    state = true;
    _ref.read(gpsTrackingStatusProvider.notifier).setStatus(
          isForegroundOnly
              ? GpsTrackingStatus.foregroundOnly
              : GpsTrackingStatus.active,
        );

    unawaited(_writeCurrentPositionSilently(location, generation));

    _subscription?.cancel();
    _subscription = location.getPositionStream().listen(
          _onPosition,
          onError: _onStreamError,
          onDone: _onStreamDone,
        );
  }

  Future<void> _writeCurrentPositionSilently(
    LocationService location,
    int generation,
  ) async {
    try {
      final pos = await location.getCurrentPositionAlreadyPermitted();
      if (!mounted || !state || generation != _trackingGeneration) return;
      if (pos != null && (pos.latitude != 0.0 || pos.longitude != 0.0)) {
        _write(pos.latitude, pos.longitude);
      }
    } catch (_) {
      // Stream updates will provide subsequent fixes safely.
    }
  }

  /// Stops GPS tracking, clears session authorization, and releases the stream subscription.
  void stopTracking() {
    _trackingGeneration++;
    _subscription?.cancel();
    _subscription = null;
    _explicitSessionTrackingAuthorized = false;
    _foregroundOnlyFallback = false;
    _lastWrittenLat = null;
    _lastWrittenLng = null;
    _pendingOfflineLat = null;
    _pendingOfflineLng = null;
    state = false;
    _ref
        .read(gpsTrackingStatusProvider.notifier)
        .setStatus(GpsTrackingStatus.idle);
  }

  /// Re-evaluates GPS availability and OS permissions silently when returning
  /// from App Settings or background. Handles permission revocation safely.
  Future<void> refreshStatus() async {
    final location = _ref.read(locationServiceProvider);
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final isOnline =
        _ref.read(deliveryAgentProvider).status == DeliveryStatus.onDuty;
    if (!isOnline) {
      if (isAndroid) {
        final snap = await location.getPermissionSnapshot();
        if (!mounted) return;
        if (snap.notificationGranted) {
          _ref.read(notificationPermissionDeniedProvider.notifier).state =
              false;
          unawaited(DeliveryLocationDisclosureDialog
              .clearNotificationDeclinedForAgent(_resolveAgentUid()));
        }
      }
      if (state) stopTracking();
      return;
    }

    final isEnabled = await location.isLocationServiceEnabled();
    if (!mounted) return;
    if (!isEnabled) {
      _trackingGeneration++;
      _subscription?.cancel();
      _subscription = null;
      state = false;
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.servicesDisabled);
      return;
    }

    final snapshot = await location.getPermissionSnapshot();
    if (!mounted) return;

    if (isAndroid) {
      if (snapshot.notificationGranted) {
        _ref.read(notificationPermissionDeniedProvider.notifier).state = false;
        unawaited(DeliveryLocationDisclosureDialog
            .clearNotificationDeclinedForAgent(_resolveAgentUid()));
      } else if (_explicitSessionTrackingAuthorized ||
          _ref.read(notificationPermissionDeniedProvider)) {
        _ref.read(notificationPermissionDeniedProvider.notifier).state = true;
      }
    }

    if (!snapshot.foregroundGranted) {
      _trackingGeneration++;
      _subscription?.cancel();
      _subscription = null;
      _explicitSessionTrackingAuthorized = false;
      _foregroundOnlyFallback = false;
      state = false;
      final rawPerm = await location.checkPermission();
      if (!mounted) return;
      _ref.read(gpsTrackingStatusProvider.notifier).setStatus(
            rawPerm == LocationPermission.deniedForever
                ? GpsTrackingStatus.permissionDeniedForever
                : GpsTrackingStatus.permissionDenied,
          );
      return;
    }

    if (_explicitSessionTrackingAuthorized) {
      if (isAndroid && snapshot.backgroundGranted) {
        _foregroundOnlyFallback = false;
      }
      await startTracking(
        explicitUserAction: true,
        foregroundOnlyFallback: _foregroundOnlyFallback,
      );
    } else {
      await _evaluateColdStartOrHydratedDuty(_ref.read(deliveryAgentProvider));
    }
  }

  void _onPosition(Position position) {
    final currentStatus = _ref.read(gpsTrackingStatusProvider);
    if (currentStatus != GpsTrackingStatus.active &&
        currentStatus != GpsTrackingStatus.foregroundOnly) {
      _ref.read(gpsTrackingStatusProvider.notifier).setStatus(
            _foregroundOnlyFallback
                ? GpsTrackingStatus.foregroundOnly
                : GpsTrackingStatus.active,
          );
    }
    _write(position.latitude, position.longitude);
  }

  void _onStreamError(dynamic err) {
    _trackingGeneration++;
    _subscription?.cancel();
    _subscription = null;
    // Require a fresh explicit user action if the OS or GPS stream errors out.
    _explicitSessionTrackingAuthorized = false;
    _foregroundOnlyFallback = false;
    state = false;
    if (err is LocationServiceDisabledException) {
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.servicesDisabled);
    } else if (err is PermissionDeniedException) {
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.permissionDenied);
    } else {
      debugPrint('AgentLiveLocationNotifier: GPS stream error: $err');
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.error);
    }
  }

  void _onStreamDone() {
    if (!mounted || _subscription == null) return;
    _trackingGeneration++;
    _subscription = null;
    // When the OS (e.g. Android 13+ Task Manager) or platform closes the
    // stream unexpectedly, revoke cached session authorization so resume/refresh
    // never silently restarts tracking without a fresh explicit user action.
    _explicitSessionTrackingAuthorized = false;
    _foregroundOnlyFallback = false;
    state = false;
    final isOnline =
        _ref.read(deliveryAgentProvider).status == DeliveryStatus.onDuty;
    _ref.read(gpsTrackingStatusProvider.notifier).setStatus(
          isOnline ? GpsTrackingStatus.consentRequired : GpsTrackingStatus.idle,
        );
  }

  void _write(double latitude, double longitude) {
    if (_lastWrittenLat == latitude && _lastWrittenLng == longitude) return;
    _lastWrittenLat = latitude;
    _lastWrittenLng = longitude;

    String agentId = _ref.read(deliveryAgentProvider).id;
    if (agentId.isEmpty) {
      try {
        agentId = FirebaseAuth.instance.currentUser?.uid ?? '';
      } catch (_) {}
    }
    if (agentId.isEmpty) return;

    String? activeOrderId;
    try {
      final activeOrders =
          _ref.read(deliveryActiveOrdersStreamProvider).value ?? [];
      activeOrderId = activeOrders.isNotEmpty ? activeOrders.first.id : null;
    } catch (_) {
      activeOrderId = null;
    }

    _ref
        .read(deliveryTrackingServiceProvider)
        .updateAgentLocation(agentId, latitude, longitude,
            orderId: activeOrderId)
        .then((_) {
      _pendingOfflineLat = null;
      _pendingOfflineLng = null;
    }).catchError((_) {
      _pendingOfflineLat = latitude;
      _pendingOfflineLng = longitude;
      _lastWrittenLat = null;
      _lastWrittenLng = null;
    });
  }

  void _flushPendingLocation() {
    if (_pendingOfflineLat != null && _pendingOfflineLng != null) {
      final lat = _pendingOfflineLat!;
      final lng = _pendingOfflineLng!;
      _write(lat, lng);
    }
  }

  @override
  void dispose() {
    _trackingGeneration++;
    _subscription?.cancel();
    _subscription = null;
    _explicitSessionTrackingAuthorized = false;
    _foregroundOnlyFallback = false;
    super.dispose();
  }

  @visibleForTesting
  void handlePositionUpdate(double latitude, double longitude) {
    _write(latitude, longitude);
  }

  @visibleForTesting
  void flushPendingLocationForTesting() {
    _flushPendingLocation();
  }
}
