import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:dairy_app/models/staff_member.dart';
import 'package:dairy_app/providers/admin_provider.dart';
import 'package:dairy_app/screens/staff/staff_roles_screen.dart';

void main() {
  group('Staff & Permissions Domain Model Tests', () {
    test('StaffPermission constants contain all 33 granular permissions', () {
      final allPerms = StaffPermission.allPermissions;
      expect(allPerms.length, equals(33));
      expect(allPerms.contains(StaffPermission.viewDashboard), isTrue);
      expect(allPerms.contains(StaffPermission.createCustomer), isTrue);
      expect(allPerms.contains(StaffPermission.editCustomer), isTrue);
      expect(allPerms.contains(StaffPermission.deleteCustomer), isTrue);
      expect(allPerms.contains(StaffPermission.createSubscription), isTrue);
      expect(allPerms.contains(StaffPermission.createProduct), isTrue);
      expect(allPerms.contains(StaffPermission.deleteProduct), isTrue);
      expect(allPerms.contains(StaffPermission.createCategory), isTrue);
      expect(allPerms.contains(StaffPermission.deleteCategory), isTrue);
      expect(allPerms.contains(StaffPermission.assignDeliveryAgent), isTrue);
      expect(allPerms.contains(StaffPermission.manageDelivery), isTrue);
      expect(allPerms.contains(StaffPermission.updatePaymentStatus), isTrue);
      expect(allPerms.contains(StaffPermission.sendNotifications), isTrue);
      expect(allPerms.contains(StaffPermission.replyComplaints), isTrue);
      expect(allPerms.contains(StaffPermission.manageStaff), isTrue);
      expect(allPerms.contains(StaffPermission.manageRoles), isTrue);
    });

    test('StaffRolePresets loads correct permission bundles per role', () {
      final adminPerms = StaffRolePresets.getPermissionsForRole('admin');
      expect(adminPerms.length, equals(33));

      final managerPerms = StaffRolePresets.getPermissionsForRole('manager');
      expect(managerPerms.length, equals(32));
      expect(managerPerms.contains(StaffPermission.manageStaff), isTrue);
      expect(managerPerms.contains(StaffPermission.manageRoles), isFalse);

      final dispatcherPerms =
          StaffRolePresets.getPermissionsForRole('dispatcher');
      expect(dispatcherPerms.contains(StaffPermission.assignDeliveryAgent), isTrue);
      expect(dispatcherPerms.contains(StaffPermission.manageDelivery), isTrue);
      expect(dispatcherPerms.contains(StaffPermission.manageStaff), isFalse);

      final staffPerms = StaffRolePresets.getPermissionsForRole('staff');
      expect(staffPerms.contains(StaffPermission.viewOrders), isTrue);
      expect(staffPerms.contains(StaffPermission.deleteCustomer), isFalse);
    });

    test('StaffMember hasPermission logic respects Super Admin override and custom perms', () {
      const superAdmin = StaffMember(
        id: 'staff_admin_1',
        name: 'Ramesh Admin',
        email: 'ramesh@sawariya.com',
        phone: '9999999999',
        role: 'admin',
        roleTitle: 'Super Admin',
        permissions: [], // Empty permissions list still grants full access
      );

      expect(superAdmin.isSuperAdmin, isTrue);
      expect(superAdmin.hasPermission(StaffPermission.manageRoles), isTrue);
      expect(superAdmin.hasPermission(StaffPermission.deleteProduct), isTrue);

      const dispatcher = StaffMember(
        id: 'staff_disp_1',
        name: 'Suresh Dispatcher',
        email: 'suresh@sawariya.com',
        phone: '8888888888',
        role: 'dispatcher',
        roleTitle: 'Route Dispatcher',
        permissions: [
          StaffPermission.viewOrders,
          StaffPermission.assignDeliveryAgent,
        ],
      );

      expect(dispatcher.isSuperAdmin, isFalse);
      expect(dispatcher.hasPermission(StaffPermission.assignDeliveryAgent), isTrue);
      expect(dispatcher.hasPermission(StaffPermission.deleteProduct), isFalse);
      expect(dispatcher.hasPermission(StaffPermission.manageStaff), isFalse);
    });

    test('StaffMember toFirestore maps correct fields and formats', () {
      const staff = StaffMember(
        id: 'staff_mgr_01',
        name: 'Anita Manager',
        email: 'anita@sawariya.com',
        phone: '9876543210',
        role: 'manager',
        roleTitle: 'Operations Manager',
        status: 'Active',
        permissions: [StaffPermission.viewDashboard, StaffPermission.viewOrders],
      );

      final map = staff.toFirestore();
      expect(map['uid'], equals('staff_mgr_01'));
      expect(map['name'], equals('Anita Manager'));
      expect(map['role'], equals('manager'));
      expect(map['roleTitle'], equals('Operations Manager'));
      expect(map['status'], equals('Active'));
      expect(map['isAdmin'], isFalse);
      expect(map['permissions'], contains(StaffPermission.viewOrders));
    });
  });

  group('Staff & Roles UI Widget & Layout Tests', () {
    testWidgets('StaffRolesScreen renders header, KPI cards, search and filters',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockProvider = AdminProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: provider_pkg.ChangeNotifierProvider<AdminProvider>.value(
              value: mockProvider,
              child: const StaffRolesScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staff & Role Permissions'), findsOneWidget);
      expect(find.text('Add Staff Member'), findsOneWidget);
      expect(find.text('Total Staff'), findsOneWidget);
      expect(find.text('Active Members'), findsOneWidget);
      expect(find.text('Operations Managers'), findsOneWidget);
      expect(find.text('Route Dispatchers'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('StaffRolesScreen renders without overflows across mobile (360px)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockProvider = AdminProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: provider_pkg.ChangeNotifierProvider<AdminProvider>.value(
              value: mockProvider,
              child: const StaffRolesScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staff & Role Permissions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StaffRolesScreen opens Add Staff dialog with permission matrix',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockProvider = AdminProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: provider_pkg.ChangeNotifierProvider<AdminProvider>.value(
              value: mockProvider,
              child: const StaffRolesScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addButton = find.text('Add Staff Member');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('Add New Staff Member'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);
      expect(find.text('Assigned Role *'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Subscriptions'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);

      // Close dialog
      final cancelButton = find.text('Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Add New Staff Member'), findsNothing);
    });
  });
}
