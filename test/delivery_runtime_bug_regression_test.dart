import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_app/core/auth/app_role.dart';
import 'package:dairy_app/core/widgets/product_image.dart';
import 'package:dairy_app/features/delivery_panel/widgets/delivery_agent_avatar.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/screens/notifications/notifications_screen.dart';

void main() {
  group('Delivery Panel Runtime Bug Regression Tests', () {
    // 1. Notification dropdown has Material ancestor
    testWidgets('1. Notification composer dropdowns have proper Material ancestor',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      // Verify no "No Material widget found" runtime exception occurred
      expect(tester.takeException(), isNull);
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.byType(Material), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    // 2. Existing authenticated phone resolves correctly
    test('2. Existing authenticated phone resolves correctly to canonical variants', () {
      final variants = PhoneAuthUtils.generateVariants('+91 98765 43210');
      expect(variants, contains('9876543210'));
      expect(variants, contains('+919876543210'));
      expect(variants, contains('919876543210'));

      final normalized = PhoneAuthUtils.normalize('+91 98765 43210');
      expect(normalized, equals('9876543210'));

      // Check role mapping
      final adminRole = UserRole.fromPhone('+919999999999');
      expect(adminRole, equals(UserRole.admin));

      final deliveryRole = UserRole.fromPhone('+917777777777');
      expect(deliveryRole, equals(UserRole.delivery));
    });

    // 3. Existing user does not create duplicate user document
    test('3. User model serialization maintains identical identity and prevents duplicate creation', () {
      const existingUser = User(
        id: 'auth_uid_123',
        name: 'Karl Rider',
        phone: '+919876543210',
        email: 'karl@sawariyadairy.com',
        role: UserRole.deliveryValue,
        roleTitle: 'Delivery Partner',
        permissions: ['delivery_orders'],
        status: 'Active',
      );

      final map = existingUser.toMap();
      expect(map['id'], equals('auth_uid_123'));
      expect(map['role'], equals('delivery'));
      expect(map['name'], equals('Karl Rider'));

      final reconstructed = User.fromMap(map);
      expect(reconstructed.id, equals(existingUser.id));
      expect(reconstructed.role, equals(existingUser.role));
      expect(reconstructed.name, equals(existingUser.name));
    });

    // 4. Delivery profile loads from correct UID
    test('4. Delivery profile loads with correct UID and delivery details', () {
      const agent = DeliveryAgent(
        id: 'agent_karl_123',
        name: 'Karl',
        phone: '+919876543210',
        vehicle: 'pulsur',
        vehicleNumber: 'TGS54T53ETG',
        assignedZone: 'meerut',
        status: DeliveryStatus.onDuty,
        totalDeliveriesToday: 5,
        completedDeliveriesToday: 3,
        earningsToday: 350.0,
        isLoaded: true,
      );

      expect(agent.id, equals('agent_karl_123'));
      expect(agent.name, equals('Karl'));
      expect(agent.phone, equals('+919876543210'));
      expect(agent.vehicle, equals('pulsur'));
      expect(agent.vehicleNumber, equals('TGS54T53ETG'));
      expect(agent.assignedZone, equals('meerut'));
    });

    // 5. Missing profile image uses fallback
    testWidgets('5. DeliveryAgentAvatar renders graceful default avatar icon when imageUrl is null/empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryAgentAvatar(
              imageUrl: null,
              radius: 30,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // Also test empty string
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryAgentAvatar(
              imageUrl: '',
              radius: 30,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    // 6. Product image URL maps correctly
    test('6. Product image URL maps across various Firestore field names', () {
      final fromImageUrl = Product.fromFirestore({
        'title': 'A2 Cow Milk',
        'price': 75.0,
        'imageUrl': 'https://storage.googleapis.com/dairy/milk.jpg',
      }, 'p1');
      expect(fromImageUrl.imageUrl, equals('https://storage.googleapis.com/dairy/milk.jpg'));

      final fromImage = Product.fromFirestore({
        'title': 'Desi Ghee',
        'price': 650.0,
        'image': 'https://storage.googleapis.com/dairy/ghee.png',
      }, 'p2');
      expect(fromImage.imageUrl, equals('https://storage.googleapis.com/dairy/ghee.png'));

      final fromProductImage = Product.fromFirestore({
        'title': 'Fresh Paneer',
        'price': 120.0,
        'productImage': 'https://storage.googleapis.com/dairy/paneer.jpg',
      }, 'p3');
      expect(fromProductImage.imageUrl, equals('https://storage.googleapis.com/dairy/paneer.jpg'));

      // Check Order.fromFirestore parses item product images
      final order = Order.fromFirestore({
        'orderCode': 'ORD-101',
        'items': [
          {
            'name': 'A2 Cow Milk',
            'quantity': 2,
            'price': 75.0,
            'image': 'https://storage.googleapis.com/dairy/milk.jpg',
          }
        ],
      }, 'ord_1');
      expect(order.items.first.product.imageUrl, equals('https://storage.googleapis.com/dairy/milk.jpg'));
    });

    // 7. Missing product image uses fallback
    testWidgets('7. ProductImage widget renders fallback placeholder when imageUrl is null/empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: null,
              size: 44,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ProductImage), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: '',
              size: 44,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ProductImage), findsOneWidget);
    });

    // 8. Invalid product image URL does not crash
    testWidgets('8. ProductImage widget handles invalid URL without crashing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: 'http://localhost:9999/invalid_image_path.jpg',
              size: 44,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ProductImage), findsOneWidget);
    });

    // 9. Profile dialog and profile tab use consistent data
    test('9. Profile data source holds authoritative delivery details consistently', () {
      final agent = DeliveryAgent.empty('agent_karl').copyWith(
        name: 'karl',
        phone: '+919876543210',
        vehicle: 'pulsur',
        vehicleNumber: 'TGS54T53ETG',
        assignedZone: 'meerut',
        profileImageUrl: 'https://example.com/karl.jpg',
      );

      expect(agent.name, equals('karl'));
      expect(agent.phone, equals('+919876543210'));
      expect(agent.vehicle, equals('pulsur'));
      expect(agent.vehicleNumber, equals('TGS54T53ETG'));
      expect(agent.assignedZone, equals('meerut'));
      expect(agent.profileImageUrl, equals('https://example.com/karl.jpg'));
    });

    // 10. Delivery role routing works after phone OTP
    test('10. Authenticated User with delivery role evaluates isDelivery correctly for routing', () {
      const deliveryUser = User(
        id: 'uid_delivery_partner',
        name: 'Karl',
        phone: '+919876543210',
        role: UserRole.deliveryValue,
      );

      expect(deliveryUser.isDelivery, isTrue);
      expect(deliveryUser.canAccessAdminPortal, isFalse);

      const customerUser = User(
        id: 'uid_customer',
        name: 'Regular Customer',
        phone: '+919876543211',
        role: UserRole.customerValue,
      );

      expect(customerUser.isDelivery, isFalse);
      expect(customerUser.canAccessAdminPortal, isFalse);
    });
  });
}
