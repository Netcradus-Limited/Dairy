import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/complaint_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_badge.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _filterTabs = [
    'All',
    'Open',
    'In Progress',
    'Resolved',
    'Closed',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showComplaintDetailsDialog(
    BuildContext context,
    AdminProvider provider,
    CustomerComplaint ticket,
  ) {
    String selectedStatus = ticket.status;
    final replyController =
        TextEditingController(text: ticket.adminReply ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDesktop = ResponsiveLayout.isDesktop(context);
          final textPrimary = AppColors.textPrimaryOf(context);
          final textSecondary = AppColors.textSecondaryOf(context);
          final cardBg = AppColors.cardBgOf(context);
          final cardBorder = AppColors.cardBorderOf(context);

          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 620 : 420,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dialog Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      ticket.displayTicketId,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge.fromString(ticket.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ticket.subject.isNotEmpty
                                    ? ticket.subject
                                    : ticket.category,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close_rounded),
                          color: textSecondary,
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Content Scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer Info Summary Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.bgOf(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                children: [
                                  _infoRow(
                                    Icons.person_outline_rounded,
                                    'Customer',
                                    ticket.customerName,
                                    textPrimary,
                                    textSecondary,
                                  ),
                                  const SizedBox(height: 6),
                                  _infoRow(
                                    Icons.phone_outlined,
                                    'Phone',
                                    ticket.phone.isNotEmpty
                                        ? ticket.phone
                                        : 'Not specified',
                                    textPrimary,
                                    textSecondary,
                                  ),
                                  if (ticket.email.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    _infoRow(
                                      Icons.email_outlined,
                                      'Email',
                                      ticket.email,
                                      textPrimary,
                                      textSecondary,
                                    ),
                                  ],
                                  if (ticket.orderId != null &&
                                      ticket.orderId!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    _infoRow(
                                      Icons.receipt_long_outlined,
                                      'Related Order',
                                      ticket.orderId!,
                                      AppColors.primary,
                                      textSecondary,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  _infoRow(
                                    Icons.category_outlined,
                                    'Category',
                                    ticket.category,
                                    textPrimary,
                                    textSecondary,
                                  ),
                                  const SizedBox(height: 6),
                                  _infoRow(
                                    Icons.access_time_rounded,
                                    'Raised At',
                                    ticket.formattedCreatedAt,
                                    textPrimary,
                                    textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Complaint Message / Description
                            Text(
                              'Customer Description',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.bgOf(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Text(
                                ticket.description,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Update Status
                            Text(
                              'Update Status',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                'Open',
                                'In Progress',
                                'Resolved',
                                'Closed',
                              ].map((st) {
                                final isSelected = selectedStatus == st;
                                return ChoiceChip(
                                  label: Text(st),
                                  selected: isSelected,
                                  onSelected: (val) {
                                    if (val) {
                                      setDialogState(() => selectedStatus = st);
                                    }
                                  },
                                  labelStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color:
                                        isSelected ? Colors.white : textPrimary,
                                  ),
                                  selectedColor: AppColors.primary,
                                  backgroundColor: AppColors.bgOf(context),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : cardBorder,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),

                            // Admin Response / Reply Notes
                            Text(
                              'Admin Response / Resolution Note',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: replyController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText:
                                    'Enter resolution notes or response for the customer...',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                                filled: true,
                                fillColor: AppColors.bgOf(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              isSaving ? null : () => Navigator.pop(dialogCtx),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() => isSaving = true);
                                  try {
                                    await provider.updateComplaintStatus(
                                      ticket.id,
                                      selectedStatus,
                                      adminReply: replyController.text.trim(),
                                    );
                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Ticket ${ticket.displayTicketId} status updated to "$selectedStatus"',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (dialogCtx.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Failed to update complaint: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Save Status',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
    Color labelColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 15, color: labelColor),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final dividerColor = AppColors.dividerOf(context);

    final allComplaints = provider.complaints;

    // Filter by status tab
    final statusFiltered = _selectedStatusFilter == 'All'
        ? allComplaints
        : allComplaints.where((c) {
            return c.status.toLowerCase() ==
                _selectedStatusFilter.toLowerCase();
          }).toList();

    // Filter by search query
    final query = _searchQuery.trim().toLowerCase();
    final complaints = query.isEmpty
        ? statusFiltered
        : statusFiltered.where((c) {
            return c.ticketId.toLowerCase().contains(query) ||
                c.id.toLowerCase().contains(query) ||
                c.customerName.toLowerCase().contains(query) ||
                c.phone.toLowerCase().contains(query) ||
                c.subject.toLowerCase().contains(query) ||
                c.category.toLowerCase().contains(query) ||
                (c.orderId ?? '').toLowerCase().contains(query);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Support & Complaints',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Resolve customer delivery issues, product damages, and query tickets in real time.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.confirmation_number_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${allComplaints.length} Total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter tabs & Search Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Status tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterTabs.map((tab) {
                    final isSelected = _selectedStatusFilter == tab;
                    final count = tab == 'All'
                        ? allComplaints.length
                        : allComplaints
                            .where((c) =>
                                c.status.toLowerCase() == tab.toLowerCase())
                            .length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedStatusFilter = tab),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isSelected ? AppColors.primary : cardBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tab,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color:
                                      isSelected ? Colors.white : textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : textSecondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Search input
              SizedBox(
                width: isDesktop ? 260 : double.infinity,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search tickets or customer...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.2),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Container with complaint list
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: provider.complaintsLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : provider.complaintsError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.error, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                provider.complaintsError!,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : complaints.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 48.0, horizontal: 16),
                              child: Column(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No complaints found',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedStatusFilter == 'All'
                                        ? 'No customer tickets have been submitted yet.'
                                        : 'No tickets with status "$_selectedStatusFilter".',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: complaints.length,
                            separatorBuilder: (ctx, idx) =>
                                Divider(color: dividerColor, height: 1),
                            itemBuilder: (ctx, idx) {
                              final ticket = complaints[idx];

                              return InkWell(
                                onTap: () => _showComplaintDetailsDialog(
                                  context,
                                  provider,
                                  ticket,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: isMobile
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Top header row: Avatar + Name & ID + StatusBadge
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(
                                                            ticket.status)
                                                        .withValues(
                                                            alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: Icon(
                                                    _statusIcon(ticket.status),
                                                    color: _statusColor(
                                                        ticket.status),
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        ticket.customerName,
                                                        style: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: textPrimary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Wrap(
                                                        spacing: 6,
                                                        runSpacing: 2,
                                                        crossAxisAlignment:
                                                            WrapCrossAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            ticket
                                                                .displayTicketId,
                                                            style: GoogleFonts
                                                                .plusJakartaSans(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: AppColors
                                                                  .primary,
                                                            ),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        5,
                                                                    vertical:
                                                                        1.5),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppColors
                                                                  .customersOrangeBg
                                                                  .withValues(
                                                                      alpha:
                                                                          0.3),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child: Text(
                                                              ticket.category,
                                                              style: GoogleFonts
                                                                  .plusJakartaSans(
                                                                fontSize: 9.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: AppColors
                                                                    .customersOrange,
                                                              ),
                                                            ),
                                                          ),
                                                          if (ticket.orderId !=
                                                                  null &&
                                                              ticket.orderId!
                                                                  .isNotEmpty)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          5,
                                                                      vertical:
                                                                          1.5),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: AppColors
                                                                    .primary
                                                                    .withValues(
                                                                        alpha:
                                                                            0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                              child: Text(
                                                                'Order #${ticket.orderId}',
                                                                style: GoogleFonts
                                                                    .plusJakartaSans(
                                                                  fontSize: 9.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: AppColors
                                                                      .primary,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                StatusBadge.fromString(
                                                    ticket.status),
                                              ],
                                            ),
                                            if (ticket.subject.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                ticket.subject,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              ticket.description,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                color: textSecondary,
                                              ),
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            // Bottom metadata Wrap + Manage link
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 6,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .access_time_rounded,
                                                        size: 12,
                                                        color:
                                                            textSecondary),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      ticket
                                                          .formattedCreatedAt,
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontSize: 11,
                                                        color:
                                                            textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (ticket.phone.isNotEmpty)
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .phone_outlined,
                                                          size: 12,
                                                          color:
                                                              textSecondary),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        ticket.phone,
                                                        style: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontSize: 11,
                                                          color:
                                                              textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                if (ticket.adminReply !=
                                                        null &&
                                                    ticket.adminReply!
                                                        .isNotEmpty)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 1),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: AppColors
                                                          .success
                                                          .withValues(
                                                              alpha:
                                                                  0.12),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(4),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .reply_rounded,
                                                            size: 11,
                                                            color: AppColors
                                                                .success),
                                                        const SizedBox(
                                                            width: 3),
                                                        Text(
                                                          'Replied',
                                                          style: GoogleFonts
                                                              .plusJakartaSans(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: AppColors
                                                                .success,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                Text(
                                                  'Manage ›',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Ticket icon avatar
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: _statusColor(
                                                        ticket.status)
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                _statusIcon(ticket.status),
                                                color: _statusColor(
                                                    ticket.status),
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Main ticket summary
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Ticket ID & Customer Name & Badges
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 4,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        ticket.displayTicketId,
                                                        style: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      ),
                                                      Text(
                                                        '•',
                                                        style: TextStyle(
                                                            color:
                                                                textSecondary),
                                                      ),
                                                      Text(
                                                        ticket.customerName,
                                                        style: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: textPrimary,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .customersOrangeBg
                                                              .withValues(
                                                                  alpha: 0.3),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          ticket.category,
                                                          style: GoogleFonts
                                                              .plusJakartaSans(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AppColors
                                                                .customersOrange,
                                                          ),
                                                        ),
                                                      ),
                                                      if (ticket.orderId !=
                                                              null &&
                                                          ticket.orderId!
                                                              .isNotEmpty)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppColors
                                                                .primary
                                                                .withValues(
                                                                    alpha: 0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                          child: Text(
                                                            'Order #${ticket.orderId}',
                                                            style: GoogleFonts
                                                                .plusJakartaSans(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: AppColors
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),

                                                  // Subject if provided
                                                  if (ticket.subject
                                                      .isNotEmpty) ...[
                                                    Text(
                                                      ticket.subject,
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                  ],

                                                  // Description
                                                  Text(
                                                    ticket.description,
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontSize: 12,
                                                      color: textSecondary,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),

                                                  // Date & Admin response badge (using Wrap)
                                                  Wrap(
                                                    spacing: 12,
                                                    runSpacing: 4,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .access_time_rounded,
                                                              size: 13,
                                                              color:
                                                                  textSecondary),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            ticket
                                                                .formattedCreatedAt,
                                                            style: GoogleFonts
                                                                .plusJakartaSans(
                                                              fontSize: 11,
                                                              color:
                                                                  textSecondary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (ticket
                                                          .phone.isNotEmpty)
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .phone_outlined,
                                                                size: 13,
                                                                color:
                                                                    textSecondary),
                                                            const SizedBox(
                                                                width: 4),
                                                            Text(
                                                              ticket.phone,
                                                              style: GoogleFonts
                                                                  .plusJakartaSans(
                                                                fontSize: 11,
                                                                color:
                                                                    textSecondary,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      if (ticket.adminReply !=
                                                              null &&
                                                          ticket.adminReply!
                                                              .isNotEmpty)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 1),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppColors
                                                                .success
                                                                .withValues(
                                                                    alpha:
                                                                        0.12),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .reply_rounded,
                                                                  size: 11,
                                                                  color: AppColors
                                                                      .success),
                                                              const SizedBox(
                                                                  width: 3),
                                                              Text(
                                                                'Replied',
                                                                style: GoogleFonts
                                                                    .plusJakartaSans(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: AppColors
                                                                      .success,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Status badge & Action
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                StatusBadge.fromString(
                                                    ticket.status),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Manage ›',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
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
                          ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return AppColors.statusPending;
      case 'in progress':
        return AppColors.statusOutForDelivery;
      case 'resolved':
        return AppColors.statusDelivered;
      case 'closed':
        return AppColors.statusCancelled;
      default:
        return AppColors.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.report_problem_outlined;
      case 'in progress':
        return Icons.pending_actions_rounded;
      case 'resolved':
        return Icons.check_circle_outline_rounded;
      case 'closed':
        return Icons.done_all_rounded;
      default:
        return Icons.support_agent_rounded;
    }
  }
}
