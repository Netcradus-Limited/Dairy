import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/product_image.dart';
import '../../../models/delivery_boy_model.dart';
import '../../../models/order.dart';
import '../../../providers/delivery_provider.dart';
import '../../../services/delivery_tracking_service.dart';
import '../../../services/order_service.dart';
import '../theme/delivery_theme.dart';
import '../widgets/delivery_header.dart';

/// Screen 3 — Order Details View matching the reference design.
class DeliveryOrderDetailView extends ConsumerStatefulWidget {
  final DeliveryOrder order;
  final VoidCallback onBack;

  const DeliveryOrderDetailView({
    super.key,
    required this.order,
    required this.onBack,
  });

  @override
  ConsumerState<DeliveryOrderDetailView> createState() =>
      _DeliveryOrderDetailViewState();
}

class _DeliveryOrderDetailViewState
    extends ConsumerState<DeliveryOrderDetailView> {
  bool _isProcessing = false;

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openSms(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('sms:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openDirections(String address) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty) return;
    final query = Uri.encodeComponent(cleanAddress);
    final geoUri = Uri.parse('geo:0,0?q=$query');
    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
        return;
      }
    } catch (_) {}
    final mapUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _acceptOrder(DeliveryOrder order) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final agent = ref.read(deliveryAgentProvider);
      final agentId = agent.id.isNotEmpty
          ? agent.id
          : (FirebaseAuth.instance.currentUser?.uid ?? '');

      if (agentId.isEmpty) {
        throw StateError('Agent not authenticated');
      }

      await ref.read(orderServiceProvider).acceptOrder(order.id, agentId);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Order #${order.displayCode} accepted!'),
            backgroundColor: DeliveryTheme.primary,
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not accept order. Please check your connection and try again.',
            ),
            backgroundColor: DeliveryTheme.statusCancelledText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _declineOrder(DeliveryOrder order) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final agent = ref.read(deliveryAgentProvider);
      final agentId = agent.id.isNotEmpty
          ? agent.id
          : (FirebaseAuth.instance.currentUser?.uid ?? '');

      if (agentId.isNotEmpty) {
        await ref.read(orderServiceProvider).declineOrder(order.id, agentId);
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Order #${order.displayCode} declined'),
            backgroundColor: DeliveryTheme.statusCancelledText,
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not decline order. Please try again.'),
            backgroundColor: DeliveryTheme.statusCancelledText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _transitionOrder(
      DeliveryOrder order, OrderStatus nextStatus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(orderServiceProvider).updateOrderStatus(
            order.id,
            nextStatus,
          );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.displayCode} status updated to ${_statusLabel(nextStatus)}',
            ),
            backgroundColor: DeliveryTheme.primary,
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Could not update order status. Please check your connection.'),
            backgroundColor: DeliveryTheme.statusCancelledText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markDelivered(DeliveryOrder order) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final agentId = ref.read(deliveryAgentProvider).id;

      await ref.read(orderServiceProvider).updateOrderStatus(
            order.id,
            OrderStatus.delivered,
          );

      if (agentId.isNotEmpty) {
        await ref
            .read(deliveryTrackingServiceProvider)
            .clearActiveOrder(agentId);
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Order #${order.displayCode} successfully delivered!'),
            backgroundColor: DeliveryTheme.primary,
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Could not complete delivery. Please check your connection.'),
            backgroundColor: DeliveryTheme.statusCancelledText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showDeliveryFailureDialog(DeliveryOrder order) {
    if (_isProcessing) return;
    final messenger = ScaffoldMessenger.of(context);

    final reasons = [
      'Customer unreachable / not available',
      'Incorrect or incomplete address',
      'Customer refused delivery',
      'Damaged goods / other issue',
    ];
    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (dContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.cancel_outlined,
                    color: DeliveryTheme.statusCancelledText, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Delivery Issue',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select reason for delivery failure for Order #${order.displayCode}:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...reasons.map((reason) {
                  final isSelected = selectedReason == reason;
                  return InkWell(
                    onTap: isSubmitting
                        ? null
                        : () => setDialogState(() => selectedReason = reason),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 18,
                            color: isSelected
                                ? DeliveryTheme.statusCancelledText
                                : DeliveryTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? DeliveryTheme.statusCancelledText
                                    : DeliveryTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dContext),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: DeliveryTheme.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final nav = Navigator.of(dContext);
                        setDialogState(() => isSubmitting = true);
                        try {
                          final agentId = ref.read(deliveryAgentProvider).id;
                          await ref
                              .read(orderServiceProvider)
                              .failDelivery(order.id, selectedReason);

                          if (agentId.isNotEmpty) {
                            await ref
                                .read(deliveryTrackingServiceProvider)
                                .clearActiveOrder(agentId);
                          }

                          if (mounted) {
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Order #${order.displayCode} marked as failed',
                                ),
                                backgroundColor:
                                    DeliveryTheme.statusCancelledText,
                              ),
                            );
                            widget.onBack();
                          }
                        } catch (e) {
                          if (mounted) {
                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Could not record failure.'),
                                backgroundColor:
                                    DeliveryTheme.statusCancelledText,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DeliveryTheme.statusCancelledText,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Report Failure',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.preparing:
        return 'Preparing / Pickup';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Accepted';
    }
  }

  String _getOrderStatusTitle(DeliveryOrderStatus status) {
    switch (status) {
      case DeliveryOrderStatus.outForDelivery:
        return 'Out for Delivery';
      case DeliveryOrderStatus.pickup:
        return 'Pickup in Progress';
      case DeliveryOrderStatus.accepted:
        return 'Order Accepted';
      case DeliveryOrderStatus.delivered:
        return 'Delivered';
      case DeliveryOrderStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Pending Acceptance';
    }
  }

  String _getOrderStatusSubtitle(DeliveryOrderStatus status) {
    switch (status) {
      case DeliveryOrderStatus.outForDelivery:
        return 'Please deliver the order to the customer';
      case DeliveryOrderStatus.pickup:
        return 'Please pick up the fresh items from the dairy hub';
      case DeliveryOrderStatus.accepted:
        return 'Order is assigned to you. Proceed to store pickup.';
      case DeliveryOrderStatus.delivered:
        return 'Order has been successfully completed';
      case DeliveryOrderStatus.cancelled:
        return 'Order delivery was cancelled or failed';
      default:
        return 'Awaiting acceptance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final customerName = order.customerName.trim().isNotEmpty
        ? order.customerName.trim()
        : 'Customer';
    final customerAddress = order.customerAddress.trim().isNotEmpty
        ? order.customerAddress.trim()
        : 'Address not specified';
    final noteText = (order.deliverySlot != null && order.deliverySlot!.trim().isNotEmpty)
        ? 'Slot: ${order.deliverySlot!.trim()}'
        : 'Please keep the order at the gate. Call if not available.';

    return Scaffold(
      backgroundColor: DeliveryTheme.background,
      body: Column(
        children: [
          // Header matching Screen 3
          DeliveryStandardHeader(
            title: 'Order Details',
            leading: IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            actions: [
              IconButton(
                onPressed: () => _makePhoneCall(order.customerPhone),
                icon: const Icon(Icons.phone_outlined,
                    color: Colors.white, size: 22),
              ),
              IconButton(
                onPressed: () => _openSms(order.customerPhone),
                icon: const Icon(Icons.chat_bubble_outline_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Order Status Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius:
                        BorderRadius.circular(DeliveryTheme.cardRadius),
                    border: Border.all(
                      color: const Color(0xFFC8E6C9),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: DeliveryTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _getOrderStatusTitle(order.status),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: DeliveryTheme.primaryDark,
                                  ),
                                ),
                                Text(
                                  '#${order.displayCode}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: DeliveryTheme.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _getOrderStatusSubtitle(order.status),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: DeliveryTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Customer Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: DeliveryTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFE8F5E9),
                            child: Icon(Icons.person_outline_rounded,
                                size: 20, color: DeliveryTheme.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              customerName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: DeliveryTheme.textDark,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _makePhoneCall(order.customerPhone),
                            icon: const Icon(Icons.phone_forwarded_rounded,
                                color: DeliveryTheme.primary, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: DeliveryTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              customerAddress,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: DeliveryTheme.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Action Row: [ Call ], [ Chat ], [ Directions ]
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _makePhoneCall(order.customerPhone),
                              icon: const Icon(Icons.phone_rounded, size: 15),
                              label: Text(
                                'Call',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DeliveryTheme.primary,
                                side: const BorderSide(
                                    color: DeliveryTheme.primary),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openSms(order.customerPhone),
                              icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 15),
                              label: Text(
                                'Chat',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DeliveryTheme.primary,
                                side: const BorderSide(
                                    color: DeliveryTheme.primary),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _openDirections(customerAddress),
                              icon: const Icon(
                                  Icons.directions_rounded,
                                  size: 15),
                              label: Text(
                                'Directions',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DeliveryTheme.primary,
                                side: const BorderSide(
                                    color: DeliveryTheme.primary),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Items Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: DeliveryTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items (${order.items.isNotEmpty ? order.items.length : 1})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: DeliveryTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (order.orderItemDetails.isNotEmpty)
                        ...order.orderItemDetails.map((item) {
                          return _buildSingleItemRow(
                            name: item.unit.isNotEmpty
                                ? '${item.name} (${item.unit})'
                                : item.name,
                            qty: item.quantity,
                            price: item.price > 0
                                ? item.price
                                : (order.amount / order.orderItemDetails.length),
                            imageUrl: item.imageUrl,
                            productId: item.productId,
                            categoryKey: item.categoryKey,
                          );
                        })
                      else if (order.items.isNotEmpty)
                        ...order.items.map((item) {
                          return _buildSingleItemRow(
                            name: item,
                            qty: 1,
                            price: order.amount / (order.items.length),
                            imageUrl: order.productImageUrl,
                          );
                        })
                      else
                        _buildSingleItemRow(
                          name: 'Fresh Milk (A2 Gir Cow)',
                          qty: 1,
                          price: order.amount > 0 ? order.amount : 120,
                          imageUrl: order.productImageUrl,
                        ),
                      const Divider(height: 24, color: Color(0xFFECEFF1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: DeliveryTheme.textDark,
                            ),
                          ),
                          Text(
                            '₹${order.amount.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: DeliveryTheme.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Customer Note Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: DeliveryTheme.cardDecoration(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.chat_outlined,
                          size: 18,
                          color: DeliveryTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer Note',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: DeliveryTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              noteText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: DeliveryTheme.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Primary Action Button (Matches large green pill button from reference)
                _buildPrimaryActionCTA(order),

                const SizedBox(height: 12),
                // Report Failure Button (Clean link)
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showDeliveryFailureDialog(order),
                    icon: const Icon(Icons.report_problem_outlined,
                        size: 16, color: DeliveryTheme.statusCancelledText),
                    label: Text(
                      'Report Delivery Issue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DeliveryTheme.statusCancelledText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleItemRow({
    required String name,
    required int qty,
    required double price,
    String? imageUrl,
    String? productId,
    String? categoryKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ProductImage(
            imageUrl: imageUrl,
            productId: productId,
            categoryKey: categoryKey,
            title: name,
            size: 38,
            radius: 8,
            fit: BoxFit.contain,
            backgroundColor: const Color(0xFFE8F5E9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DeliveryTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$qty x ₹${price.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: DeliveryTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${(qty * price).toStringAsFixed(0)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DeliveryTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionCTA(DeliveryOrder order) {
    if (order.status == DeliveryOrderStatus.pendingAcceptance) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _acceptOrder(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: DeliveryTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFA5D6A7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 2,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Accept Order',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isProcessing ? null : () => _declineOrder(order),
              style: OutlinedButton.styleFrom(
                foregroundColor: DeliveryTheme.statusCancelledText,
                side: const BorderSide(
                  color: DeliveryTheme.statusCancelledText,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Decline Order',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    String label;
    VoidCallback? action;

    switch (order.status) {
      case DeliveryOrderStatus.accepted:
        label = 'Start Pickup';
        action = () => _transitionOrder(order, OrderStatus.preparing);
        break;
      case DeliveryOrderStatus.pickup:
        label = 'Start Delivery';
        action = () => _transitionOrder(order, OrderStatus.outForDelivery);
        break;
      case DeliveryOrderStatus.outForDelivery:
        label = 'Mark as Delivered';
        action = () => _markDelivered(order);
        break;
      case DeliveryOrderStatus.delivered:
        label = 'Order Completed';
        action = null;
        break;
      case DeliveryOrderStatus.cancelled:
      case DeliveryOrderStatus.declined:
        label = 'Order Cancelled';
        action = null;
        break;
      default:
        label = 'Start Pickup';
        action = null;
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : action,
        style: ElevatedButton.styleFrom(
          backgroundColor: DeliveryTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFA5D6A7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 2,
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.keyboard_double_arrow_right_rounded,
                      size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
