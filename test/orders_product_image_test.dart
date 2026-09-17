import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/core/constants/app_assets.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/order.dart';

void main() {
  group('Product Image Mapping across all screens', () {
    test('Products resolve to their specific requested asset images', () {
      const milk = Product(
        id: 'prod_fresh_milk',
        title: 'Fresh Milk',
        categoryId: 'cat_milk',
        categoryName: 'Milk',
        price: 45,
        unit: '500 ml',
        imageUrl: '',
      );

      const lassi = Product(
        id: 'prod_fresh_lassi',
        title: 'Fresh Lassi',
        categoryId: 'cat_lassi',
        categoryName: 'Lassi',
        price: 30,
        unit: '300 ml',
        imageUrl: '',
      );

      const makhan = Product(
        id: 'prod_fresh_makhan',
        title: 'Fresh Makhan',
        categoryId: 'cat_makhan',
        categoryName: 'Makhan',
        price: 60,
        unit: '100 g',
        imageUrl: '',
      );

      const paneer = Product(
        id: 'prod_fresh_paneer',
        title: 'Fresh Paneer',
        categoryId: 'cat_paneer',
        categoryName: 'Paneer',
        price: 95,
        unit: '200 g',
        imageUrl: '',
      );

      const ghee = Product(
        id: 'prod_pure_ghee',
        title: 'Pure Ghee',
        categoryId: 'cat_ghee',
        categoryName: 'Pure Ghee',
        price: 650,
        unit: '1 L',
        imageUrl: '',
      );

      // Verify exact mappings requested by the user:
      // Pure Ghee -> assets/images/nng.png
      // Fresh Lassi -> assets/images/nnl.png
      // Fresh Paneer -> assets/images/nnp.png
      // Fresh Milk -> assets/images/nnd.png
      // Fresh Makhan -> assets/images/nnm.png
      expect(ghee.resolvedImageUrl, 'assets/images/nng.png');
      expect(lassi.resolvedImageUrl, 'assets/images/nnl.png');
      expect(paneer.resolvedImageUrl, 'assets/images/nnp.png');
      expect(milk.resolvedImageUrl, 'assets/images/nnd.png');
      expect(makhan.resolvedImageUrl, 'assets/images/nnm.png');

      expect(AppAssets.gheePng, 'assets/images/nng.png');
      expect(AppAssets.lassiPng, 'assets/images/nnl.png');
      expect(AppAssets.paneerPng, 'assets/images/nnp.png');
      expect(AppAssets.milkPng, 'assets/images/nnd.png');
      expect(AppAssets.makhanPng, 'assets/images/nnm.png');
    });

    test('Category icons remain untouched', () {
      expect(AppAssets.milkCategory, 'assets/images/doodh.png');
      expect(AppAssets.gheeCategory, 'assets/images/newgh.png');
      expect(AppAssets.lassiCategory, 'assets/images/las.png');
      expect(AppAssets.makhanCategory, 'assets/images/mak.png');
      expect(AppAssets.paneerCategory, 'assets/images/pan.png');
      expect(AppAssets.upleCategory, 'assets/images/u3.png');
      expect(AppAssets.waterCategory, 'assets/images/w3.png');
    });

    test('AppAssets.productImage resolves correctly for titles and categories',
        () {
      expect(AppAssets.productImage(title: 'Pure Ghee 1 L'),
          'assets/images/nng.png');
      expect(AppAssets.productImage(categoryKey: 'cat_ghee'),
          'assets/images/nng.png');

      expect(AppAssets.productImage(title: 'Fresh Lassi 300 ml'),
          'assets/images/nnl.png');
      expect(AppAssets.productImage(categoryKey: 'cat_lassi'),
          'assets/images/nnl.png');

      expect(AppAssets.productImage(title: 'Fresh Paneer 200 g'),
          'assets/images/nnp.png');
      expect(AppAssets.productImage(categoryKey: 'cat_paneer'),
          'assets/images/nnp.png');

      expect(AppAssets.productImage(title: 'Fresh Milk 500 ml'),
          'assets/images/nnd.png');
      expect(AppAssets.productImage(categoryKey: 'cat_milk'),
          'assets/images/nnd.png');

      expect(AppAssets.productImage(title: 'Fresh Makhan 100 g'),
          'assets/images/nnm.png');
      expect(AppAssets.productImage(categoryKey: 'cat_makhan'),
          'assets/images/nnm.png');
    });

    test('Orders resolve to matching product images across items', () {
      final order = Order.fromFirestore({
        'status': 'placed',
        'subtotal': 880.0,
        'deliveryCharge': 0.0,
        'discount': 0.0,
        'totalAmount': 880.0,
        'items': [
          {
            'productId': 'prod_pure_ghee',
            'title': 'Pure Ghee',
            'unit': '1 L',
            'price': 650.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nng.png',
          },
          {
            'productId': 'prod_fresh_lassi',
            'title': 'Fresh Lassi',
            'unit': '300 ml',
            'price': 30.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nnl.png',
          },
          {
            'productId': 'prod_fresh_paneer',
            'title': 'Fresh Paneer',
            'unit': '200 g',
            'price': 95.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nnp.png',
          },
          {
            'productId': 'prod_fresh_milk',
            'title': 'Fresh Milk',
            'unit': '500 ml',
            'price': 45.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nnd.png',
          },
          {
            'productId': 'prod_fresh_makhan',
            'title': 'Fresh Makhan',
            'unit': '100 g',
            'price': 60.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nnm.png',
          },
        ],
      }, 'order_test_123');

      expect(order.items[0].product.resolvedImageUrl, 'assets/images/nng.png');
      expect(order.items[1].product.resolvedImageUrl, 'assets/images/nnl.png');
      expect(order.items[2].product.resolvedImageUrl, 'assets/images/nnp.png');
      expect(order.items[3].product.resolvedImageUrl, 'assets/images/nnd.png');
      expect(order.items[4].product.resolvedImageUrl, 'assets/images/nnm.png');
    });

    test(
        'Existing Firestore orders with stale nnd.png image resolve to their correct product images',
        () {
      // Test the exact orders seen in the screenshot
      final orderWithStaleMilkImage = Order.fromFirestore({
        'status': 'cancelled',
        'subtotal': 670.0,
        'deliveryCharge': 0.0,
        'discount': 0.0,
        'totalAmount': 670.0,
        'items': [
          {
            'productId': '',
            'title': 'Fresh Paneer 200 g',
            'unit': '200 g',
            'price': 95.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nnd.png', // Stale default
          },
          {
            'productId': '',
            'title': 'Pure Ghee 1 L',
            'unit': '1 L',
            'price': 650.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nnd.png', // Stale default
          },
        ],
      }, 'GGhB3QDR2QU9jZQW0SEX');

      expect(orderWithStaleMilkImage.items[0].product.resolvedImageUrl,
          'assets/images/nnp.png');
      expect(orderWithStaleMilkImage.items[1].product.resolvedImageUrl,
          'assets/images/nng.png');

      final lassiMakhanOrder = Order.fromFirestore({
        'status': 'delivered',
        'subtotal': 120.0,
        'deliveryCharge': 0.0,
        'discount': 0.0,
        'totalAmount': 120.0,
        'items': [
          {
            'productId': '',
            'title': 'Fresh Lassi 300 ml',
            'unit': '300 ml',
            'price': 30.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nnd.png', // Stale default
          },
          {
            'productId': '',
            'title': 'Fresh Makhan 100 g',
            'unit': '100 g',
            'price': 60.0,
            'quantity': 1,
            'imageUrl': 'assets/images/nnd.png', // Stale default
          },
        ],
      }, 'n2mT73NMrm2UV2MgfSto');

      expect(lassiMakhanOrder.items[0].product.resolvedImageUrl,
          'assets/images/nnl.png');
      expect(lassiMakhanOrder.items[1].product.resolvedImageUrl,
          'assets/images/nnm.png');
    });
  });
}
