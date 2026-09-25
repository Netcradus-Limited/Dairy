import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dairy_app/core/widgets/address_tile.dart';
import 'package:dairy_app/core/widgets/price_summary.dart';
import 'package:dairy_app/features/cart/cart_screen.dart';
import 'package:dairy_app/features/checkout/checkout_screen.dart';
import 'package:dairy_app/features/product/product_details_screen.dart';
import 'package:dairy_app/features/subscription/subscriptions_screen.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/subscription.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/address_provider.dart';
import 'package:dairy_app/providers/cart_provider.dart';
import 'package:dairy_app/providers/subscription_provider.dart';
import 'package:dairy_app/services/subscription_service.dart';
import 'package:dairy_app/features/orders/order_details_screen.dart';
import 'package:dairy_app/features/profile/customer_support_screen.dart';
import 'package:dairy_app/features/subscription/edit_subscription_screen.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/order.dart';

class FakeSubscriptionNotifier extends SubscriptionNotifier {
  FakeSubscriptionNotifier(List<Subscription> subs)
      : super(
          service: SubscriptionService(),
          user: const User(id: '', name: '', phone: ''),
        ) {
    state = SubscriptionState(loading: false, subscriptions: subs);
  }
}

void main() {
  const testProduct = Product(
    id: 'prod_milk_01',
    title: 'Pure A2 Gir Cow Fresh Farm Milk',
    categoryId: 'cat_milk',
    categoryName: 'Fresh Milk',
    price: 85.0,
    originalPrice: 95.0,
    unit: '1 L Glass Bottle',
    imageUrl: 'assets/images/doodh.png',
    rating: 4.9,
    reviewCount: 128,
    isA2CowMilk: true,
    description: 'Pure, raw, unpasteurized A2 cow milk delivered fresh.',
  );

  const testAddress = Address(
    id: 'addr_01',
    fullName: 'Ramesh Patel',
    mobileNumber: '+91 9876543210',
    houseFlat: 'Flat 402, Sai Vihar',
    streetArea: 'MG Road, Shivaji Nagar',
    city: 'Pune',
    state: 'Maharashtra',
    pinCode: '411005',
    latitude: 18.5204,
    longitude: 73.8567,
    label: 'Home',
    isDefault: true,
  );

  final testSubscription = Subscription(
    id: 'sub_01',
    product: testProduct,
    quantity: 2,
    frequency: SubscriptionFrequency.daily,
    status: SubscriptionStatus.active,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 12, 31),
    nextDeliveryDate: DateTime(2026, 9, 22, 6, 0),
    deliveryTimeSlot: 'Morning (6:00 AM - 9:00 AM)',
    includeIcePack: true,
    planId: 'plan_01',
    planName: 'Daily Pure A2 Milk Plan',
    autoRenew: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testOrder = Order(
    id: 'ord_01',
    orderCode: 'KRT482',
    items: const [
      CartItem(
        product: testProduct,
        quantity: 2,
      ),
    ],
    subtotal: 170.0,
    deliveryCharge: 0.0,
    discount: 0.0,
    totalAmount: 170.0,
    status: OrderStatus.placed,
    orderDate: DateTime(2026, 9, 21, 10, 0),
    deliveryAddress: testAddress,
  );

  final viewports = <String, Size>{
    'Small Android (360x800)': const Size(360, 800),
    'iPhone X/Mini (375x812)': const Size(375, 812),
    'iPhone 12/13/14 (390x844)': const Size(390, 844),
    'Pixel / Galaxy (412x915)': const Size(412, 915),
    'Desktop Baseline (1366x768)': const Size(1366, 768),
  };

  group('Responsive Viewport Tests — No RenderFlex Overflows', () {
    for (final entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('CartScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cartProvider.overrideWith(
                  (ref) => CartNotifier()..addItem(testProduct, 2)),
            ],
            child: const MaterialApp(
              home: CartScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('100% Fresh Dairy Direct from Sawariya Farms'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AddressTile renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AddressTile(
                  address: testAddress,
                  isSelected: true,
                  onSelect: () {},
                  onEdit: () {},
                  onDelete: () {},
                  onSetDefault: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('GPS Pin'), findsOneWidget);
        expect(find.text('Default'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SubscriptionsScreen renders cards without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        FlutterError.onError = FlutterError.dumpErrorToConsole;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionProvider.overrideWith(
                (ref) => FakeSubscriptionNotifier([testSubscription]),
              ),
            ],
            child: const MaterialApp(
              home: SubscriptionsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final err = tester.takeException();
        if (err is FlutterError) {
          debugPrint(
              'DEBUG SubscriptionsScreen diagnostics:\n${err.diagnostics.map((d) => d.toStringDeep()).join('\n')}');
        }
        expect(find.text('My Subscriptions'), findsOneWidget);
        expect(find.text('Pure A2 Gir Cow Fresh Farm Milk'), findsOneWidget);
        expect(err, isNull);
      });

      testWidgets('PriceSummaryCard renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16.0),
                child: PriceSummaryCard(
                  subtotal: 450.0,
                  deliveryCharge: 30.0,
                  discount: 45.0,
                  grandTotal: 435.0,
                  actionButtonText: 'Proceed to Checkout',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Order Bill Summary'), findsOneWidget);
        expect(find.text('Grand Total'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ProductDetailsScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        FlutterError.onError = FlutterError.dumpErrorToConsole;
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: ProductDetailsScreen(product: testProduct),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final err = tester.takeException();
        if (err != null) {
          try {
            debugPrint(
                'DEBUG ProductDetailsScreen error deep: ${(err as dynamic).toStringDeep()}');
          } catch (_) {
            debugPrint('DEBUG ProductDetailsScreen error: $err');
          }
        }
        expect(find.text('Pure A2 Gir Cow Fresh Farm Milk'),
            findsAtLeastNWidgets(1));
        expect(find.text('Add to Cart'), findsOneWidget);
        expect(find.text('Buy Now'), findsOneWidget);
        expect(err, isNull);
      });

      testWidgets('CheckoutScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cartProvider.overrideWith(
                  (ref) => CartNotifier()..addItem(testProduct, 1)),
              selectedAddressProvider.overrideWith((ref) => null),
            ],
            child: const MaterialApp(
              home: CheckoutScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Checkout & Order Review'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('OrderDetailsScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        FlutterError.onError = FlutterError.dumpErrorToConsole;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: OrderDetailsScreen(order: testOrder),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Order Items'), findsOneWidget);
        expect(find.text('Bill Summary'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CustomerSupportScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CustomerSupportScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Customer Support & Complaints'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('EditSubscriptionScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: EditSubscriptionScreen(subscription: testSubscription),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
