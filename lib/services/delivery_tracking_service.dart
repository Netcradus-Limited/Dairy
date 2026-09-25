import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Backend service for real-time delivery tracking backed by Cloud Firestore.
///
/// Data model in Firestore:
///   collection('delivery_agents').doc(<agentId>)
///     {
///       'location':   [latitude, longitude], // live position as a 2-element array
///       'orderId':    String?,               // order currently being delivered
///       'isOnline':   bool,                  // duty status
///       'updatedAt':  Timestamp,             // server time of last update
///     }
class DeliveryTrackingService {
  final FirebaseFirestore _firestore;

  DeliveryTrackingService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Validates that [lat] and [lng] form real, non-zero geographic coordinates.
  static bool isValidCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite)
      return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    // Reject zero placeholder coordinates (0.0, 0.0)
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  /// Parses and validates geographic coordinates from diverse Firestore formats:
  /// - `[latitude, longitude]` array
  /// - `GeoPoint(latitude, longitude)`
  /// - `{'latitude': ..., 'longitude': ...}` or `{'lat': ..., 'lng': ...}` Map
  static LatLng? parseCoordinates(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.length >= 2) {
      final lat = (raw[0] as num?)?.toDouble();
      final lng = (raw[1] as num?)?.toDouble();
      if (isValidCoordinates(lat, lng)) return LatLng(lat!, lng!);
    } else if (raw is GeoPoint) {
      if (isValidCoordinates(raw.latitude, raw.longitude)) {
        return LatLng(raw.latitude, raw.longitude);
      }
    } else if (raw is Map) {
      final rawLat = raw['latitude'] ?? raw['lat'];
      final rawLng = raw['longitude'] ?? raw['lng'] ?? raw['lon'];
      final double? lat = rawLat is num
          ? rawLat.toDouble()
          : (rawLat is String ? double.tryParse(rawLat) : null);
      final double? lng = rawLng is num
          ? rawLng.toDouble()
          : (rawLng is String ? double.tryParse(rawLng) : null);
      if (isValidCoordinates(lat, lng)) return LatLng(lat!, lng!);
    }
    return null;
  }

  /// Calculates straight-line / geodesic coordinate distance in kilometers
  /// between two points using [latlong2] [Distance].
  ///
  /// Returns `null` if either coordinate pair is null, out of bounds, NaN,
  /// infinite, or zero placeholder (0.0, 0.0).
  static double? calculateDistanceKm(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    if (!isValidCoordinates(lat1, lon1) || !isValidCoordinates(lat2, lon2)) {
      return null;
    }
    const distanceCalc = Distance();
    final meters = distanceCalc.distance(
      LatLng(lat1!, lon1!),
      LatLng(lat2!, lon2!),
    );
    return meters / 1000.0;
  }

  /// Formats distance in kilometers as a human-readable string (e.g. "3.2 km").
  /// Returns "—" when distance is null, negative, NaN, or infinite.
  static String formatDistance(double? distanceKm) {
    if (distanceKm == null ||
        distanceKm.isNaN ||
        distanceKm.isInfinite ||
        distanceKm < 0) {
      return '—';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Calculates an estimated delivery transit time (ETA) based on coordinate distance.
  ///
  /// Documented model assumptions:
  /// - Coordinate-based geodesic distance with an urban street winding factor (~1.2x).
  /// - Average urban two-wheeler delivery transit speed of ~20-25 km/h.
  /// - Fixed buffer for pickup preparation/handover: ~2.5 minutes.
  /// - Formula: `((distanceKm * 3.0) + 2.5).round().clamp(1, 180)` minutes.
  ///   Example: 3.2 km -> (3.2 * 3.0) + 2.5 = 12.1 -> "~12 min".
  /// - Returns "~X min" format when distance is valid.
  /// - Returns [fallbackSlot] (or "—") when distance is null or invalid.
  static String calculateEstimatedTime(
    double? distanceKm, {
    String? fallbackSlot,
  }) {
    if (distanceKm == null ||
        distanceKm.isNaN ||
        distanceKm.isInfinite ||
        distanceKm < 0) {
      if (fallbackSlot != null &&
          fallbackSlot.trim().isNotEmpty &&
          fallbackSlot.trim() != '—') {
        return fallbackSlot.trim();
      }
      return '—';
    }
    final int minutes = ((distanceKm * 3.0) + 2.5).round().clamp(1, 180);
    return '~$minutes min';
  }

  /// Pushes the delivery agent's live position to Firestore as a `[latitude,
  /// longitude]` array, stamping `updatedAt`. Use [merge: true] so non-location
  /// fields (e.g. `isOnline`) are preserved across updates.
  Future<void> updateAgentLocation(
    String agentId,
    double latitude,
    double longitude, {
    String? orderId,
  }) async {
    if (!isValidCoordinates(latitude, longitude)) return;
    await _firestore.collection('delivery_agents').doc(agentId).set(
      {
        'location': [latitude, longitude],
        'orderId': orderId ?? FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Updates only the agent's duty/online status in Firestore. Used when the
  /// agent toggles online/offline so the stored `isOnline` flag always reflects
  /// the current dynamic state rather than a stale value.
  Future<void> updateAgentOnlineStatus(
    String agentId,
    bool isOnline,
  ) async {
    await _firestore.collection('delivery_agents').doc(agentId).set(
      {
        'isOnline': isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Clears the agent's active orderId from Firestore.
  Future<void> clearActiveOrder(String agentId) async {
    await _firestore.collection('delivery_agents').doc(agentId).update({
      'orderId': FieldValue.delete(),
    });
  }

  /// Streams the agent's live [LatLng] (emits `null` when no real location yet).
  /// Parses `location` or document fields and validates coordinate boundaries.
  Stream<LatLng?> agentLocationStream(String agentId) {
    if (agentId.trim().isEmpty) return Stream.value(null);
    return _firestore
        .collection('delivery_agents')
        .doc(agentId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;

      // 1. Check 'location' field (List, GeoPoint, or Map)
      final parsedLocation = parseCoordinates(data['location']);
      if (parsedLocation != null) return parsedLocation;

      // 2. Check document fields (e.g. data['latitude'] and data['longitude'])
      return parseCoordinates(data);
    });
  }

  /// Convenience stream for tracking a specific order's assigned agent, given
  /// the agent id that owns that order.
  Stream<LatLng?> orderLocationStream(String agentId) =>
      agentLocationStream(agentId);
}

/// Provides a singleton [DeliveryTrackingService].
final deliveryTrackingServiceProvider = Provider<DeliveryTrackingService>(
  (ref) => DeliveryTrackingService(),
);
