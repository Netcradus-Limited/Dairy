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
    // Use LayoutBuilder to give each card a minimum sensible width.
    // On small screens the row becomes horizontally scrollable.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Minimum card width: 72px, ideal is equal split.
        const double minCardWidth = 72.0;
        const double gap = 8.0;
        const int cardCount = 4;
        final double availableWidth = constraints.maxWidth;
        final double equalWidth =
            (availableWidth - gap * (cardCount - 1)) / cardCount;
        final bool needsScroll = equalWidth < minCardWidth;

        Widget row = Row(
          mainAxisSize: needsScroll ? MainAxisSize.min : MainAxisSize.max,
          children: [
            _card(
              count: '$totalOrders',
              label: "Today's Orders",
              icon: Icons.inventory_2_outlined,
              iconColor: DeliveryTheme.metricOrdersIcon,
              iconBgColor: DeliveryTheme.metricOrdersBg,
              width: needsScroll ? minCardWidth + 8 : null,
              onTap: () => onCardTap?.call(0),
            ),
            const SizedBox(width: gap),
            _card(
              count: '$deliveredCount',
              label: 'Delivered',
              icon: Icons.check_circle_outline_rounded,
              iconColor: DeliveryTheme.metricDeliveredIcon,
              iconBgColor: DeliveryTheme.metricDeliveredBg,
              width: needsScroll ? minCardWidth + 8 : null,
              onTap: () => onCardTap?.call(1),
            ),
            const SizedBox(width: gap),
            _card(
              count: '$inProgressCount',
              label: 'In Progress',
              icon: Icons.access_time_rounded,
              iconColor: DeliveryTheme.metricProgressIcon,
              iconBgColor: DeliveryTheme.metricProgressBg,
              width: needsScroll ? minCardWidth + 8 : null,
              onTap: () => onCardTap?.call(2),
            ),
            const SizedBox(width: gap),
            _card(
              count: '$pendingCount',
              label: 'Pending',
              icon: Icons.error_outline_rounded,
              iconColor: DeliveryTheme.metricPendingIcon,
              iconBgColor: DeliveryTheme.metricPendingBg,
              width: needsScroll ? minCardWidth + 8 : null,
              onTap: () => onCardTap?.call(3),
            ),
          ],
        );

        if (needsScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: row,
          );
        }
        return row;
      },
    );
  }

  Widget _card({
    required String count,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback? onTap,
    double? width,
  }) {
    final card = DeliverySummaryCard(
      count: count,
      label: label,
      icon: icon,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
      onTap: onTap,
    );
    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return Expanded(child: card);
  }

}
