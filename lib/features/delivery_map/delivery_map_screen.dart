import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../models/delivery_boy_model.dart';
import '../../providers/delivery_live_location_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../services/route_service.dart';

/// Physical hub constants and default initial map view.
class _MapConstants {
  /// Default camera center for initial map tile load before real coordinates arrive.
  static const LatLng defaultMapCenter = LatLng(22.7255, 75.8800);

  /// Physical pickup location for Sawariya Dairy Hub (Vijay Nagar).
  static const LatLng pickupHub = LatLng(22.7255, 75.8800);

  /// Extracts coordinates from a [DeliveryOrder] only if valid real coordinates exist.
  static LatLng? locationForOrder(DeliveryOrder order) {
    if (order.hasValidCoordinates) {
      return LatLng(order.latitude!, order.longitude!);
    }
    return null;
  }

  /// Extracts pickup coordinates from a [DeliveryOrder] only if valid real coordinates exist.
  static LatLng? pickupLocationForOrder(DeliveryOrder order) {
    if (order.hasValidPickupCoordinates) {
      return LatLng(order.pickupLatitude!, order.pickupLongitude!);
    }
    return null;
  }
}

/// Live delivery tracking map built on OpenStreetMap tiles.
/// The delivery agent's position is streamed from Firestore in real time.
class DeliveryMapScreen extends ConsumerStatefulWidget {
  const DeliveryMapScreen({super.key});

