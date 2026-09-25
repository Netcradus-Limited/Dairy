import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/battery_optimization_provider.dart';

/// Clean, colorful, responsive, non-blocking warning banner displayed in the
/// Delivery Panel when Android battery optimizations may throttle continuous
/// background GPS tracking.
class BatteryOptimizationWarningBanner extends ConsumerWidget {
  const BatteryOptimizationWarningBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteryState = ref.watch(batteryOptimizationProvider);

    if (!batteryState.shouldShowWarning) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const warningColor = Color(0xFFD97706);
    final bgColor = isDark ? const Color(0xFF291B07) : const Color(0xFFFFFBEB);
    final borderColor =
        isDark ? const Color(0xFF5E3A06) : const Color(0xFFFDE68A);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          final iconWidget = Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: warningColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.battery_alert_rounded,
              size: 20,
              color: warningColor,
            ),
          );

          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Background Location Warning',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Battery optimization may limit background location. For reliable delivery tracking, allow unrestricted background usage for Sawariya Dairy.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? const Color(0xFFF3F4F6) : AppColors.textPrimary,
                ),
              ),
            ],
          );

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () {
                  ref.read(batteryOptimizationProvider.notifier).fixSettings();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: warningColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.settings_outlined, size: 14),
                label: Text(
                  'Fix Battery Settings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss',
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  ref.read(batteryOptimizationProvider.notifier).dismiss();
                },
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconWidget,
                    const SizedBox(width: 10),
                    Expanded(child: textContent),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Dismiss',
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        ref
                            .read(batteryOptimizationProvider.notifier)
                            .dismiss();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(batteryOptimizationProvider.notifier)
                          .fixSettings();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: warningColor,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 14),
                    label: Text(
                      'Fix Battery Settings',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 10),
              Expanded(child: textContent),
              const SizedBox(width: 10),
              actionButtons,
            ],
          );
        },
      ),
    );
  }
}
