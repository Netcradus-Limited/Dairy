import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/delivery_theme.dart';

/// Single metric card used in the 4-item Today's Summary row.
class DeliverySummaryCard extends StatelessWidget {
  final String count;
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback? onTap;

  const DeliverySummaryCard({
    super.key,
    required this.count,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeliveryTheme.cardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: DeliveryTheme.cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DeliveryTheme.textDark,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DeliveryTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The responsive 4-card Today Summary row from the reference image.
class DeliveryTodaySummaryRow extends StatelessWidget {
  final int totalOrders;
  final int deliveredCount;
  final int inProgressCount;
  final int pendingCount;
  final ValueChanged<int>? onCardTap;

  const DeliveryTodaySummaryRow({
    super.key,
    required this.totalOrders,
    required this.deliveredCount,
    required this.inProgressCount,
    required this.pendingCount,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DeliverySummaryCard(
            count: '$totalOrders',
            label: "Today's Orders",
            icon: Icons.inventory_2_outlined,
            iconColor: DeliveryTheme.metricOrdersIcon,
            iconBgColor: DeliveryTheme.metricOrdersBg,
            onTap: () => onCardTap?.call(0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DeliverySummaryCard(
            count: '$deliveredCount',
            label: 'Delivered',
            icon: Icons.check_circle_outline_rounded,
            iconColor: DeliveryTheme.metricDeliveredIcon,
            iconBgColor: DeliveryTheme.metricDeliveredBg,
            onTap: () => onCardTap?.call(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DeliverySummaryCard(
            count: '$inProgressCount',
            label: 'In Progress',
            icon: Icons.access_time_rounded,
            iconColor: DeliveryTheme.metricProgressIcon,
            iconBgColor: DeliveryTheme.metricProgressBg,
            onTap: () => onCardTap?.call(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DeliverySummaryCard(
            count: '$pendingCount',
            label: 'Pending',
            icon: Icons.error_outline_rounded,
            iconColor: DeliveryTheme.metricPendingIcon,
            iconBgColor: DeliveryTheme.metricPendingBg,
            onTap: () => onCardTap?.call(3),
          ),
        ),
      ],
    );
  }
}
