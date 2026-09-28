import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/product_image.dart';
import '../../models/order.dart';
import '../delivery_panel/screens/delivery_order_detail_route_screen.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/order_service.dart';
import 'order_tracking_screen.dart';

/// Order Details Screen — full breakdown of a single order
class OrderDetailsScreen extends ConsumerWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for live Firestore state changes (e.g., after cancel)
    final asyncOrders = ref.watch(customerOrdersProvider);
    final liveOrder = asyncOrders.when(
      data: (orders) =>
          orders.firstWhere((o) => o.id == order.id, orElse: () => order),
      loading: () => order,
      error: (_, __) => order,
    );
    final isCancelled = liveOrder.isCancelled;
    final canCancel = liveOrder.canCancel;
    final isDesktop = context.isDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order #${liveOrder.displayOrderCode}'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHorizontalPadding,
          vertical: 20,
        ),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1100 : 640),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildLeftColumn(
                            context, ref, liveOrder, isCancelled, canCancel),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: _buildRightColumn(
                            context, ref, liveOrder, isCancelled),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderHeader(liveOrder, isCancelled),
                      const SizedBox(height: 16),
                      _buildItemsList(liveOrder),
                      const SizedBox(height: 16),
                      _buildPriceSummary(liveOrder),
                      const SizedBox(height: 16),
                      _buildAddressCard(liveOrder),
                      const SizedBox(height: 16),
                      _buildPaymentCard(liveOrder),
                      const SizedBox(height: 24),
                      _buildActions(
                          context, ref, liveOrder, isCancelled, canCancel),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context, WidgetRef ref, Order o,
      bool isCancelled, bool canCancel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOrderHeader(o, isCancelled),
        const SizedBox(height: 16),
        _buildItemsList(o),
        const SizedBox(height: 16),
        _buildPriceSummary(o),
        const SizedBox(height: 24),
        _buildActions(context, ref, o, isCancelled, canCancel),
      ],
    );
  }

  Widget _buildRightColumn(
      BuildContext context, WidgetRef ref, Order o, bool isCancelled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAddressCard(o),
        const SizedBox(height: 16),
        _buildPaymentCard(o),
      ],
    );
  }

  Widget _buildOrderHeader(Order o, bool isCancelled) {
    final statusColor = isCancelled ? AppColors.error : AppColors.primaryBlue;
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${o.displayOrderCode}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatDate(o.orderDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${o.items.length} product${o.items.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              o.status.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(Order o) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...o.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: ProductImage(
                          imageUrl: item.product.imageUrl,
                          categoryKey: item.product.categoryId,
                          productId: item.product.id,
                          title: item.product.title,
                          size: 42,
                          radius: 8,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.product.unit,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Qty: ${item.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${item.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(Order o) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _PriceRow('Item Subtotal', '₹${o.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _PriceRow(
            'Delivery Charge',
            o.deliveryCharge == 0.0
                ? 'FREE'
                : '₹${o.deliveryCharge.toStringAsFixed(2)}',
            valueColor: o.deliveryCharge == 0.0 ? AppColors.freshGreen : null,
          ),
          if (o.discount > 0) ...[
            const SizedBox(height: 8),
            _PriceRow(
              'Discount Applied',
              '-₹${o.discount.toStringAsFixed(2)}',
              valueColor: AppColors.freshGreen,
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Paid',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '₹${o.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(Order o) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded,
                  color: AppColors.primaryBlue, size: 18),
              SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            o.deliveryAddress.fullName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            o.deliveryAddress.fullAddressText,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            o.deliveryAddress.mobileNumber,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Order o) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment_rounded,
              color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  o.paymentMethod,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, Order o,
      bool isCancelled, bool canCancel) {
    final user = ref.watch(userProvider);
    final deliveryAgent = ref.watch(deliveryAgentProvider);
    final effectiveAgentId =
        deliveryAgent.id.isNotEmpty ? deliveryAgent.id : user.id;
    final isDeliveryAgent = user.isDelivery ||
        (effectiveAgentId.isNotEmpty && o.assignedAgentId == effectiveAgentId);

    if (isDeliveryAgent) {
      // DELIVERY PANEL: Strictly NO "Track Order", NO "Cancel Order"
      if (o.status == OrderStatus.delivered) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 22),
              SizedBox(width: 8),
              Text(
                'Delivered',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        );
      }

      if (isCancelled) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
              SizedBox(width: 8),
              Text(
                'Order Cancelled',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        );
      }

      // Active order for delivery agent: REPLACE "Track Order" with "Delivered"
      return _DeliveryOrderDeliveredButton(
        order: o,
        agentId: effectiveAgentId,
        agentName: deliveryAgent.name.isNotEmpty
            ? deliveryAgent.name
            : (user.name.isNotEmpty ? user.name : 'Delivery Staff'),
      );
    }

    // Customer / Admin view:
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isCancelled && o.status != OrderStatus.delivered) ...[
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(order: o),
                ),
              );
            },
            icon: const Icon(Icons.location_searching_rounded),
            label: const Text('Track Order',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isCancelled || o.isCompleted) ...[
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Items added to cart. You can review and checkout!')),
              );
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Reorder',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (canCancel) ...[
          OutlinedButton.icon(
            onPressed: () {
              _confirmCancel(context, ref, o.id);
            },
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            label: const Text(
              'Cancel Order',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order?'),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(orderServiceProvider).cancelOrder(orderId);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order cancelled successfully.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel order: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$min $amPm';
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PriceRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Screen wrapper for deep-link navigation directly by [orderId].
class OrderDetailsRouteScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsRouteScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    if (user.isDelivery) {
      return DeliveryOrderDetailRouteScreen(orderId: orderId);
    }

    return FutureBuilder<Order?>(
      future: ref.read(orderServiceProvider).getOrderById(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            ),
          );
        }
        final order = snapshot.data;
        if (order == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Order Details'),
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 60, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'Order #$orderId not found',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return OrderDetailsScreen(order: order);
      },
    );
  }
}

/// Delivery completion action button for the Delivery Panel order detail view.
class _DeliveryOrderDeliveredButton extends ConsumerStatefulWidget {
  final Order order;
  final String agentId;
  final String agentName;

  const _DeliveryOrderDeliveredButton({
    required this.order,
    required this.agentId,
    required this.agentName,
  });

  @override
  ConsumerState<_DeliveryOrderDeliveredButton> createState() =>
      _DeliveryOrderDeliveredButtonState();
}

class _DeliveryOrderDeliveredButtonState
    extends ConsumerState<_DeliveryOrderDeliveredButton> {
  bool _isProcessing = false;

  Future<void> _handleDelivered() async {
    if (_isProcessing) return;

    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(userProvider);
    final order = widget.order;
    final agentId = widget.agentId;

    // Security check: validate that the logged-in delivery boy is assigned to this order
    if (order.assignedAgentId != null &&
        order.assignedAgentId!.isNotEmpty &&
        order.assignedAgentId != agentId &&
        !user.isAdmin) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Access Denied: You are not assigned to this order.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (order.status == OrderStatus.delivered) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This order has already been delivered.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      return;
    }

    if (order.isCancelled) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cannot deliver a cancelled order.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await ref.read(orderServiceProvider).markOrderDelivered(
            orderId: order.id,
            agentId: agentId,
            agentName: widget.agentName,
          );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                'Order #${order.displayOrderCode} delivered successfully!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not mark order delivered: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : _handleDelivered,
      icon: _isProcessing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check_circle_outline_rounded, size: 20),
      label: Text(
        _isProcessing ? 'Updating...' : 'Delivered',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFA5D6A7),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
