import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/product_image.dart';
import '../../models/customer_model.dart';
import '../../models/order.dart' as app_order;
import '../../models/subscription.dart';
import '../../providers/admin_provider.dart';
import '../../services/subscription_service.dart';

/// Admin Modal Dialog / BottomSheet for inspecting and managing a single subscription
class AdminSubscriptionDetailsDialog extends StatefulWidget {
  final Subscription subscription;

  const AdminSubscriptionDetailsDialog({
    super.key,
    required this.subscription,
  });

  static Future<void> show(BuildContext context, Subscription subscription) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminSubscriptionDetailsDialog(subscription: subscription),
    );
  }

  @override
  State<AdminSubscriptionDetailsDialog> createState() =>
      _AdminSubscriptionDetailsDialogState();
}

class _AdminSubscriptionDetailsDialogState
    extends State<AdminSubscriptionDetailsDialog> {
  late Subscription _sub;
  bool _isProcessing = false;
  final SubscriptionService _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _sub = widget.subscription;
  }

  Color _getStatusColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return AppColors.freshGreen;
      case SubscriptionStatus.paused:
        return const Color(0xFFD97706);
      case SubscriptionStatus.cancelled:
        return AppColors.error;
    }
  }

  Color _getStatusBgColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return const Color(0xFFE8FAF2);
      case SubscriptionStatus.paused:
        return const Color(0xFFFEF3C7);
      case SubscriptionStatus.cancelled:
        return const Color(0xFFFEE2E2);
    }
  }

  Future<void> _handlePause(AdminProvider provider) async {
    setState(() => _isProcessing = true);
    try {
      await provider.pauseSubscription(_sub.id);
      if (mounted) {
        setState(() {
          _sub = _sub.copyWith(
            status: SubscriptionStatus.paused,
            updatedAt: DateTime.now(),
          );
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription #${_sub.id} paused successfully.'),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pause subscription: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleResume(AdminProvider provider) async {
    setState(() => _isProcessing = true);
    try {
      await provider.resumeSubscription(_sub.id);
      if (mounted) {
        final now = DateTime.now();
        DateTime nextDate = _sub.nextDeliveryDate ?? now;
        if (nextDate.isBefore(now)) {
          nextDate = _subService.calculateNextDeliveryDate(_sub.frequency, fromDate: now);
        }
        setState(() {
          _sub = _sub.copyWith(
            status: SubscriptionStatus.active,
            nextDeliveryDate: nextDate,
            updatedAt: now,
          );
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription #${_sub.id} resumed successfully.'),
            backgroundColor: AppColors.freshGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resume subscription: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleCancel(AdminProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'Cancel Subscription?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel subscription #${_sub.id}? Future deliveries will be discontinued. This action updates status to Cancelled without deleting records.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await provider.cancelSubscription(_sub.id);
      if (mounted) {
        setState(() {
          _sub = _sub.copyWith(
            status: SubscriptionStatus.cancelled,
            autoRenew: false,
            updatedAt: DateTime.now(),
          );
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription #${_sub.id} has been cancelled.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel subscription: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleEdit(AdminProvider provider) async {
    int editQuantity = _sub.quantity;
    SubscriptionFrequency editFrequency = _sub.frequency;
    String editSlot = _sub.deliveryTimeSlot;
    DateTime editNextDelivery = _sub.nextDeliveryDate ?? DateTime.now();

    final qtyController = TextEditingController(text: '$editQuantity');
    final slotController = TextEditingController(text: editSlot);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Edit Subscription #${_sub.id}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product preview
                Row(
                  children: [
                    ProductImage(
                      imageUrl: _sub.product.imageUrl,
                      categoryKey: _sub.product.categoryId,
                      title: _sub.product.title,
                      size: 36,
                      radius: 6,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sub.product.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Size: ${_sub.product.unit} • ₹${_sub.product.price.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quantity
                Text(
                  'Quantity per delivery',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter quantity',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) {
                    final q = int.tryParse(val.trim());
                    if (q != null && q > 0) editQuantity = q;
                  },
                ),
                const SizedBox(height: 14),

                // Frequency
                Text(
                  'Frequency',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<SubscriptionFrequency>(
                  initialValue: editFrequency,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: SubscriptionFrequency.values
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.label,
                                style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (f) {
                    if (f != null) {
                      setDialogState(() => editFrequency = f);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Delivery Slot
                Text(
                  'Delivery Time Slot',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: slotController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Morning (6:00 AM - 9:00 AM)',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => editSlot = val.trim(),
                ),
                const SizedBox(height: 14),

                // Next Delivery Date
                Text(
                  'Next Delivery Date',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogCtx,
                      initialDate: editNextDelivery,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => editNextDelivery = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(editNextDelivery),
                          style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final q = int.tryParse(qtyController.text.trim()) ?? editQuantity;
                if (q < 1) return;
                editQuantity = q;
                editSlot = slotController.text.trim().isNotEmpty
                    ? slotController.text.trim()
                    : editSlot;
                Navigator.of(dialogCtx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    setState(() => _isProcessing = true);
    try {
      final updated = _sub.copyWith(
        quantity: editQuantity,
        frequency: editFrequency,
        deliveryTimeSlot: editSlot,
        nextDeliveryDate: editNextDelivery,
        updatedAt: DateTime.now(),
      );
      await provider.updateSubscription(updated);
      if (mounted) {
        setState(() {
          _sub = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription #${_sub.id} updated successfully.'),
            backgroundColor: AppColors.freshGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);

    final DairyCustomer? customer = provider.getCustomerById(_sub.userId);
    final statusColor = _getStatusColor(_sub.status);
    final statusBgColor = _getStatusBgColor(_sub.status);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 680,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cardBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Subscription Details',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                _sub.status.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'ID: ${_sub.id}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _sub.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Subscription ID copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Icon(Icons.copy_rounded,
                                  size: 13, color: textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product & Configuration Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProductImage(
                            imageUrl: _sub.product.imageUrl,
                            categoryKey: _sub.product.categoryId,
                            title: _sub.product.title,
                            size: 54,
                            radius: 8,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _sub.product.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildPill(
                                      'Product size: ${_sub.product.unit.isNotEmpty ? _sub.product.unit : "1 pc"}',
                                      AppColors.primary,
                                    ),
                                    _buildPill(
                                      'Quantity: ${_sub.quantity}',
                                      Colors.deepPurple,
                                    ),
                                    _buildPill(
                                      _sub.frequency.label,
                                      Colors.teal,
                                    ),
                                    if (_sub.includeIcePack)
                                      _buildPill('Ice Pack', Colors.blue),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Delivery Slot: ${_sub.deliveryTimeSlot}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Two Column Grid: Customer Info & Financial Schedule
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Column
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.bgOf(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Customer Details',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _infoRow(
                                  'Name',
                                  customer?.name.isNotEmpty == true
                                      ? customer!.name
                                      : (_sub.userId ?? 'Customer'),
                                  textPrimary,
                                  textMuted,
                                ),
                                const SizedBox(height: 6),
                                _infoRow(
                                  'Phone',
                                  customer?.phone.isNotEmpty == true
                                      ? customer!.phone
                                      : '—',
                                  textPrimary,
                                  textMuted,
                                ),
                                const SizedBox(height: 6),
                                _infoRow(
                                  'Address',
                                  customer?.address.isNotEmpty == true
                                      ? customer!.address
                                      : 'Registered Address',
                                  textPrimary,
                                  textMuted,
                                ),
                                const SizedBox(height: 6),
                                _infoRow(
                                  'User ID',
                                  _sub.userId ?? '—',
                                  textPrimary,
                                  textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Financial & Schedule Column
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.bgOf(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.payments_outlined,
                                        size: 16, color: AppColors.revenueGreen),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Schedule & Pricing',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _infoRow(
                                  'Price per delivery',
                                  '₹${_sub.priceAfterDiscountPerDelivery.toStringAsFixed(2)}',
                                  textPrimary,
                                  textMuted,
                                  highlight: true,
                                ),
                                const SizedBox(height: 6),
                                _infoRow(
                                  'Est. Monthly',
                                  '₹${_sub.monthlyCost.toStringAsFixed(2)}',
                                  AppColors.primary,
                                  textMuted,
                                  highlight: true,
                                ),
                                const SizedBox(height: 6),
                                _infoRow(
                                  'Start Date',
                                  DateFormat('dd MMM yyyy').format(_sub.startDate),
                                  textPrimary,
                                  textMuted,
                                ),
                                const SizedBox(height: 6),
                                _infoRow(
                                  'Next Delivery',
                                  _sub.nextDeliveryDate != null
                                      ? DateFormat('dd MMM yyyy')
                                          .format(_sub.nextDeliveryDate!)
                                      : '—',
                                  textPrimary,
                                  textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Delivery History Section
                    Text(
                      'Delivery History',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    StreamBuilder<List<app_order.Order>>(
                      stream: _subService.streamOrdersForSubscription(_sub.id),
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final orders = snapshot.data ?? [];
                        if (orders.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 20),
                            decoration: BoxDecoration(
                              color: AppColors.bgOf(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Center(
                              child: Text(
                                'No delivery orders generated yet for subscription #${_sub.id}.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ),
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.bgOf(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: orders.length,
                            separatorBuilder: (ctx, i) =>
                                Divider(height: 1, color: cardBorder),
                            itemBuilder: (ctx, i) {
                              final o = orders[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.local_shipping_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                title: Text(
                                  'Order #${o.displayOrderCode} • ₹${o.totalAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${DateFormat('dd MMM yyyy, hh:mm a').format(o.orderDate)} • Agent: ${o.assignedAgentId != null && o.assignedAgentId!.isNotEmpty ? o.assignedAgentId : "Unassigned"}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: textSecondary,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: o.status == app_order.OrderStatus.delivered
                                        ? AppColors.revenueGreen.withValues(alpha: 0.1)
                                        : Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    o.status.name.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: o.status == app_order.OrderStatus.delivered
                                          ? AppColors.revenueGreen
                                          : Colors.amber[800],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cardBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side edit button
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : () => _handleEdit(provider),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Subscription'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),

                  // Right side lifecycle action buttons
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_sub.status == SubscriptionStatus.active)
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _handlePause(provider),
                          icon: const Icon(Icons.pause_circle_outline_rounded,
                              size: 16),
                          label: const Text('Pause'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      if (_sub.status == SubscriptionStatus.paused)
                        ElevatedButton.icon(
                          onPressed:
                              _isProcessing ? null : () => _handleResume(provider),
                          icon: const Icon(Icons.play_circle_outline_rounded,
                              size: 16),
                          label: const Text('Resume'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.freshGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      if (_sub.status != SubscriptionStatus.cancelled)
                        ElevatedButton.icon(
                          onPressed:
                              _isProcessing ? null : () => _handleCancel(provider),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Cancel Subscription'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _infoRow(
      String label, String value, Color valueColor, Color labelColor,
      {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: valueColor,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
