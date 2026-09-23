import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';

class OrderStatusDonutChart extends StatefulWidget {
  const OrderStatusDonutChart({super.key});

  @override
  State<OrderStatusDonutChart> createState() => _OrderStatusDonutChartState();
}

class _OrderStatusDonutChartState extends State<OrderStatusDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);

    final pendingCount = provider.pendingOrdersCount;
    final confirmedCount = provider.confirmedOrdersCount;
    final preparingCount = provider.preparingOrdersCount;
    final outForDeliveryCount = provider.outForDeliveryOrdersCount;
    final deliveredCount = provider.deliveredOrdersCount;
    final cancelledCount = provider.cancelledOrdersCount;
    final totalOrders = provider.totalOrdersCount;

    final sectionsData = [
      {
        'label': 'Pending',
        'value': pendingCount,
        'color': AppColors.statusPending
      },
      {
        'label': 'Confirmed',
        'value': confirmedCount,
        'color': AppColors.statusConfirmed
      },
      {
        'label': 'Preparing',
        'value': preparingCount,
        'color': AppColors.statusPreparing
      },
      {
        'label': 'Out for Delivery',
        'value': outForDeliveryCount,
        'color': AppColors.statusOutForDelivery
      },
      {
        'label': 'Delivered',
        'value': deliveredCount,
        'color': AppColors.statusDelivered
      },
      {
        'label': 'Cancelled',
        'value': cancelledCount,
        'color': AppColors.statusCancelled
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Orders Status',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkBackground : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: provider.orderStatusTimeFilter,
                    dropdownColor: cardBg,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: textSecondary),
                    isDense: true,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
                      DropdownMenuItem(
                          value: 'Yesterday', child: Text('Yesterday')),
                      DropdownMenuItem(
                          value: 'Tomorrow', child: Text('Tomorrow')),
                    ],
                    onChanged: (val) {
                      if (val != null) provider.setOrderStatusTimeFilter(val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart & Legend Area
          Expanded(
            child: Row(
              children: [
                // Donut Chart with Center Text
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  touchedIndex = -1;
                                  return;
                                }
                                touchedIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          sections: totalOrders == 0
                              ? [
                                  PieChartSectionData(
                                    color: cardBorder,
                                    value: 1,
                                    title: '',
                                    radius: 18.0,
                                  ),
                                ]
                              : List.generate(sectionsData.length, (i) {
                                  final isTouched = i == touchedIndex;
                                  final radius = isTouched ? 22.0 : 18.0;
                                  final data = sectionsData[i];
                                  final val = data['value'] as int;

                                  return PieChartSectionData(
                                    color: data['color'] as Color,
                                    value: val > 0 ? val.toDouble() : 0.001,
                                    title: '',
                                    radius: radius,
                                  );
                                }),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalOrders',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Total',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Legend
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: sectionsData.map((item) {
                      final color = item['color'] as Color;
                      final label = item['label'] as String;
                      final count = item['value'] as int;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$count',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
