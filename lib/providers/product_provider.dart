import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../repositories/firestore_product_repository.dart';

export 'cart_provider.dart';

/// Provides the Cloud Firestore-backed product/category repository.
///
/// Auto-seeding is disabled here: this provider backs customer-facing screens,
/// and customers cannot write the catalog under Firestore rules. Missing
/// defaults are already merged client-side by the repository streams. Seeding
/// of default catalog documents runs from `AdminProvider` (admin routes only).
final firestoreProductRepoProvider =
    Provider<FirestoreProductRepository>((ref) {
  return FirestoreProductRepository(null, false);
});

// ─── Category stream from Firestore ─────────────────────────────────────────

/// Real-time stream of categories from the Firestore `categories` collection.
/// Emits an empty list on error so the UI can render gracefully.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref
      .watch(firestoreProductRepoProvider)
      .streamCategories()
      .handleError((_) => <Category>[]);
});

// ─── Product streams from Firestore ─────────────────────────────────────────

/// Real-time stream of all products from the Firestore `products` collection.
/// Emits an empty list on error so the UI can render gracefully.
final allProductsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref
      .watch(firestoreProductRepoProvider)
      .streamProducts()
      .handleError((_) => <Product>[]);
});

/// Convenience provider that exposes the current product list as a plain
/// [List<Product>] (empty when loading or on error).  Consumer screens that
/// only need the list without [AsyncValue] machinery can watch this.
final allProductsProvider = Provider<List<Product>>((ref) {
  return ref.watch(allProductsStreamProvider).valueOrNull ?? [];
});

/// Products flagged as fresh deals in Firestore.
final freshDealsProvider = Provider<List<Product>>((ref) {
  return ref
          .watch(allProductsStreamProvider)
          .valueOrNull
          ?.where((p) => p.isFreshDeal)
          .toList() ??
      [];
});

/// Products flagged as A2 cow milk in Firestore.
final a2ProductsProvider = Provider<List<Product>>((ref) {
  return ref
          .watch(allProductsStreamProvider)
          .valueOrNull
          ?.where((p) => p.isA2CowMilk)
          .toList() ??
      [];
});

/// Products flagged as best sellers in Firestore.
final bestSellersProvider = Provider<List<Product>>((ref) {
  return ref
          .watch(allProductsStreamProvider)
          .valueOrNull
          ?.where((p) => p.isBestSeller)
          .toList() ??
      [];
});

final selectedCategoryProvider = StateProvider<String>((ref) {
  return 'cat_all';
});

/// Global search query provider for products
final productSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});
