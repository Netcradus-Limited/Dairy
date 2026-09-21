import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../models/delivery_boy_model.dart';
import '../../../models/order.dart';
import '../../../providers/delivery_provider.dart';
import '../../../services/order_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/delivery_tracking_service.dart';

/// Active Delivery Tab - Pickup -> Out for Delivery -> Delivered flow
class ActiveDeliveryTab extends ConsumerStatefulWidget {
  const ActiveDeliveryTab({super.key});

  @override
  ConsumerState<ActiveDeliveryTab> createState() => _ActiveDeliveryTabState();
}

class _ActiveDeliveryTabState extends ConsumerState<ActiveDeliveryTab> {
  DeliveryOrder? _selectedOrder;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final agent = ref.watch(deliveryAgentProvider);
    final isOnline = agent.status == DeliveryStatus.onDuty;
    final textPrimary = AppColors.textPrimaryOf(context);

    if (!isOnline) {
      return _buildOfflineView(context);
    }

    final ordersAsync = ref.watch(deliveryActiveOrdersStreamProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorView(context),
      data: (orders) {
        final activeOrders = orders
            .where((o) =>
                o.status == DeliveryOrderStatus.accepted ||
                o.status == DeliveryOrderStatus.pickup ||
                o.status == DeliveryOrderStatus.outForDelivery)
            .toList();

        if (activeOrders.isEmpty) {
          return _buildEmptyView(context);
        }

        // If there's a selected order, show detail view on mobile
        if (!isDesktop && _selectedOrder != null) {
          return _buildOrderDetailView(_selectedOrder!);
        }

        return ListView(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          children: [
            Text(
              'Active Deliveries (${activeOrders.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...activeOrders.map((order) => _buildOrderCard(order, isDesktop)),
          ],
        );
      },
    );
  }

