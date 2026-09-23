import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_provider.dart';
import '../../../services/delivery_tracking_service.dart';
import '../theme/delivery_theme.dart';
import '../widgets/delivery_header.dart';

/// Screen 4 — Live Tracking / Map ("On the Way") matching the reference design.
/// Built strictly using flutter_map + OpenStreetMap.
class DeliveryMapTab extends ConsumerStatefulWidget {
  const DeliveryMapTab({super.key});

  @override
  ConsumerState<DeliveryMapTab> createState() => _DeliveryMapTabState();
}

class _DeliveryMapTabState extends ConsumerState<DeliveryMapTab> {
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(22.7255, 75.8800);
  bool _hasCentered = false;

  void _reCenter(LatLng point) {
    _mapController.move(point, 15.5);
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openExternalDirections(
      double? destLat, double? destLng, String address) async {
    Uri uri;
    if (destLat != null &&
        destLng != null &&
        DeliveryTrackingService.isValidCoordinates(destLat, destLng)) {
      final query = Uri.encodeComponent('$destLat,$destLng');
      final geoUri = Uri.parse('geo:$destLat,$destLng?q=$query');
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
        return;
      }
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng');
    } else {
      final query = Uri.encodeComponent(address);
      final geoUri = Uri.parse('geo:0,0?q=$query');
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
        return;
      }
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders =
        ref.watch(deliveryActiveOrdersStreamProvider).asData?.value ?? [];
    final agentLocationAsync = ref.watch(deliveryAgentLocationStreamProvider);

    // Pick current active delivery order (pickup or out for delivery)
    DeliveryOrder? activeOrder;
    if (activeOrders.isNotEmpty) {
      activeOrder = activeOrders.firstWhere(
        (o) =>
            o.status == DeliveryOrderStatus.outForDelivery ||
            o.status == DeliveryOrderStatus.pickup,
        orElse: () => activeOrders.first,
      );
    }

    // Determine agent coordinates from live GPS stream
    final rawAgentLocation = agentLocationAsync.valueOrNull;
    final agentPos = rawAgentLocation ?? _defaultCenter;
    final bool hasRealAgentGps = rawAgentLocation != null &&
        DeliveryTrackingService.isValidCoordinates(
            rawAgentLocation.latitude, rawAgentLocation.longitude);

    // Determine customer coordinates — do NOT invent coordinates if unavailable
    LatLng? customerPos;
    if (activeOrder != null && activeOrder.hasValidCoordinates) {
      customerPos = LatLng(activeOrder.latitude!, activeOrder.longitude!);
    }

    // Dynamic distance & ETA calculation via DeliveryTrackingService
    double? distanceKm;
    if (hasRealAgentGps && customerPos != null) {
      distanceKm = DeliveryTrackingService.calculateDistanceKm(
        agentPos.latitude,
        agentPos.longitude,
        customerPos.latitude,
        customerPos.longitude,
      );
    }

    final String formattedDistance = distanceKm != null
        ? DeliveryTrackingService.formatDistance(distanceKm)
        : (hasRealAgentGps ? '—' : 'GPS off');

    final String formattedEta = distanceKm != null
        ? DeliveryTrackingService.calculateEstimatedTime(distanceKm,
            fallbackSlot: activeOrder?.estimatedTime)
        : (activeOrder?.estimatedTime.isNotEmpty == true
            ? activeOrder!.estimatedTime
            : '—');

    // Auto-center once coordinates arrive
    if (!_hasCentered && agentLocationAsync.valueOrNull != null) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reCenter(agentPos);
      });
    }

    // Route polyline points (only if real customer destination exists)
    final routePoints =
        customerPos != null ? [agentPos, customerPos] : <LatLng>[];

    return Scaffold(
      backgroundColor: DeliveryTheme.background,
      body: Stack(
        children: [
          // 1. flutter_map with OpenStreetMap Tiles
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: agentPos,
              initialZoom: 14.5,
              maxZoom: 18.0,
              minZoom: 4.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sawariyadairy.app',
                maxZoom: 19,
              ),
              // Route polyline in bold green (only if customer pin available)
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.5,
                      color: DeliveryTheme.primary,
                    ),
                  ],
                ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Agent marker (green circle with delivery scooter/house icon)
                  Marker(
                    point: agentPos,
                    width: 50,
                    height: 50,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: DeliveryTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  // Destination marker (red pin) — only when customerPos is valid
                  if (customerPos != null)
                    Marker(
                      point: customerPos,
                      width: 44,
                      height: 44,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x44E53935),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. Top Header ("On the Way")
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DeliveryStandardHeader(
              title: 'On the Way',
              leading: IconButton(
                onPressed: () {
                  ref.read(deliveryPanelTabProvider.notifier).setTab(0);
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              actions: [
                if (activeOrder != null)
                  IconButton(
                    onPressed: () =>
                        _makePhoneCall(activeOrder!.customerPhone),
                    icon: const Icon(Icons.phone_outlined,
                        color: Colors.white, size: 22),
                  ),
              ],
            ),
          ),

          // 3. Floating Route Info Badge (Dynamic ETA • Distance)
          if (activeOrder != null)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 16, color: DeliveryTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        formattedEta,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: DeliveryTheme.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFB0BEC5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDistance,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DeliveryTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Floating GPS Target / Re-center Button
          Positioned(
            right: 16,
            bottom: activeOrder != null ? 220 : 90,
            child: FloatingActionButton.small(
              heroTag: 'map_recenter_fab',
              onPressed: () => _reCenter(agentPos),
              backgroundColor: Colors.white,
              foregroundColor: DeliveryTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),

          // 5. Bottom Floating Delivery Card matching reference
          if (activeOrder != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivering to',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: DeliveryTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeOrder.customerName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: DeliveryTheme.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 14,
                                      color: DeliveryTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      activeOrder.customerAddress,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: DeliveryTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Green Directions button
                        ElevatedButton.icon(
                          onPressed: () => _openExternalDirections(
                            customerPos?.latitude,
                            customerPos?.longitude,
                            activeOrder!.customerAddress,
                          ),
                          icon: const Icon(Icons.near_me_rounded, size: 16),
                          label: Text(
                            'Directions',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DeliveryTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFECEFF1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 18, color: DeliveryTheme.primary),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estimated Arrival',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: DeliveryTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  activeOrder.estimatedTime.isNotEmpty
                                      ? activeOrder.estimatedTime
                                      : (formattedEta != '—'
                                          ? formattedEta
                                          : 'Pending'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: DeliveryTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formattedDistance,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: DeliveryTheme.textSecondary,
                              ),
                            ),
                            Text(
                              formattedEta,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: DeliveryTheme.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
