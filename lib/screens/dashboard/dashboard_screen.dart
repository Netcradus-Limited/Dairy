import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/kpi_data.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/charts/order_status_donut_chart.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/top_selling_products_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title: Business Overview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Overview',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time business performance, customer growth, and order lifecycle metrics.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.ordersLoading || provider.usersLoading) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Primary KPIs Row (Revenue, Total Orders, Customers, Delivery Fleet)
          _buildKpiGrid(context, provider.kpiMetrics, isDesktop, isTablet),
          const SizedBox(height: 16),

          // Order Status Lifecycle KPIs Row (Active/On Route, Pending, Delivered, Cancelled)
          _buildKpiGrid(context, provider.orderStatusKpis, isDesktop, isTablet),
          const SizedBox(height: 20),

          // Middle Section: Charts & Top Selling Products
          _buildMiddleSection(context, isDesktop),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(
    BuildContext context,
    List<KpiMetric> metrics,
    bool isDesktop,
    bool isTablet,
  ) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    if (isDesktop) {
      return Row(
        children: metrics.map((metric) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: KpiCard(metric: metric),
            ),
          );
        }).toList(),
      );
    } else if (isTablet) {
      // 2 x 2 grid for tablet
      final rows = <Widget>[];
      for (int i = 0; i < metrics.length; i += 2) {
        final first = metrics[i];
        final second = (i + 1 < metrics.length) ? metrics[i + 1] : null;

        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(child: KpiCard(metric: first)),
                const SizedBox(width: 12),
                Expanded(
                  child: second != null
                      ? KpiCard(metric: second)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
      return Column(children: rows);
    } else {
      // Mobile Column
      return Column(
        children: metrics.map((metric) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: KpiCard(metric: metric),
          );
        }).toList(),
      );
    }
  }

  Widget _buildMiddleSection(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      return const IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: OrderStatusDonutChart(),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: TopSellingProductsCard(),
            ),
          ],
        ),
      );
    } else {
      // Stack for tablet and mobile
      return const Column(
        children: [
          SizedBox(height: 320, child: OrderStatusDonutChart()),
          SizedBox(height: 16),
          TopSellingProductsCard(),
        ],
      );
    }
  }
}
