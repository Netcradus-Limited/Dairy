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

  /// Starts streaming real GPS coordinates to Firestore. Requests permission
  /// first; if denied, tracking stays off (state remains `false`).
  ///
  /// On Android 10+, also requests [ACCESS_BACKGROUND_LOCATION] so that
  /// the geolocator foreground service can continue sending updates when the
  /// app is minimised or the screen is locked. If the user denies background
  /// access, tracking degrades gracefully to foreground-only (no crash).
  Future<void> startTracking() async {
    if (state) return; // Duplicate-start guard

    final location = _ref.read(locationServiceProvider);
    final granted = await location.requestLocationPermission();
    if (!granted) {
      state = false;
      return;
    }

    // Task 7: Request background location permission (Android 10+).
    // Result is intentionally ignored for graceful foreground-only degradation.
    await location.requestBackgroundLocationPermission();

    // Task 3: Check battery optimization status when tracking starts
    unawaited(_ref.read(batteryOptimizationProvider.notifier).checkStatus());

    state = true;
    _writeCurrentPosition();

    _subscription = location.getPositionStream().listen(
      _onPosition,
      onError: (_) {
        // Transient GPS/permission errors are non-fatal: keep listening and
        // simply skip the bad reading.
      },
    );
  }

  /// Stops GPS tracking and releases the stream subscription.
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    // Task 7: Reset deduplication state so the next tracking session
    // always writes the first position even if coordinates haven't changed.
    _lastWrittenLat = null;
    _lastWrittenLng = null;
    _pendingOfflineLat = null;
    _pendingOfflineLng = null;
    state = false;
  }

  /// Convenience toggle used by the map / panel "share live location" buttons.
  void toggle() {
    if (state) {
      stopTracking();
    } else {
      startTracking();
    }
  }

  void _onPosition(Position position) {
    _write(position.latitude, position.longitude);
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

    final activeOrders =
        _ref.read(deliveryActiveOrdersStreamProvider).value ?? [];
    final activeOrderId =
        activeOrders.isNotEmpty ? activeOrders.first.id : null;

    // Task 7 & Task 9: .catchError ensures Firestore write failures (network, rules,
    // quota) are silently swallowed and never crash the GPS stream.
    // In addition, save pending offline coordinates to sync upon reconnect.
    _ref
        .read(deliveryTrackingServiceProvider)
        .updateAgentLocation(agentId, latitude, longitude, orderId: activeOrderId)
        .then((_) {
          _pendingOfflineLat = null;
          _pendingOfflineLng = null;
        })
        .catchError((_) {
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
