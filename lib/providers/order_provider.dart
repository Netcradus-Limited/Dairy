import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import 'user_provider.dart';

class OrdersNotifier extends StateNotifier<List<Order>> {
  OrdersNotifier() : super(const []);

  void cancelOrder(String orderId) {
    state = state.map((order) {
      if (order.id == orderId) {
        return order.copyWith(status: OrderStatus.cancelled);
      }
      return order;
    }).toList();
  }

  void addOrder(Order newOrder) {
    state = [newOrder, ...state];
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, List<Order>>((ref) {
  return OrdersNotifier();
});

final allOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(ordersProvider);
});

final upcomingOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(ordersProvider).where((o) => o.isUpcoming).toList();
});

final completedOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(ordersProvider).where((o) => o.isCompleted).toList();
});

final cancelledOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(ordersProvider).where((o) => o.isCancelled).toList();
});

/// Live Firestore stream of a user's orders, keyed by their user id.
final userOrdersStreamProvider =
    StreamProvider.autoDispose.family<List<Order>, String>((ref, userId) {
  return ref.watch(orderServiceProvider).streamOrdersForUser(userId);
});

// ---------------------------------------------------------------------------
// Firestore-backed customer providers (replace mock ordersProvider usage)
// ---------------------------------------------------------------------------

/// The currently authenticated Firebase user's uid, or null for guests.
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(userProvider);
  String? authUid;
  try {
    if (Firebase.apps.isNotEmpty) {
      authUid = FirebaseAuth.instance.currentUser?.uid;
    }
  } catch (_) {}
  if (authUid != null && authUid.isNotEmpty) return authUid;
  return user.id.isEmpty ? null : user.id;
});

/// All orders for the current user from Firestore.
final customerOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const Stream.empty();
  }
  return ref.watch(orderServiceProvider).streamOrdersForUser(userId);
});

/// Upcoming orders for the current user from Firestore.
final customerUpcomingOrdersProvider = Provider<AsyncValue<List<Order>>>((ref) {
  return ref.watch(customerOrdersProvider).whenData(
        (orders) => orders.where((o) => o.isUpcoming).toList(),
      );
});

/// Completed orders for the current user from Firestore.
final customerCompletedOrdersProvider =
    Provider<AsyncValue<List<Order>>>((ref) {
  return ref.watch(customerOrdersProvider).whenData(
        (orders) => orders.where((o) => o.isCompleted).toList(),
      );
});

/// Cancelled orders for the current user from Firestore.
final customerCancelledOrdersProvider =
    Provider<AsyncValue<List<Order>>>((ref) {
  return ref.watch(customerOrdersProvider).whenData(
        (orders) => orders.where((o) => o.isCancelled).toList(),
      );
});
