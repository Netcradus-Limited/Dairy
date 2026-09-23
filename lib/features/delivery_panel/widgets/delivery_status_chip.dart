import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/delivery_theme.dart';

enum DeliveryChipType {
  next,
  inProgress,
  pending,
  delivered,
  cancelled,
}

class DeliveryStatusChip extends StatelessWidget {
  final String label;
  final DeliveryChipType type;

  const DeliveryStatusChip({
    super.key,
    required this.label,
    required this.type,
  });

  factory DeliveryStatusChip.fromStatus(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('deliver') && !lower.contains('out')) {
      return const DeliveryStatusChip(
        label: 'Delivered',
        type: DeliveryChipType.delivered,
      );
    } else if (lower.contains('progress') ||
        lower.contains('pickup') ||
        lower.contains('out')) {
      return const DeliveryStatusChip(
        label: 'In Progress',
        type: DeliveryChipType.inProgress,
      );
    } else if (lower.contains('cancel') || lower.contains('fail')) {
      return const DeliveryStatusChip(
        label: 'Cancelled',
        type: DeliveryChipType.cancelled,
      );
    } else if (lower.contains('next') || lower.contains('accept')) {
      return const DeliveryStatusChip(
        label: 'Next',
        type: DeliveryChipType.next,
      );
    } else {
      return const DeliveryStatusChip(
        label: 'Pending',
        type: DeliveryChipType.pending,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (type) {
      case DeliveryChipType.next:
        bg = DeliveryTheme.statusNextBg;
        text = DeliveryTheme.statusNextText;
        break;
      case DeliveryChipType.inProgress:
        bg = DeliveryTheme.statusProgressBg;
        text = DeliveryTheme.statusProgressText;
        break;
      case DeliveryChipType.pending:
        bg = DeliveryTheme.statusPendingBg;
        text = DeliveryTheme.statusPendingText;
        break;
      case DeliveryChipType.delivered:
        bg = DeliveryTheme.statusNextBg;
        text = DeliveryTheme.statusNextText;
        break;
      case DeliveryChipType.cancelled:
        bg = DeliveryTheme.statusCancelledBg;
        text = DeliveryTheme.statusCancelledText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
