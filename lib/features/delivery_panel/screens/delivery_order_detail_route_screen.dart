import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/order.dart';
import '../../../providers/delivery_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/order_service.dart';
import '../theme/delivery_theme.dart';
import 'delivery_order_detail_view.dart';

/// Dedicated GoRoute screen wrapper for deep-link navigation directly by [orderId]
/// within the delivery panel workflow (/delivery/orders/:orderId).
///
/// Security & RBAC:
/// - Delivery agents can strictly view ONLY orders assigned to their authenticated UID.
/// - Admins have full access.
/// - Unrelated or unassigned orders are blocked with clear feedback.
class DeliveryOrderDetailRouteScreen extends ConsumerWidget {
  final String orderId;

  const DeliveryOrderDetailRouteScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final currentAgent = ref.watch(deliveryAgentProvider);
    final effectiveAgentId =
        (currentAgent.id.isNotEmpty) ? currentAgent.id : user.id;

    return FutureBuilder<Order?>(
      future: ref.read(orderServiceProvider).getOrderById(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: DeliveryTheme.background,
            body: Center(
              child: CircularProgressIndicator(color: DeliveryTheme.primary),
            ),
          );
        }

        final order = snapshot.data;
        if (order == null) {
          return Scaffold(
            backgroundColor: DeliveryTheme.background,
            appBar: AppBar(
              title: const Text('Order Details'),
              backgroundColor: DeliveryTheme.cardBg,
              foregroundColor: DeliveryTheme.textDark,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 60, color: DeliveryTheme.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'Order #$orderId not found',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DeliveryTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/delivery');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DeliveryTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Back to Delivery Panel'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // RBAC validation: Delivery agent can only view orders assigned to them
        if (order.assignedAgentId != null &&
            order.assignedAgentId!.isNotEmpty &&
            order.assignedAgentId != effectiveAgentId &&
            !user.isAdmin) {
          return Scaffold(
            backgroundColor: DeliveryTheme.background,
            appBar: AppBar(
              title: const Text('Access Denied'),
              backgroundColor: DeliveryTheme.cardBg,
              foregroundColor: DeliveryTheme.textDark,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 60, color: DeliveryTheme.statusCancelledText),
                    const SizedBox(height: 12),
                    const Text(
                      'Access Denied: This order is assigned to another delivery agent.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DeliveryTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/delivery');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DeliveryTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Back to Delivery Panel'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final deliveryOrder = deliveryOrderFromOrder(order);
        return DeliveryOrderDetailView(
          order: deliveryOrder,
          onBack: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/delivery');
            }
          },
        );
      },
    );
  }
}
