import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/delivery_boy_model.dart';
import '../services/delivery_tracking_service.dart';
import '../services/location_service.dart';
import '../services/network_connectivity_service.dart';
import 'battery_optimization_provider.dart';
import 'delivery_provider.dart';

/// Represents the granular health and availability state of device GPS tracking.
enum GpsTrackingStatus {
  /// Actively streaming valid high-accuracy positions.
  active,

  /// Inactive / off-duty / idle.
  idle,

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
  GpsTrackingStatusNotifier(
      [GpsTrackingStatus initial = GpsTrackingStatus.idle])
      : super(initial);

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

/// Toggles the delivery agent's live GPS tracking. While the agent is online,
/// high-accuracy device coordinates are streamed to Firestore (as a
/// `[latitude, longitude]` array) so the customer tracking map and the delivery
/// map reflect the agent's position in real time.
final agentLiveLocationProvider =
    StateNotifierProvider<AgentLiveLocationNotifier, bool>((ref) {
  return AgentLiveLocationNotifier(ref);
});

class AgentLiveLocationNotifier extends StateNotifier<bool> {
  final Ref _ref;
  StreamSubscription<Position>? _subscription;

  // Task 7: Secondary coordinate deduplication guard at the provider level.
  // The primary filter is AndroidSettings.distanceFilter (20 m); this prevents
  // duplicate Firestore writes when _writeCurrentPosition() and the stream
  // start emit the same coordinates on tracking start.
  double? _lastWrittenLat;
  double? _lastWrittenLng;

  // Task 9: Buffers unsynced GPS coordinates when Firestore writes fail due
  // to network loss, ensuring the latest position syncs upon reconnection.
  double? _pendingOfflineLat;
  double? _pendingOfflineLng;

  AgentLiveLocationNotifier(this._ref) : super(false) {
    // Keep GPS tracking in sync with the agent's duty (online/offline) state:
    // tracking starts automatically when they go online and stops when offline.
    _ref.listen<DeliveryAgent>(deliveryAgentProvider, (previous, next) {
      final isOnline = next.status == DeliveryStatus.onDuty;
      if (isOnline && !state) {
        startTracking();
      } else if (!isOnline && state) {
        stopTracking();
      }
    });

    // Task 9: When connectivity returns, safely flush pending offline location
    _ref.listen<bool>(networkConnectivityProvider, (previous, next) {
      if (previous == false && next == true && state) {
        _flushPendingLocation();
      }
    });
  }

  /// Starts streaming real GPS coordinates to Firestore.
  ///
  /// Checks permissions and GPS service status first:
  /// - If GPS is turned off, sets status to [GpsTrackingStatus.servicesDisabled]
  /// - If permission is permanently denied, sets status to [GpsTrackingStatus.permissionDeniedForever]
  /// - If permission is denied, sets status to [GpsTrackingStatus.permissionDenied]
  /// - On Android 10+, requests [ACCESS_BACKGROUND_LOCATION] for true background tracking
  Future<void> startTracking() async {
    if (state) return; // Duplicate-start guard

    final location = _ref.read(locationServiceProvider);
    final permStatus = await location.checkAndRequestPermissions();

    if (permStatus == LocationResultStatus.servicesDisabled) {
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.servicesDisabled);
      state = false;
      return;
    }

    if (permStatus == LocationResultStatus.permissionDeniedForever) {
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.permissionDeniedForever);
      state = false;
      return;
    }

    if (permStatus == LocationResultStatus.permissionDenied) {
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.permissionDenied);
      state = false;
      return;
    }

    if (permStatus != LocationResultStatus.success) {
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.error);
      state = false;
      return;
    }

    // Task 3: Check battery optimization status when tracking starts
    unawaited(_ref.read(batteryOptimizationProvider.notifier).checkStatus());

    state = true;
    _ref
        .read(gpsTrackingStatusProvider.notifier)
        .setStatus(GpsTrackingStatus.active);
    _writeCurrentPosition();

    _subscription = location.getPositionStream().listen(
          _onPosition,
          onError: _onStreamError,
        );
  }

  /// Stops GPS tracking and releases the stream subscription.
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _lastWrittenLat = null;
    _lastWrittenLng = null;
    _pendingOfflineLat = null;
    _pendingOfflineLng = null;
    state = false;
    _ref
        .read(gpsTrackingStatusProvider.notifier)
        .setStatus(GpsTrackingStatus.idle);
  }

  /// Convenience toggle used by the map / panel "share live location" buttons.
  void toggle() {
    if (state) {
      stopTracking();
    } else {
      startTracking();
    }
  }

  /// Re-evaluates GPS availability and auto-recovers tracking when returning
  /// from device settings or background.
  Future<void> refreshStatus() async {
    final isOnline =
        _ref.read(deliveryAgentProvider).status == DeliveryStatus.onDuty;
    if (!isOnline) {
      if (state) stopTracking();
      return;
    }

    final location = _ref.read(locationServiceProvider);
    final isEnabled = await location.isLocationServiceEnabled();
    if (!isEnabled) {
      if (state) {
        _subscription?.cancel();
        _subscription = null;
        state = false;
      }
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.servicesDisabled);
      return;
    }

    // If on-duty and currently inactive or in error state, attempt start
    if (!state) {
      await startTracking();
    }
  }

  void _onPosition(Position position) {
    if (_ref.read(gpsTrackingStatusProvider) != GpsTrackingStatus.active) {
      _ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.active);
    }
    _write(position.latitude, position.longitude);
  }

  void _onStreamError(dynamic err) {
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

  Future<void> _writeCurrentPosition() async {
    final position =
        await _ref.read(locationServiceProvider).getCurrentPosition();
    if (position != null) _write(position.latitude, position.longitude);
  }

  void _write(double latitude, double longitude) {
    // Task 7: Secondary coordinate deduplication guard.
    // Prevents a redundant Firestore write when _writeCurrentPosition() and
    // the stream first emission report identical coordinates on tracking start.
    if (_lastWrittenLat == latitude && _lastWrittenLng == longitude) return;
    _lastWrittenLat = latitude;
    _lastWrittenLng = longitude;

    String agentId = _ref.read(deliveryAgentProvider).id;
    if (agentId.isEmpty) {
      agentId = FirebaseAuth.instance.currentUser?.uid ?? '';
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

    // Task 7 & Task 9: .catchError ensures Firestore write failures (network, rules,
    // quota) are silently swallowed and never crash the GPS stream.
    // In addition, save pending offline coordinates to sync upon reconnect.
    _ref
        .read(deliveryTrackingServiceProvider)
        .updateAgentLocation(agentId, latitude, longitude,
            orderId: activeOrderId)
        .then((_) {
      _pendingOfflineLat = null;
      _pendingOfflineLng = null;
    }).catchError((_) {
      /* Write failures are non-fatal — tracking continues */
      _pendingOfflineLat = latitude;
      _pendingOfflineLng = longitude;
      // Clear _lastWrittenLat so the next tick or reconnection can retry writing
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
    _subscription?.cancel();
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
