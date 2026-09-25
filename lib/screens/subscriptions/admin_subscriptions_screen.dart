import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/product_image.dart';
import '../../models/customer_model.dart';
import '../../models/subscription.dart';
import '../../providers/admin_provider.dart';
import 'admin_subscription_details_dialog.dart';

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  String _selectedStatusFilter = 'All';
  String _selectedFrequencyFilter = 'All';
  String _localSearch = '';

  final currencyFormatter =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  Color _statusColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return AppColors.freshGreen;
      case SubscriptionStatus.paused:
        return const Color(0xFFD97706);
      case SubscriptionStatus.cancelled:
        return AppColors.error;
    }
  }

  Color _statusBg(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return const Color(0xFFE8FAF2);
      case SubscriptionStatus.paused:
        return const Color(0xFFFEF3C7);
      case SubscriptionStatus.cancelled:
        return const Color(0xFFFEE2E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);

    // Filtered subscriptions list
    final effectiveQuery = _localSearch.trim().isNotEmpty
        ? _localSearch.trim().toLowerCase()
        : provider.searchQuery.trim().toLowerCase();

    final allSubs = provider.subscriptions;

    final filteredSubs = allSubs.where((s) {
      // 1. Status Filter
      if (_selectedStatusFilter != 'All') {
        if (_selectedStatusFilter.toLowerCase() !=
            s.status.label.toLowerCase()) {
          return false;
        }
      }

      // 2. Frequency Filter
      if (_selectedFrequencyFilter != 'All') {
        if (_selectedFrequencyFilter.toLowerCase() !=
            s.frequency.label.toLowerCase()) {
          return false;
        }
      }

      // 3. Search Query
      if (effectiveQuery.isNotEmpty) {
        final cust = provider.getCustomerById(s.userId);
        final custName = (cust?.name ?? '').toLowerCase();
        final custPhone = (cust?.phone ?? '').toLowerCase();
        final productTitle = s.product.title.toLowerCase();
        final subId = s.id.toLowerCase();
        final userId = (s.userId ?? '').toLowerCase();

        final matches = custName.contains(effectiveQuery) ||
            custPhone.contains(effectiveQuery) ||
            productTitle.contains(effectiveQuery) ||
            subId.contains(effectiveQuery) ||
            userId.contains(effectiveQuery);

        if (!matches) return false;
      }

      return true;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscriptions Management',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time oversight of customer subscriptions, recurring deliveries, and monthly revenue.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Error banner (e.g. Permission Denied or Network Failure)
          if (provider.subscriptionsError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF87171)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Firestore Subscription Error',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF991B1B),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.subscriptionsError!,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFB91C1C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Top KPI Summary Cards Grid
          _buildKpiSummaryGrid(context, provider, isDesktop),
          const SizedBox(height: 20),

          // Filter & Search Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar + Status Filter Pills
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _localSearch = v),
                        style: TextStyle(color: textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText:
                              'Search by customer, phone, product, or ID...',
                          hintStyle: TextStyle(color: textMuted, fontSize: 13),
                          prefixIcon: Icon(Icons.search,
                              size: 18, color: textSecondary),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: AppColors.bgOf(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Filter Chips & Frequency Filter Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Status:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                    ...['All', 'Active', 'Paused', 'Cancelled'].map((status) {
                      final isSelected = _selectedStatusFilter == status;
                      return ChoiceChip(
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedStatusFilter = status);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : textPrimary,
                        ),
                        backgroundColor: AppColors.bgOf(context),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : cardBorder,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      'Frequency:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                    ...['All', 'Daily', 'Alternate Day', 'Weekly'].map((freq) {
                      final isSelected = _selectedFrequencyFilter == freq;
                      return ChoiceChip(
                        label: Text(freq),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedFrequencyFilter = freq);
                        },
                        selectedColor: Colors.teal,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : textPrimary,
                        ),
                        backgroundColor: AppColors.bgOf(context),
                        side: BorderSide(
                          color: isSelected ? Colors.teal : cardBorder,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Subscriptions List Card / Table
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: provider.subscriptionsLoading && allSubs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : filteredSubs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 48.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 48,
                                color: textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                effectiveQuery.isNotEmpty ||
                                        _selectedStatusFilter != 'All' ||
                                        _selectedFrequencyFilter != 'All'
                                    ? 'No subscriptions match your current filter criteria.'
                                    : 'No customer subscriptions found in Firestore.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Customer subscriptions created via the app will automatically appear here in real time.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : isDesktop
                        ? _buildDesktopTable(
                            context, provider, filteredSubs, cardBorder)
                        : _buildMobileCards(
                            context, provider, filteredSubs, cardBorder),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryGrid(
      BuildContext context, AdminProvider provider, bool isDesktop) {
    final kpis = [
      _KpiData(
        title: 'Total Subscriptions',
        value: '${provider.totalSubscriptionsCount}',
        subtitle: 'All customer recurring orders',
        icon: Icons.calendar_month_rounded,
        color: AppColors.primary,
        bgColor: const Color(0xFFEAF5FF),
      ),
      _KpiData(
        title: 'Active Subscriptions',
        value: '${provider.activeSubscriptionsCount}',
        subtitle: 'Generating active deliveries',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.freshGreen,
        bgColor: const Color(0xFFE8FAF2),
      ),
      _KpiData(
        title: 'Paused Subscriptions',
        value: '${provider.pausedSubscriptionsCount}',
        subtitle: 'Temporarily on hold',
        icon: Icons.pause_circle_outline_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFEF3C7),
      ),
      _KpiData(
        title: 'Cancelled',
        value: '${provider.cancelledSubscriptionsCount}',
        subtitle: 'Discontinued subscriptions',
        icon: Icons.cancel_outlined,
        color: AppColors.error,
        bgColor: const Color(0xFFFEE2E2),
      ),
      _KpiData(
        title: "Today's Deliveries",
        value: '${provider.todaySubscriptionDeliveriesCount}',
        subtitle: 'Scheduled for today',
        icon: Icons.local_shipping_outlined,
        color: Colors.deepPurple,
        bgColor: const Color(0xFFF3E8FF),
      ),
      _KpiData(
        title: 'Est. Monthly Revenue',
        value: currencyFormatter
            .format(provider.estimatedMonthlySubscriptionRevenue),
        subtitle: 'From active subscribers',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.revenueGreen,
        bgColor: const Color(0xFFE6F4EA),
      ),
    ];

    return LayoutBuilder(builder: (ctx, constraints) {
      final crossAxisCount =
          isDesktop ? 3 : (constraints.maxWidth > 520 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: kpis.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: 100,
        ),
        itemBuilder: (ctx, i) {
          final k = kpis[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBgOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorderOf(context)),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: k.bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(k.icon, color: k.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        k.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        k.value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        k.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.textMutedOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildDesktopTable(BuildContext context, AdminProvider provider,
      List<Subscription> subs, Color cardBorder) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subs.length,
      separatorBuilder: (ctx, i) => Divider(height: 1, color: cardBorder),
      itemBuilder: (ctx, i) {
        final sub = subs[i];
        final DairyCustomer? cust = provider.getCustomerById(sub.userId);
        final statusColor = _statusColor(sub.status);
        final statusBgColor = _statusBg(sub.status);

        return InkWell(
          onTap: () => AdminSubscriptionDetailsDialog.show(context, sub),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                // Product Image & Info
                ProductImage(
                  imageUrl: sub.product.imageUrl,
                  categoryKey: sub.product.categoryId,
                  title: sub.product.title,
                  size: 42,
                  radius: 8,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.product.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Product size: ${sub.product.unit.isNotEmpty ? sub.product.unit : "1 pc"} • ID: ${sub.id}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Customer Info
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cust?.name.isNotEmpty == true
                            ? cust!.name
                            : (sub.userId ?? 'Customer'),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cust?.phone.isNotEmpty == true
                            ? cust!.phone
                            : (sub.userId ?? '—'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quantity & Frequency
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quantity: ${sub.quantity}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub.frequency.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Schedule (Slot & Next Delivery)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.deliveryTimeSlot,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub.nextDeliveryDate != null
                            ? 'Next: ${DateFormat('dd MMM yyyy').format(sub.nextDeliveryDate!)}'
                            : 'Next: —',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Price per delivery & Monthly
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${sub.priceAfterDiscountPerDelivery.toStringAsFixed(0)} / del',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '₹${sub.monthlyCost.toStringAsFixed(0)} / mo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    sub.status.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Quick Action View
                IconButton(
                  onPressed: () =>
                      AdminSubscriptionDetailsDialog.show(context, sub),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  color: textSecondary,
                  tooltip: 'View Details',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCards(BuildContext context, AdminProvider provider,
      List<Subscription> subs, Color cardBorder) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subs.length,
      separatorBuilder: (ctx, i) => Divider(height: 1, color: cardBorder),
      itemBuilder: (ctx, i) {
        final sub = subs[i];
        final DairyCustomer? cust = provider.getCustomerById(sub.userId);
        final statusColor = _statusColor(sub.status);
        final statusBgColor = _statusBg(sub.status);

        return InkWell(
          onTap: () => AdminSubscriptionDetailsDialog.show(context, sub),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Product + Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductImage(
                      imageUrl: sub.product.imageUrl,
                      categoryKey: sub.product.categoryId,
                      title: sub.product.title,
                      size: 44,
                      radius: 8,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.product.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Product size: ${sub.product.unit.isNotEmpty ? sub.product.unit : "1 pc"}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        sub.status.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Customer Info Row
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      cust?.name.isNotEmpty == true
                          ? cust!.name
                          : (sub.userId ?? 'Customer'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    if (cust?.phone.isNotEmpty == true) ...[
                      Text(' • ', style: TextStyle(color: textMuted)),
                      Text(
                        cust!.phone,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Configuration Row
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Quantity: ${sub.quantity}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Frequency: ${sub.frequency.label}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                    ),
                    Text(
                      'Slot: ${sub.deliveryTimeSlot}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Schedule & Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sub.nextDeliveryDate != null
                          ? 'Next: ${DateFormat('dd MMM yyyy').format(sub.nextDeliveryDate!)}'
                          : 'Next: —',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: textMuted,
                      ),
                    ),
                    Text(
                      '₹${sub.priceAfterDiscountPerDelivery.toStringAsFixed(0)} / delivery',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
