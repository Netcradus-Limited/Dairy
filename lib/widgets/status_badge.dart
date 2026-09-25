import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/order_model.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color? customColor;
  final Color? customBgColor;

  const StatusBadge({
    super.key,
    required this.text,
    this.customColor,
    this.customBgColor,
  });

  factory StatusBadge.fromOrderStatus(OrderStatus status) {
    Color color;
    Color bg;
    switch (status) {
      case OrderStatus.pending:
        color = AppColors.statusPending;
        bg = const Color(0xFFFFF4EC);
        break;
      case OrderStatus.confirmed:
        color = AppColors.statusConfirmed;
        bg = const Color(0xFFFFECE5);
        break;
      case OrderStatus.assigned:
        color = AppColors.deliveriesPurple;
        bg = AppColors.deliveriesPurpleBg;
        break;
      case OrderStatus.preparing:
        color = AppColors.statusPreparing;
        bg = const Color(0xFFF6EEFE);
        break;
      case OrderStatus.outForDelivery:
        color = AppColors.statusOutForDelivery;
        bg = const Color(0xFFE8F6FD);
        break;
      case OrderStatus.delivered:
        color = AppColors.statusDelivered;
        bg = const Color(0xFFE8FAF2);
        break;
      case OrderStatus.cancelled:
        color = AppColors.statusCancelled;
        bg = const Color(0xFFF1F5F9);
        break;
    }

    return StatusBadge(
      text: status.displayName,
      customColor: color,
      customBgColor: bg,
    );
  }

  factory StatusBadge.fromString(String text) {
    final lower = text.toLowerCase();
    Color color = AppColors.primary;
    Color bg = AppColors.primaryLight;

    if (lower.contains('route') || lower.contains('out for delivery')) {
      color = AppColors.statusOutForDelivery;
      bg = const Color(0xFFE8F6FD);
    } else if (lower.contains('delivered') ||
        lower.contains('completed') ||
        lower.contains('active') ||
        lower.contains('success')) {
      color = AppColors.statusDelivered;
      bg = const Color(0xFFE8FAF2);
    } else if (lower.contains('assigned')) {
      color = AppColors.deliveriesPurple;
      bg = AppColors.deliveriesPurpleBg;
    } else if (lower.contains('confirmed')) {
      color = AppColors.statusConfirmed;
      bg = const Color(0xFFFFECE5);
    } else if (lower.contains('pending') || lower.contains('low balance')) {
      color = AppColors.statusPending;
      bg = const Color(0xFFFFF4EC);
    } else if (lower.contains('cancelled') || lower.contains('failed')) {
      color = AppColors.statusCancelled;
      bg = const Color(0xFFF1F5F9);
    }

    return StatusBadge(
      text: text,
      customColor: color,
      customBgColor: bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = customColor ?? AppColors.primary;
    final bg = customBgColor ?? color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
