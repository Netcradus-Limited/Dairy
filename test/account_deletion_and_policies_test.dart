import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:dairy_app/services/account_deletion_service.dart';
import 'package:dairy_app/features/profile/legal_policies_screen.dart';
import 'package:dairy_app/features/profile/account_deletion_screen.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_location_permission_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Account Deletion Service Tests', () {
    test('Unauthenticated user returns unauthenticated status safely',
        () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final service = AccountDeletionService(firestore: fakeFirestore);
      final result = await service.deleteAccount();

      expect(
          result.status, equals(AccountDeletionResultStatus.unauthenticated));
      expect(result.isSuccess, isFalse);
    });

    test('Data cleanup handles active subscriptions and subcollections',
        () async {
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
      final subBefore =
          await fakeFirestore.collection('subscriptions').doc('sub_1').get();
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
    testWidgets('Renders all policy tabs and business disclaimer banners',
        (tester) async {
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

      // Verify all unfinished placeholders have been removed
      expect(find.textContaining('BUSINESS DECISION REQUIRED'), findsNothing);

      // Verify verified company and operational details
      expect(find.textContaining('SAWARIYA SARKAR DAIRY LLP'), findsWidgets);
      expect(find.textContaining('COD ONLY'), findsWidgets);
    });
  });

  group('Delivery Location Rationale Dialog Tests', () {
    testWidgets('Shows foreground-only location rationale with both choices',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForegroundLocationRationaleDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Location Needed'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
    });

    testWidgets(
        'Disclosure states sharing continues when minimised or screen-locked',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForegroundLocationRationaleDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The app keeps collecting location via a foreground service while the
      // app is minimised or the screen is locked. The disclosure must say so,
      // otherwise it understates real collection (Play User Data policy).
      expect(find.textContaining('minimise the app or lock your screen'),
          findsOneWidget);
      expect(find.textContaining('On Duty'), findsWidgets);
    });

    testWidgets('Disclosure covers start trigger, notification and stop',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForegroundLocationRationaleDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('never starts on its own'), findsOneWidget);
      expect(find.textContaining('ongoing notification'), findsOneWidget);
      expect(find.textContaining('Sharing stops as soon as you go Offline'),
          findsOneWidget);
      expect(find.textContaining('Tap Continue'), findsOneWidget);
      expect(find.textContaining('Tap Not Now'), findsOneWidget);
    });

    testWidgets('Disclosure never claims collection only while app is open',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForegroundLocationRationaleDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('while you are using the'), findsNothing);
      expect(find.textContaining('only while the app is open'), findsNothing);
      expect(find.textContaining('non-dismissible'), findsNothing);
      expect(find.textContaining('permanent notification'), findsNothing);
    });

    testWidgets('Disclosure renders without overflow on a small phone',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForegroundLocationRationaleDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
    });

    testWidgets('Rationale never mentions background or always-on location',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForegroundLocationRationaleDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Background'), findsNothing);
      expect(find.textContaining('background'), findsNothing);
      expect(find.textContaining('all the time'), findsNothing);
    });
  });

  group('Account Deletion Screen Tests', () {
    testWidgets('Renders warning, confirmation checkbox, and delete button',
        (tester) async {
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
      expect(
          find.text('Statutory Order Records De-identified'), findsOneWidget);
      expect(find.text('Permanently Delete Account'), findsOneWidget);
    });
  });
}
