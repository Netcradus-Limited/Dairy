import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/delivery_boy_model.dart';
import '../services/delivery_tracking_service.dart';
import '../services/location_service.dart';
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
  }

  /// Starts streaming real GPS coordinates to Firestore. Requests permission
  /// first; if denied, tracking stays off (state remains `false`).
  Future<void> startTracking() async {
    if (state) return;

    final location = _ref.read(locationServiceProvider);
    final granted = await location.requestLocationPermission();
    if (!granted) {
      state = false;
      return;
    }

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
    String agentId = _ref.read(deliveryAgentProvider).id;
    if (agentId.isEmpty) {
      agentId = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    if (agentId.isEmpty) return;

    final activeOrders =
        _ref.read(deliveryActiveOrdersStreamProvider).value ?? [];
    final activeOrderId =
        activeOrders.isNotEmpty ? activeOrders.first.id : null;
    _ref.read(deliveryTrackingServiceProvider).updateAgentLocation(
        agentId, latitude, longitude,
        orderId: activeOrderId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
