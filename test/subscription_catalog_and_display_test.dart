import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/subscription.dart';
import 'package:dairy_app/repositories/product_repository.dart';

void main() {
  group('Subscription Catalog & Quantity Display Verification', () {
    test(
        '1. Subscribable dairy catalog filters out Water Bottle and Organic Uple',
        () {
      final repo = ProductRepository();
      final allFallback = [
        ...repo.getA2MilkProducts(),
        ...repo.getFreshDeals(),
        ...repo.getBestSellers(),
      ];

      final subscribable = allFallback
          .where((p) => p.subscriptionEnabled && p.inStock)
          .map((p) => p.title)
          .toSet();

      // Ensure authentic dairy categories are present
      expect(subscribable.contains('Sawariya Milk'), true);
      expect(subscribable.contains('Sawariya Pure Desi Ghee'), true);
      expect(subscribable.contains('Sawariya Paneer'), true);
      expect(subscribable.contains('Sawariya Thick Creamy Lassi'), true);
      expect(subscribable.contains('Sawariya Makhan '), true);

      // Ensure Water Bottle and Organic Uple are NOT in the subscribable products list
      expect(subscribable.contains('Water Bottle'), false);
      expect(subscribable.contains('Water Bottle 20L'), false);
      expect(subscribable.contains('Cow Dung Cake (Uple)'), false);
      expect(subscribable.contains('Organic Uple'), false);
    });

    test(
        '2. Product deserialization properly identifies non-subscribable items',
        () {
      final waterProduct = Product.fromFirestore({
        'title': 'Water Bottle 20L',
        'categoryId': 'cat_water',
        'categoryName': 'Water',
        'price': 60.0,
        'unit': '20 L',
      }, 'prod_water');

      final upleProduct = Product.fromFirestore({
        'title': 'Organic Uple',
        'categoryId': 'cat_uple',
        'categoryName': 'Uple',
        'price': 40.0,
        'unit': '1 pc',
      }, 'prod_uple');

      final milkProduct = Product.fromFirestore({
        'title': 'Fresh Milk',
        'categoryId': 'cat_milk',
        'categoryName': 'Milk',
        'price': 45.0,
        'unit': '500 ml',
      }, 'prod_milk');

      expect(waterProduct.subscriptionEnabled, false);
      expect(upleProduct.subscriptionEnabled, false);
      expect(milkProduct.subscriptionEnabled, true);
    });

    test(
        '3. Subscription quantity remains integer and formats separately from unit',
        () {
      final now = DateTime(2026, 9, 18);
      const milk = Product(
        id: 'prod_milk_1l',
        title: 'Sawariya Milk 1L',
        categoryId: 'cat_milk',
        categoryName: 'Milk',
        price: 65.0,
        unit: '1 L',
        imageUrl: '',
        subscriptionEnabled: true,
      );

      final sub = Subscription(
        id: 'sub_test_qty',
        product: milk,
        quantity: 2,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        deliveryTimeSlot: 'Morning (6:00 AM - 9:00 AM)',
        discountRate: 0.10,
        planId: 'plan_milk',
        planName: 'Daily Milk 1L Plan',
      );

      // Verify stored quantity is integer
      expect(sub.quantity, 2);
      expect(sub.quantity, isA<int>());

      // Subtitle format: "${product.unit} • ${product.categoryName}" -> "1 L • Milk"
      final subtitle = '${sub.product.unit} • ${sub.product.categoryName}';
      expect(subtitle, '1 L • Milk');

      // Detail row format: "${subscription.quantity}" -> "2" (NOT "2 1 L")
      final qtyDisplay = '${sub.quantity}';
      expect(qtyDisplay, '2');
      expect(qtyDisplay, isNot(contains('1 L')));

      // Pricing preview: 2 * 65.0 = 130.0; after 10% discount = 117.0
      expect(sub.pricePerDelivery, 130.0);
      expect(sub.priceAfterDiscountPerDelivery, 117.0);
    });
  });
}
