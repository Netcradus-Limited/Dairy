import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../models/order.dart';
import '../../models/address.dart';
import '../../providers/delivery_provider.dart';

/// Single tracking step on the timeline
class _TrackingStep {
  final String label;
  final IconData icon;

  const _TrackingStep(this.label, this.icon);
}

/// Order Tracking Timeline Screen
class OrderTrackingScreen extends ConsumerWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  static const List<_TrackingStep> _steps = [
    _TrackingStep('Order Placed', Icons.receipt_long_rounded),
    _TrackingStep('Confirmed', Icons.check_circle_outline_rounded),
    _TrackingStep('Preparing Fresh', Icons.restaurant_rounded),
    _TrackingStep('Out for Delivery', Icons.delivery_dining_rounded),
    _TrackingStep('Delivered', Icons.home_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = order.status.stepIndex;
    final isCancelled = order.isCancelled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order #${order.displayOrderCode}'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? AppColors.error.withValues(alpha: 0.08)
                        : AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCancelled
                          ? AppColors.error.withValues(alpha: 0.3)
                          : AppColors.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? AppColors.error.withValues(alpha: 0.12)
                              : AppColors.primaryBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCancelled
                              ? Icons.cancel_outlined
                              : Icons.local_shipping_rounded,
                          color: isCancelled
                              ? AppColors.error
                              : AppColors.primaryBlue,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCancelled
                                  ? 'Order Cancelled'
                                  : order.status.label,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isCancelled
                                    ? AppColors.error
                                    : AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              order.estimatedDeliveryTime,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (order.status == OrderStatus.outForDelivery &&
                    order.assignedAgentId != null &&
                    order.assignedAgentId!.isNotEmpty) ...[
                  _LiveTrackingMapCard(
                    agentId: order.assignedAgentId!,
                    deliveryAddress: order.deliveryAddress,
                    orderId: order.id,
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 12),

                // Timeline
                if (!isCancelled) ...[
                  const Text(
                    'Delivery Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: List.generate(_steps.length, (i) {
                        final step = _steps[i];
                        final isDone = i <= currentStep;
                        final isActive = i == currentStep;
                        final isLast = i == _steps.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon + vertical line column
                            Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDone
                                        ? AppColors.primaryBlue
                                        : AppColors.border,
                                    shape: BoxShape.circle,
                                    boxShadow: isActive
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primaryBlue
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    step.icon,
                                    size: 20,
                                    color: isDone
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 44,
                                    color: isDone && i < currentStep
                                        ? AppColors.primaryBlue
                                        : AppColors.border,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Label + time
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: 8,
                                  bottom: isLast ? 0 : 34,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            step.label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isDone
                                                  ? AppColors.textPrimary
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                          if (isActive) ...[
                                            const SizedBox(height: 3),
                                            const Text(
                                              'Current stage',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primaryBlue,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isDone)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.freshGreen,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Delivery Address Summary
                _InfoCard(
                  title: 'Delivery Address',
                  icon: Icons.location_on_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.deliveryAddress.fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.deliveryAddress.fullAddressText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.deliveryAddress.mobileNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method
                _InfoCard(
                  title: 'Payment Method',
                  icon: Icons.payment_rounded,
                  child: Text(
                    order.paymentMethod,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LiveTrackingMapCard extends ConsumerStatefulWidget {
  final String agentId;
  final Address deliveryAddress;
  final String orderId;

  const _LiveTrackingMapCard({
    required this.agentId,
    required this.deliveryAddress,
    required this.orderId,
  });

  @override
  ConsumerState<_LiveTrackingMapCard> createState() =>
      _LiveTrackingMapCardState();
}

class _LiveTrackingMapCardState extends ConsumerState<_LiveTrackingMapCard> {
  final MapController _mapController = MapController();
  bool _hasInitiallyFitted = false;

  // Indore center coordinates
  static const LatLng indoreCenter = LatLng(22.7255, 75.8800);
  static const LatLng pickupHub = LatLng(22.7255, 75.8800);

  LatLng? _getCustomerLatLng() {
    try {
      if (widget.deliveryAddress.hasCoordinates) {
        return LatLng(
          widget.deliveryAddress.latitude!,
          widget.deliveryAddress.longitude!,
        );
      }

      // Fallback test points if any (matching delivery panel map)
      const dropPoints = {
        'DO-001': LatLng(22.7180, 75.8720),
        'DO-002': LatLng(22.7410, 75.8920),
      };

      return dropPoints[widget.orderId] ??
          LatLng(
            indoreCenter.latitude + (widget.orderId.hashCode % 20) * 0.0008,
            indoreCenter.longitude + (widget.orderId.hashCode % 15) * 0.0009,
          );
    } catch (_) {
      return null;
    }
  }

  void _fitMapBounds(LatLng? agentPos, LatLng? dropLoc) {
    if (!mounted) return;

    final points = <LatLng>[];
    points.add(pickupHub);
    if (agentPos != null) points.add(agentPos);
    if (dropLoc != null) points.add(dropLoc);

    if (points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(50),
            ),
          );
        } catch (_) {
          // Ignore if map layout is not yet ready
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Optimized single-listener subscription managed by Riverpod autoDispose family
    final locationAsync = ref.watch(orderAgentLocationStreamProvider(widget.agentId));
    final agentPos = locationAsync.valueOrNull;

    // Approximate drop coordinates for the customer
    final dropLoc = _getCustomerLatLng();

    // Auto-fit bounds ONCE upon first coordinates arrival without breaking widget state
    if (!_hasInitiallyFitted && (agentPos != null || dropLoc != null)) {
      _hasInitiallyFitted = true;
      _fitMapBounds(agentPos, dropLoc);
    }

    // Build list of active markers
    final markers = <Marker>[];

    // 1. Hub/Pickup Marker
    markers.add(
      const Marker(
        point: pickupHub,
        width: 32,
        height: 32,
        child: Icon(
          Icons.store_rounded,
          color: AppColors.primaryBlue,
          size: 24,
        ),
      ),
    );

    // 2. Customer Drop Location Marker (if available)
    if (dropLoc != null) {
      markers.add(
        Marker(
          point: dropLoc,
          width: 32,
          height: 32,
          child: const Icon(
            Icons.home_rounded,
            color: AppColors.error,
            size: 24,
          ),
        ),
      );
    }

    // 3. Agent Live Position Marker (if available)
    if (agentPos != null) {
      markers.add(
        Marker(
          point: agentPos,
          width: 38,
          height: 38,
          child: const Icon(
            Icons.delivery_dining_rounded,
            color: AppColors.freshGreen,
            size: 28,
          ),
        ),
      );
    }

    // 4. Polyline Route
    final route = <LatLng>[];
    if (agentPos != null && dropLoc != null) {
      route.addAll([pickupHub, agentPos, dropLoc]);
    }

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: agentPos ?? dropLoc ?? pickupHub,
                initialZoom: 14,
                minZoom: 4,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sawariyassarkar.app',
                ),
                if (route.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route,
                        strokeWidth: 4,
                        color: AppColors.primaryBlue.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: markers,
                ),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      color: agentPos != null
                          ? AppColors.freshGreen
                          : AppColors.textMuted,
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      agentPos != null
                          ? 'Agent Live Location'
                          : 'Connecting Location...',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Re-center / Fit bounds manual button
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _fitMapBounds(agentPos, dropLoc),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.center_focus_strong_rounded,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),
            if (agentPos == null)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Waiting for driver\'s live location...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
