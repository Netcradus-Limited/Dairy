import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_provider.dart';
import '../theme/delivery_theme.dart';
import '../widgets/battery_optimization_warning_banner.dart';
import '../widgets/delivery_header.dart';
import '../widgets/delivery_order_card.dart';
import '../widgets/delivery_promo_banner.dart';
import '../widgets/delivery_summary_card.dart';
import '../widgets/gps_status_warning_banner.dart';
import 'delivery_order_detail_view.dart';

/// Screen 1 — Delivery Home Tab matching the reference design.
class DeliveryHomeTab extends ConsumerStatefulWidget {
  const DeliveryHomeTab({super.key});

  @override
  ConsumerState<DeliveryHomeTab> createState() => _DeliveryHomeTabState();
}

class _DeliveryHomeTabState extends ConsumerState<DeliveryHomeTab> {
  DeliveryOrder? _activeDetailOrder;

  @override
  Widget build(BuildContext context) {
    // If an order is selected for detail view on mobile, show the full detail screen
    if (_activeDetailOrder != null) {
      return DeliveryOrderDetailView(
        order: _activeDetailOrder!,
        onBack: () => setState(() => _activeDetailOrder = null),
      );
    }

    final agent = ref.watch(deliveryAgentProvider);
    final isOnline = agent.status == DeliveryStatus.onDuty;

    // Live streams
    final activeOrdersAsync = ref.watch(deliveryActiveOrdersStreamProvider);
    final requests = ref.watch(deliveryRequestsStreamProvider);
    final historyAsync = ref.watch(deliveryHistoryStreamProvider);

    // Combine active orders + accepted requests
    final activeOrders = activeOrdersAsync.asData?.value ?? [];
    final deliveredOrders = historyAsync.asData?.value ?? [];

    // Filter today's delivered
    final now = DateTime.now();
    final todayDeliveredCount = deliveredOrders.where((o) {
      final dt = o.deliveredTime ?? o.orderTime;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).length;

    final inProgressOrders = activeOrders
        .where((o) =>
            o.status == DeliveryOrderStatus.pickup ||
            o.status == DeliveryOrderStatus.outForDelivery)
        .toList();

    final pendingOrders = requests
        .where((o) =>
            o.status == DeliveryOrderStatus.pendingAcceptance ||
            o.status == DeliveryOrderStatus.accepted)
        .toList();

    final int totalOrdersCount =
        activeOrders.length + pendingOrders.length + todayDeliveredCount;
    final inProgressCount = inProgressOrders.length;
    final pendingCount = pendingOrders.length;

    // Display orders list for "Today's Deliveries"
    final displayOrders = [
      ...inProgressOrders,
      ...activeOrders.where((o) =>
          o.status != DeliveryOrderStatus.pickup &&
          o.status != DeliveryOrderStatus.outForDelivery),
      ...pendingOrders,
    ];

    return Scaffold(
      backgroundColor: DeliveryTheme.background,
      body: Column(
        children: [
          // Screen 1 Header
          DeliveryHomeHeader(
            onProfileTap: () {
              ref.read(deliveryPanelTabProvider.notifier).setTab(4);
            },
          ),

          // Main Scrollable Area
          Expanded(
            child: RefreshIndicator(
              color: DeliveryTheme.primary,
              onRefresh: () async {
                ref.invalidate(deliveryActiveOrdersStreamProvider);
                ref.invalidate(deliveryRequestsStreamProvider);
              },
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Warnings: Battery Optimization & GPS
                  const GpsStatusWarningBanner(),
                  const BatteryOptimizationWarningBanner(),

                  // Offline prompt if offline
                  if (!isOnline) _buildOfflineNotice(context),

                  // Today Summary (4 cards)
                  DeliveryTodaySummaryRow(
                    totalOrders: totalOrdersCount,
                    deliveredCount: todayDeliveredCount,
                    inProgressCount: inProgressCount,
                    pendingCount: pendingCount,
                    onCardTap: (index) {
                      // Navigate to My Orders
                      ref.read(deliveryPanelTabProvider.notifier).setTab(1);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Promotional Banner
                  const DeliveryPromoBanner(),
                  const SizedBox(height: 20),

                  // "Today's Deliveries" Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Deliveries",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: DeliveryTheme.textDark,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          ref.read(deliveryPanelTabProvider.notifier).setTab(1);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View All',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: DeliveryTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: DeliveryTheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List of Orders
                  if (displayOrders.isEmpty)
                    _buildEmptyOrdersCard(context)
                  else
                    ...displayOrders.map(
                      (order) => DeliveryOrderCard(
                        order: order,
                        onTap: () {
                          setState(() => _activeDetailOrder = order);
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineNotice(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are currently offline. Go to Profile to switch online and receive deliveries.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFBF360C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrdersCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: DeliveryTheme.cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.done_all_rounded,
              size: 36,
              color: DeliveryTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'All caught up for now!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: DeliveryTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New assigned deliveries will appear here automatically.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: DeliveryTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
