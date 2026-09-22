import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_app/models/order.dart' as model;

/// Filter states for the delivery agent's order history view.
enum OrderHistoryFilter {
  all,
  completed,
  cancelled,
}

/// Currently selected history filter (All / Completed / Cancelled).
final orderHistoryFilterProvider =
    StateProvider<OrderHistoryFilter>((ref) => OrderHistoryFilter.all);

/// Live Firestore stream of the delivery agent's order history.
///
/// Queries `orders` where the agent is assigned, filters by the selected
/// [OrderHistoryFilter], and returns the results sorted by `createdAt`
/// (descending) via [model.Order.orderDate].
///
/// The family parameter is the agent's uid; watching [orderHistoryFilterProvider]
/// rebuilt this stream whenever the filter changes.
final deliveryHistoryStreamProvider =
    StreamProvider.family<List<model.Order>, String>((ref, agentId) {
  final filter = ref.watch(orderHistoryFilterProvider);

  return FirebaseFirestore.instance
      .collection('orders')
      .where('assignedAgentId', isEqualTo: agentId)
      .snapshots()
      .map((snap) {
    final rawOrders = snap.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return null;
          return model.Order.fromFirestore(data, doc.id);
        })
        .whereType<model.Order>()
        .where((order) {
          if (filter == OrderHistoryFilter.completed) {
            return order.status == model.OrderStatus.delivered;
          }
          if (filter == OrderHistoryFilter.cancelled) {
            return order.status == model.OrderStatus.cancelled;
          }
          // OrderHistoryFilter.all: strictly include historical orders only
          return order.status == model.OrderStatus.delivered ||
              order.status == model.OrderStatus.cancelled;
        });

    // Prevent duplicate history entries
    final seenIds = <String>{};
    final orders = <model.Order>[];
    for (final order in rawOrders) {
      final key = order.id.isNotEmpty ? order.id : order.orderCode;
      if (key.isNotEmpty && seenIds.add(key)) {
        orders.add(order);
      } else if (key.isEmpty) {
        orders.add(order);
      }
    }

    // Sort descending by most relevant delivery/order date (newest first).
    orders.sort((a, b) {
      final dateA = a.deliveredAt ?? a.deliveryDate ?? a.orderDate;
      final dateB = b.deliveredAt ?? b.deliveryDate ?? b.orderDate;
      return dateB.compareTo(dateA);
    });
    return orders;
  });
});
