import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_badge.dart';

class DeliveryManagementScreen extends StatelessWidget {
  const DeliveryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);
    final dividerColor = AppColors.dividerOf(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Routes & Dispatch',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          Text(
            'Monitor morning milk batches (5:00 AM - 7:00 AM) and evening supply corridors.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          // Today's Delivery Progress Overview
          Text(
            "Today's Delivery Progress",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTodaysProgressCard(
            context,
            isDesktop,
            provider,
            cardBg,
            cardBorder,
            textPrimary,
            textSecondary,
            textMuted,
          ),
          const SizedBox(height: 24),
          // Corridor Cards
          Text(
            'Active Delivery Corridors',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          if (provider.corridorsLoading && provider.corridors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            )
          else if (provider.corridorsError != null &&
              provider.corridors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.corridorsError!,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (provider.corridors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined, size: 36, color: textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'No active delivery corridors registered yet.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Corridors will appear automatically as delivery staff and customer zones are added.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.corridors.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 2 : 1,
                mainAxisExtent: 140,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (ctx, idx) {
                final corridor = provider.corridors[idx];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              corridor.routeName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryLight.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${corridor.subscribersCount} Subscriptions',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              corridor.zone,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.electric_moped_outlined,
                              size: 16, color: textMuted),
                          const SizedBox(width: 4),
                          Text(
                            corridor.vehicleType,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 16, color: textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Rider: ${corridor.riderName}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            corridor.timing,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.revenueGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          // Batch Progress Table
          Text(
            "Today's Batch Deliveries Progress",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          if (provider.deliveryBatchesLoading &&
              provider.deliveryBatches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            )
          else if (provider.deliveryBatchesError != null &&
              provider.deliveryBatches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.deliveryBatchesError!,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (provider.deliveryBatches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 36, color: textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'No delivery batches dispatched today.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active dispatch batches will appear here as orders are assigned to delivery partners.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.deliveryBatches.length,
                separatorBuilder: (ctx, idx) => Divider(color: dividerColor),
                itemBuilder: (ctx, idx) {
                  final batch = provider.deliveryBatches[idx];
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            batch.deliveryId,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch.staffName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                batch.zone,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${batch.completedCount} / ${batch.assignedCount} Delivered',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${(batch.completionPercentage * 100).toInt()}%',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: batch.completionPercentage,
                                backgroundColor: cardBorder,
                                color: batch.completionPercentage >= 1.0
                                    ? AppColors.revenueGreen
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        StatusBadge.fromString(batch.status),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTodaysProgressCard(
    BuildContext context,
    bool isDesktop,
    AdminProvider provider,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (provider.todaysDeliveryProgressLoading && provider.orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
          boxShadow: AppColors.cardShadow,
        ),
        child: const CircularProgressIndicator(),
      );
    }

    if (provider.todaysDeliveryProgressError != null &&
        provider.orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                provider.todaysDeliveryProgressError!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final progress = provider.todaysDeliveryProgress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Real-Time Dispatch Status',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${progress.completed} of ${progress.total} deliveries fulfilled',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (progress.completionPercentage >= 100.0 &&
                          progress.total > 0)
                      ? AppColors.revenueGreen.withValues(alpha: 0.15)
                      : AppColors.primaryLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${progress.completionPercentage.toInt()}% Completed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: (progress.completionPercentage >= 100.0 &&
                            progress.total > 0)
                        ? AppColors.revenueGreen
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress.progressFraction,
            backgroundColor: cardBorder,
            color: (progress.completionPercentage >= 100.0 && progress.total > 0)
                ? AppColors.revenueGreen
                : AppColors.primary,
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 18),
          // KPI Metric Items
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                      child: _buildProgressMetric(
                        label: 'Total Orders',
                        value: '${progress.total}',
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.ordersBlue,
                        bgColor: AppColors.ordersBlueBg,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        label: 'Delivered',
                        value: '${progress.completed}',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.statusDelivered,
                        bgColor: const Color(0xFFE8FAF2),
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        label: 'Pending',
                        value: '${progress.pending}',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.statusPending,
                        bgColor: const Color(0xFFFFF4EC),
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        label: 'Cancelled',
                        value: '${progress.cancelled}',
                        icon: Icons.cancel_outlined,
                        color: AppColors.statusCancelled,
                        bgColor: const Color(0xFFF1F5F9),
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildResponsiveMetricItem(
                      context: context,
                      label: 'Total Orders',
                      value: '${progress.total}',
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.ordersBlue,
                      bgColor: AppColors.ordersBlueBg,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                    _buildResponsiveMetricItem(
                      context: context,
                      label: 'Delivered',
                      value: '${progress.completed}',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.statusDelivered,
                      bgColor: const Color(0xFFE8FAF2),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                    _buildResponsiveMetricItem(
                      context: context,
                      label: 'Pending',
                      value: '${progress.pending}',
                      icon: Icons.pending_actions_rounded,
                      color: AppColors.statusPending,
                      bgColor: const Color(0xFFFFF4EC),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                    _buildResponsiveMetricItem(
                      context: context,
                      label: 'Cancelled',
                      value: '${progress.cancelled}',
                      icon: Icons.cancel_outlined,
                      color: AppColors.statusCancelled,
                      bgColor: const Color(0xFFF1F5F9),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                  ],
                ),
          if (progress.total == 0 && progress.cancelled == 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: textMuted),
                const SizedBox(width: 6),
                Text(
                  'No deliveries scheduled for today yet.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveMetricItem({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final cardWidth = (screenWidth - 32 - 40 - 10) / 2;
        return SizedBox(
          width: cardWidth > 130 ? cardWidth : 130,
          child: _buildProgressMetric(
            label: label,
            value: value,
            icon: icon,
            color: color,
            bgColor: bgColor,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
        );
      },
    );
  }
}