  Widget _buildOfflineView(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You\'re Offline',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go online to manage active deliveries',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(deliveryAgentProvider.notifier).toggleDuty(),
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text('Go Online'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 64,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Deliveries',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accept requests from the Requests tab to start delivering',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Could not load orders',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(DeliveryOrder order, bool isDesktop) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusBadge(order.status),
              if (order.isSubscription) ...[
                const SizedBox(width: 8),
                _buildSubscriptionBadge(),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.displayCode}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      order.customerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${order.deliveryFee.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    (order.estimatedTime.isNotEmpty && order.estimatedTime != '—')
                        ? '${order.distance} · ${order.estimatedTime}'
                        : order.distance,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildLocationRow(
                  icon: Icons.store_rounded,
                  label: 'Pickup',
                  address: order.pickupLocation,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLocationRow(
                  icon: Icons.home_rounded,
                  label: 'Delivery',
                  address: order.customerAddress,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: order.items
                .map((item) => Chip(
                      label: Text(
                        item,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11),
                      ),
                      backgroundColor:
                          AppColors.primaryLight.withValues(alpha: 0.1),
                      side: const BorderSide(color: AppColors.primaryLight),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(order),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String address,
    required Color color,
  }) {
    final textMuted = AppColors.textMutedOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          address,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: textMuted,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusBadge(DeliveryOrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.statusLabel,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: status.statusColor,
        ),
      ),
    );
  }

  Widget _buildSubscriptionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat_rounded, size: 12, color: Color(0xFF6366F1)),
          const SizedBox(width: 4),
          Text(
            'Subscription',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DeliveryOrder order) {
    switch (order.status) {
      case DeliveryOrderStatus.accepted:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _callCustomer(order.customerPhone),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call Customer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToPickup(order),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navigate to Pickup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _transitionOrder(order, OrderStatus.preparing);
                },
                icon: const Icon(Icons.inventory_2_rounded, size: 18),
                label: const Text('Start Pickup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );
      case DeliveryOrderStatus.pickup:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _callCustomer(order.customerPhone),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call Customer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToCustomer(order.customerAddress),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navigate to Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _transitionOrder(order, OrderStatus.outForDelivery);
                },
                icon: const Icon(Icons.local_shipping_rounded, size: 18),
                label: const Text('Start Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );
      case DeliveryOrderStatus.outForDelivery:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _callCustomer(order.customerPhone),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call Customer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToCustomer(order.customerAddress),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navigate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showDeliveryConfirmation(order),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Mark Delivered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOrderDetailView(DeliveryOrder order) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);
    final cardBg = AppColors.cardBgOf(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _selectedOrder = null),
        ),
        title: Text(
          'Order #${order.displayCode}',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusBadge(order.status),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer Details',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary)),
                  const SizedBox(height: 12),
                  _buildDetailRow('Name', order.customerName),
                  _buildDetailRow('Phone', order.customerPhone),
                  _buildDetailRow('Address', order.customerAddress),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pickup Details',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary)),
                  const SizedBox(height: 12),
                  _buildDetailRow('Location', order.pickupLocation),
                  _buildDetailRow('Phone', order.pickupPhone),
                  if (order.distance.isNotEmpty && order.distance != '—')
                    _buildDetailRow('Distance', order.distance),
                  if (order.estimatedTime.isNotEmpty && order.estimatedTime != '—')
                    _buildDetailRow('ETA', order.estimatedTime),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary)),
                  const SizedBox(height: 12),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.circle_rounded,
                                size: 8, color: textMuted),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(item,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14, color: textSecondary))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Earnings',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary)),
                  const SizedBox(height: 12),
                  _buildDetailRow('Delivery Fee',
                      '₹${order.deliveryFee.toStringAsFixed(0)}'),
                  _buildDetailRow(
                      'Order Amount', '₹${order.amount.toStringAsFixed(0)}'),
                  const Divider(),
                  _buildDetailRow('Total Earnings',
                      '₹${(order.amount + order.deliveryFee).toStringAsFixed(0)}',
                      isTotal: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(order),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? textPrimary : textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isTotal ? AppColors.success : textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeliveryConfirmation(DeliveryOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delivery',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Mark order #${order.displayCode} as delivered?',
            style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondaryOf(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final agentId = ref.read(deliveryAgentProvider).id;
                if (order.isSubscription) {
                  await SubscriptionService().completeSubscriptionDelivery(
                    order.id,
                    agentId: agentId.isNotEmpty ? agentId : null,
                  );
                } else {
                  await ref
                      .read(orderServiceProvider)
                      .updateOrderStatus(order.id, OrderStatus.delivered);
                }

                // Clear the agent's active orderId in Firestore & stop location tracking for that order
                if (agentId.isNotEmpty) {
                  await ref
                      .read(deliveryTrackingServiceProvider)
                      .clearActiveOrder(agentId);
                }
              } catch (e, st) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not update order. Check your connection and try again.',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
                return;
              }
              // Add to history
              ref.read(deliveryHistoryProvider.notifier).addToHistory(
                    DeliveryHistoryItem(
                      orderId: order.orderId,
                      orderCode: order.displayCode,
                      customerName: order.customerName,
                      status: 'Delivered',
                      earnings: order.deliveryFee,
                      date: DateTime.now(),
                      distance: order.distance,
                    ),
                  );
              // Update agent earnings
              final agent = ref.read(deliveryAgentProvider);
              ref.read(deliveryAgentProvider.notifier).updateStats(
                    completedDeliveries: agent.completedDeliveriesToday + 1,
                    earnings: agent.earningsToday + order.deliveryFee,
                  );
              // Add earnings record
              ref.read(deliveryEarningsProvider.notifier).addEarnings(
                    DeliveryEarnings(
                      date: DateTime.now(),
                      baseEarnings: order.deliveryFee,
                      tips: 0,
                      bonuses: 0,
                      deliveriesCount: 1,
                      total: order.deliveryFee,
                    ),
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order #${order.displayCode} delivered!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text('Confirm', style: GoogleFonts.plusJakartaSans()),
          ),
        ],
      ),
    );
  }

  void _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not launch dialer'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _navigateToPickup(DeliveryOrder order) async {
    final location = order.pickupLocation.trim();
    if (location.isEmpty || location == '—' || location == 'Not specified') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup location not available for navigation'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final Uri uri;
    if (order.hasValidPickupCoordinates) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${order.pickupLatitude},${order.pickupLongitude}');
    } else {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToCustomer(String address) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Updates an order's status in Firestore with graceful error handling so a
  /// failed network write surfaces a message instead of failing silently.
  Future<void> _transitionOrder(DeliveryOrder order, OrderStatus status) async {
    try {
      await ref.read(orderServiceProvider).updateOrderStatus(order.id, status);
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update order. Check your connection and try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
