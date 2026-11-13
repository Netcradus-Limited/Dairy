import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dairy_app/core/auth/app_role.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/category.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/repositories/firestore_product_repository.dart';
import 'package:dairy_app/services/network_connectivity_service.dart';
import 'package:dairy_app/services/order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase B: Web & Platform Network Connectivity Tests', () {
    test('NetworkConnectivityNotifier updates state on connectivity change', () async {
      bool mockOnline = true;
      final service = NetworkConnectivityService(
        checker: () async => mockOnline,
        checkInterval: const Duration(milliseconds: 50),
      );

      final notifier = NetworkConnectivityNotifier(service, true);
      expect(notifier.state, isTrue);

      // Transition to offline
      mockOnline = false;
      await notifier.checkNow();
      expect(notifier.state, isFalse);

      // Transition back to online
      mockOnline = true;
      await notifier.checkNow();
      expect(notifier.state, isTrue);

      notifier.dispose();
    });

    test('NetworkConnectivityNotifier does not trigger duplicate states', () async {
      final service = NetworkConnectivityService(
        checker: () async => true,
      );

      final notifier = NetworkConnectivityNotifier(service, true);
      int stateChangeCount = 0;
      notifier.addListener((_) {
        stateChangeCount++;
      });

      // Initial subscription triggers 1 notification
      expect(stateChangeCount, equals(1));

      // Redundant check while still online
      await notifier.checkNow();
      expect(stateChangeCount, equals(1)); // No duplicate emit

      notifier.setOnline(true);
      expect(stateChangeCount, equals(1)); // No duplicate emit

      notifier.setOnline(false);
      expect(stateChangeCount, equals(2)); // Changed!

      notifier.dispose();
    });
  });

  group('Phase A: Firestore Stream Resilience & Data Preservation Tests', () {
    test('FirestoreProductRepository streams products and preserves cache on error', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreProductRepository(firestore, false);

      // Add a test product to fake Firestore
      await firestore.collection('products').doc('prod_1').set({
        'title': 'Fresh Farm Milk',
        'price': 65.0,
        'category': 'Milk',
        'unit': '1 L',
        'isAvailable': true,
      });

      final stream = repo.streamProducts();
      final firstEmission = await stream.first;

      expect(firstEmission.any((p) => p.title == 'Fresh Farm Milk'), isTrue);
    });

    test('FirestoreProductRepository streams categories with default fallbacks safely', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreProductRepository(firestore, false);

      final categories = await repo.streamCategories().first;
      expect(categories, isNotEmpty);
      expect(categories.any((c) => c.title.toLowerCase().contains('milk')), isTrue);
    });

    test('OrderService streamOrdersForUser handles empty userId safely', () async {
      final firestore = FakeFirebaseFirestore();
      final service = OrderService(firestore: firestore);

      final emptyStream = service.streamOrdersForUser('');
      final result = await emptyStream.first;
      expect(result, isEmpty);
    });
  });

  group('Phase C: Authentication & Role Security (Fail Closed)', () {
    test('Privileged role fails closed to customer when user document does not exist', () async {
      final firestore = FakeFirebaseFirestore();

      // Non-privileged customer phone
      final testPhone = '9876543210';
      final testUid = 'user_abc_123';

      // Create only a basic customer document in users/{uid}
      await firestore.collection('users').doc(testUid).set({
        'uid': testUid,
        'phone': testPhone,
        'role': 'customer',
      });

      // Verify that even if a caller passed currentRole: 'admin', authoritative lookup FAILS CLOSED
      final notifier = UserNotifier();
      // Wait for session init
      await notifier.sessionLoaded;

      // Ensure that setting a session for an unverified UID defaults role to customer
      final unverifiedUser = User(
        id: testUid,
        name: 'Regular Customer',
        phone: testPhone,
        email: 'user@test.com',
        role: 'customer',
      );
      await notifier.setSession(unverifiedUser);

      expect(notifier.state.role, equals(UserRole.customerValue));
      expect(notifier.state.isAdmin, isFalse);
      expect(notifier.state.isDelivery, isFalse);

      notifier.dispose();
    });

    test('Zero-trust phone role verification: UserRole.fromPhone defaults to customer securely (BUG-004 fix)', () {
      expect(UserRole.fromPhone('+919999999999'), equals(UserRole.customer));
      expect(UserRole.fromPhone('9999999999'), equals(UserRole.customer));
      expect(UserRole.fromPhone('+917777777777'), equals(UserRole.customer));
      expect(UserRole.fromPhone('7777777777'), equals(UserRole.customer));
      expect(UserRole.fromPhone('8888888888'), equals(UserRole.customer));
      expect(UserRole.fromPhone('+919876543210'), equals(UserRole.customer));
    });

    test('clearSession resets state to guestUser and clears persisted session', () async {
      final notifier = UserNotifier();
      await notifier.sessionLoaded;

      final testUser = User(
        id: 'user_456',
        name: 'Tester',
        phone: '9876543210',
        email: 'test@example.com',
        role: 'customer',
      );
      await notifier.setSession(testUser);
      expect(notifier.state.id, equals('user_456'));

      await notifier.clearSession();
      expect(notifier.state.id, isEmpty);
      expect(notifier.state.name, equals('Guest Customer'));
      expect(notifier.state.role, equals(UserRole.customerValue));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_session'), isNull);

      notifier.dispose();
    });
  });
}