  @override
  ConsumerState<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends ConsumerState<DeliveryMapScreen> {
  final MapController _mapController = MapController();
  DeliveryOrder? _selectedOrder;
  bool _followAgent = false;
  bool _hasInitiallyCentered = false;

  // --- Task 6: route state ------------------------------------------------
  /// The last computed route result. Null when no drawable route is available.
  RouteResult? _routeResult;

  /// Agent position used for the last route calculation — used for the
  /// 50 m threshold guard so we do not rebuild on every GPS tick.
  LatLng? _lastAgentPos;

  /// Order ID used for the last route calculation — recalculate whenever the
  /// selected order changes.
  String? _lastOrderId;
  // -------------------------------------------------------------------------

  void _focusOn(LatLng point, {double zoom = 16}) {
    _mapController.move(point, zoom);
  }

  void _selectOrder(DeliveryOrder order) {
    setState(() {
      _selectedOrder = order;
      // Force route rebuild on order selection change, even if agent has not
      // moved, by resetting the last order guard.
      _lastOrderId = null;
    });
    final loc = _MapConstants.locationForOrder(order);
    if (loc != null) {
      _focusOn(loc, zoom: 16);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS coordinates unavailable for Order #${order.displayCode}. Customer address: ${order.customerAddress}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // --- Task 6: threshold-guarded route builder ----------------------------
  /// Rebuilds [_routeResult] using [RouteService] only when the selected order
  /// changes or the agent has moved by more than [RouteService.minMovementMeters]
  /// (50 m). Returns immediately without updating state when the threshold has
  /// not been crossed, preventing unnecessary rebuilds on every GPS tick.
  ///
  /// Lines are **straight-line fallback segments** (coordinate-to-coordinate).
  /// No external road-routing API is called.
  void _maybeRebuildRoute(LatLng? agentPos) {
    final order = _selectedOrder;
    final orderIdChanged = order?.id != _lastOrderId;
    final agentMovedEnough = RouteService.hasCoordinatesChangedEnough(
      _lastAgentPos,
      agentPos,
    );

    // Only skip rebuild when nothing relevant has changed.
    if (!orderIdChanged && !agentMovedEnough) return;

    LatLng? pickupPos;
    LatLng? customerPos;

    if (order != null) {
      pickupPos = _MapConstants.pickupLocationForOrder(order) ??
          _MapConstants.pickupHub;
      customerPos = _MapConstants.locationForOrder(order);
    }

    final result = RouteService.buildStraightLineRoute(
      agentPos: agentPos,
      pickupPos: pickupPos,
      customerPos: customerPos,
    );

    // Update guards and state together.
    _lastOrderId = order?.id;
    _lastAgentPos = agentPos;
    _routeResult = result;
  }
  // -------------------------------------------------------------------------

  void _toggleLiveLocation() {
    ref.read(agentLiveLocationProvider.notifier).toggle();
  }

  List<Marker> _buildMarkers(List<DeliveryOrder> orders, LatLng? agentPos) {
    final markers = <Marker>[];

    // Hub / Pickup markers:
    // If orders have explicit dynamic pickup coordinates, render their distinct pickup locations.
    // If no order provides custom pickup coordinates, render the standard physical dairy hub marker.
    final pickupPoints = <String, LatLng>{};
    for (final order in orders) {
      final pickupLoc = _MapConstants.pickupLocationForOrder(order);
      if (pickupLoc != null) {
        final label = (order.pickupLocation.isNotEmpty &&
                order.pickupLocation != 'Not specified' &&
                order.pickupLocation != '—')
            ? order.pickupLocation
            : 'Hub';
        pickupPoints[label] = pickupLoc;
      }
    }

    if (pickupPoints.isEmpty) {
      markers.add(
        const Marker(
          point: _MapConstants.pickupHub,
          width: 40,
          height: 40,
          child: _MapPin(
            color: AppColors.primaryBlue,
            icon: Icons.store_rounded,
            label: 'Hub',
          ),
        ),
      );
    } else {
      for (final entry in pickupPoints.entries) {
        markers.add(
          Marker(
            point: entry.value,
            width: 40,
            height: 40,
            child: _MapPin(
              color: AppColors.primaryBlue,
              icon: Icons.store_rounded,
              label: entry.key,
            ),
          ),
        );
      }
    }

    // Agent live marker: rendered ONLY if real agent coordinates are streamed from Firestore.
    if (agentPos != null) {
      markers.add(
        Marker(
          point: agentPos,
          width: 44,
          height: 44,
          child: const _MapPin(
            color: AppColors.freshGreen,
            icon: Icons.delivery_dining_rounded,
            label: 'Live',
          ),
        ),
      );
    }

    // Customer order markers: rendered ONLY if order has valid real coordinates.
    for (final order in orders) {
      final orderLoc = _MapConstants.locationForOrder(order);
      if (orderLoc == null) continue;

      final isSelected = order.id == _selectedOrder?.id;
      markers.add(
        Marker(
          point: orderLoc,
          width: isSelected ? 46 : 38,
          height: isSelected ? 46 : 38,
          child: GestureDetector(
            onTap: () => _selectOrder(order),
            child: _MapPin(
              color: order.status.statusColor,
              icon: Icons.location_on_rounded,
              label: order.displayCode,
              highlighted: isSelected,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(deliveryAgentProvider);
    final sharing = ref.watch(agentLiveLocationProvider);
    final ordersAsync = ref.watch(deliveryActiveOrdersStreamProvider);
    final agentLocationAsync = ref.watch(deliveryAgentLocationStreamProvider);

    final agentPos = agentLocationAsync.valueOrNull;

    // Center map on real agent location when first received
    if (agentPos != null && !_hasInitiallyCentered) {
      _hasInitiallyCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(agentPos, 16.0);
      });
    }

    // Optional auto-follow: keep agent centered as they move
    if (_followAgent && agentPos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(agentPos, _mapController.camera.zoom);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Delivery Map'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            tooltip: sharing ? 'Stop live location' : 'Share live location',
            icon: Icon(sharing
                ? Icons.pause_circle_rounded
                : Icons.play_circle_rounded),
            onPressed: _toggleLiveLocation,
          ),
          IconButton(
            tooltip: agentPos != null ? 'Recenter on Agent' : 'Recenter on Hub',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {
              if (agentPos != null) {
                _focusOn(agentPos, zoom: 16);
              } else {
                _focusOn(_MapConstants.pickupHub, zoom: 15);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Agent GPS location is currently unavailable.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Could not load active orders'),
        ),
        data: (orders) {
          final activeOrders = orders
              .where((o) =>
                  o.status != DeliveryOrderStatus.delivered &&
                  o.status != DeliveryOrderStatus.cancelled &&
                  o.status != DeliveryOrderStatus.declined)
              .toList();

          // Task 6: rebuild route only when order or agent position changes
          // beyond the 50 m threshold (inside build() is fine because
          // _maybeRebuildRoute is idempotent and updates state in-place;
          // the setState guard in _selectOrder and the threshold guard in
          // RouteService ensure we never trigger infinite rebuild loops).
          _maybeRebuildRoute(agentPos);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: agentPos ?? _MapConstants.defaultMapCenter,
                  initialZoom: 15.5,
                  minZoom: 4,
                  maxZoom: 19,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'in.sawariyadairy.delivery',
                    maxZoom: 19,
                    maxNativeZoom: 19,
                    retinaMode: RetinaMode.isHighDensity(context),
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint('Map Tile error: $error on tile $tile');
                    },
                  ),
                  // Task 6: draw polyline from RouteService result.
                  // Lines are straight-line fallback segments (not road routes).
                  if (_routeResult != null && _routeResult!.isDrawable)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routeResult!.points,
                          strokeWidth: 4,
                          color: AppColors.primaryBlue
                              .withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: _buildMarkers(activeOrders, agentPos),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _AgentStatusCard(
                  agent: agent,
                  isLive: agentPos != null,
                  agentLocation: agentPos,
                  isLoading: agentLocationAsync.isLoading,
                  hasError: agentLocationAsync.hasError,
                ),
              ),
              // Task 6: straight-line route legend badge.
              // Shown only when a route is visible so the user understands
              // the line is a coordinate-to-coordinate fallback, NOT a real
              // road route (no routing API is configured for this project).
              if (_routeResult != null && _routeResult!.isDrawable)
                Positioned(
                  bottom: 72,
                  left: 12,
                  child: _RouteLegendBadge(
                    description: _routeResult!.segmentDescription,
                    isFallback: _routeResult!.isStraightLineFallback,
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  tooltip: _followAgent
                      ? 'Stop following agent'
                      : 'Follow agent',
                  backgroundColor: _followAgent
                      ? AppColors.primaryBlue
                      : AppColors.surface,
                  foregroundColor:
                      _followAgent ? Colors.white : AppColors.primaryBlue,
                  onPressed: () {
                    if (agentPos == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot follow: Agent location is currently unavailable.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    setState(() => _followAgent = !_followAgent);
                  },
                  child: const Icon(Icons.gps_fixed_rounded),
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.32,
                minChildSize: 0.18,
                maxChildSize: 0.7,
                builder: (context, scrollController) =>
                    _DeliveryListSheet(
                  scrollController: scrollController,
                  orders: activeOrders,
                  selectedOrder: _selectedOrder,
                  onTap: _selectOrder,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AgentStatusCard extends StatelessWidget {
  final DeliveryAgent agent;
  final bool isLive;
  final LatLng? agentLocation;
  final bool isLoading;
  final bool hasError;

  const _AgentStatusCard({
    required this.agent,
    required this.isLive,
    this.agentLocation,
    this.isLoading = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final onDuty = agent.status == DeliveryStatus.onDuty ||
        agent.status == DeliveryStatus.breakTime;
    final hasRealLocation = agentLocation != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadowSm,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: onDuty ? AppColors.freshGreen : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name.isNotEmpty ? agent.name : 'Delivery Agent',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${agent.assignedZone.isNotEmpty ? agent.assignedZone : "Zone Not Set"} · ${agent.status.name.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasRealLocation && isLive)
                      ? AppColors.freshGreen.withValues(alpha: 0.12)
                      : (hasError
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.textMuted.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 4),
                    ] else
                      Icon(
                        (hasRealLocation && isLive)
                            ? Icons.location_on_rounded
                            : (hasError ? Icons.error_outline_rounded : Icons.location_off_rounded),
                        size: 12,
                        color: (hasRealLocation && isLive)
                            ? AppColors.freshGreen
                            : (hasError ? AppColors.error : AppColors.textMuted),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      isLoading
                          ? 'LOCATING'
                          : (hasRealLocation && isLive
                              ? 'LIVE'
                              : (hasError ? 'ERROR' : 'NO GPS')),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: (hasRealLocation && isLive)
                            ? AppColors.freshGreen
                            : (hasError ? AppColors.error : AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${agent.completedDeliveriesToday}/${agent.totalDeliveriesToday} done',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ),
        if (!hasRealLocation && !isLoading)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.location_off_rounded, size: 14, color: Colors.amber.shade900),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasError
                        ? 'Could not connect to location stream · Check connection'
                        : 'Agent location unavailable · Waiting for real GPS stream',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DeliveryListSheet extends StatelessWidget {
  final ScrollController scrollController;
  final List<DeliveryOrder> orders;
  final DeliveryOrder? selectedOrder;
  final void Function(DeliveryOrder) onTap;

  const _DeliveryListSheet({
    required this.scrollController,
    required this.orders,
    required this.selectedOrder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: AppColors.cardShadowLg,
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.route_rounded,
                    size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Active Deliveries (${orders.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: orders.isEmpty
                ? const Center(
                    child: Text(
                      'No active deliveries right now',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final selected = order.id == selectedOrder?.id;
                      return _DeliveryListItem(
                        order: order,
                        selected: selected,
                        onTap: () => onTap(order),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryListItem extends StatelessWidget {
  final DeliveryOrder order;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryListItem({
    required this.order,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasGps = order.hasValidCoordinates;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: order.status.statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasGps ? Icons.location_on_rounded : Icons.place_outlined,
                color: order.status.statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.customerAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: order.status.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: order.status.statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.distance} · ${order.estimatedTime}${hasGps ? '' : ' · No GPS'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool highlighted;

  const _MapPin({
    required this.color,
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!highlighted) {
      return Center(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: color,
              width: 2,
            ),
            boxShadow: AppColors.cardShadowSm,
          ),
          padding: const EdgeInsets.all(5),
          child: Icon(icon, color: color, size: 18),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final maxHeight = hasBoundedHeight ? constraints.maxHeight : 46.0;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 64.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: color,
                      width: 2.5,
                    ),
                    boxShadow: AppColors.cardShadowSm,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Icon(icon, color: color, size: 18),
                  ),
                ),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 2),
                Flexible(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _RouteLegendBadge  (Task 6)
// ---------------------------------------------------------------------------

/// A small floating badge displayed on the map whenever a route polyline is
/// visible.
///
/// Clearly communicates to the user that the line drawn is a
/// **straight-line coordinate-to-coordinate segment**, NOT a real road route.
/// This is required because no road-routing API (OSRM, Google Directions,
/// OpenRouteService, etc.) is configured for this project.
class _RouteLegendBadge extends StatelessWidget {
  /// Human-readable description of the segments shown (e.g. "Agent → Pickup → Customer").
  final String description;

  /// Whether the route is a straight-line fallback (always true currently).
  final bool isFallback;

  const _RouteLegendBadge({
    required this.description,
    required this.isFallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.35)),
        boxShadow: AppColors.cardShadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                description,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isFallback)
                const Text(
                  'Straight-line route (no road routing)',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
