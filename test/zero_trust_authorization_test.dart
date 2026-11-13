import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/core/auth/app_role.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-004: Zero-Trust Authorization & Session Verification Tests', () {
    test('TEST-01: UserRole defaults safely to customer for all phone lookups', () {
      expect(UserRole.fromPhone('+919999999999'), equals(UserRole.customer));
      expect(UserRole.fromPhone('9999999999'), equals(UserRole.customer));
      expect(UserRole.fromPhone('8888888888'), equals(UserRole.customer));
      expect(UserRole.fromPhone('7777777777'), equals(UserRole.customer));
      expect(UserRole.fromPhone(null), equals(UserRole.customer));
      expect(UserRole.fromPhone(''), equals(UserRole.customer));
    });

    test('TEST-02: PhoneAuthUtils generates canonical 10-digit Indian numbers and query variants', () {
      expect(PhoneAuthUtils.normalize('+919876543210'), equals('9876543210'));
      expect(PhoneAuthUtils.normalize('09876543210'), equals('9876543210'));
      expect(PhoneAuthUtils.normalize('919876543210'), equals('9876543210'));
      expect(PhoneAuthUtils.normalize('+91 98765 43210'), equals('9876543210'));
      expect(PhoneAuthUtils.normalize(''), equals(''));
      expect(PhoneAuthUtils.normalize(null), equals(''));

      final variants = PhoneAuthUtils.generateVariants('+919876543210');
      expect(variants, contains('+919876543210'));
      expect(variants, contains('9876543210'));
      expect(variants, contains('919876543210'));
      expect(variants, contains('09876543210'));
    });

    test('TEST-03: UserNotifier initial state is unverified and guestUser by default', () {
      final notifier = UserNotifier();
      expect(notifier.state.id, isEmpty);
      expect(notifier.state.role, equals(UserRole.customerValue));
      expect(notifier.isRoleServerVerified, isFalse);
    });

    test('TEST-04: clearSession completely resets role, user, and verification flags', () async {
      final notifier = UserNotifier();
      await notifier.setSession(const User(
        id: 'cust_uid_1',
        name: 'Test Customer',
        phone: '+919876543210',
        role: UserRole.customerValue,
      ));

      expect(notifier.state.id, equals('cust_uid_1'));
      expect(notifier.state.role, equals(UserRole.customerValue));

      await notifier.clearSession();
      expect(notifier.state.id, isEmpty);
      expect(notifier.state.role, equals(UserRole.customerValue));
      expect(notifier.isRoleServerVerified, isFalse);
    });

    test('TEST-05: User model role getters strictly require isRoleServerVerified == true', () {
      // Unverified models (cached or hostile): all privileged getters must return false
      const unverifiedAdmin = User(
        id: 'adm_1',
        name: 'Admin',
        phone: '+919876543210',
        role: 'admin',
        isRoleServerVerified: false,
      );
      expect(unverifiedAdmin.isAdmin, isFalse);
      expect(unverifiedAdmin.canAccessAdminPortal, isFalse);
      expect(unverifiedAdmin.isDelivery, isFalse);
      expect(unverifiedAdmin.isCustomer, isTrue); // Fails safely to customer

      const unverifiedDelivery = User(
        id: 'del_1',
        name: 'Delivery',
        phone: '+919876543210',
        role: 'delivery',
        isRoleServerVerified: false,
      );
      expect(unverifiedDelivery.isDelivery, isFalse);
      expect(unverifiedDelivery.isCustomer, isTrue);

      // Verified models: role getters enforce correct RBAC permissions
      const verifiedAdmin = User(
        id: 'adm_1',
        name: 'Admin',
        phone: '+919876543210',
        role: 'admin',
        isRoleServerVerified: true,
      );
      expect(verifiedAdmin.isAdmin, isTrue);
      expect(verifiedAdmin.canAccessAdminPortal, isTrue);
      expect(verifiedAdmin.isDelivery, isFalse);
      expect(verifiedAdmin.isCustomer, isFalse);

      const verifiedDelivery = User(
        id: 'del_1',
        name: 'Delivery',
        phone: '+919876543210',
        role: 'delivery',
        isRoleServerVerified: true,
      );
      expect(verifiedDelivery.isAdmin, isFalse);
      expect(verifiedDelivery.isDelivery, isTrue);
      expect(verifiedDelivery.canAccessAdminPortal, isFalse);

      const verifiedDispatcher = User(
        id: 'staff_1',
        name: 'Dispatcher',
        phone: '+919876543210',
        role: 'dispatcher',
        isRoleServerVerified: true,
      );
      expect(verifiedDispatcher.isAdmin, isFalse);
      expect(verifiedDispatcher.isStaff, isTrue);
      expect(verifiedDispatcher.canAccessAdminPortal, isTrue);
      expect(verifiedDispatcher.isDelivery, isFalse);
    });

    test('TEST-06: Caller-supplied phone parameter cannot escalate privileges in fromPhoneAndRole', () {
      expect(UserRole.fromPhoneAndRole(phone: '+919999999999', role: null), equals(UserRole.customer));
      expect(UserRole.fromPhoneAndRole(phone: '+919999999999', role: 'customer'), equals(UserRole.customer));
      expect(UserRole.fromPhoneAndRole(phone: '8888888888', role: ''), equals(UserRole.customer));
      expect(UserRole.fromPhoneAndRole(phone: '7777777777', role: 'random_role'), equals(UserRole.customer));

      // Explicit server-verified role is respected
      expect(UserRole.fromPhoneAndRole(phone: '+919876543210', role: 'admin'), equals(UserRole.admin));
      expect(UserRole.fromPhoneAndRole(phone: '+919876543210', role: 'delivery'), equals(UserRole.delivery));
    });

    test('TEST-07: Sanitizing invalid or hostile role strings fails safely to customer', () {
      expect(UserRole.sanitize(''), equals(UserRole.customerValue));
      expect(UserRole.sanitize(null), equals(UserRole.customerValue));
      expect(UserRole.sanitize('root'), equals(UserRole.customerValue));
      expect(UserRole.sanitize('system_admin'), equals(UserRole.customerValue));
      expect(UserRole.sanitize('hacker'), equals(UserRole.customerValue));
      expect(UserRole.sanitize('ADMIN'), equals(UserRole.adminValue));
      expect(UserRole.sanitize('delivery'), equals(UserRole.deliveryValue));
      expect(UserRole.sanitize('dispatcher'), equals('dispatcher'));
    });

    test('TEST-08: User.fromMap always deserializes with isRoleServerVerified false', () {
      // Even if local storage contains a forged isRoleServerVerified field, User.fromMap ignores it
      final user = User.fromMap({
        'id': 'fake_admin',
        'role': 'admin',
        'isRoleServerVerified': true,
        'isAdmin': true,
      });

      expect(user.isRoleServerVerified, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.canAccessAdminPortal, isFalse);
      expect(user.isCustomer, isTrue);
    });

    test('TEST-09: copyWith accurately preserves or updates isRoleServerVerified', () {
      const user = User(
        id: 'u1',
        name: 'User',
        phone: '+919876543210',
        role: 'admin',
        isRoleServerVerified: false,
      );

      final verified = user.copyWith(isRoleServerVerified: true);
      expect(verified.isRoleServerVerified, isTrue);
      expect(verified.canAccessAdminPortal, isTrue);

      final unverifiedAgain = verified.copyWith(isRoleServerVerified: false);
      expect(unverifiedAgain.isRoleServerVerified, isFalse);
      expect(unverifiedAgain.canAccessAdminPortal, isFalse);
    });
  });
}
