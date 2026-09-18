import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/core/constants/app_assets.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/product_model.dart';
import 'package:dairy_app/models/order.dart';

void main() {
  group('Asset Path Normalization & Rules', () {
    test('assets/images/milk.png is preserved and not doubled', () {
      expect(
        AppAssets.normalizeAssetPath('assets/images/milk.png'),
        'assets/images/milk.png',
      );
    });

    test('images/milk.png is normalized to assets/images/milk.png', () {
      expect(
        AppAssets.normalizeAssetPath('images/milk.png'),
        'assets/images/milk.png',
      );
    });

    test('milk.png is normalized to assets/images/milk.png', () {
      expect(
        AppAssets.normalizeAssetPath('milk.png'),
        'assets/images/milk.png',
      );
    });

    test('assets/images/gheen.png is kept as single assets/ prefix', () {
      expect(
        AppAssets.normalizeAssetPath('assets/images/gheen.png'),
        'assets/images/gheen.png',
      );
    });

    test('images/gheen.png normalizes to assets/images/gheen.png', () {
      expect(
        AppAssets.normalizeAssetPath('images/gheen.png'),
        'assets/images/gheen.png',
      );
    });

    test('Duplicate assets/assets/ prefixes are stripped', () {
      expect(
        AppAssets.normalizeAssetPath('assets/assets/images/gheen.png'),
        'assets/images/gheen.png',
      );
      expect(
        AppAssets.normalizeAssetPath('assets/assets/images/milk.png'),
        'assets/images/milk.png',
      );
      expect(
        AppAssets.normalizeAssetPath('assets/assets/assets/images/paneernew.png'),
        'assets/images/paneernew.png',
      );
    });

    test('Remote URLs (http, https, gs) remain untouched without assets/ prefix', () {
      expect(
        AppAssets.normalizeAssetPath('https://example.com/ghee.png'),
        'https://example.com/ghee.png',
      );
      expect(
        AppAssets.normalizeAssetPath('http://example.com/images/milk.png'),
        'http://example.com/images/milk.png',
      );
      expect(
        AppAssets.normalizeAssetPath('gs://sawariya.appspot.com/products/ghee.png'),
        'gs://sawariya.appspot.com/products/ghee.png',
      );
    });

    test('Null and empty strings return empty string', () {
      expect(AppAssets.normalizeAssetPath(null), '');
      expect(AppAssets.normalizeAssetPath(''), '');
      expect(AppAssets.normalizeAssetPath('   '), '');
    });

    test('assets/assets/images/ is NEVER produced by any normalization', () {
      final samplePaths = [
        'assets/images/gheen.png',
        'images/gheen.png',
        'gheen.png',
        'assets/assets/images/gheen.png',
        'assets/images/lassi.png',
        'assets/images/paneernew.png',
        'assets/images/makhanew.png',
        'https://example.com/ghee.png',
        'gs://bucket/image.png',
      ];

      for (final p in samplePaths) {
        final normalized = AppAssets.normalizeAssetPath(p);
        expect(normalized.contains('assets/assets/'), isFalse);
      }
    });
  });

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

      const uple = Product(
        id: 'prod_uple',
        title: 'Organic Uple',
        categoryId: 'cat_uple',
        categoryName: 'Uple',
        price: 40,
        unit: '1 pc',
        imageUrl: '',
      );

      const water = Product(
        id: 'prod_water',
        title: 'Water Bottle 20L',
        categoryId: 'cat_water',
        categoryName: 'Water',
        price: 60,
        unit: '20 L',
        imageUrl: '',
      );

      // Verify exact mappings requested:
      // Pure Ghee -> assets/images/nng.png
      // Fresh Lassi -> assets/images/nnl.png
      // Fresh Paneer -> assets/images/nnp.png
      // Fresh Milk -> assets/images/nnd.png
      // Fresh Makhan -> assets/images/nnm.png
      // Uple -> assets/images/uple.png
      // Water -> assets/images/water.png
      expect(ghee.resolvedImageUrl, 'assets/images/nng.png');
      expect(lassi.resolvedImageUrl, 'assets/images/nnl.png');
      expect(paneer.resolvedImageUrl, 'assets/images/nnp.png');
      expect(milk.resolvedImageUrl, 'assets/images/nnd.png');
      expect(makhan.resolvedImageUrl, 'assets/images/nnm.png');
      expect(uple.resolvedImageUrl, 'assets/images/uple.png');
      expect(water.resolvedImageUrl, 'assets/images/water.png');

      expect(AppAssets.gheePng, 'assets/images/nng.png');
      expect(AppAssets.lassiPng, 'assets/images/nnl.png');
      expect(AppAssets.paneerPng, 'assets/images/nnp.png');
      expect(AppAssets.milkPng, 'assets/images/nnd.png');
      expect(AppAssets.makhanPng, 'assets/images/nnm.png');
      expect(AppAssets.uplePng, 'assets/images/uple.png');
      expect(AppAssets.waterPng, 'assets/images/water.png');
    });

    test('DairyProduct admin model resolves to the same verified images', () {
      const dpGhee = DairyProduct(
        id: 'prod_pure_ghee',
        name: 'Pure Ghee',
        subtitle: 'Pure cow ghee',
        category: 'Pure Ghee',
        unit: '1 L',
        price: 650,
        imageUrl: 'assets/images/gheen.png',
      );

      const dpLassi = DairyProduct(
        id: 'prod_fresh_lassi',
        name: 'Fresh Lassi',
        subtitle: 'Sweet lassi',
        category: 'Lassi',
        unit: '300 ml',
        price: 30,
        imageUrl: 'assets/images/lassi.png',
      );

      const dpMakhan = DairyProduct(
        id: 'prod_fresh_makhan',
        name: 'Fresh Makhan',
        subtitle: 'White butter',
        category: 'Makhan',
        unit: '100 g',
        price: 60,
        imageUrl: 'assets/images/makhanew.png',
      );

      const dpPaneer = DairyProduct(
        id: 'prod_fresh_paneer',
        name: 'Fresh Paneer',
        subtitle: 'Fresh cottage cheese',
        category: 'Paneer',
        unit: '200 g',
        price: 95,
        imageUrl: 'assets/images/paneernew.png',
      );

      const dpMilk = DairyProduct(
        id: 'prod_fresh_milk',
        name: 'Fresh Milk',
        subtitle: 'Farm fresh milk',
        category: 'Milk',
        unit: '500 ml',
        price: 45,
        imageUrl: 'assets/images/milk.png',
      );

      expect(dpGhee.resolvedImageUrl, 'assets/images/nng.png');
      expect(dpLassi.resolvedImageUrl, 'assets/images/nnl.png');
      expect(dpMakhan.resolvedImageUrl, 'assets/images/nnm.png');
      expect(dpPaneer.resolvedImageUrl, 'assets/images/nnp.png');
      expect(dpMilk.resolvedImageUrl, 'assets/images/nnd.png');
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

    test('AppAssets.productImage resolves legacy/unbundled asset names safely', () {
      expect(
        AppAssets.productImage(imageUrl: 'assets/images/gheen.png'),
        'assets/images/nng.png',
      );
      expect(
        AppAssets.productImage(imageUrl: 'assets/images/lassi.png'),
        'assets/images/nnl.png',
      );
      expect(
        AppAssets.productImage(imageUrl: 'assets/images/paneernew.png'),
        'assets/images/nnp.png',
      );
      expect(
        AppAssets.productImage(imageUrl: 'assets/images/makhanew.png'),
        'assets/images/nnm.png',
      );
    });

    test('AppAssets.productImage resolves correctly for titles and categories', () {
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
