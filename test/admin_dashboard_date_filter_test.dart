import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/order.dart' as order;
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/product_model.dart';
import 'package:dairy_app/providers/admin_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Dashboard Date Filter Tests', () {
    late AdminProvider provider;

    const defaultAddress = Address(
      id: 'addr_1',
      label: 'Home',
      fullName: 'John Doe',
      mobileNumber: '9876543210',
      houseFlat: 'A-101',
      streetArea: 'Sector 5',
      city: 'Indore',
      state: 'MP',
      pinCode: '452001',
    );

    final milkProduct = const Product(
      id: 'prod_milk',
      title: 'Fresh Cow Milk',
      categoryId: 'cat_milk',
      categoryName: 'Milk',
      price: 65.0,
      unit: '1 L',
      imageUrl: '',
    );

    final paneerProduct = const Product(
      id: 'prod_paneer',
      title: 'Fresh Paneer',
      categoryId: 'cat_paneer',
      categoryName: 'Paneer',
      price: 95.0,
      unit: '250 g',
      imageUrl: '',
    );

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final todayNoon = DateTime(now.year, now.month, now.day, 12, 30);
    final todayLateNight = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final yesterdayNoon = DateTime(now.year, now.month, now.day - 1, 14, 0);
    final yesterdayMorning = DateTime(now.year, now.month, now.day - 1, 8, 30);

    final tomorrowMorning = DateTime(now.year, now.month, now.day + 1, 7, 0);

    final todayOrder1 = order.Order(
      id: 'ord_today_1',
      orderCode: 'TOD001',
      items: [
        CartItem(product: milkProduct, quantity: 2), // ₹130
      ],
      subtotal: 130.0,
      totalAmount: 130.0,
      status: order.OrderStatus.delivered,
      orderDate: todayNoon,
      deliveryAddress: defaultAddress,
    );

    final todayOrder2 = order.Order(
      id: 'ord_today_2',
      orderCode: 'TOD002',
      items: [
        CartItem(product: paneerProduct, quantity: 1), // ₹95
      ],
      subtotal: 95.0,
      totalAmount: 95.0,
      status: order.OrderStatus.placed,
      orderDate: todayLateNight,
      deliveryAddress: defaultAddress,
    );

    final todayOrderMidnight = order.Order(
      id: 'ord_today_midnight',
      orderCode: 'TOD003',
      items: [
        CartItem(product: milkProduct, quantity: 1), // ₹65
      ],
      subtotal: 65.0,
      totalAmount: 65.0,
      status: order.OrderStatus.confirmed,
      orderDate: todayMidnight,
      deliveryAddress: defaultAddress,
    );

    final yesterdayOrder1 = order.Order(
      id: 'ord_yest_1',
      orderCode: 'YES001',
      items: [
        CartItem(product: milkProduct, quantity: 4), // ₹260
      ],
      subtotal: 260.0,
      totalAmount: 260.0,
      status: order.OrderStatus.delivered,
      orderDate: yesterdayNoon,
      deliveryAddress: defaultAddress,
    );

    final yesterdayOrder2 = order.Order(
      id: 'ord_yest_2',
      orderCode: 'YES002',
      items: [
        CartItem(product: paneerProduct, quantity: 2), // ₹190
      ],
      subtotal: 190.0,
      totalAmount: 190.0,
      status: order.OrderStatus.cancelled,
      orderDate: yesterdayMorning,
      deliveryAddress: defaultAddress,
    );

    final tomorrowOrder1 = order.Order(
      id: 'ord_tom_1',
      orderCode: 'TOM001',
      items: [
        CartItem(product: milkProduct, quantity: 1), // ₹65
      ],
      subtotal: 65.0,
      totalAmount: 65.0,
      status: order.OrderStatus.placed,
      orderDate: tomorrowMorning,
      deliveryDate: tomorrowMorning,
      deliveryAddress: defaultAddress,
    );

    setUp(() {
      provider = AdminProvider();
      provider.setProductsForTesting([
        DairyProduct(
          id: 'prod_milk',
          name: 'Fresh Cow Milk',
          subtitle: 'Pure Milk',
          category: 'Milk',
          unit: '1 L',
          price: 65.0,
        ),
        DairyProduct(
          id: 'prod_paneer',
          name: 'Fresh Paneer',
          subtitle: 'Pure Paneer',
          category: 'Paneer',
          unit: '250 g',
          price: 95.0,
        ),
      ]);
      provider.setRawOrdersForTesting([
        todayOrder1,
        todayOrder2,
        todayOrderMidnight,
        yesterdayOrder1,
        yesterdayOrder2,
        tomorrowOrder1,
      ]);
    });

    test('1. Today contains only today orders', () {
      provider.setOrderStatusTimeFilter('Today');
      expect(provider.dashboardDateFilter, equals(DashboardDateFilter.today));
      expect(provider.totalOrdersCount, equals(3));
      expect(
        provider.filteredDashboardOrders.map((o) => o.id).toList(),
        containsAll(['ord_today_1', 'ord_today_2', 'ord_today_midnight']),
      );
      expect(
        provider.filteredDashboardOrders.map((o) => o.id).toList(),
        isNot(contains('ord_yest_1')),
      );
      expect(
        provider.filteredDashboardOrders.map((o) => o.id).toList(),
        isNot(contains('ord_tom_1')),
      );
    });

    test('2. Yesterday excludes today orders', () {
      provider.setOrderStatusTimeFilter('Yesterday');
      expect(provider.dashboardDateFilter, equals(DashboardDateFilter.yesterday));
      expect(provider.totalOrdersCount, equals(2));
      expect(
        provider.filteredDashboardOrders.map((o) => o.id).toList(),
        containsAll(['ord_yest_1', 'ord_yest_2']),
      );
      expect(
        provider.filteredDashboardOrders.map((o) => o.id).toList(),
        isNot(contains('ord_today_1')),
      );
    });

    test('3. Tomorrow excludes today and yesterday orders', () {
      provider.setOrderStatusTimeFilter('Tomorrow');
      expect(provider.dashboardDateFilter, equals(DashboardDateFilter.tomorrow));
      expect(provider.totalOrdersCount, equals(1));
      expect(
        provider.filteredDashboardOrders.map((o) => o.id).toList(),
        containsAll(['ord_tom_1']),
      );
      expect(
        provider.filteredDashboardOrders.map((o) => o.id).toList(),
        isNot(contains('ord_today_1')),
      );
      expect(
        provider.filteredDashboardOrders.map((o) => o.id).toList(),
        isNot(contains('ord_yest_1')),
      );
    });

    test('4. Tomorrow with no records returns zero and empty values', () {
      // Exclude tomorrowOrder1
      provider.setRawOrdersForTesting([
        todayOrder1,
        todayOrder2,
        todayOrderMidnight,
        yesterdayOrder1,
        yesterdayOrder2,
      ]);
      provider.setOrderStatusTimeFilter('Tomorrow');

      expect(provider.totalOrdersCount, equals(0));
      expect(provider.totalRevenue, equals(0.0));
      expect(provider.pendingOrdersCount, equals(0));
      expect(provider.deliveredOrdersCount, equals(0));
      expect(provider.cancelledOrdersCount, equals(0));
      expect(provider.topSellingProducts, isEmpty);
    });

    test('5. Midnight boundaries are handled with full precision', () {
      provider.setOrderStatusTimeFilter('Today');
      final ids = provider.filteredDashboardOrders.map((o) => o.id).toList();
      // Exact midnight 00:00:00 is included in Today
      expect(ids, contains('ord_today_midnight'));
      // Late night 23:59:59 is included in Today
      expect(ids, contains('ord_today_2'));
    });

    test('6. Revenue changes dynamically with selected date', () {
      // Today: ord_today_1 is delivered (₹130), ord_today_2 placed (₹95), ord_today_midnight confirmed (₹65) -> Revenue = ₹130
      provider.setOrderStatusTimeFilter('Today');
      expect(provider.totalRevenue, equals(130.0));

      // Yesterday: ord_yest_1 is delivered (₹260), ord_yest_2 is cancelled (₹190) -> Revenue = ₹260
      provider.setOrderStatusTimeFilter('Yesterday');
      expect(provider.totalRevenue, equals(260.0));

      // Tomorrow: ord_tom_1 is placed (₹65) -> Revenue = ₹0.0
      provider.setOrderStatusTimeFilter('Tomorrow');
      expect(provider.totalRevenue, equals(0.0));
    });

    test('7. Status counts change dynamically with selected date', () {
      // Today: 1 delivered, 1 pending (placed), 1 active/confirmed
      provider.setOrderStatusTimeFilter('Today');
      expect(provider.deliveredOrdersCount, equals(1));
      expect(provider.pendingOrdersCount, equals(1));
      expect(provider.confirmedOrdersCount, equals(1));
      expect(provider.cancelledOrdersCount, equals(0));

      // Yesterday: 1 delivered, 1 cancelled
      provider.setOrderStatusTimeFilter('Yesterday');
      expect(provider.deliveredOrdersCount, equals(1));
      expect(provider.pendingOrdersCount, equals(0));
      expect(provider.cancelledOrdersCount, equals(1));
    });

    test('8. Chart total equals sum of filtered status counts', () {
      provider.setOrderStatusTimeFilter('Today');
      final todaySum = provider.pendingOrdersCount +
          provider.confirmedOrdersCount +
          provider.preparingOrdersCount +
          provider.outForDeliveryOrdersCount +
          provider.deliveredOrdersCount +
          provider.cancelledOrdersCount;
      expect(provider.totalOrdersCount, equals(todaySum));
      expect(provider.totalOrdersCount, equals(3));

      provider.setOrderStatusTimeFilter('Yesterday');
      final yestSum = provider.pendingOrdersCount +
          provider.confirmedOrdersCount +
          provider.preparingOrdersCount +
          provider.outForDeliveryOrdersCount +
          provider.deliveredOrdersCount +
          provider.cancelledOrdersCount;
      expect(provider.totalOrdersCount, equals(yestSum));
      expect(provider.totalOrdersCount, equals(2));
    });

    test('9. Top-selling products are strictly derived from filtered orders', () {
      // Today: Milk (2 units from ord_today_1 + 1 unit from ord_today_midnight = 3 units), Paneer (1 unit)
      provider.setOrderStatusTimeFilter('Today');
      final todayTop = provider.topSellingProducts;
      expect(todayTop.length, equals(2));
      expect(todayTop.first.id, equals('prod_milk'));
      expect(todayTop.first.ordersCount, equals(3));
      expect(todayTop.last.id, equals('prod_paneer'));
      expect(todayTop.last.ordersCount, equals(1));

      // Yesterday: Milk (4 units from ord_yest_1). ord_yest_2 cancelled so Paneer excluded.
      provider.setOrderStatusTimeFilter('Yesterday');
      final yestTop = provider.topSellingProducts;
      expect(yestTop.length, equals(1));
      expect(yestTop.first.id, equals('prod_milk'));
      expect(yestTop.first.ordersCount, equals(4));
    });

    test('10. Switching filters updates immediately without retaining stale data', () {
      provider.setOrderStatusTimeFilter('Today');
      expect(provider.totalOrdersCount, equals(3));

      provider.setOrderStatusTimeFilter('Yesterday');
      expect(provider.totalOrdersCount, equals(2));

      provider.setOrderStatusTimeFilter('Tomorrow');
      expect(provider.totalOrdersCount, equals(1));

      provider.setOrderStatusTimeFilter('Today');
      expect(provider.totalOrdersCount, equals(3));
    });
  });
}
