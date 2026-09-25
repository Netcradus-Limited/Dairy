import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/category.dart';

/// Fetches dairy products, categories, and prices from Cloud Firestore.
///
/// Expected Firestore collections:
///   products/{productId}   -> Product.toFirestore()
///   categories/{categoryId} -> Category.toFirestore()
class FirestoreProductRepository {
  final FirebaseFirestore? _firestore;

  static bool _hasSeededDefaults = false;

  FirestoreProductRepository(
      [FirebaseFirestore? firestore, bool autoSeed = true])
      : _firestore = firestore {
    if (autoSeed && !_hasSeededDefaults && _canAccessFirestore()) {
      _hasSeededDefaults = true;
      unawaited(seedDefaultsIfNeeded());
    }
  }

  static bool _canAccessFirestore() {
    try {
      FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection('categories');

  // ─── Merging Helpers for Missing Defaults ─────────────────────────────────

  static List<Category> _mergeMissingDefaultCategories(List<Category> list) {
    final existingIds = {for (final c in list) c.id};
    final merged = List<Category>.from(list);
    for (final entry in _defaultCategories.entries) {
      if (!existingIds.contains(entry.key)) {
        merged.add(Category.fromFirestore(entry.value, entry.key));
      }
    }
    return merged;
  }

  static List<Map<String, dynamic>> _mergeMissingDefaultRawCategories(
      List<Map<String, dynamic>> list) {
    final existingIds = {for (final c in list) c['id'] as String?};
    final merged = List<Map<String, dynamic>>.from(list);
    for (final entry in _defaultCategories.entries) {
      if (!existingIds.contains(entry.key)) {
        merged.add({'id': entry.key, ...entry.value});
      }
    }
    return merged;
  }

  static List<Product> _mergeMissingDefaultProducts(List<Product> list) {
    final existingIds = {for (final p in list) p.id};
    final merged = List<Product>.from(list);
    for (final entry in _defaultProducts.entries) {
      if (!existingIds.contains(entry.key)) {
        merged.add(Product.fromFirestore(entry.value, entry.key));
      }
    }
    return merged;
  }

  static List<Map<String, dynamic>> _mergeMissingDefaultRawProducts(
      List<Map<String, dynamic>> list) {
    final existingIds = {for (final p in list) p['id'] as String?};
    final merged = List<Map<String, dynamic>>.from(list);
    for (final entry in _defaultProducts.entries) {
      if (!existingIds.contains(entry.key)) {
        merged.add({'id': entry.key, ...entry.value});
      }
    }
    return merged;
  }

  // ─── Streams ─────────────────────────────────────────────────────────────

  /// Real-time stream of all products (with missing default products safely merged).
  Stream<List<Product>> streamProducts() {
    try {
      return _products.snapshots().map((snap) => _mergeMissingDefaultProducts(
          snap.docs
              .map((d) => Product.fromFirestore(d.data(), d.id))
              .toList()));
    } catch (_) {
      return Stream.value(_mergeMissingDefaultProducts([]));
    }
  }

  /// Real-time stream of active categories for customers, sorted by sortOrder
  /// (with missing default categories safely merged).
  Stream<List<Category>> streamCategories() {
    try {
      return _categories.snapshots().map((snap) {
        final list = snap.docs
            .map((d) => Category.fromFirestore(d.data(), d.id))
            .toList();
        final merged = _mergeMissingDefaultCategories(list);
        final active = merged.where((c) => c.isActive).toList();
        active.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return active;
      });
    } catch (_) {
      final merged = _mergeMissingDefaultCategories([]);
      final active = merged.where((c) => c.isActive).toList();
      active.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return Stream.value(active);
    }
  }

  /// Real-time stream of raw product documents.
  ///
  /// Each map contains the full Firestore fields **plus** an `'id'` key.
  /// Used by the Admin Panel to read admin-only fields (fatContent,
  /// packaging, emoji, stockQuantity, etc.) that are not part of the
  /// customer-facing [Product] model.
  Stream<List<Map<String, dynamic>>> streamRawProducts() {
    try {
      return _products.snapshots().map((snap) =>
          _mergeMissingDefaultRawProducts(
              snap.docs.map((d) => {...d.data(), 'id': d.id}).toList()));
    } catch (_) {
      return Stream.value(_mergeMissingDefaultRawProducts([]));
    }
  }

  /// Real-time stream of raw category documents (with `'id'` key), sorted by sortOrder.
  Stream<List<Map<String, dynamic>>> streamRawCategories() {
    try {
      return _categories.snapshots().map((snap) {
        final list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        final merged = _mergeMissingDefaultRawCategories(list);
        merged.sort((a, b) {
          final sortA = (a['sortOrder'] as num?)?.toInt() ?? 0;
          final sortB = (b['sortOrder'] as num?)?.toInt() ?? 0;
          return sortA.compareTo(sortB);
        });
        return merged;
      });
    } catch (_) {
      return Stream.value(_mergeMissingDefaultRawCategories([]));
    }
  }

  // ─── One-time fetches ────────────────────────────────────────────────────

  /// One-time fetch of all products (useful with a [FutureBuilder]).
  Future<List<Product>> fetchProducts() async {
    final snap = await _products.get();
    final list =
        snap.docs.map((d) => Product.fromFirestore(d.data(), d.id)).toList();
    return _mergeMissingDefaultProducts(list);
  }

  /// One-time fetch of active categories (useful with a [FutureBuilder]), sorted by sortOrder.
  Future<List<Category>> fetchCategories() async {
    final snap = await _categories.get();
    final list =
        snap.docs.map((d) => Category.fromFirestore(d.data(), d.id)).toList();
    final merged = _mergeMissingDefaultCategories(list);
    final active = merged.where((c) => c.isActive).toList();
    active.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return active;
  }

  // ─── Writes ──────────────────────────────────────────────────────────────

  /// Writes (or overwrites) a product document.
  Future<void> setProduct(Product product) =>
      _products.doc(product.id).set(product.toFirestore());

  /// Writes (or overwrites) a product document from a raw map.
  ///
  /// Allows the Admin Panel to store extra fields beyond the [Product] model
  /// (e.g. fatContent, packaging, emoji, stockQuantity).
  Future<void> setProductRaw(String id, Map<String, dynamic> data) =>
      _products.doc(id).set(data, SetOptions(merge: true));

  /// Writes (or overwrites) a category document.
  Future<void> setCategory(Category category) =>
      _categories.doc(category.id).set(category.toFirestore());

  /// Writes (or overwrites) a category document from a raw map.
  Future<void> setCategoryRaw(String id, Map<String, dynamic> data) =>
      _categories.doc(id).set(data, SetOptions(merge: true));

  // ─── Deletes ─────────────────────────────────────────────────────────────

  /// Deletes a product document by [id].
  Future<void> deleteProduct(String id) => _products.doc(id).delete();

  /// Deletes a category document by [id].
  Future<void> deleteCategory(String id) => _categories.doc(id).delete();

  // ─── Default seeding ─────────────────────────────────────────────────────

  /// Safely seeds missing default categories and products (including Uple & Water)
  /// to Firestore.  Uses `SetOptions(merge: true)` with deterministic IDs so it
  /// never overwrites existing modified data or duplicates records.
  Future<void> seedDefaultsIfNeeded() async {
    try {
      final batch = _db.batch();
      bool hasWrites = false;

      for (final entry in _defaultCategories.entries) {
        final doc = await _categories.doc(entry.key).get();
        if (!doc.exists) {
          batch.set(
            _categories.doc(entry.key),
            entry.value,
            SetOptions(merge: true),
          );
          hasWrites = true;
        }
      }

      for (final entry in _defaultProducts.entries) {
        final doc = await _products.doc(entry.key).get();
        if (!doc.exists) {
          batch.set(
            _products.doc(entry.key),
            entry.value,
            SetOptions(merge: true),
          );
          hasWrites = true;
        }
      }

      if (hasWrites) {
        await batch.commit();
        developer.log(
          'Missing default categories & products seeded to Firestore successfully.',
          name: 'FirestoreProductRepository',
        );
      }
    } catch (e) {
      developer.log(
        'seedDefaultsIfNeeded failed (non-fatal): $e',
        name: 'FirestoreProductRepository',
      );
    }
  }
}

// ─── Default seed data ───────────────────────────────────────────────────────
//
// Maps are kept outside the class to keep the repository file focused on
// Firestore access.  Every document uses deterministic IDs so the seed is
// naturally idempotent even without the config-gate check.
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Map<String, dynamic>> _defaultCategories = {
  'cat_milk': {
    'title': 'Milk',
    'subtitle': '100% Pure & Fresh',
    'imageUrl': 'assets/images/doodh.png',
    'iconName': 'milk',
    'colorValue': 0xFFEAF5FF,
    'itemCount': 1,
    'name': 'Milk',
    'description': '100% Pure & Fresh',
    'productCount': 1,
    'emoji': '🥛',
    'isActive': true,
    'sortOrder': 0,
    'subscriptionEnabled': true,
  },
  'cat_paneer': {
    'title': 'Paneer',
    'subtitle': 'Soft & Delicious',
    'imageUrl': 'assets/images/pan.png',
    'iconName': 'paneer',
    'colorValue': 0xFFFFF5EA,
    'itemCount': 1,
    'name': 'Paneer',
    'description': 'Soft & Delicious',
    'productCount': 1,
    'emoji': '🧀',
    'isActive': true,
    'sortOrder': 1,
    'subscriptionEnabled': true,
  },
  'cat_ghee': {
    'title': 'Pure Ghee',
    'subtitle': 'Premium Quality',
    'imageUrl': 'assets/images/newgh.png',
    'iconName': 'ghee',
    'colorValue': 0xFFFFF9EE,
    'itemCount': 1,
    'name': 'Pure Ghee',
    'description': 'Premium Quality',
    'productCount': 1,
    'emoji': '🍯',
    'isActive': true,
    'sortOrder': 2,
    'subscriptionEnabled': true,
  },
  'cat_lassi': {
    'title': 'Lassi',
    'subtitle': 'Refreshing & Tasty',
    'imageUrl': 'assets/images/las.png',
    'iconName': 'lassi',
    'colorValue': 0xFFEBF3FE,
    'itemCount': 1,
    'name': 'Lassi',
    'description': 'Refreshing & Tasty',
    'productCount': 1,
    'emoji': '🥛',
    'isActive': true,
    'sortOrder': 3,
    'subscriptionEnabled': true,
  },
  'cat_makhan': {
    'title': 'Makhan',
    'subtitle': 'Thick & Healthy',
    'imageUrl': 'assets/images/mak.png',
    'iconName': 'makhan',
    'colorValue': 0xFFF0F9F4,
    'itemCount': 1,
    'name': 'Makhan',
    'description': 'Thick & Healthy',
    'productCount': 1,
    'emoji': '🧈',
    'isActive': true,
    'sortOrder': 4,
    'subscriptionEnabled': true,
  },
  'cat_uple': {
    'title': 'Uple',
    'subtitle': 'Organic Uple',
    'imageUrl': 'assets/images/u3.png',
    'iconName': 'uple',
    'colorValue': 0xFFFFF5EA,
    'itemCount': 1,
    'name': 'Uple',
    'description': 'Organic Uple',
    'productCount': 1,
    'emoji': '🟤',
    'isActive': true,
    'sortOrder': 5,
    'subscriptionEnabled': false,
  },
  'cat_water': {
    'title': 'Water',
    'subtitle': '20L Water Bottle',
    'imageUrl': 'assets/images/w3.png',
    'iconName': 'water',
    'colorValue': 0xFFEAF5FF,
    'itemCount': 1,
    'name': 'Water',
    'description': 'Pure 20L Water Bottle',
    'productCount': 1,
    'emoji': '💧',
    'isActive': true,
    'sortOrder': 6,
    'subscriptionEnabled': false,
  },
};

const Map<String, Map<String, dynamic>> _defaultProducts = {
  'prod_fresh_milk': {
    'title': 'Fresh Milk',
    'categoryId': 'cat_milk',
    'categoryName': 'Milk',
    'price': 45.0,
    'originalPrice': null,
    'unit': '500 ml',
    'imageUrl': 'assets/images/nnd.png',
    'description': 'Pure fresh milk sourced daily from healthy cows.',
    'rating': 4.8,
    'reviewCount': 120,
    'isFreshDeal': true,
    'isBestSeller': true,
    'isA2CowMilk': false,
    'inStock': true,
    'subscriptionEnabled': true,
    'fatContent': '3.5% Fat',
    'packaging': 'Fresh Pouch',
    'emoji': '🥛',
    'stockQuantity': 100,
    'ordersCount': 0,
    'totalRevenue': 0.0,
  },
  'prod_fresh_paneer': {
    'title': 'Fresh Paneer',
    'categoryId': 'cat_paneer',
    'categoryName': 'Paneer',
    'price': 95.0,
    'originalPrice': null,
    'unit': '200 g',
    'imageUrl': 'assets/images/nnp.png',
    'description':
        'Ultra-soft, protein-rich fresh cottage cheese prepared daily.',
    'rating': 4.8,
    'reviewCount': 210,
    'isFreshDeal': false,
    'isBestSeller': true,
    'isA2CowMilk': false,
    'inStock': true,
    'subscriptionEnabled': true,
    'fatContent': '',
    'packaging': 'Fresh Pack',
    'emoji': '🧀',
    'stockQuantity': 80,
    'ordersCount': 0,
    'totalRevenue': 0.0,
  },
  'prod_pure_ghee': {
    'title': 'Pure Ghee',
    'categoryId': 'cat_ghee',
    'categoryName': 'Pure Ghee',
    'price': 650.0,
    'originalPrice': 720.0,
    'unit': '1 L',
    'imageUrl': 'assets/images/nng.png',
    'description':
        'Traditional bilona method pure cow ghee with rich granular texture and aroma.',
    'rating': 5.0,
    'reviewCount': 512,
    'isFreshDeal': true,
    'isBestSeller': true,
    'isA2CowMilk': false,
    'inStock': true,
    'subscriptionEnabled': true,
    'fatContent': '',
    'packaging': 'Glass Jar',
    'emoji': '🍯',
    'stockQuantity': 50,
    'ordersCount': 0,
    'totalRevenue': 0.0,
  },
  'prod_fresh_lassi': {
    'title': 'Fresh Lassi',
    'categoryId': 'cat_lassi',
    'categoryName': 'Lassi',
    'price': 30.0,
    'originalPrice': 35.0,
    'unit': '300 ml',
    'imageUrl': 'assets/images/nnl.png',
    'description': 'Thick, creamy, and refreshing probiotic sweet lassi.',
    'rating': 4.8,
    'reviewCount': 195,
    'isFreshDeal': false,
    'isBestSeller': true,
    'isA2CowMilk': false,
    'inStock': true,
    'subscriptionEnabled': true,
    'fatContent': '',
    'packaging': 'Fresh Bottle',
    'emoji': '🥛',
    'stockQuantity': 60,
    'ordersCount': 0,
    'totalRevenue': 0.0,
  },
  'prod_fresh_makhan': {
    'title': 'Fresh Makhan',
    'categoryId': 'cat_makhan',
    'categoryName': 'Makhan',
    'price': 60.0,
    'originalPrice': 65.0,
    'unit': '100 g',
    'imageUrl': 'assets/images/nnm.png',
    'description': 'Freshly churned creamy unsalted table butter.',
    'rating': 4.7,
    'reviewCount': 140,
    'isFreshDeal': false,
    'isBestSeller': true,
    'isA2CowMilk': false,
    'inStock': true,
    'subscriptionEnabled': true,
    'fatContent': '',
    'packaging': 'Fresh Pack',
    'emoji': '🧈',
    'stockQuantity': 70,
    'ordersCount': 0,
    'totalRevenue': 0.0,
  },
  'prod_uple': {
    'title': 'Organic Uple',
    'categoryId': 'cat_uple',
    'categoryName': 'Uple',
    'price': 40.0,
    'originalPrice': null,
    'unit': '1 pc',
    'imageUrl': 'assets/images/uple.png',
    'description': 'Premium organic cow dung cakes for pooja and rituals.',
    'rating': 4.8,
    'reviewCount': 60,
    'isFreshDeal': false,
    'isBestSeller': true,
    'isA2CowMilk': false,
    'inStock': true,
    'subscriptionEnabled': false,
    'fatContent': '',
    'packaging': 'Eco Pack',
    'emoji': '🟤',
    'stockQuantity': 120,
    'ordersCount': 0,
    'totalRevenue': 0.0,
  },
  'prod_water': {
    'title': 'Water Bottle 20L',
    'categoryId': 'cat_water',
    'categoryName': 'Water',
    'price': 60.0,
    'originalPrice': null,
    'unit': '20 L',
    'imageUrl': 'assets/images/water.png',
    'description': 'Pure and safe 20L water bottle delivered to your doorstep.',
    'rating': 4.7,
    'reviewCount': 85,
    'isFreshDeal': false,
    'isBestSeller': true,
    'isA2CowMilk': false,
    'inStock': true,
    'subscriptionEnabled': false,
    'fatContent': '',
    'packaging': 'Bottle',
    'emoji': '💧',
    'stockQuantity': 90,
    'ordersCount': 0,
    'totalRevenue': 0.0,
  },
};
