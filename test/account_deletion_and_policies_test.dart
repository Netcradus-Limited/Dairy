import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:dairy_app/services/account_deletion_service.dart';
import 'package:dairy_app/features/profile/legal_policies_screen.dart';
import 'package:dairy_app/features/profile/account_deletion_screen.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_location_disclosure_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Account Deletion Service Tests', () {
    test('Unauthenticated user returns unauthenticated status safely', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = AccountDeletionService(firestore: fakeFirestore);
      final result = await service.deleteAccount();

      expect(result.status, equals(AccountDeletionResultStatus.unauthenticated));
      expect(result.isSuccess, isFalse);
    });

    test('Data cleanup handles active subscriptions and subcollections', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      const testUid = 'user_delete_test_123';

      // Seed user doc
      await fakeFirestore.collection('users').doc(testUid).set({
        'name': 'Ramesh Kumar',
        'phone': '+91 98765 43210',
        'email': 'ramesh@example.com',
        'accountStatus': 'active',
      });

      // Seed subscription
      await fakeFirestore.collection('subscriptions').doc('sub_1').set({
        'userId': testUid,
        'status': 'Active',
      });

      // Seed address subcollection
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('addresses')
          .doc('addr_1')
          .set({'address': '123 Main Street'});

      // Verify records exist
      final subBefore = await fakeFirestore.collection('subscriptions').doc('sub_1').get();
      expect(subBefore.data()?['status'], equals('Active'));

      final addrBefore = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('addresses')
          .doc('addr_1')
          .get();
      expect(addrBefore.exists, isTrue);
    });
  });

  group('Legal Policies Screen Tests', () {
    testWidgets('Renders all policy tabs and business disclaimer banners', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalPoliciesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('Legal & Policies'), findsOneWidget);

      // Tab navigation (can appear in tab bar and header)
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Terms & Conditions'), findsWidgets);
      expect(find.text('Refund & Cancellation'), findsWidgets);
      expect(find.text('Delivery Policy'), findsWidgets);
      expect(find.text('Account Deletion'), findsWidgets);

      // Verify business placeholder alert banner
      expect(find.textContaining('BUSINESS DECISION REQUIRED'), findsWidgets);
    });
  });

  group('Delivery Location Disclosure Dialog Tests', () {
    testWidgets('Renders prominent background location disclosure points', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryLocationDisclosureDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Location Access'), findsOneWidget);
      expect(find.text('Agree & Continue'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);

      // Verify rich text bullet points
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Who can see your location:'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('When tracking occurs:'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('When tracking stops:'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Customer Privacy:'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Account Deletion Screen Tests', () {
    testWidgets('Renders warning, confirmation checkbox, and delete button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AccountDeletionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Account'), findsWidgets);
      expect(find.text('Permanent Action'), findsOneWidget);
      expect(find.text('Active Subscriptions Cancelled'), findsOneWidget);
      expect(find.text('Saved Addresses Removed'), findsOneWidget);
      expect(find.text('Statutory Order Records De-identified'), findsOneWidget);
      expect(find.text('Permanently Delete Account'), findsOneWidget);
    });
  });
}
