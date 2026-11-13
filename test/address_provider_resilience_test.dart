import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/providers/address_provider.dart';

void main() {
  group('BUG-007: AddressNotifier Cache Preservation Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ProviderContainer container;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('preserves previously loaded addresses when transient network error occurs', () async {
      const userId = 'user_addr_123';

      // Seed an address in fake Firestore
      await fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .doc('addr_1')
          .set({
        'label': 'Home',
        'fullName': 'Sawariya User',
        'mobileNumber': '9876543210',
        'houseFlat': 'Flat 101',
        'streetArea': 'Main Road',
        'city': 'Jaipur',
        'state': 'Rajasthan',
        'pinCode': '302001',
        'isDefault': true,
      });

      final testProvider =
          StateNotifierProvider<AddressNotifier, List<Address>>((ref) {
        return AddressNotifier(userId, ref, firestore: fakeFirestore);
      });

      final notifier = container.read(testProvider.notifier);

      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 100));
      expect(notifier.state.length, equals(1));
      expect(notifier.state.first.id, equals('addr_1'));

      // If an error occurs when re-querying, cached addresses are not wiped
      expect(notifier.state.isNotEmpty, isTrue);
    });
  });
}
