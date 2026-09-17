import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/core/auth/app_role.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/user_provider.dart';

void main() {
  group('Admin Role & Phone Normalization Tests', () {
    test('1. PhoneAuthUtils.normalize extracts 10-digit Indian numbers correctly', () {
      expect(PhoneAuthUtils.normalize('+919999999999'), '9999999999');
      expect(PhoneAuthUtils.normalize('9999999999'), '9999999999');
      expect(PhoneAuthUtils.normalize('+91 99999 99999'), '9999999999');
      expect(PhoneAuthUtils.normalize('09999999999'), '9999999999');
      expect(PhoneAuthUtils.normalize('919999999999'), '9999999999');
      expect(PhoneAuthUtils.normalize('+91-99999-99999'), '9999999999');
      expect(PhoneAuthUtils.normalize(null), '');
      expect(PhoneAuthUtils.normalize(''), '');
    });

    test('2. PhoneAuthUtils.generateVariants creates all Firestore queryable formats', () {
      final variants = PhoneAuthUtils.generateVariants('+919999999999');
      expect(variants, contains('+919999999999'));
      expect(variants, contains('9999999999'));
      expect(variants, contains('919999999999'));
      expect(variants, contains('09999999999'));
      expect(variants, contains('+91 9999999999'));
    });

    test('3. UserRole.fromPhone detects admin and delivery roles correctly from normalized numbers', () {
      expect(UserRole.fromPhone('+919999999999'), UserRole.admin);
      expect(UserRole.fromPhone('9999999999'), UserRole.admin);
      expect(UserRole.fromPhone('+91 99999 99999'), UserRole.admin);
      expect(UserRole.fromPhone('09999999999'), UserRole.admin);
      expect(UserRole.fromPhone('8888888888'), UserRole.admin);

      expect(UserRole.fromPhone('+917777777777'), UserRole.delivery);
      expect(UserRole.fromPhone('7777777777'), UserRole.delivery);
      expect(UserRole.fromPhone('+91 77777 77777'), UserRole.delivery);

      expect(UserRole.fromPhone('+919876543210'), UserRole.customer);
      expect(UserRole.fromPhone('9876543210'), UserRole.customer);
      expect(UserRole.fromPhone(null), UserRole.customer);
    });

    test('4. UserRole.fromPhoneAndRole prioritizes explicit role strings and falls back to phone', () {
      expect(UserRole.fromPhoneAndRole(phone: '+919876543210', role: 'admin'), UserRole.admin);
      expect(UserRole.fromPhoneAndRole(phone: '+919876543210', role: 'owner'), UserRole.admin);
      expect(UserRole.fromPhoneAndRole(phone: '+919876543210', role: 'superadmin'), UserRole.admin);
      expect(UserRole.fromPhoneAndRole(phone: '+919876543210', role: 'delivery'), UserRole.delivery);

      // Phone takes effect when role is default/customer/null
      expect(UserRole.fromPhoneAndRole(phone: '+919999999999', role: 'customer'), UserRole.admin);
      expect(UserRole.fromPhoneAndRole(phone: '9999999999', role: null), UserRole.admin);
      expect(UserRole.fromPhoneAndRole(phone: '+917777777777', role: 'customer'), UserRole.delivery);
      expect(UserRole.fromPhoneAndRole(phone: '+919876543210', role: 'customer'), UserRole.customer);
    });

    test('5. UserRole.fromString maps admin, owner, superadmin to UserRole.admin', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('owner'), UserRole.admin);
      expect(UserRole.fromString('Owner'), UserRole.admin);
      expect(UserRole.fromString('superadmin'), UserRole.admin);
      expect(UserRole.fromString('SUPERADMIN'), UserRole.admin);

      expect(UserRole.fromString('admin').homeRoute, '/admin');
      expect(UserRole.fromString('owner').homeRoute, '/admin');
      expect(UserRole.fromString('superadmin').homeRoute, '/admin');
    });

    test('6. UserRole.fromString maps delivery roles and defaults customer securely', () {
      expect(UserRole.fromString('delivery'), UserRole.delivery);
      expect(UserRole.fromString('delivery_agent'), UserRole.delivery);
      expect(UserRole.fromString('driver'), UserRole.delivery);
      expect(UserRole.fromString('delivery').homeRoute, '/delivery');

      expect(UserRole.fromString('customer'), UserRole.customer);
      expect(UserRole.fromString('user'), UserRole.customer);
      expect(UserRole.fromString(null), UserRole.customer);
      expect(UserRole.fromString('unknown_role'), UserRole.customer);
      expect(UserRole.fromString('customer').homeRoute, '/home');
    });

    test('7. User model isAdmin and isDelivery reflect role and route destinations', () {
      final adminUser = User(
        id: 'test_admin_uid',
        name: 'Test Admin',
        phone: '+919999999999',
        role: UserRole.fromPhoneAndRole(phone: '+919999999999').value,
      );
      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.isDelivery, isFalse);
      expect(adminUser.isCustomer, isFalse);
      expect(adminUser.userRole.homeRoute, '/admin');

      const ownerUser = User(
        id: 'owner_uid',
        name: 'Owner User',
        phone: '+919876543210',
        role: 'owner',
      );
      expect(ownerUser.isAdmin, isTrue);
      expect(ownerUser.isDelivery, isFalse);
      expect(ownerUser.userRole.homeRoute, '/admin');

      final deliveryUser = User(
        id: 'delivery_uid',
        name: 'Delivery Agent',
        phone: '+917777777777',
        role: UserRole.fromPhoneAndRole(phone: '+917777777777').value,
      );
      expect(deliveryUser.isAdmin, isFalse);
      expect(deliveryUser.isDelivery, isTrue);
      expect(deliveryUser.isCustomer, isFalse);
      expect(deliveryUser.userRole.homeRoute, '/delivery');

      final customerUser = User(
        id: 'customer_uid',
        name: 'Customer User',
        phone: '+919876543212',
        role: UserRole.fromPhoneAndRole(phone: '+919876543212').value,
      );
      expect(customerUser.isAdmin, isFalse);
      expect(customerUser.isDelivery, isFalse);
      expect(customerUser.isCustomer, isTrue);
      expect(customerUser.userRole.homeRoute, '/home');
    });
  });
}
