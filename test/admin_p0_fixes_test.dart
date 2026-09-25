import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/staff_member.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/services/payment_service.dart';

void main() {
  group('P0 Fixes: Task 1 - Payment Error Handling', () {
    test(
        'PaymentService.updatePaymentStatus throws meaningful exception on missing firestore',
        () async {
      final service = PaymentService();
      // When firestore instance is not initialized or invalid, updatePaymentStatus must throw / propagate
      expect(
        () => service.updatePaymentStatus('non_existent_payment', 'Success'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('P0 Fixes: Task 3 - Staff Pre-Provisioning & Auth UID Reconciliation',
      () {
    test(
        'StaffRolePresets provides all required permissions for manager, dispatcher, and admin',
        () {
      final adminPerms = StaffRolePresets.getPermissionsForRole('admin');
      final managerPerms = StaffRolePresets.getPermissionsForRole('manager');
      final dispatcherPerms =
          StaffRolePresets.getPermissionsForRole('dispatcher');
      final staffPerms = StaffRolePresets.getPermissionsForRole('staff');

      expect(adminPerms.length, equals(33));
      expect(managerPerms.contains(StaffPermission.createProduct), isTrue);
      expect(managerPerms.contains(StaffPermission.editCustomer), isTrue);
      expect(dispatcherPerms.contains(StaffPermission.assignDeliveryAgent),
          isTrue);
      expect(dispatcherPerms.contains(StaffPermission.viewOrders), isTrue);
      expect(staffPerms.contains(StaffPermission.viewOrders), isTrue);
    });

    test('StaffMember correctly identifies Super Admin vs granular role', () {
      const admin = StaffMember(
        id: 'admin_uid_1',
        name: 'Admin User',
        email: 'admin@sawariya.com',
        phone: '9999999999',
        role: 'admin',
        roleTitle: 'Super Admin',
      );

      expect(admin.isSuperAdmin, isTrue);
      expect(admin.hasPermission(StaffPermission.manageRoles), isTrue);
      expect(admin.hasPermission(StaffPermission.deleteCustomer), isTrue);

      const manager = StaffMember(
        id: 'manager_uid_1',
        name: 'Manager User',
        email: 'mgr@sawariya.com',
        phone: '9876543210',
        role: 'manager',
        roleTitle: 'Operations Manager',
        permissions: [
          StaffPermission.createProduct,
          StaffPermission.editProduct,
          StaffPermission.viewOrders,
        ],
      );

      expect(manager.isSuperAdmin, isFalse);
      expect(manager.hasPermission(StaffPermission.createProduct), isTrue);
      expect(manager.hasPermission(StaffPermission.deleteProduct), isFalse);
      expect(manager.hasPermission(StaffPermission.manageRoles), isFalse);
    });
  });

  group('P0 Fixes: Task 4 - User Model Permissions & RBAC Enforcement', () {
    test('User.hasPermission respects superadmin and checks list', () {
      const superAdminUser = User(
        id: 'admin_1',
        name: 'Super Admin',
        phone: '9999999999',
        email: 'super@sawariya.com',
        role: 'admin',
        permissions: [],
      );

      expect(superAdminUser.isAdmin, isTrue);
      expect(superAdminUser.hasPermission('createProduct'), isTrue);
      expect(superAdminUser.hasPermission('anything'), isTrue);

      const staffUser = User(
        id: 'staff_1',
        name: 'Staff Member',
        phone: '9876543210',
        email: 'staff@sawariya.com',
        role: 'staff',
        permissions: ['viewOrders', 'assignDeliveryAgent'],
      );

      expect(staffUser.isAdmin, isFalse);
      expect(staffUser.hasPermission('viewOrders'), isTrue);
      expect(staffUser.hasPermission('assignDeliveryAgent'), isTrue);
      expect(staffUser.hasPermission('createProduct'), isFalse);
    });
  });
}
