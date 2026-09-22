import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../localization/app_language.dart';

enum PaymentMethodType { cashOnDelivery }

/// Payment Method Display Tile (Cash on Delivery)
class PaymentOptionTile extends StatelessWidget {
  final PaymentMethodType method;
  final PaymentMethodType selectedMethod;
  final ValueChanged<PaymentMethodType>? onSelected;

  const PaymentOptionTile({
    super.key,
    required this.method,
    required this.selectedMethod,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = method == selectedMethod;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.lightBlue : AppColors.surface,
        borderRadius: AppSizes.borderMedium,
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : AppColors.border,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onSelected != null ? () => onSelected!(method) : null,
        borderRadius: AppSizes.borderMedium,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p14),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
                    width: isSelected ? 6 : 2,
                  ),
                ),
              ),
              const Icon(
                Icons.payments_rounded,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Cash on Delivery (COD)'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('Pay cash or UPI upon fresh delivery at your doorstep'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
