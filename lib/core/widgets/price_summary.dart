import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../localization/app_language.dart';

/// Price Summary Card Widget for Cart & Checkout Screens
class PriceSummaryCard extends StatelessWidget {
  final double subtotal;
  final double deliveryCharge;
  final double discount;
  final double grandTotal;
  final VoidCallback? onActionButtonPressed;
  final String actionButtonText;
  final bool showActionButton;

  const PriceSummaryCard({
    super.key,
    required this.subtotal,
    required this.deliveryCharge,
    required this.discount,
    required this.grandTotal,
    this.onActionButtonPressed,
    this.actionButtonText = 'Proceed to Checkout',
    this.showActionButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Order Bill Summary'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.p14),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.p14),

          // Subtotal
          _SummaryRow(
            label: tr('Item Subtotal'),
            value: '₹${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSizes.p8),

          // Delivery Charge
          _SummaryRow(
            label: tr('Delivery Charge'),
            value: deliveryCharge == 0.0
                ? tr('FREE')
                : '₹${deliveryCharge.toStringAsFixed(2)}',
            valueColor: deliveryCharge == 0.0
                ? AppColors.freshGreen
                : AppColors.textPrimary,
          ),
          const SizedBox(height: AppSizes.p8),

          // Discount if applicable
          if (discount > 0) ...[
            _SummaryRow(
              label: tr('Special Offer Discount (10%)'),
              value: '-₹${discount.toStringAsFixed(2)}',
              valueColor: AppColors.freshGreen,
            ),
            const SizedBox(height: AppSizes.p8),
          ],

          // Free Delivery Banner hint if subtotal < 500
          if (subtotal > 0 && subtotal < 500) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: AppSizes.borderSmall,
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '₹${(500 - subtotal).toStringAsFixed(0)} ${tr('more for FREE delivery!')}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p8),
          ],

          const Divider(height: 1),
          const SizedBox(height: AppSizes.p12),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tr('Grand Total'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),

          if (showActionButton) ...[
            const SizedBox(height: AppSizes.p16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onActionButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSizes.borderMedium,
                  ),
                  elevation: 2,
                ),
                child: Text(
                  tr(actionButtonText),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
