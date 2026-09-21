import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_provider.dart';
import '../../../services/order_service.dart';

int _requestCountdownSeconds(DeliveryOrder order) {
  final elapsed = DateTime.now().difference(order.orderTime).inSeconds;
  return (30 - elapsed).clamp(0, 30);
}

/// Requests Tab - Incoming delivery requests with accept/decline
class RequestsTab extends ConsumerStatefulWidget {
  const RequestsTab({super.key});

  @override
  ConsumerState<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<RequestsTab> {
  Timer? _timer;
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final requests = ref
        .watch(deliveryRequestsStreamProvider)
        .where((r) => !_dismissed.contains(r.id))
        .toList();
    final agent = ref.watch(deliveryAgentProvider);
    final isOnline = agent.status == DeliveryStatus.onDuty;
    final pendingRequests = requests
        .where((r) => r.status == DeliveryOrderStatus.pendingAcceptance)
        .toList();
    final acceptedRequests = requests
        .where((r) => r.status == DeliveryOrderStatus.accepted)
        .toList();

    final textPrimary = AppColors.textPrimaryOf(context);

    if (!isOnline) {
      return _buildOfflineView(context);
    }

    if (pendingRequests.isEmpty && acceptedRequests.isEmpty) {
      return _buildEmptyView(context);
    }

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      children: [
        if (pendingRequests.isNotEmpty) ...[
          Text(
            'New Requests',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...pendingRequests
              .map((request) => _buildRequestCard(request, isUrgent: true)),
          const SizedBox(height: 24),
        ],
        if (acceptedRequests.isNotEmpty) ...[
          Text(
            'Accepted Requests',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...acceptedRequests
              .map((request) => _buildRequestCard(request, isUrgent: false)),
        ],
      ],
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
              'Go online to start receiving delivery requests',
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
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All Caught Up!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No new delivery requests at the moment',
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

  Widget _buildRequestCard(DeliveryOrder request, {required bool isUrgent}) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);

    final timeLeft = _requestCountdownSeconds(request);
    final isExpiring = timeLeft <= 10 && timeLeft > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent && isExpiring ? AppColors.error : cardBorder,
          width: isUrgent && isExpiring ? 2 : 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${request.displayCode}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.customerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUrgent) _buildCountdownTimer(timeLeft, isExpiring),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Icons.location_on_outlined,
                label: request.distance,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.access_time_rounded,
                label: request.estimatedTime,
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.attach_money_rounded,
                label: '₹${request.deliveryFee.toStringAsFixed(0)}',
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pickup: ${request.pickupLocation}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Delivery: ${request.customerAddress}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: request.items
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
          if (isUrgent) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDecline(request.id),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleAccept(request.id),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToActiveTab,
                icon: const Icon(Icons.local_shipping_rounded, size: 18),
                label: const Text('View Active Deliveries'),
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
        ],
      ),
    );
  }

  Widget _buildCountdownTimer(int seconds, bool isExpiring) {
    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isExpiring
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpiring ? AppColors.error : AppColors.warning,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: isExpiring ? AppColors.error : AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isExpiring ? AppColors.error : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAccept(String requestId) async {
    final agent = ref.read(deliveryAgentProvider);
    final order = _findOrder(requestId);
    if (order == null) return;

    try {
      // Persist acceptance to Firestore (single source of truth). The order
      // moves from Requests to Active automatically via the live stream.
      await ref.read(orderServiceProvider).acceptOrder(order.id, agent.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${order.displayCode} accepted!'),
          backgroundColor: AppColors.success,
        ),
      );
      // Switch to Active tab
      ref.read(deliveryPanelTabProvider.notifier).setTab(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not accept order. Check your connection and try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  DeliveryOrder? _findOrder(String requestId) {
    try {
      return ref
          .read(deliveryRequestsStreamProvider)
          .firstWhere((r) => r.id == requestId);
    } on StateError {
      return null;
    }
  }

  void _handleDecline(String requestId) async {
    final order = _findOrder(requestId);
    if (order == null) return;
    final agent = ref.read(deliveryAgentProvider);

    try {
      if (agent.id.isNotEmpty) {
        await ref.read(orderServiceProvider).declineOrder(order.id, agent.id);
      }
      if (!mounted) return;
      setState(() => _dismissed.add(requestId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${order.displayCode} declined'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not decline order. Please try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _navigateToActiveTab() {
    ref.read(deliveryPanelTabProvider.notifier).setTab(1);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}