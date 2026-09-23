import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/customer_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_badge.dart';
import 'customer_profile_screen.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    // If a customer is currently selected, render the dedicated Customer Profile view
    if (provider.selectedCustomer != null) {
      return CustomerProfileScreen(customer: provider.selectedCustomer!);
    }

    final isDesktop = ResponsiveLayout.isDesktop(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final filteredCustomers = provider.customers.where((c) {
      if (provider.searchQuery.isEmpty) return true;
      final q = provider.searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.deliveryZone.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Header
          if (!isDesktop) ...[
            Text(
              'Customer Management',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage registered dairy subscribers, addresses, and customer wallet balances.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCustomerDialog(context, provider, null),
                icon: const Icon(Icons.person_add_alt_1_rounded,
                    size: 18, color: Colors.white),
                label: Text(
                  'Add Customer',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Management',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage registered dairy subscribers, addresses, and customer wallet balances.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showCustomerDialog(context, provider, null),
                  icon: const Icon(Icons.person_add_alt_1_rounded,
                      size: 18, color: Colors.white),
                  label: Text(
                    'Add Customer',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Error Banner
          if (provider.usersError != null) ...[
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
                    child: Text(
                      provider.usersError!,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Customer List Table / Cards
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: provider.usersLoading && provider.customers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : filteredCustomers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 48.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 48,
                                color: AppColors.textMutedOf(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                provider.searchQuery.isEmpty
                                    ? 'No customers registered yet.'
                                    : 'No customers matching "${provider.searchQuery}".',
                                style: GoogleFonts.plusJakartaSans(
                                  color: textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Click "Add Customer" to create a new customer record.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.textMutedOf(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredCustomers.length,
                        separatorBuilder: (ctx, idx) =>
                            Divider(height: 1, color: cardBorder),
                        itemBuilder: (ctx, idx) {
                          final customer = filteredCustomers[idx];
                          return InkWell(
                            onTap: () => provider.selectCustomer(customer),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: isDesktop
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor:
                                              AppColors.primaryLight
                                                  .withValues(alpha: 0.2),
                                          child: Text(
                                            customer.name.isNotEmpty
                                                ? customer.name
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : 'C',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                customer.name,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${customer.phone}${customer.deliveryZone.isNotEmpty ? ' • ${customer.deliveryZone}' : ''}',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  color: textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                customer.subscriptionPlan,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                customer.milkPreference,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  color: AppColors.textMutedOf(
                                                      context),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                currencyFormatter.format(
                                                    customer.walletBalance),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: customer.walletBalance >=
                                                          0
                                                      ? AppColors.revenueGreen
                                                      : const Color(0xFFEF4444),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              StatusBadge.fromString(
                                                  customer.status),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Actions: Details, Edit and Delete
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.visibility_outlined,
                                                  size: 18,
                                                  color: AppColors.primary),
                                              tooltip: 'View Profile',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 32, minHeight: 32),
                                              onPressed: () => provider
                                                  .selectCustomer(customer),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 18,
                                                  color: AppColors.ordersBlue),
                                              tooltip: 'Edit Customer',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 32, minHeight: 32),
                                              onPressed: () =>
                                                  _showCustomerDialog(context,
                                                      provider, customer),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: Color(0xFFEF4444)),
                                              tooltip: 'Delete Customer',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 32, minHeight: 32),
                                              onPressed: () =>
                                                  _showDeleteConfirmation(
                                                      context,
                                                      provider,
                                                      customer),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Mobile Header: Avatar, Name & Status
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: AppColors
                                                  .primaryLight
                                                  .withValues(alpha: 0.2),
                                              child: Text(
                                                customer.name.isNotEmpty
                                                    ? customer.name
                                                        .substring(0, 1)
                                                        .toUpperCase()
                                                    : 'C',
                                                style: GoogleFonts
                                                    .plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    customer.name,
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    customer.phone,
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontSize: 11,
                                                      color: textSecondary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            StatusBadge.fromString(
                                                customer.status),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        // Middle: Delivery Zone & Plan
                                        if (customer.deliveryZone.isNotEmpty ||
                                            customer
                                                .subscriptionPlan.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8.0),
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                if (customer
                                                    .deliveryZone.isNotEmpty)
                                                  Text(
                                                    '📍 ${customer.deliveryZone}',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontSize: 11,
                                                      color: textSecondary,
                                                    ),
                                                  ),
                                                if (customer.subscriptionPlan
                                                    .isNotEmpty)
                                                  Text(
                                                    '🥛 ${customer.subscriptionPlan}',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontSize: 11,
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        // Bottom Row: Wallet Balance & Actions
                                         Wrap(
                                           alignment:
                                               WrapAlignment.spaceBetween,
                                           crossAxisAlignment:
                                               WrapCrossAlignment.center,
                                           spacing: 8,
                                           runSpacing: 6,
                                           children: [
                                             Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 Text(
                                                   'Wallet: ',
                                                   style: GoogleFonts
                                                       .plusJakartaSans(
                                                     fontSize: 12,
                                                     color: textSecondary,
                                                   ),
                                                 ),
                                                 Text(
                                                   currencyFormatter.format(
                                                       customer.walletBalance),
                                                   style: GoogleFonts
                                                       .plusJakartaSans(
                                                     fontSize: 13,
                                                     fontWeight: FontWeight.w800,
                                                     color: customer
                                                                 .walletBalance >=
                                                             0
                                                         ? AppColors.revenueGreen
                                                         : const Color(
                                                             0xFFEF4444),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                             Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 IconButton(
                                                   icon: const Icon(
                                                       Icons.visibility_outlined,
                                                       size: 18,
                                                       color: AppColors.primary),
                                                   tooltip: 'View Profile',
                                                   padding: EdgeInsets.zero,
                                                   visualDensity:
                                                       VisualDensity.compact,
                                                   constraints:
                                                       const BoxConstraints(
                                                           minWidth: 32,
                                                           minHeight: 32),
                                                   onPressed: () => provider
                                                       .selectCustomer(customer),
                                                 ),
                                                 IconButton(
                                                   icon: const Icon(
                                                       Icons.edit_outlined,
                                                       size: 18,
                                                       color:
                                                           AppColors.ordersBlue),
                                                   tooltip: 'Edit Customer',
                                                   padding: EdgeInsets.zero,
                                                   visualDensity:
                                                       VisualDensity.compact,
                                                   constraints:
                                                       const BoxConstraints(
                                                           minWidth: 32,
                                                           minHeight: 32),
                                                   onPressed: () =>
                                                       _showCustomerDialog(
                                                           context,
                                                           provider,
                                                           customer),
                                                 ),
                                                 IconButton(
                                                   icon: const Icon(
                                                       Icons
                                                           .delete_outline_rounded,
                                                       size: 18,
                                                       color: Color(0xFFEF4444)),
                                                   tooltip: 'Delete Customer',
                                                   padding: EdgeInsets.zero,
                                                   visualDensity:
                                                       VisualDensity.compact,
                                                   constraints:
                                                       const BoxConstraints(
                                                           minWidth: 32,
                                                           minHeight: 32),
                                                   onPressed: () =>
                                                       _showDeleteConfirmation(
                                                           context,
                                                           provider,
                                                           customer),
                                                 ),
                                               ],
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

  void _showCustomerDialog(
      BuildContext context, AdminProvider provider, DairyCustomer? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final zoneCtrl = TextEditingController(
        text: existing?.deliveryZone ?? 'Sector 7x Highrise Belt');
    final planCtrl = TextEditingController(
        text: existing?.subscriptionPlan ?? 'Daily Morning (2 Litres)');
    final milkCtrl = TextEditingController(
        text: existing?.milkPreference ?? 'Pure A2 Cow Milk');
    final walletCtrl = TextEditingController(
        text: existing != null ? '${existing.walletBalance.toInt()}' : '500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEdit ? 'Edit Customer Details' : 'Add New Dairy Subscriber',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Customer Full Name *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Phone Number *'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Email Address'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Delivery Address & Flat/Apt'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: zoneCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Delivery Zone'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: walletCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Wallet Balance (₹)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: planCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Subscription Plan (e.g. Daily Morning 2L)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: milkCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Milk Variety Preference'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                try {
                  if (isEdit) {
                    await provider.updateCustomer(
                      existing.copyWith(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim().isEmpty
                            ? existing.phone
                            : phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty
                            ? existing.email
                            : emailCtrl.text.trim(),
                        address: addressCtrl.text.trim().isEmpty
                            ? existing.address
                            : addressCtrl.text.trim(),
                        deliveryZone: zoneCtrl.text.trim().isEmpty
                            ? existing.deliveryZone
                            : zoneCtrl.text.trim(),
                        subscriptionPlan: planCtrl.text.trim().isEmpty
                            ? existing.subscriptionPlan
                            : planCtrl.text.trim(),
                        milkPreference: milkCtrl.text.trim().isEmpty
                            ? existing.milkPreference
                            : milkCtrl.text.trim(),
                        walletBalance: double.tryParse(walletCtrl.text) ??
                            existing.walletBalance,
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Customer "${nameCtrl.text}" updated successfully!'),
                          backgroundColor: AppColors.revenueGreen,
                        ),
                      );
                    }
                  } else {
                    final customerId =
                        'CUST-${DateTime.now().millisecondsSinceEpoch % 100000}';
                    await provider.addCustomer(
                      DairyCustomer(
                        id: customerId,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim().isEmpty
                            ? '+91 99999 00000'
                            : phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty
                            ? '${nameCtrl.text.toLowerCase().replaceAll(' ', '')}@sawariyadairy.com'
                            : emailCtrl.text.trim(),
                        address: addressCtrl.text.trim().isEmpty
                            ? 'Noida, Uttar Pradesh'
                            : addressCtrl.text.trim(),
                        deliveryZone: zoneCtrl.text.trim().isEmpty
                            ? 'Central Noida Hub'
                            : zoneCtrl.text.trim(),
                        subscriptionPlan: planCtrl.text.trim().isEmpty
                            ? 'Daily Morning (2 Litres)'
                            : planCtrl.text.trim(),
                        milkPreference: milkCtrl.text.trim().isEmpty
                            ? 'Pure A2 Cow Milk'
                            : milkCtrl.text.trim(),
                        walletBalance: double.tryParse(walletCtrl.text) ?? 500.0,
                        status: 'Active',
                        joinedDate:
                            DateFormat('dd MMM yyyy').format(DateTime.now()),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Customer "${nameCtrl.text}" added successfully!'),
                          backgroundColor: AppColors.revenueGreen,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save customer: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isEdit ? 'Save Changes' : 'Save Customer',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, AdminProvider provider, DairyCustomer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Delete Customer',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove customer "${customer.name}" (${customer.id}) from Firestore? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondaryOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.deleteCustomer(customer.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Customer "${customer.name}" deleted successfully.'),
                      backgroundColor: AppColors.revenueGreen,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete customer: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
