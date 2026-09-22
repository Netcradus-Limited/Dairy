import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/app_network_image.dart';
import '../../models/delivery_staff_model.dart';
import '../../models/order_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_badge.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String selectedFilter = 'All';
  bool _updating = false;

  Future<void> _updateStatus(
    BuildContext context,
    AdminProvider provider,
    String orderId,
    OrderStatus newStatus,
  ) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await provider.updateOrderStatus(orderId, newStatus);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update order status. Please try again.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.statusCancelled,
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _showAssignAgentDialog(
    BuildContext context,
    AdminProvider provider,
    DairyOrder order,
  ) async {
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);

    String? selectedAgentId = order.assignedAgentId;
    String searchQuery = '';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allRiders = provider.riders;
            final filteredRiders = allRiders.where((r) {
              if (searchQuery.trim().isEmpty) return true;
              final q = searchQuery.toLowerCase().trim();
              return r.name.toLowerCase().contains(q) ||
                  r.phone.contains(q) ||
                  r.assignedZone.toLowerCase().contains(q) ||
                  r.id.toLowerCase().contains(q);
            }).toList();

            final selectedRider = allRiders.cast<DeliveryRider?>().firstWhere(
                  (r) => r?.id == selectedAgentId,
                  orElse: () => null,
                );

            final screenWidth = MediaQuery.sizeOf(dialogContext).width;
            final isNarrow = screenWidth < 480;

            return Dialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cardBorder),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(540.0, screenWidth - 32),
                  maxHeight: 620,
                ),
                child: Padding(
                  padding: EdgeInsets.all(isNarrow ? 16.0 : 24.0),
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
                                    const Icon(
                                      Icons.directions_bike_rounded,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        order.isAssigned
                                            ? 'Reassign Delivery Agent'
                                            : 'Assign Delivery Agent',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Order #${order.displayCode} • ${order.customerName}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            color: textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search input
                      TextField(
                        onChanged: (val) =>
                            setDialogState(() => searchQuery = val),
                        style: TextStyle(color: textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search agent by name, phone, or zone...',
                          hintStyle: TextStyle(color: textMuted, fontSize: 13),
                          prefixIcon: Icon(Icons.search,
                              size: 20, color: textSecondary),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Agents List
                      Expanded(
                        child: filteredRiders.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_off_outlined,
                                          size: 40, color: textMuted),
                                      const SizedBox(height: 8),
                                      Text(
                                        searchQuery.isNotEmpty
                                            ? 'No matching delivery agents found.'
                                            : 'No delivery agents registered yet.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredRiders.length,
                                separatorBuilder: (ctx, i) =>
                                    Divider(color: cardBorder, height: 1),
                                itemBuilder: (ctx, i) {
                                  final rider = filteredRiders[i];
                                  final isSelected =
                                      selectedAgentId == rider.id;
                                  final isCurrentlyAssigned =
                                      order.assignedAgentId == rider.id;

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: isSubmitting
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              selectedAgentId = rider.id;
                                            });
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0, vertical: 10.0),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color:
                                                  AppColors.deliveriesPurpleBg,
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : cardBorder,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: rider.profileImageUrl !=
                                                          null &&
                                                      rider.profileImageUrl!
                                                          .isNotEmpty
                                                  ? AppNetworkImage(
                                                      imageUrl: rider
                                                          .profileImageUrl!,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Center(
                                                      child: Text(
                                                        rider.name.isNotEmpty
                                                            ? rider.name[0]
                                                                .toUpperCase()
                                                            : 'D',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .deliveriesPurple,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Name & details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        rider.name,
                                                        style: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: textPrimary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (isCurrentlyAssigned) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .revenueGreenBg,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: const Text(
                                                          'Assigned',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AppColors
                                                                .revenueGreen,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${rider.phone.isNotEmpty ? rider.phone : "No Phone"} • ${rider.assignedZone.isNotEmpty ? rider.assignedZone : "All Zones"}',
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
                                          // Online status indicator
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: rider.isOnline
                                                  ? AppColors.revenueGreenBg
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: rider.isOnline
                                                        ? AppColors.revenueGreen
                                                        : textMuted,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  rider.isOnline
                                                      ? 'Online'
                                                      : 'Offline',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: rider.isOnline
                                                        ? AppColors.revenueGreen
                                                        : textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Radio selection
                                          Radio<String>(
                                            value: rider.id,
                                            groupValue: selectedAgentId,
                                            activeColor: AppColors.primary,
                                            visualDensity:
                                                VisualDensity.compact,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            onChanged: isSubmitting
                                                ? null
                                                : (val) {
                                                    setDialogState(() {
                                                      selectedAgentId = val;
                                                    });
                                                  },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: cardBorder, height: 1),
                      const SizedBox(height: 16),

                      // Footer Actions
                      if (isNarrow)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: (isSubmitting ||
                                      selectedAgentId == null ||
                                      selectedAgentId ==
                                          order.assignedAgentId)
                                  ? null
                                  : () async {
                                      setDialogState(
                                          () => isSubmitting = true);
                                      try {
                                        await provider.assignDeliveryAgent(
                                          order.id,
                                          selectedAgentId,
                                          agentName: selectedRider?.name,
                                        );
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                order.isAssigned
                                                    ? 'Order reassigned to ${selectedRider?.name ?? "agent"}.'
                                                    : 'Order assigned to ${selectedRider?.name ?? "agent"}.',
                                              ),
                                              backgroundColor:
                                                  AppColors.revenueGreen,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setDialogState(
                                            () => isSubmitting = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Failed to assign agent: $e'),
                                                backgroundColor:
                                                    AppColors.statusCancelled,
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
                                    horizontal: 16, vertical: 12),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      order.isAssigned
                                          ? 'Confirm Reassignment'
                                          : 'Assign Agent',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (order.isAssigned)
                                  TextButton.icon(
                                    onPressed: isSubmitting
                                        ? null
                                        : () async {
                                            setDialogState(
                                                () => isSubmitting = true);
                                            try {
                                              await provider
                                                  .assignDeliveryAgent(order.id, null);
                                              if (dialogContext.mounted) {
                                                Navigator.of(dialogContext).pop();
                                              }
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Agent unassigned from order.'),
                                                    backgroundColor:
                                                        AppColors.ordersBlue,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              setDialogState(
                                                  () => isSubmitting = false);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Failed to unassign agent: $e'),
                                                    backgroundColor:
                                                        AppColors.statusCancelled,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    icon: const Icon(
                                        Icons.person_remove_outlined,
                                        size: 16,
                                        color: AppColors.statusCancelled),
                                    label: const Text(
                                      'Unassign',
                                      style: TextStyle(
                                        color: AppColors.statusCancelled,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                TextButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => Navigator.of(dialogContext).pop(),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (order.isAssigned)
                              TextButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        setDialogState(
                                            () => isSubmitting = true);
                                        try {
                                          await provider
                                              .assignDeliveryAgent(order.id, null);
                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext).pop();
                                          }
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Agent unassigned from order.'),
                                                backgroundColor:
                                                    AppColors.ordersBlue,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setDialogState(
                                              () => isSubmitting = false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Failed to unassign agent: $e'),
                                                backgroundColor:
                                                    AppColors.statusCancelled,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.person_remove_outlined,
                                    size: 16, color: AppColors.statusCancelled),
                                label: const Text(
                                  'Unassign',
                                  style: TextStyle(
                                    color: AppColors.statusCancelled,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => Navigator.of(dialogContext).pop(),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: (isSubmitting ||
                                          selectedAgentId == null ||
                                          selectedAgentId ==
                                              order.assignedAgentId)
                                      ? null
                                      : () async {
                                          setDialogState(
                                              () => isSubmitting = true);
                                          try {
                                            await provider.assignDeliveryAgent(
                                              order.id,
                                              selectedAgentId,
                                              agentName: selectedRider?.name,
                                            );
                                            if (dialogContext.mounted) {
                                              Navigator.of(dialogContext).pop();
                                            }
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    order.isAssigned
                                                        ? 'Order reassigned to ${selectedRider?.name ?? "agent"}.'
                                                        : 'Order assigned to ${selectedRider?.name ?? "agent"}.',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.revenueGreen,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            setDialogState(
                                                () => isSubmitting = false);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                ..showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Failed to assign agent: $e'),
                                                    backgroundColor:
                                                        AppColors.statusCancelled,
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
                                        horizontal: 16, vertical: 10),
                                  ),
                                  child: isSubmitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          order.isAssigned
                                              ? 'Confirm Reassignment'
                                              : 'Assign Agent',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showOrderDetailsDialog(
    BuildContext context,
    AdminProvider provider,
    DairyOrder order,
  ) async {
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isNarrow = MediaQuery.sizeOf(dialogContext).width < 500;
        return Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cardBorder),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  math.min(540.0, MediaQuery.sizeOf(dialogContext).width - 32),
            ),
            child: Padding(
              padding: EdgeInsets.all(isNarrow ? 16.0 : 24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Order #${order.displayCode}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (order.isSubscription)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF6366F1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.autorenew_rounded,
                                            size: 13,
                                            color: Color(0xFF6366F1),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'SUBSCRIPTION',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF6366F1),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Placed at: ${order.time}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          color: textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: cardBorder, height: 1),
                    const SizedBox(height: 16),

                    // Subscription Info Box if applicable
                    if (order.isSubscription) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.repeat_rounded,
                                  size: 16,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Subscription Generated Order',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              'Subscription ID: ${order.subscriptionId ?? "N/A"}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Customer Details
                    Text(
                      'CUSTOMER INFORMATION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          if (order.customerPhone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              order.customerPhone,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                          if (order.address.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              order.address,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Order Summary
                    Text(
                      'ORDER DETAILS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Items',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  order.itemsSummary,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Delivery Slot',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                order.deliverySlot,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payment Mode',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                order.paymentMode,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Assigned Agent',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                order.isAssigned
                                    ? (order.assignedAgentName ?? order.assignedAgentId ?? 'Assigned')
                                    : 'Not Assigned',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: order.isAssigned
                                      ? AppColors.primary
                                      : textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(color: cardBorder, height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                currencyFormatter.format(order.amount),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status & Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Status: ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            StatusBadge.fromOrderStatus(order.status),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgentAssignmentCell(
    BuildContext context,
    AdminProvider provider,
    DairyOrder order,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color cardBorder,
  ) {
    if (order.isAssigned) {
      final assignedName =
          order.assignedAgentName != null && order.assignedAgentName!.isNotEmpty
              ? order.assignedAgentName!
              : (provider.riders
                      .cast<DeliveryRider?>()
                      .firstWhere((r) => r?.id == order.assignedAgentId,
                          orElse: () => null)
                      ?.name ??
                  'Agent (${order.assignedAgentId})');

      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showAssignAgentDialog(context, provider, order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.deliveriesPurpleBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.deliveriesPurple.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_bike_rounded,
                size: 15,
                color: AppColors.deliveriesPurple,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      assignedName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Tap to reassign',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppColors.deliveriesPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.swap_horiz_rounded,
                size: 16,
                color: AppColors.deliveriesPurple,
              ),
            ],
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _showAssignAgentDialog(context, provider, order),
      icon: const Icon(Icons.person_add_alt_1_outlined, size: 14),
      label: const Text(
        'Assign Agent',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
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

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orders & Dispatch Management',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Track live morning & evening delivery orders, assign delivery fleet, and update statuses.',
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
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'All',
                'Pending',
                'Confirmed',
                'Preparing',
                'Out for Delivery',
                'Delivered',
                'Cancelled'
              ].map((status) {
                final isSelected = selectedFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => selectedFilter = status);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                    backgroundColor: cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : cardBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Orders List/Table Container
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: _buildOrdersContent(
              context,
              provider,
              cardBg,
              cardBorder,
              textPrimary,
              textSecondary,
              textMuted,
              dividerColor,
              currencyFormatter,
              isDesktop,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersContent(
    BuildContext context,
    AdminProvider provider,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color dividerColor,
    NumberFormat currencyFormatter,
    bool isDesktop,
  ) {
    if (provider.ordersLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (provider.ordersError != null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline,
                color: AppColors.statusCancelled, size: 36),
            SizedBox(height: 12),
            Text('Could not load orders.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filteredOrders = provider.orders.where((order) {
      if (selectedFilter != 'All' &&
          order.status.displayName.toLowerCase() !=
              selectedFilter.toLowerCase()) {
        return false;
      }
      if (provider.searchQuery.isEmpty) return true;
      final q = provider.searchQuery.toLowerCase();
      return order.id.toLowerCase().contains(q) ||
          order.displayCode.toLowerCase().contains(q) ||
          order.customerName.toLowerCase().contains(q) ||
          order.address.toLowerCase().contains(q) ||
          order.itemsSummary.toLowerCase().contains(q) ||
          (order.assignedAgentName != null &&
              order.assignedAgentName!.toLowerCase().contains(q)) ||
          (order.assignedAgentId != null &&
              order.assignedAgentId!.toLowerCase().contains(q));
    }).toList();

    if (filteredOrders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, color: textMuted, size: 36),
              const SizedBox(height: 12),
              Text(
                selectedFilter == 'All'
                    ? 'No orders yet.'
                    : 'No $selectedFilter orders.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
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
      itemCount: filteredOrders.length,
      separatorBuilder: (ctx, idx) => Divider(color: dividerColor),
      itemBuilder: (ctx, idx) {
        final order = filteredOrders[idx];

        if (isDesktop) {
          // Desktop Table Row
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showOrderDetailsDialog(context, provider, order),
              hoverColor: AppColors.primary.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Order ID & Time
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                'Order #${order.displayCode}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: order.isSubscription
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                                      : AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: order.isSubscription
                                        ? const Color(0xFF6366F1)
                                        : AppColors.primary.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  order.isSubscription ? 'SUBSCRIPTION' : 'NORMAL',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    color: order.isSubscription
                                        ? const Color(0xFF6366F1)
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.time,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Customer & Items
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.itemsSummary,
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
                    // Delivery Slot & Payment Mode
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.deliverySlot,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            order.paymentMode,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Delivery Agent Column
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildAgentAssignmentCell(
                          context,
                          provider,
                          order,
                          textPrimary,
                          textSecondary,
                          textMuted,
                          cardBorder,
                        ),
                      ),
                    ),
                    // Amount
                    Expanded(
                      flex: 2,
                      child: Text(
                        currencyFormatter.format(order.amount),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    // Status Action Dropdown
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<OrderStatus>(
                          initialValue: order.status,
                          color: cardBg,
                          onSelected: (newStatus) => _updateStatus(
                            context,
                            provider,
                            order.id,
                            newStatus,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusBadge.fromOrderStatus(order.status),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down,
                                  size: 18, color: textSecondary),
                            ],
                          ),
                          itemBuilder: (ctx) => OrderStatus.values.map((s) {
                            return PopupMenuItem(
                              value: s,
                              child: Text(
                                s.displayName,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13, color: textPrimary),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Mobile / Compact Card View
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showOrderDetailsDialog(context, provider, order),
            hoverColor: AppColors.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Order ID & Status Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Order #${order.displayCode}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: order.isSubscription
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                                        : AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: order.isSubscription
                                          ? const Color(0xFF6366F1)
                                          : AppColors.primary.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    order.isSubscription ? 'SUBSCRIPTION' : 'NORMAL',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                      color: order.isSubscription
                                          ? const Color(0xFF6366F1)
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              order.time,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<OrderStatus>(
                        initialValue: order.status,
                        color: cardBg,
                        onSelected: (newStatus) => _updateStatus(
                          context,
                          provider,
                          order.id,
                          newStatus,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge.fromOrderStatus(order.status),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_drop_down,
                                size: 16, color: textSecondary),
                          ],
                        ),
                        itemBuilder: (ctx) => OrderStatus.values.map((s) {
                          return PopupMenuItem(
                            value: s,
                            child: Text(
                              s.displayName,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, color: textPrimary),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Customer & Items & Amount
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.itemsSummary,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyFormatter.format(order.amount),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Address
                  if (order.address.isNotEmpty)
                    Text(
                      order.address,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 10),

                  // Delivery Agent Assignment
                  _buildAgentAssignmentCell(
                    context,
                    provider,
                    order,
                    textPrimary,
                    textSecondary,
                    textMuted,
                    cardBorder,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
