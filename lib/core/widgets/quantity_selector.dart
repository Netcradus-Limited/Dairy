import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

/// Quantity Selector Component (- QTY +)
class QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double height;
  final double width;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.height = 36.0,
    this.width = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return SizedBox(
        height: height,
        width: width,
        child: ElevatedButton(
          onPressed: onIncrement,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lightBlue,
            foregroundColor: AppColors.primaryBlue,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p8),
            shape: const RoundedRectangleBorder(
                borderRadius: AppSizes.borderMedium),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ADD',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.add, size: 16, color: AppColors.primaryBlue),
            ],
          ),
        ),
      );
    }

    return Container(
      height: height,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: AppSizes.borderMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              minimumSize: const Size(24, 24),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: const Icon(Icons.remove,
                size: 16, color: AppColors.textOnPrimary),
            onPressed: onDecrement,
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textOnPrimary,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              minimumSize: const Size(24, 24),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon:
                const Icon(Icons.add, size: 16, color: AppColors.textOnPrimary),
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}
