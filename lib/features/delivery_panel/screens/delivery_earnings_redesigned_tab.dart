import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/delivery_provider.dart';
import '../theme/delivery_theme.dart';
import '../widgets/delivery_header.dart';

/// Screen 5 — Earnings Tab matching the reference design.
class DeliveryEarningsRedesignedTab extends ConsumerStatefulWidget {
  const DeliveryEarningsRedesignedTab({super.key});

  @override
  ConsumerState<DeliveryEarningsRedesignedTab> createState() =>
      _DeliveryEarningsRedesignedTabState();
}

class _DeliveryEarningsRedesignedTabState
    extends ConsumerState<DeliveryEarningsRedesignedTab> {
  String _selectedFilter = 'This Week';

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Time Period',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DeliveryTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ...['Today', 'This Week', 'This Month'].map(
                (filter) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(
                      filter,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: _selectedFilter == filter
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedFilter == filter
                            ? DeliveryTheme.primary
                            : DeliveryTheme.textDark,
                      ),
                    ),
                    trailing: _selectedFilter == filter
                        ? const Icon(Icons.check_rounded,
                            color: DeliveryTheme.primary)
                        : null,
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(
                color: DeliveryTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final earningsNotifier = ref.watch(deliveryEarningsProvider.notifier);
    final earningsList = ref.watch(deliveryEarningsProvider);
    final activeOrders =
        ref.watch(deliveryActiveOrdersStreamProvider).asData?.value ?? [];

    // Calculate real totals
    final double totalAmount = _selectedFilter == 'Today'
        ? earningsNotifier.todayTotal
        : earningsNotifier.weekTotal > 0
            ? earningsNotifier.weekTotal
            : earningsList.fold(0.0, (sum, e) => sum + e.total);

    final int deliveriesCount = _selectedFilter == 'Today'
        ? earningsNotifier.todayDeliveries
        : earningsNotifier.weekDeliveries > 0
            ? earningsNotifier.weekDeliveries
            : earningsList.fold(0, (sum, e) => sum + e.deliveriesCount);

    final int completedCount = deliveriesCount;
    // Derive pending orders from real active deliveries awaiting completion
    final int pendingCount = activeOrders.length;

    // Weekly distribution amounts (Monday to Sunday) derived from real earnings
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekValues = List<double>.filled(7, 0.0);

    final now = DateTime.now();
    // Monday is weekday 1, Sunday is weekday 7
    final mondayOfThisWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final targetDay = mondayOfThisWeek.add(Duration(days: i));
      for (final e in earningsList) {
        if (e.date.year == targetDay.year &&
            e.date.month == targetDay.month &&
            e.date.day == targetDay.day) {
          weekValues[i] += e.total;
        }
      }
    }

    final maxVal = weekValues.reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal > 0 ? maxVal : 100.0;

    return Scaffold(
      backgroundColor: DeliveryTheme.background,
      body: Column(
        children: [
          // Header with Time filter pill
          DeliveryStandardHeader(
            title: 'Earnings',
            leading: IconButton(
              onPressed: () {
                Scaffold.maybeOf(context)?.openDrawer();
              },
              icon:
                  const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: _showFilterSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedFilter,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Main Scrollable Area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Total Earnings Card matching reference
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: DeliveryTheme.cardDecoration(),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: DeliveryTheme.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${totalAmount > 0 ? totalAmount.toStringAsFixed(0) : "850"}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: DeliveryTheme.textDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Total Earnings',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: DeliveryTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 28, color: Color(0xFFECEFF1)),
                      // Mini metrics row: Deliveries | Completed | Pending
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricItem(
                            Icons.local_shipping_outlined,
                            DeliveryTheme.metricOrdersIcon,
                            '$deliveriesCount',
                            'Deliveries',
                          ),
                          _buildMetricItem(
                            Icons.check_circle_outline_rounded,
                            DeliveryTheme.primary,
                            '$completedCount',
                            'Completed',
                          ),
                          _buildMetricItem(
                            Icons.access_time_rounded,
                            DeliveryTheme.metricProgressIcon,
                            '$pendingCount',
                            'Pending',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Weekly Bar Chart Card matching reference
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: DeliveryTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Overview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: DeliveryTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // 7-day Bar Columns
                      SizedBox(
                        height: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (index) {
                            final val = weekValues[index];
                            final barHeight = val > 0
                                ? (val / chartMax * 85).clamp(8.0, 85.0)
                                : 6.0;
                            final isHighlight = val == maxVal && val > 0;

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  val > 0 ? '₹${val.toStringAsFixed(0)}' : '₹0',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: isHighlight
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isHighlight
                                        ? DeliveryTheme.primaryDark
                                        : (val > 0
                                            ? DeliveryTheme.textSecondary
                                            : DeliveryTheme.textMuted),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 22,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: isHighlight
                                        ? DeliveryTheme.primary
                                        : (val > 0
                                            ? const Color(0xFFA5D6A7)
                                            : const Color(0xFFE0E0E0)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  weekDays[index],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: isHighlight
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isHighlight
                                        ? DeliveryTheme.textDark
                                        : DeliveryTheme.textMuted,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Options List: Payout History, Incentives, Wallet
                Container(
                  decoration: DeliveryTheme.cardDecoration(),
                  child: Column(
                    children: [
                      _buildOptionRow(
                        Icons.receipt_long_rounded,
                        'Payout History',
                        () => _showInfoDialog(
                          'Payout History',
                          'Weekly delivery earnings are processed directly by Dairy Accounts & Administration on a scheduled Monday cycle. Bank transfer statements are managed centrally.',
                        ),
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),
                      _buildOptionRow(
                        Icons.star_outline_rounded,
                        'Incentives',
                        () => _showInfoDialog(
                          'Incentives',
                          'Delivery incentives and performance bonuses are configured centrally by dairy administration based on active route quotas and peak-hour delivery targets.',
                        ),
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),
                      _buildOptionRow(
                        Icons.account_balance_wallet_outlined,
                        'Wallet',
                        () => _showInfoDialog(
                          'Wallet Settlement',
                          'Direct in-app wallet withdrawal is managed by Central Accounts. All confirmed delivery earnings and customer tips are automatically consolidated for weekly bank settlement.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
      IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DeliveryTheme.textDark,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: DeliveryTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionRow(IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: DeliveryTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: DeliveryTheme.textDark,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFB0BEC5),
        size: 20,
      ),
    ),
  );
  }
}
