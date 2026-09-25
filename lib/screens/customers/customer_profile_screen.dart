import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/product_image.dart';
import '../../models/customer_delivery_record.dart';
import '../../models/customer_model.dart';
import '../../models/order.dart';
import '../../models/payment_model.dart';
import '../../models/subscription.dart';
import '../../providers/admin_provider.dart';
import '../../services/customer_profile_service.dart';
import '../../widgets/status_badge.dart';

/// Complete Responsive Customer Profile Screen for Sawariya Dairy Admin Panel.
/// Provides real-time insights into Today, Tomorrow, Purchase History, Subscriptions, and Ledger.
class CustomerProfileScreen extends StatefulWidget {
  final DairyCustomer customer;
  final CustomerProfileService? service;

  const CustomerProfileScreen({
    super.key,
    required this.customer,
    this.service,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  late final CustomerProfileService _service;
  late final TabController _tabController;

  // Streams
  Stream<List<Order>>? _ordersStream;
  Stream<List<DairyPayment>>? _paymentsStream;
  Stream<Subscription?>? _subscriptionStream;
  Stream<List<DateTime>>? _skippedDatesStream;
  Stream<List<CustomerDeliveryRecord>>? _deliveryRecordsStream;

  // History tab filters
  String _historyFilter =
      'All'; // All, Today, Yesterday, This Week, This Month, Custom
  DateTime? _selectedSingleDate;
  DateTimeRange? _customDateRange;
  bool _sortNewestFirst = true;
  String _historySearchQuery = '';

  final currencyFormatter =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CustomerProfileService();
    _tabController = TabController(length: 5, vsync: this);
    _initStreams();
  }

  void _initStreams() {
    final uid = widget.customer.id;
    _ordersStream = _service.streamCustomerOrders(uid);
    _paymentsStream = _service.streamCustomerPayments(uid);
    _subscriptionStream = _service.streamCustomerSubscription(uid);
    _skippedDatesStream = _service.streamSkippedDates(uid);
    _deliveryRecordsStream = _service.streamDeliveryRecords(uid);
  }

  @override
  void didUpdateWidget(covariant CustomerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer.id != widget.customer.id) {
      _initStreams();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final adminProv = context.read<AdminProvider>();

    return StreamBuilder<List<Order>>(
      stream: _ordersStream,
      builder: (context, ordersSnap) {
        return StreamBuilder<Subscription?>(
          stream: _subscriptionStream,
          builder: (context, subSnap) {
            return StreamBuilder<List<DateTime>>(
              stream: _skippedDatesStream,
              builder: (context, skipSnap) {
                return StreamBuilder<List<DairyPayment>>(
                  stream: _paymentsStream,
                  builder: (context, paySnap) {
                    return StreamBuilder<List<CustomerDeliveryRecord>>(
                      stream: _deliveryRecordsStream,
                      builder: (context, recordsSnap) {
                        final orders = ordersSnap.data ?? [];
                        final subscription = subSnap.data;
                        final skippedDates = skipSnap.data ?? [];
                        final customRecords = recordsSnap.data ?? [];
                        final payments = paySnap.data ?? [];

                        final todaysDeliveries = _service.getTodaysDeliveries(
                          customerId: widget.customer.id,
                          orders: orders,
                          subscription: subscription,
                          skippedDates: skippedDates,
                          customRecords: customRecords,
                        );

                        final tomorrowsDeliveries =
                            _service.getTomorrowsDeliveries(
                          customerId: widget.customer.id,
                          orders: orders,
                          subscription: subscription,
                          skippedDates: skippedDates,
                          customRecords: customRecords,
                        );

                        final monthlyDeliveredTotal =
                            _service.getMonthlyDeliveredTotal(
                          customerId: widget.customer.id,
                          orders: orders,
                          subscription: subscription,
                          skippedDates: skippedDates,
                          customRecords: customRecords,
                        );

                        final ledger = _service.computeLedgerSummary(
                          customer: widget.customer,
                          orders: orders,
                          payments: payments,
                          monthlyDeliveredAmount: monthlyDeliveredTotal,
                        );

                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 28 : 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Navigation Back Button & Header
                              _buildHeader(
                                context,
                                adminProv,
                                textPrimary,
                                textSecondary,
                                cardBg,
                                cardBorder,
                                isDesktop,
                              ),
                              const SizedBox(height: 16),

                              // 2. Summary Metric KPI Cards
                              _buildSummaryCards(
                                context,
                                todaysDeliveries,
                                tomorrowsDeliveries,
                                monthlyDeliveredTotal,
                                ledger.pendingAmount,
                                isDesktop,
                                cardBg,
                                cardBorder,
                                textPrimary,
                                textSecondary,
                              ),
                              const SizedBox(height: 20),

                              // 3. Main Tabs Container
                              Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder),
                                  boxShadow: AppColors.cardShadow,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Tab Bar
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: cardBorder),
                                        ),
                                      ),
                                      child: TabBar(
                                        controller: _tabController,
                                        isScrollable: !isDesktop,
                                        labelColor: AppColors.primary,
                                        unselectedLabelColor: textSecondary,
                                        indicatorColor: AppColors.primary,
                                        indicatorWeight: 3,
                                        labelStyle: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        unselectedLabelStyle:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        tabs: const [
                                          Tab(
                                            icon: Icon(Icons.today_rounded,
                                                size: 18),
                                            text: 'Today',
                                          ),
                                          Tab(
                                            icon: Icon(
                                                Icons.event_available_rounded,
                                                size: 18),
                                            text: 'Tomorrow',
                                          ),
                                          Tab(
                                            icon: Icon(Icons.history_rounded,
                                                size: 18),
                                            text: 'Purchase History',
                                          ),
                                          Tab(
                                            icon: Icon(Icons.autorenew_rounded,
                                                size: 18),
                                            text: 'Subscription',
                                          ),
                                          Tab(
                                            icon: Icon(
                                                Icons
                                                    .account_balance_wallet_outlined,
                                                size: 18),
                                            text: 'Payments',
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Tab Views
                                    SizedBox(
                                      height: 650,
                                      child: TabBarView(
                                        controller: _tabController,
                                        children: [
                                          // Tab 1: Today
                                          _buildTodayTab(
                                            context,
                                            todaysDeliveries,
                                            cardBorder,
                                            textPrimary,
                                            textSecondary,
                                          ),
                                          // Tab 2: Tomorrow
                                          _buildTomorrowTab(
                                            context,
                                            tomorrowsDeliveries,
                                            cardBorder,
                                            textPrimary,
                                            textSecondary,
                                          ),
                                          // Tab 3: Purchase History
                                          _buildPurchaseHistoryTab(
                                            context,
                                            orders,
                                            subscription,
                                            skippedDates,
                                            customRecords,
                                            cardBorder,
                                            textPrimary,
                                            textSecondary,
                                            isDesktop,
                                          ),
                                          // Tab 4: Subscription
                                          _buildSubscriptionTab(
                                            context,
                                            subscription,
                                            skippedDates,
                                            cardBorder,
                                            textPrimary,
                                            textSecondary,
                                            isDesktop,
                                          ),
                                          // Tab 5: Payments
                                          _buildPaymentsTab(
                                            context,
                                            payments,
                                            ledger,
                                            cardBorder,
                                            textPrimary,
                                            textSecondary,
                                            isDesktop,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. HEADER COMPONENT
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
      child: (widget.customer.profileImageUrl != null &&
              widget.customer.profileImageUrl!.trim().isNotEmpty &&
              (widget.customer.profileImageUrl!.startsWith('http://') ||
                  widget.customer.profileImageUrl!.startsWith('https://')))
          ? ClipOval(
              child: AppNetworkImage(
                imageUrl: widget.customer.profileImageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  widget.customer.name.isNotEmpty
                      ? widget.customer.name.substring(0, 1).toUpperCase()
                      : 'C',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          : Text(
              widget.customer.name.isNotEmpty
                  ? widget.customer.name.substring(0, 1).toUpperCase()
                  : 'C',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.primary,
              ),
            ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AdminProvider adminProv,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Back Row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: () => adminProv.clearSelectedCustomer(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Back to Customers',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              '/',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            Text(
              'Customer Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Main Customer Identity Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: AppColors.cardShadow,
          ),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                widget.customer.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              StatusBadge.fromString(widget.customer.status),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.lightBlue
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ID: ${widget.customer.id}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              _buildInfoChip(Icons.phone_outlined,
                                  widget.customer.phone, textSecondary),
                              if (widget.customer.email.isNotEmpty)
                                _buildInfoChip(Icons.email_outlined,
                                    widget.customer.email, textSecondary),
                              if (widget.customer.address.isNotEmpty)
                                _buildInfoChip(Icons.location_on_outlined,
                                    widget.customer.address, textSecondary),
                              if (widget.customer.deliveryZone.isNotEmpty)
                                _buildInfoChip(
                                    Icons.map_outlined,
                                    widget.customer.deliveryZone,
                                    textSecondary),
                              _buildInfoChip(
                                  Icons.calendar_today_outlined,
                                  'Joined: ${widget.customer.joinedDate}',
                                  textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Wallet Balance Callout
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8DECF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Wallet Balance',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormatter
                                .format(widget.customer.walletBalance),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: widget.customer.walletBalance >= 0
                                  ? AppColors.revenueGreen
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mobile Top Row: Avatar + Name + Status + ID
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customer.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  StatusBadge.fromString(
                                      widget.customer.status),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightBlue
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'ID: ${widget.customer.id}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Details Column with full text wrap / ellipsis
                    _buildDetailRow(Icons.phone_outlined, widget.customer.phone,
                        textSecondary),
                    if (widget.customer.email.isNotEmpty)
                      _buildDetailRow(Icons.email_outlined,
                          widget.customer.email, textSecondary),
                    if (widget.customer.address.isNotEmpty)
                      _buildDetailRow(Icons.location_on_outlined,
                          widget.customer.address, textSecondary),
                    if (widget.customer.deliveryZone.isNotEmpty)
                      _buildDetailRow(Icons.map_outlined,
                          widget.customer.deliveryZone, textSecondary),
                    _buildDetailRow(Icons.calendar_today_outlined,
                        'Joined: ${widget.customer.joinedDate}', textSecondary),

                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Mobile Wallet Balance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Wallet Balance',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        Text(
                          currencyFormatter
                              .format(widget.customer.walletBalance),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: widget.customer.walletBalance >= 0
                                ? AppColors.revenueGreen
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. SUMMARY KPI CARDS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSummaryCards(
    BuildContext context,
    List<CustomerDeliveryRecord> todayItems,
    List<CustomerDeliveryRecord> tomorrowItems,
    double monthlyTotal,
    double totalDue,
    bool isDesktop,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final double todayAmount =
        todayItems.fold(0.0, (acc, i) => acc + i.totalAmount);
    final String todaySummary = todayItems.isNotEmpty
        ? '${todayItems.fold(0, (acc, i) => acc + i.quantity)} Items • ${todayItems.first.productName}'
        : 'No Scheduled Deliveries';

    final double tomorrowAmount =
        tomorrowItems.fold(0.0, (acc, i) => acc + i.totalAmount);
    final String tomorrowSummary = tomorrowItems.isNotEmpty
        ? '${tomorrowItems.fold(0, (acc, i) => acc + i.quantity)} Items • ${tomorrowItems.first.productName}'
        : 'No Scheduled Deliveries';

    final cards = [
      _buildKpiCard(
        title: 'TODAY',
        mainValue: todayItems.isNotEmpty
            ? currencyFormatter.format(todayAmount)
            : '₹0',
        subtitle: todaySummary,
        icon: Icons.today_rounded,
        iconColor: AppColors.primary,
        bgColor: const Color(0xFFEBF7EE),
        cardBg: cardBg,
        cardBorder: cardBorder,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ),
      _buildKpiCard(
        title: 'TOMORROW',
        mainValue: tomorrowItems.isNotEmpty
            ? currencyFormatter.format(tomorrowAmount)
            : '₹0',
        subtitle: tomorrowSummary,
        icon: Icons.event_available_rounded,
        iconColor: AppColors.primaryBlue,
        bgColor: const Color(0xFFEFF6FF),
        cardBg: cardBg,
        cardBorder: cardBorder,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ),
      _buildKpiCard(
        title: 'THIS MONTH',
        mainValue: currencyFormatter.format(monthlyTotal),
        subtitle: 'Valid Delivered Purchases',
        icon: Icons.calendar_month_rounded,
        iconColor: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
        cardBg: cardBg,
        cardBorder: cardBorder,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ),
      _buildKpiCard(
        title: 'TOTAL DUE',
        mainValue: currencyFormatter.format(totalDue),
        subtitle: totalDue > 0 ? 'Pending Payment Balance' : 'All Dues Cleared',
        icon: Icons.account_balance_wallet_rounded,
        iconColor:
            totalDue > 0 ? const Color(0xFFEF4444) : AppColors.revenueGreen,
        bgColor:
            totalDue > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
        cardBg: cardBg,
        cardBorder: cardBorder,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map((c) => Expanded(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: c,
                )))
            .toList(),
      );
    } else {
      final isVerySmall = MediaQuery.of(context).size.width < 360;
      return GridView.count(
        crossAxisCount: isVerySmall ? 1 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: isVerySmall ? 2.8 : 1.3,
        children: cards,
      );
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String mainValue,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
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
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mainValue,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. TAB 1: TODAY TAB
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildTodayTab(
    BuildContext context,
    List<CustomerDeliveryRecord> items,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final now = DateTime.now();
    final todayStr = DateFormat('dd MMM yyyy').format(now);
    final todayFormatted = DateFormat('d MMMM yyyy').format(now);

    if (items.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.today_rounded,
        title: 'No delivery scheduled for today',
        subtitle:
            'This customer has no products scheduled for $todayFormatted.',
        textSecondary: textSecondary,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Today • $todayStr',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              return _buildDeliveryItemCard(
                  item, cardBorder, textPrimary, textSecondary);
            },
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. TAB 2: TOMORROW TAB
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildTomorrowTab(
    BuildContext context,
    List<CustomerDeliveryRecord> items,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = DateFormat('dd MMM yyyy').format(tomorrow);
    final tomorrowFormatted = DateFormat('d MMMM yyyy').format(tomorrow);

    if (items.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.event_available_rounded,
        title: 'No delivery scheduled for tomorrow',
        subtitle:
            'This customer has no products scheduled for $tomorrowFormatted.',
        textSecondary: textSecondary,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_rounded,
                  size: 16, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Tomorrow • $tomorrowStr',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              return _buildDeliveryItemCard(
                  item, cardBorder, textPrimary, textSecondary);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryItemCard(
    CustomerDeliveryRecord item,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          ProductImage(
            imageUrl: item.productImage,
            title: item.productName,
            productId: item.productId,
            size: 52,
            radius: 10,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} ${item.unit} • ${item.formattedTimeSlot} Delivery',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.orderCode != null || item.subscriptionId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.orderCode != null
                        ? 'Order Ref: #${item.orderCode}'
                        : 'Subscription Plan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(item.totalAmount),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBadge.fromString(item.deliveryStatus),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.paymentStatus.toLowerCase() == 'paid'
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.paymentStatus,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: item.paymentStatus.toLowerCase() == 'paid'
                            ? const Color(0xFF166534)
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. TAB 3: PURCHASE HISTORY TAB
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPurchaseHistoryTab(
    BuildContext context,
    List<Order> orders,
    Subscription? subscription,
    List<DateTime> skippedDates,
    List<CustomerDeliveryRecord> customRecords,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isDesktop,
  ) {
    // 1. Determine Date Range based on filter
    final now = DateTime.now();
    DateTime rangeStart;
    DateTime rangeEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_selectedSingleDate != null) {
      rangeStart = DateTime(_selectedSingleDate!.year,
          _selectedSingleDate!.month, _selectedSingleDate!.day);
      rangeEnd = DateTime(_selectedSingleDate!.year, _selectedSingleDate!.month,
          _selectedSingleDate!.day, 23, 59, 59);
    } else {
      switch (_historyFilter) {
        case 'Today':
          rangeStart = DateTime(now.year, now.month, now.day);
          break;
        case 'Yesterday':
          final y = now.subtract(const Duration(days: 1));
          rangeStart = DateTime(y.year, y.month, y.day);
          rangeEnd = DateTime(y.year, y.month, y.day, 23, 59, 59);
          break;
        case 'This Week':
          rangeStart = now.subtract(Duration(days: now.weekday - 1));
          rangeStart =
              DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
          break;
        case 'This Month':
          rangeStart = DateTime(now.year, now.month, 1);
          break;
        case 'Custom':
          if (_customDateRange != null) {
            rangeStart = _customDateRange!.start;
            rangeEnd = DateTime(
                _customDateRange!.end.year,
                _customDateRange!.end.month,
                _customDateRange!.end.day,
                23,
                59,
                59);
          } else {
            rangeStart = now.subtract(const Duration(days: 90));
          }
          break;
        case 'All':
        default:
          rangeStart = now.subtract(const Duration(days: 180));
          break;
      }
    }

    // 2. Fetch records
    var list = _service.getConsolidatedDeliveries(
      customerId: widget.customer.id,
      startDate: rangeStart,
      endDate: rangeEnd,
      orders: orders,
      subscription: subscription,
      skippedDates: skippedDates,
      customRecords: customRecords,
    );

    // 3. Search filter
    if (_historySearchQuery.trim().isNotEmpty) {
      final q = _historySearchQuery.trim().toLowerCase();
      list = list.where((i) {
        return i.productName.toLowerCase().contains(q) ||
            (i.orderCode != null && i.orderCode!.toLowerCase().contains(q)) ||
            i.deliveryStatus.toLowerCase().contains(q);
      }).toList();
    }

    // 4. Sort
    list.sort((a, b) =>
        _sortNewestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date));

    return Column(
      children: [
        // Filter and Action Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Filter Chips
                  ...['All', 'Today', 'Yesterday', 'This Week', 'This Month']
                      .map((filter) {
                    final isSelected =
                        _selectedSingleDate == null && _historyFilter == filter;
                    return ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedSingleDate = null;
                            _historyFilter = filter;
                          });
                        }
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : textPrimary,
                      ),
                    );
                  }),

                  // Specific Date Picker Button
                  ActionChip(
                    avatar: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      _selectedSingleDate != null
                          ? 'Date: ${DateFormat('dd MMM yyyy').format(_selectedSingleDate!)}'
                          : 'Select Specific Date',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedSingleDate != null
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                    backgroundColor: _selectedSingleDate != null
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.1),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedSingleDate ?? DateTime.now(),
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedSingleDate = picked;
                        });
                      }
                    },
                  ),

                  if (_selectedSingleDate != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Clear Date Filter',
                      onPressed: () {
                        setState(() {
                          _selectedSingleDate = null;
                        });
                      },
                    ),

                  // Sort Button
                  IconButton(
                    icon: Icon(
                      _sortNewestFirst
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    tooltip: _sortNewestFirst
                        ? 'Sort: Newest First'
                        : 'Sort: Oldest First',
                    onPressed: () {
                      setState(() {
                        _sortNewestFirst = !_sortNewestFirst;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List / Table
        Expanded(
          child: list.isEmpty
              ? _buildEmptyTabState(
                  icon: Icons.history_rounded,
                  title: 'No purchase history found',
                  subtitle: 'Completed customer purchases will appear here.',
                  textSecondary: textSecondary,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final item = list[idx];
                    return _buildHistoryRecordRow(item, cardBorder, textPrimary,
                        textSecondary, isDesktop);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryRecordRow(
    CustomerDeliveryRecord item,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isDesktop,
  ) {
    if (!isDesktop) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(
              imageUrl: item.productImage,
              title: item.productName,
              productId: item.productId,
              size: 44,
              radius: 8,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(item.date)} • ${item.formattedTimeSlot}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity} ${item.unit}${item.orderCode != null ? ' • #${item.orderCode}' : ' • Sub'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormatter.format(item.totalAmount),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge.fromString(item.deliveryStatus),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          // Date Column
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(item.date),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                Text(
                  item.formattedTimeSlot,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Product Image & Name
          ProductImage(
            imageUrl: item.productImage,
            title: item.productName,
            productId: item.productId,
            size: 38,
            radius: 8,
          ),
          const SizedBox(width: 12),

          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                Text(
                  '${item.quantity} ${item.unit}${item.orderCode != null ? ' • #${item.orderCode}' : ' • Sub'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          SizedBox(
            width: 80,
            child: Text(
              currencyFormatter.format(item.totalAmount),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),

          // Status Badges
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusBadge.fromString(item.deliveryStatus),
              if (isDesktop) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.paymentStatus.toLowerCase() == 'paid'
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.paymentStatus,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: item.paymentStatus.toLowerCase() == 'paid'
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. TAB 4: SUBSCRIPTION TAB
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSubscriptionTab(
    BuildContext context,
    Subscription? sub,
    List<DateTime> skippedDates,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isDesktop,
  ) {
    if (sub == null) {
      return _buildEmptyTabState(
        icon: Icons.autorenew_rounded,
        title: 'No active subscription',
        subtitle: 'This customer currently has no active dairy subscription.',
        textSecondary: textSecondary,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Subscription Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductImage(
                      imageUrl: sub.product.imageUrl,
                      title: sub.product.title,
                      productId: sub.product.id,
                      size: 64,
                      radius: 12,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sub.product.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge.fromString(sub.status.label),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sub.quantity} × ${sub.product.unit} • ${sub.frequency.label} • ${sub.deliveryTimeSlot}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Started: ${DateFormat('dd MMM yyyy').format(sub.startDate)}${sub.endDate != null ? ' • Ends: ${DateFormat('dd MMM yyyy').format(sub.endDate!)}' : ' • Ongoing'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Pricing and Controls
                if (isDesktop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily: ${currencyFormatter.format(sub.priceAfterDiscountPerDelivery)} • Est. Monthly: ${currencyFormatter.format(sub.monthlyCost)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (sub.isActive)
                            OutlinedButton.icon(
                              onPressed: () => _handlePauseSubscription(sub),
                              icon: const Icon(Icons.pause_circle_outline,
                                  size: 16),
                              label: const Text('Pause'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF59E0B),
                              ),
                            ),
                          if (sub.isPaused)
                            ElevatedButton.icon(
                              onPressed: () => _handleResumeSubscription(sub),
                              icon: const Icon(Icons.play_circle_outline,
                                  size: 16),
                              label: const Text('Resume'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () => _handleSkipDateDialog(sub),
                            icon:
                                const Icon(Icons.event_busy_rounded, size: 16),
                            label: const Text('Skip Date'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily: ${currencyFormatter.format(sub.priceAfterDiscountPerDelivery)} • Est. Monthly: ${currencyFormatter.format(sub.monthlyCost)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (sub.isActive)
                            OutlinedButton.icon(
                              onPressed: () => _handlePauseSubscription(sub),
                              icon: const Icon(Icons.pause_circle_outline,
                                  size: 16),
                              label: const Text('Pause'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF59E0B),
                              ),
                            ),
                          if (sub.isPaused)
                            ElevatedButton.icon(
                              onPressed: () => _handleResumeSubscription(sub),
                              icon: const Icon(Icons.play_circle_outline,
                                  size: 16),
                              label: const Text('Resume'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () => _handleSkipDateDialog(sub),
                            icon:
                                const Icon(Icons.event_busy_rounded, size: 16),
                            label: const Text('Skip Date'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Skipped Dates Section
          Text(
            'Skipped Delivery Dates',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (skippedDates.isEmpty)
            Text(
              'No skipped dates recorded for this customer.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: textSecondary,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skippedDates.map((date) {
                return Chip(
                  avatar: const Icon(Icons.event_busy_rounded,
                      size: 14, color: Color(0xFFEF4444)),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  backgroundColor: const Color(0xFFFEE2E2),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  onDeleted: () async {
                    await _service.removeSkippedDate(widget.customer.id, date);
                    if (mounted) setState(() {});
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _handlePauseSubscription(Subscription sub) async {
    try {
      await _service.pauseSubscription(widget.customer.id, sub);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription paused successfully.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to pause: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleResumeSubscription(Subscription sub) async {
    try {
      await _service.resumeSubscription(widget.customer.id, sub);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription resumed successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to resume: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSkipDateDialog(Subscription sub) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null) {
      try {
        await _service.skipSubscriptionDate(widget.customer.id, picked);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Delivery for ${DateFormat('dd MMM yyyy').format(picked)} marked as Skipped.'),
            backgroundColor: AppColors.primary,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to skip date: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 7. TAB 5: PAYMENTS TAB
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPaymentsTab(
    BuildContext context,
    List<DairyPayment> payments,
    ({
      double totalPurchases,
      double totalPaid,
      double pendingAmount,
      double walletBalance,
    }) ledger,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isDesktop,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ledger Summary Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: isDesktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                          child: _buildLedgerMetric(
                              'Total Purchases',
                              currencyFormatter.format(ledger.totalPurchases),
                              textPrimary)),
                      Expanded(
                          child: _buildLedgerMetric(
                              'Total Paid',
                              currencyFormatter.format(ledger.totalPaid),
                              AppColors.revenueGreen)),
                      Expanded(
                          child: _buildLedgerMetric(
                              'Pending Amount',
                              currencyFormatter.format(ledger.pendingAmount),
                              const Color(0xFFEF4444))),
                      Expanded(
                          child: _buildLedgerMetric(
                              'Wallet Balance',
                              currencyFormatter.format(ledger.walletBalance),
                              AppColors.primary)),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _buildLedgerMetric(
                                  'Total Purchases',
                                  currencyFormatter
                                      .format(ledger.totalPurchases),
                                  textPrimary)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildLedgerMetric(
                                  'Total Paid',
                                  currencyFormatter.format(ledger.totalPaid),
                                  AppColors.revenueGreen)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _buildLedgerMetric(
                                  'Pending Amount',
                                  currencyFormatter
                                      .format(ledger.pendingAmount),
                                  const Color(0xFFEF4444))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildLedgerMetric(
                                  'Wallet Balance',
                                  currencyFormatter
                                      .format(ledger.walletBalance),
                                  AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          Text(
            'Payment & Transaction Records',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildEmptyTabState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No payment records found',
                subtitle:
                    'Transactions and payment receipts for this customer will appear here.',
                textSecondary: textSecondary,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final p = payments[idx];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFCFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: p.status.toLowerCase() == 'success'
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          p.status.toLowerCase() == 'success'
                              ? Icons.check_circle_outline_rounded
                              : Icons.schedule_rounded,
                          size: 18,
                          color: p.status.toLowerCase() == 'success'
                              ? const Color(0xFF166534)
                              : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment for ${p.orderOrWalletId}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.timestamp} • ${p.method}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormatter.format(p.amount),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          StatusBadge.fromString(p.status),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLedgerMetric(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EMPTY STATE HELPER
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textSecondary,
  }) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFEBF7EE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
