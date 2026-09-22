import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../../models/address.dart';

/// Address Tile for Address List & Checkout Screen
class AddressTile extends StatelessWidget {
  final Address address;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onSetDefault;

  const AddressTile({
    super.key,
    required this.address,
    required this.isSelected,
    required this.onSelect,
    this.onDelete,
    this.onEdit,
    this.onSetDefault,
  });

  IconData _getIconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('home')) {
      return Icons.home_outlined;
    } else if (l.contains('work') || l.contains('office')) {
      return Icons.business_center_outlined;
    }
    return Icons.location_on_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: address.isDefault
              ? AppColors.primaryBlue
              : const Color(0xFFE2E8F0),
          width: address.isDefault ? 1.8 : 1.0,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;

              final headerBadges = Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    address.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (address.hasCoordinates)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AppColors.freshGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gps_fixed_rounded,
                            size: 10,
                            color: AppColors.freshGreen,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'GPS Pin',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.freshGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2DD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: AppColors.primaryBlue,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );

              final actionButtons = [
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Edit Address',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                if (onSetDefault != null)
                  TextButton(
                    onPressed: address.isDefault ? null : onSetDefault,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Make Default',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: address.isDefault
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                if (onDelete != null)
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            _getIconForLabel(address.label),
                            size: 22,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: headerBadges),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        children: [
                          const TextSpan(
                            text: 'Recipient: ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          TextSpan(text: address.fullName),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4),
                        children: [
                          const TextSpan(
                            text: 'Full Address: ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          TextSpan(text: address.fullAddressText),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        children: [
                          const TextSpan(
                            text: 'Phone Number: ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          TextSpan(text: address.mobileNumber),
                        ],
                      ),
                    ),
                    if (actionButtons.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: actionButtons,
                      ),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _getIconForLabel(address.label),
                      size: 24,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerBadges,
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textSecondary),
                            children: [
                              const TextSpan(
                                text: 'Recipient: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              TextSpan(text: address.fullName),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.4),
                            children: [
                              const TextSpan(
                                text: 'Full Address: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              TextSpan(text: address.fullAddressText),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textSecondary),
                            children: [
                              const TextSpan(
                                text: 'Phone Number: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              TextSpan(text: address.mobileNumber),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: actionButtons
                        .map((btn) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: btn,
                            ))
                        .toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
