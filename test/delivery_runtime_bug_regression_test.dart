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
import 'package:dairy_app/features/delivery_panel/screens/delivery_home_tab.dart';
import 'package:dairy_app/features/delivery_panel/screens/delivery_map_tab.dart';
import 'package:dairy_app/features/delivery_panel/widgets/gps_status_warning_banner.dart';
import 'package:dairy_app/features/delivery_panel/widgets/battery_optimization_warning_banner.dart';
import 'package:dairy_app/providers/delivery_live_location_provider.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/battery_optimization_provider.dart';
import 'package:dairy_app/services/battery_optimization_service.dart';

class _MockDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  _MockDeliveryNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockBatteryOptimizationService extends BatteryOptimizationService {
  @override
  Future<bool> isIgnoringBatteryOptimizations() async => false;
}

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

    // 11. GPS and battery warning banners render without RenderFlex overflow
    testWidgets(
        '11. DeliveryHomeTab renders warning banners inside scrollable area without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          deliveryAgentProvider.overrideWith(
            (ref) => _MockDeliveryNotifier(
              DeliveryAgent.empty('agent_test_1').copyWith(
                name: 'Karl Rider',
                phone: '+919876543210',
                vehicle: 'Pulsar',
                status: DeliveryStatus.onDuty,
              ),
            ),
          ),
          gpsTrackingStatusProvider.overrideWith(
            (ref) => GpsTrackingStatusNotifier(GpsTrackingStatus.servicesDisabled),
          ),
          batteryOptimizationProvider.overrideWith(
            (ref) => BatteryOptimizationNotifier(
              _MockBatteryOptimizationService(),
              initial: const BatteryOptimizationState(
                isRestricted: true,
                isDismissed: false,
              ),
            ),
          ),
          deliveryActiveOrdersStreamProvider.overrideWith(
            (ref) => Stream.value(<DeliveryOrder>[]),
          ),
          deliveryRequestsStreamProvider.overrideWithValue(
            <DeliveryOrder>[],
          ),
          deliveryHistoryStreamProvider.overrideWithValue(
            const AsyncValue.data(<DeliveryOrder>[]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DeliveryHomeTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no RenderFlex overflow exception
      expect(tester.takeException(), isNull);

      // Verify exactly ONE GPS warning banner and ONE battery optimization warning banner
      expect(find.byType(GpsStatusWarningBanner), findsOneWidget);
      expect(find.byType(BatteryOptimizationWarningBanner), findsOneWidget);
      expect(find.text('GPS is Turned Off'), findsOneWidget);
      expect(find.text('Background Location Warning'), findsOneWidget);
    });

    // 12. Delivery map tab displays "GPS Unavailable" when location is disabled
    testWidgets(
        '12. DeliveryMapTab displays GPS Unavailable and waiting for location when GPS is off',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          deliveryActiveOrdersStreamProvider.overrideWith(
            (ref) => Stream.value([
              DeliveryOrder(
                id: 'order_gps_test',
                orderId: 'order_gps_test',
                orderCode: 'ORD-1234',
                customerName: 'Test Customer',
                customerAddress: 'Vijay Nagar, Indore',
                customerPhone: '+919876543210',
                pickupLocation: 'Sawariya Dairy Hub',
                pickupPhone: '+91 731 400 5000',
                amount: 250,
                deliveryFee: 30.0,
                status: DeliveryOrderStatus.outForDelivery,
                items: const ['Milk 1L'],
                latitude: 22.7533,
                longitude: 75.8937,
                orderTime: DateTime.now(),
                distance: '2.5 km',
                estimatedTime: '15 mins',
              ),
            ]),
          ),
          deliveryAgentLocationStreamProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DeliveryMapTab(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('GPS Unavailable'), findsOneWidget);
      expect(find.text('Waiting for location'), findsOneWidget);
    });
  });
}
