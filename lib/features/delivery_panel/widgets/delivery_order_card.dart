import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/widgets/product_image.dart';
import '../../../models/delivery_boy_model.dart';
import '../theme/delivery_theme.dart';
import 'delivery_status_chip.dart';

/// Reusable order card matching the reference design for Home, My Orders, and History.
class DeliveryOrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final VoidCallback? onTap;
  final bool showItemsCount;
  final bool showDate;

  const DeliveryOrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.showItemsCount = true,
    this.showDate = false,
  });

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:$minute $period';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  DeliveryChipType _getChipType() {
    switch (order.status) {
      case DeliveryOrderStatus.delivered:
        return DeliveryChipType.delivered;
      case DeliveryOrderStatus.pickup:
      case DeliveryOrderStatus.outForDelivery:
        return DeliveryChipType.inProgress;
      case DeliveryOrderStatus.accepted:
        return DeliveryChipType.next;
      case DeliveryOrderStatus.cancelled:
        return DeliveryChipType.cancelled;
      default:
        return DeliveryChipType.pending;
    }
  }

  String _getChipLabel() {
    switch (order.status) {
      case DeliveryOrderStatus.delivered:
        return 'Delivered';
      case DeliveryOrderStatus.pickup:
      case DeliveryOrderStatus.outForDelivery:
        return 'In Progress';
      case DeliveryOrderStatus.accepted:
        return 'Next';
      case DeliveryOrderStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = order.customerName.trim().isNotEmpty
        ? order.customerName.trim()
        : 'Customer';
    final addressText = order.customerAddress.trim().isNotEmpty
        ? order.customerAddress.trim()
        : 'Address not specified';
    final timeStr = _formatTime(order.orderTime);
    final dateStr = _formatDate(order.orderTime);
    final itemCount = order.items.isNotEmpty ? order.items.length : 1;
    final amountText = '₹${order.amount.toStringAsFixed(0)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: DeliveryTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DeliveryTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Product image or green package fallback icon
                order.productImageUrl != null &&
                        order.productImageUrl!.trim().isNotEmpty
                    ? ProductImage(
                        imageUrl: order.productImageUrl,
                        size: 44,
                        radius: 12,
                        fit: BoxFit.contain,
                        backgroundColor: const Color(0xFFE8F5E9),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: DeliveryTheme.primary,
                          size: 22,
                        ),
                      ),
                const SizedBox(width: 12),

                // Order metadata (Customer, address, item info)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: DeliveryTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: DeliveryTheme.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              addressText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: DeliveryTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (showItemsCount) ...[
                        const SizedBox(height: 3),
                        Text(
                          '$itemCount ${itemCount == 1 ? "item" : "items"} • $amountText',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: DeliveryTheme.primaryDark,
                          ),
                        ),
                      ] else if (showDate) ...[
                        const SizedBox(height: 3),
                        Text(
                          dateStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: DeliveryTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right column: Time/Amount + Status pill + Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          showDate ? amountText : timeStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: showDate ? 14 : 11,
                            fontWeight:
                                showDate ? FontWeight.w800 : FontWeight.w600,
                            color: showDate
                                ? DeliveryTheme.textDark
                                : DeliveryTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DeliveryStatusChip(
                          label: _getChipLabel(),
                          type: _getChipType(),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFB0BEC5),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
