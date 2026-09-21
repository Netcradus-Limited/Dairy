import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/address.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../repositories/product_repository.dart';
import '../services/order_service.dart';
import 'user_provider.dart';

const _sampleAddress = Address(
  id: 'addr_1',
  label: 'Home',
  fullName: 'Rahul Sharma',
  mobileNumber: '+91 9876543210',
  houseFlat: 'Flat 402, Sunshine Heights',
  streetArea: 'MG Road, Vijay Nagar',
  city: 'Indore',
  state: 'Madhya Pradesh',
  pinCode: '452010',
  isDefault: true,
);

Product _safeProduct(
  List<Product> list,
  int index,
  List<Product> fallback,
) {
  if (list.isNotEmpty) {
    return list[index < list.length ? index : list.length - 1];
  }
  if (fallback.isNotEmpty) return fallback.first;
  throw StateError('No products available to build mock orders');
}

List<Order> _getMockOrders() {
  final repo = ProductRepository();
  final allProducts = repo.getFreshDeals();
  final a2Products = repo.getA2MilkProducts();
  final bestSellers = repo.getBestSellers();

  // If the repository has no products at all, fail safe with an empty list
  // instead of throwing during provider initialization (which would blank
  // the entire Orders screen).
  if (allProducts.isEmpty) return const [];

  return [
    Order(
      id: 'SD-9842',
      items: [
        CartItem(
            product: _safeProduct(a2Products, 0, allProducts), quantity: 2),
        CartItem(
            product: _safeProduct(allProducts, 1, allProducts), quantity: 1),
      ],
      subtotal: 740.0,
      deliveryCharge: 0.0,
      discount: 74.0,
      totalAmount: 666.0,
      status: OrderStatus.outForDelivery,
      orderDate: DateTime.now().subtract(const Duration(hours: 1)),
      deliveryAddress: _sampleAddress,
      paymentMethod: 'Cash on Delivery',
      estimatedDeliveryTime: 'Today by 7:30 AM',
    ),
    Order(
      id: 'SD-9810',
      items: [
        CartItem(
            product: _safeProduct(allProducts, 0, allProducts), quantity: 2),
        CartItem(
            product: _safeProduct(allProducts, 2, allProducts), quantity: 1),
      ],
      subtotal: 163.0,
      deliveryCharge: 30.0,
      discount: 0.0,
      totalAmount: 193.0,
      status: OrderStatus.preparing,
      orderDate: DateTime.now().subtract(const Duration(hours: 3)),
      deliveryAddress: _sampleAddress,
      paymentMethod: 'Online Payment (UPI)',
      estimatedDeliveryTime: 'Today by 8:00 AM',
    ),
    Order(
      id: 'SD-9745',
      items: [
        CartItem(
            product: _safeProduct(allProducts, 3, allProducts), quantity: 2),
        CartItem(
            product: _safeProduct(bestSellers, 4, allProducts), quantity: 1),
      ],
      subtotal: 150.0,
      deliveryCharge: 30.0,
      discount: 0.0,
      totalAmount: 180.0,
      status: OrderStatus.delivered,
      orderDate: DateTime.now().subtract(const Duration(days: 1)),
      deliveryAddress: _sampleAddress,
      paymentMethod: 'Online Payment (GPay)',
      estimatedDeliveryTime: 'Delivered yesterday at 7:15 AM',
    ),
    Order(
      id: 'SD-9602',
      items: [
        CartItem(
            product: _safeProduct(bestSellers, 5, allProducts), quantity: 3),
      ],
      subtotal: 120.0,
      deliveryCharge: 30.0,
      discount: 0.0,
      totalAmount: 150.0,
      status: OrderStatus.cancelled,
      orderDate: DateTime.now().subtract(const Duration(days: 3)),
      deliveryAddress: _sampleAddress,
      paymentMethod: 'Cash on Delivery',
      estimatedDeliveryTime: 'Cancelled by customer',
    ),
  ];
}

class OrdersNotifier extends StateNotifier<List<Order>> {
  OrdersNotifier() : super(_getMockOrders());

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
