import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/payment_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_badge.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _methodFilter = 'All';

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final dividerColor = AppColors.dividerOf(context);
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Apply Client-Side Search and Filtering on real Firestore payment records
    final filteredPayments = provider.payments.where((payment) {
      // 1. Status Filter
      if (_statusFilter != 'All') {
        if (payment.status.toLowerCase() != _statusFilter.toLowerCase()) {
          return false;
        }
      }

      // 2. Method Filter
      if (_methodFilter != 'All') {
        final m = payment.method.toLowerCase();
        if (_methodFilter == 'Cash' && !m.contains('cash')) return false;
        if (_methodFilter == 'Online' &&
            (m.contains('cash') || m.contains('wallet'))) return false;
        if (_methodFilter == 'Wallet' && !m.contains('wallet')) return false;
      }

      // 3. Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchName = payment.customerName.toLowerCase().contains(query);
        final matchId = payment.id.toLowerCase().contains(query);
        final matchOrder =
            payment.orderOrWalletId.toLowerCase().contains(query);
        final matchMethod = payment.method.toLowerCase().contains(query);
        final matchTxn =
            payment.transactionId?.toLowerCase().contains(query) ?? false;
        if (!matchName &&
            !matchId &&
            !matchOrder &&
            !matchMethod &&
            !matchTxn) {
          return false;
        }
      }

      return true;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header & Description ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payments & Collections',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Real-time Firestore-backed customer auto-debits, online settlements, and cash collections.',
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

          // ─── Summary KPI Cards ─────────────────────────────────────────────
          _buildKpiSummary(
            context,
            isDesktop,
            cardBg,
            cardBorder,
            textPrimary,
            textSecondary,
            currencyFormatter,
            provider,
          ),
          const SizedBox(height: 20),

          // ─── Search & Filters Bar ──────────────────────────────────────────
          _buildFilterBar(
            context,
            isDesktop,
            cardBg,
            cardBorder,
            textPrimary,
            textSecondary,
          ),
          const SizedBox(height: 16),

          // ─── Content List / State Handling ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: _buildPaymentsContent(
              context,
              isDesktop,
              provider,
              filteredPayments,
              currencyFormatter,
              dividerColor,
              textPrimary,
              textSecondary,
              textMuted,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// KPI Summary Grid (Total Collections, Completed, Pending, Transactions)
  Widget _buildKpiSummary(
    BuildContext context,
    bool isDesktop,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    NumberFormat currencyFormatter,
    AdminProvider provider,
  ) {
    final kpis = [
      _KpiItem(
        title: 'Total Collections',
        value: currencyFormatter.format(provider.totalPaymentsAmount),
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.revenueGreen,
        bgColor: AppColors.revenueGreenBg.withValues(alpha: 0.2),
      ),
      _KpiItem(
        title: 'Successful Payments',
        value: '${provider.successfulPaymentsCount}',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF2E7D32),
        bgColor: const Color(0xFFE8F5E9),
      ),
      _KpiItem(
        title: 'Pending Collections',
        value: '${provider.pendingPaymentsCount}',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFF57C00),
        bgColor: const Color(0xFFFFF3E0),
      ),
      _KpiItem(
        title: 'Total Transactions',
        value: '${provider.totalPaymentsCount}',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: kpis.map((kpi) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: _buildKpiCard(
                  kpi, cardBg, cardBorder, textPrimary, textSecondary),
            ),
          );
        }).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 360;
        final cardWidth = isVeryNarrow
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kpis.map((kpi) {
            return SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                  kpi, cardBg, cardBorder, textPrimary, textSecondary),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(
    _KpiItem kpi,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kpi.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(kpi.icon, color: kpi.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kpi.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kpi.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Filter & Search Controls
  Widget _buildFilterBar(
    BuildContext context,
    bool isDesktop,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final searchField = SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by customer, ID, or order...',
          hintStyle:
              GoogleFonts.plusJakartaSans(fontSize: 12.5, color: textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: AppColors.freshGreen.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.freshGreen, width: 1.5),
          ),
        ),
      ),
    );

    final filtersWrap = Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Status Filter
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Status: ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            DropdownButton<String>(
              value: _statusFilter,
              underline: const SizedBox(),
              isDense: true,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              items: ['All', 'Success', 'Pending', 'Failed', 'Cancelled']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _statusFilter = val);
              },
            ),
          ],
        ),

        // Method Filter
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Method: ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            DropdownButton<String>(
              value: _methodFilter,
              underline: const SizedBox(),
              isDense: true,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              items: ['All', 'Cash', 'Online', 'Wallet']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _methodFilter = val);
              },
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: isDesktop
          ? Row(
              children: [
                SizedBox(width: 320, child: searchField),
                const Spacer(),
                filtersWrap,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                filtersWrap,
              ],
            ),
    );
  }

  /// Main List Content with Loading / Empty / Error State Handling
  Widget _buildPaymentsContent(
    BuildContext context,
    bool isDesktop,
    AdminProvider provider,
    List<DairyPayment> payments,
    NumberFormat currencyFormatter,
    Color dividerColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (provider.paymentsLoading && provider.payments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading real-time payments from Firestore...'),
            ],
          ),
        ),
      );
    }

    if (provider.paymentsError != null && provider.payments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 8),
              Text(
                provider.paymentsError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.error, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (payments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56.0, horizontal: 20.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: textMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty ||
                        _statusFilter != 'All' ||
                        _methodFilter != 'All'
                    ? 'No matching payment records found.'
                    : 'No payments recorded in Firestore yet.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Live transactions and order collections will appear here automatically.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      separatorBuilder: (ctx, idx) => Divider(color: dividerColor, height: 1),
      itemBuilder: (ctx, idx) {
        final payment = payments[idx];
        final isCash = payment.method.toLowerCase().contains('cash');
        final isSuccess = payment.status.toLowerCase() == 'success';

        return InkWell(
          onTap: () => _showPaymentDetailModal(context, payment, provider),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Leading Method Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? AppColors.revenueGreenBg.withValues(alpha: 0.2)
                        : (isCash
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFFFEBEE)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCash
                        ? Icons.payments_outlined
                        : (payment.method.toLowerCase().contains('wallet')
                            ? Icons.account_balance_wallet_outlined
                            : Icons.credit_card_outlined),
                    color: isSuccess
                        ? AppColors.revenueGreen
                        : (isCash
                            ? const Color(0xFFF57C00)
                            : const Color(0xFFD32F2F)),
                  ),
                ),
                const SizedBox(width: 14),

                // Customer & ID Details
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${payment.id} • ${payment.orderOrWalletId} • ${payment.method}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Timestamp on desktop
                if (isDesktop)
                  Expanded(
                    flex: 2,
                    child: Text(
                      payment.timestamp,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ),

                // Amount & Status Badge
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormatter.format(payment.amount),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      StatusBadge.fromString(payment.status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Payment Details & Admin Status Update Modal
  void _showPaymentDetailModal(
    BuildContext context,
    DairyPayment payment,
    AdminProvider provider,
  ) {
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      StatusBadge.fromString(payment.status),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildModalRow('Payment ID', payment.id),
                  _buildModalRow('Order Reference', payment.orderOrWalletId),
                  _buildModalRow('Customer Name', payment.customerName),
                  if (payment.customerPhone != null &&
                      payment.customerPhone!.isNotEmpty)
                    _buildModalRow('Customer Phone', payment.customerPhone!),
                  _buildModalRow('Payment Method', payment.method),
                  _buildModalRow(
                      'Amount', '₹${payment.amount.toStringAsFixed(2)}'),
                  if (payment.transactionId != null)
                    _buildModalRow('Transaction ID', payment.transactionId!),
                  _buildModalRow('Timestamp', payment.timestamp),
                  const SizedBox(height: 20),

                  // Action Buttons for Pending Payments
                  if (payment.status == 'Pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.revenueGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: isUpdating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline,
                                    size: 18),
                            label: Text(
                              isUpdating
                                  ? 'Updating Status...'
                                  : 'Mark as Paid (Success)',
                            ),
                            onPressed: isUpdating
                                ? null
                                : () async {
                                    setModalState(() => isUpdating = true);
                                    try {
                                      await provider.updatePaymentStatus(
                                          payment.id, 'Success');
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Payment ${payment.id} marked as Paid (Success).',
                                            ),
                                            backgroundColor:
                                                AppColors.revenueGreen,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (modalCtx.mounted) {
                                        setModalState(() => isUpdating = false);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to update payment status: $e',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey[600], fontSize: 13)),
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  _KpiItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
