import 'package:latlong2/latlong.dart';

import 'delivery_tracking_service.dart';

// ---------------------------------------------------------------------------
// RouteResult
// ---------------------------------------------------------------------------

/// The result of a route calculation for the active delivery.
///
/// [points] is an ordered list of [LatLng] waypoints (length ≥ 2 is drawable).
///
/// [isStraightLineFallback] is **always true** in the current implementation
/// because no road-routing API is configured for this project. Lines drawn from
/// these points are direct coordinate-to-coordinate segments, NOT real road
/// routes. This flag exists so a future implementation can wire in OSRM /
/// OpenRouteService / etc. by changing only this service.
///
/// [segmentDescription] is a human-readable label for the UI (e.g.
/// "Agent → Pickup → Customer").
class RouteResult {
  /// Ordered waypoints. Draw a polyline through all points in sequence.
  final List<LatLng> points;

  /// True when the points are straight-line segments (not real road routing).
  ///
  /// This is always `true` in the current implementation — there is no road
  /// routing API configured. Display this information to the user so they are
  /// not misled into believing the line follows actual roads.
  final bool isStraightLineFallback;

  /// Human-readable description of the segments present (for UI / legend).
  final String segmentDescription;

  const RouteResult({
    required this.points,
    required this.isStraightLineFallback,
    required this.segmentDescription,
  });

  /// Whether the result contains enough points to draw at least one segment.
  bool get isDrawable => points.length >= 2;
}

// ---------------------------------------------------------------------------
// RouteService
// ---------------------------------------------------------------------------

/// Builds straight-line delivery route waypoints from available coordinates.
///
/// ## Current Implementation
/// This service produces **coordinate-to-coordinate straight-line segments**.
/// It does **not** call any external road-routing API. No API key is required.
///
/// The preferred segment order is:
/// ```
///   Agent current location → Pickup location → Customer delivery location
/// ```
///
/// Partial routes are handled gracefully when some coordinates are unavailable:
/// - agent + pickup (no customer)   → agent → pickup
/// - pickup + customer (no agent)   → pickup → customer
/// - agent + customer (no pickup)   → agent → customer
/// - fewer than 2 valid coordinates → null (markers only, no polyline)
///
/// ## Coordinate Validation
/// All coordinates are validated through [DeliveryTrackingService.isValidCoordinates]
/// before being accepted. Zero (0.0, 0.0), NaN, Infinite, and out-of-range
/// values are rejected.
///
/// ## Performance — Threshold Guard
/// [hasCoordinatesChangedEnough] can be used by callers to gate recalculation.
/// Route recalculation is skipped when the agent has not moved more than
/// [minMovementMeters] (default 50 m) since the last calculation and the
/// selected order has not changed. This prevents excessive rebuilds on every
/// GPS tick.
class RouteService {
  /// Minimum agent movement (metres) before a route rebuild is triggered.
  static const double minMovementMeters = 50.0;

  /// Validates a single [LatLng] by delegating to the project's existing
  /// coordinate validation logic.
  static bool _isValid(LatLng? point) {
    if (point == null) return false;
    return DeliveryTrackingService.isValidCoordinates(
        point.latitude, point.longitude);
  }

  /// Returns `true` when [newPos] has moved more than [minMovementMeters]
  /// from [oldPos], or when either value is null (treat as changed).
  ///
  /// Used by the map widget to avoid recalculating the route on every GPS
  /// update when the agent is nearly stationary.
  static bool hasCoordinatesChangedEnough(
    LatLng? oldPos,
    LatLng? newPos,
  ) {
    if (oldPos == null || newPos == null) return true;
    if (!_isValid(oldPos) || !_isValid(newPos)) return true;
    const calc = Distance();
    final meters = calc.distance(oldPos, newPos);
    return meters >= minMovementMeters;
  }

  /// Builds a straight-line route from the available coordinates.
  ///
  /// Returns `null` when fewer than 2 valid coordinates are available (the map
  /// should show markers only in that case).
  ///
  /// The [agentPos], [pickupPos], and [customerPos] parameters accept `null`
  /// to indicate that a coordinate is not yet available.
  ///
  /// **Note**: lines are straight coordinate-to-coordinate segments, NOT
  /// real road routes. See [RouteResult.isStraightLineFallback].
  static RouteResult? buildStraightLineRoute({
    LatLng? agentPos,
    LatLng? pickupPos,
    LatLng? customerPos,
  }) {
    final hasAgent = _isValid(agentPos);
    final hasPickup = _isValid(pickupPos);
    final hasCustomer = _isValid(customerPos);

    // Full preferred route: agent → pickup → customer
    if (hasAgent && hasPickup && hasCustomer) {
      return RouteResult(
        points: [agentPos!, pickupPos!, customerPos!],
        isStraightLineFallback: true,
        segmentDescription: 'Agent → Pickup → Customer',
      );
    }

    // Partial: agent + pickup only (customer coordinates unavailable)
    if (hasAgent && hasPickup) {
      return RouteResult(
        points: [agentPos!, pickupPos!],
        isStraightLineFallback: true,
        segmentDescription: 'Agent → Pickup',
      );
    }

    // Partial: pickup + customer only (agent location unavailable)
    if (hasPickup && hasCustomer) {
      return RouteResult(
        points: [pickupPos!, customerPos!],
        isStraightLineFallback: true,
        segmentDescription: 'Pickup → Customer',
      );
    }

    // Partial: agent + customer only (pickup coordinates unavailable)
    if (hasAgent && hasCustomer) {
      return RouteResult(
        points: [agentPos!, customerPos!],
        isStraightLineFallback: true,
        segmentDescription: 'Agent → Customer',
      );
    }

    // Fewer than 2 valid coordinates — no polyline possible
    return null;
  }
}
