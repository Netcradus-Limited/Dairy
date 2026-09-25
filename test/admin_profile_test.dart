import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as provider;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dairy_app/core/auth/app_role.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/admin_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/screens/admin_main_shell.dart';
import 'package:dairy_app/screens/profile/admin_profile_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testAdmin = User(
    id: 'admin_usr_001',
    name: 'Vikram Singh',
    phone: '+91 98765 43210',
    email: 'vikram@sawariyadairy.com',
    profileImageUrl: 'https://firebasestorage.googleapis.com/sample_admin.jpg',
    role: UserRole.adminValue,
  );

  const nonAdminCustomer = User(
    id: 'cust_001',
    name: 'Customer User',
    phone: '+91 91234 56789',
    email: 'customer@example.com',
    role: UserRole.customerValue,
  );

  Widget createAdminProfileTestWidget({
    required ProviderContainer container,
    AdminProvider? adminProvider,
  }) {
    final prov = adminProvider ?? (AdminProvider()..setNavIndex(11));
    return UncontrolledProviderScope(
      container: container,
      child: provider.ChangeNotifierProvider<AdminProvider>.value(
        value: prov,
        child: const MaterialApp(
          home: Scaffold(
            body: AdminProfileScreen(),
          ),
        ),
      ),
    );
  }

  Widget createAdminShellTestWidget({
    required ProviderContainer container,
    required AdminProvider adminProvider,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: provider.ChangeNotifierProvider<AdminProvider>.value(
        value: adminProvider,
        child: const MaterialApp(
          home: AdminMainShell(),
        ),
      ),
    );
  }

  group('Task 3 — Admin Profile & Account Management Tests', () {
    testWidgets(
        '1. Admin profile loads and displays authenticated admin details',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setSession(testAdmin);

      await tester
          .pumpWidget(createAdminProfileTestWidget(container: container));
      await tester.pumpAndSettle();

      // Verify title, admin name, email, and super admin badge
      expect(find.text('Admin Profile & Account'), findsOneWidget);
      expect(find.text('Vikram Singh'), findsWidgets);
      expect(find.text('vikram@sawariyadairy.com'), findsWidgets);
      expect(find.text('Super Admin'), findsWidgets);
      expect(find.text('UID: admin_usr_001'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Save Profile Changes'), findsOneWidget);
    });

    testWidgets(
        '2. Admin full name can be updated and syncs immediately to provider',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setSession(testAdmin);

      await tester
          .pumpWidget(createAdminProfileTestWidget(container: container));
      await tester.pumpAndSettle();

      // Clear existing name and enter updated name
      final nameFields = find.byType(TextFormField);
      expect(nameFields, findsWidgets);

      await tester.enterText(nameFields.first, 'Vikramaditya Singh');
      await tester.pumpAndSettle();

      // Tap Save Profile Changes
      await tester.tap(find.text('Save Profile Changes'));
      await tester.pumpAndSettle();

      // Verify Riverpod userProvider received updated name
      expect(container.read(userProvider).name, equals('Vikramaditya Singh'));
      expect(find.text('Vikramaditya Singh'), findsWidgets);
    });

    testWidgets('3. Profile image URL updates and updates Riverpod state',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setSession(testAdmin);

      await tester
          .pumpWidget(createAdminProfileTestWidget(container: container));
      await tester.pumpAndSettle();

      const newImageUrl =
          'https://firebasestorage.googleapis.com/new_admin_avatar.png';
      await container.read(userProvider.notifier).updateProfile(
            profileImageUrl: newImageUrl,
          );
      await tester.pumpAndSettle();

      expect(container.read(userProvider).profileImageUrl, equals(newImageUrl));
    });

    testWidgets(
        '4. Admin role is strictly preserved and cannot be escalated/changed',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setSession(testAdmin);

      // Perform profile update
      await container.read(userProvider.notifier).updateProfile(
            name: 'Vikram Singh Executive',
          );

      final updated = container.read(userProvider);
      expect(updated.role, equals(UserRole.adminValue));
      expect(updated.isAdmin, isTrue);
      expect(updated.isCustomer, isFalse);
    });

    testWidgets(
        '5. Non-admin access to AdminMainShell is rejected with Access Denied',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setSession(nonAdminCustomer);

      final adminProvider = AdminProvider();
      await tester.pumpWidget(
        createAdminShellTestWidget(
          container: container,
          adminProvider: adminProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Return to Safe Screen'), findsOneWidget);
    });

    testWidgets(
        '6. AdminMainShell renders AdminProfileScreen on navigation index 11',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setSession(testAdmin);

      final adminProvider = AdminProvider()..setNavIndex(11);
      await tester.pumpWidget(
        createAdminShellTestWidget(
          container: container,
          adminProvider: adminProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminProfileScreen), findsOneWidget);
      expect(find.text('Admin Profile & Account'), findsOneWidget);
    });

    testWidgets(
        '7. Desktop viewport renders AdminProfileScreen without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setSession(testAdmin);

      await tester
          .pumpWidget(createAdminProfileTestWidget(container: container));
      await tester.pumpAndSettle();

      expect(find.byType(AdminProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '8. Mobile viewport renders AdminProfileScreen without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setSession(testAdmin);

      await tester
          .pumpWidget(createAdminProfileTestWidget(container: container));
      await tester.pumpAndSettle();

      expect(find.byType(AdminProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
