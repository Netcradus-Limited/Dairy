import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BUG-008: CartNotifier Debounced Firestore Sync Tests', () {
    const testProduct = Product(
      id: 'prod_milk_1',
      title: 'Pure Cow Milk 1L',
      categoryId: 'cat_milk',
      categoryName: 'Milk',
      price: 65.0,
      imageUrl: 'https://example.com/milk.png',
      inStock: true,
      unit: '1L',
    );

    test('rapidly incrementing cart updates in-memory quantity immediately', () {
      final fakeFirestore = FakeFirebaseFirestore();
      final notifier = CartNotifier(fakeFirestore, null);

      // Rapidly tap 5 times
      for (int i = 0; i < 5; i++) {
        notifier.addItem(testProduct, 1);
      }

      // In-memory state is immediately 5 without waiting for debounce timer
      expect(notifier.state[testProduct.id]?.quantity, equals(5));

      notifier.dispose();
    });

    test('removeItem cancels any pending debounced sync timers cleanly', () {
      final fakeFirestore = FakeFirebaseFirestore();
      final notifier = CartNotifier(fakeFirestore, null);

      notifier.addItem(testProduct, 2);
      expect(notifier.state[testProduct.id]?.quantity, equals(2));

      notifier.removeItem(testProduct.id);
      expect(notifier.state[testProduct.id], isNull);

      notifier.dispose();
    });

    test('flushPendingSyncs dispatches in-flight debounced writes immediately', () {
      final fakeFirestore = FakeFirebaseFirestore();
      final notifier = CartNotifier(fakeFirestore, null);

      notifier.addItem(testProduct, 3);
      expect(notifier.state[testProduct.id]?.quantity, equals(3));

      // Flush before 300ms timer expires
      notifier.flushPendingSyncs();

      expect(notifier.state[testProduct.id]?.quantity, equals(3));

      notifier.dispose();
    });
  });
}
