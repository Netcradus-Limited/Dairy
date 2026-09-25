import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/providers/delivery_provider.dart';

void main() {
  const sampleAddress = Address(
    id: 'addr_1',
    label: 'Home',
    fullName: 'Arun Patel',
    mobileNumber: '+91 98765 43210',
    houseFlat: '101, Galaxy Tower',
    streetArea: 'South Tukoganj',
    city: 'Indore',
    state: 'Madhya Pradesh',
    pinCode: '452001',
    latitude: 22.7196,
    longitude: 75.8577,
  );

  const sampleProduct = Product(
    id: 'prod_milk_1',
    title: 'Fresh Cow Milk',
    categoryId: 'cat_dairy',
    categoryName: 'Milk',
    price: 65.0,
    unit: '1L',
    imageUrl: '',
  );

  Order createBaseOrder({
    required String id,
    String? pickupLocation,
    String? pickupPhone,
    double? pickupLatitude,
    double? pickupLongitude,
  }) {
    return Order(
      id: id,
      orderCode: 'ORD123',
      items: [
        CartItem(product: sampleProduct, quantity: 2),
      ],
      subtotal: 130.0,
      deliveryCharge: 20.0,
      totalAmount: 150.0,
      status: OrderStatus.placed,
      orderDate: DateTime(2026, 3, 1, 8, 30),
      deliveryAddress: sampleAddress,
      pickupLocation: pickupLocation,
      pickupPhone: pickupPhone,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
    );
  }

  group('Task 2 — Dynamic Pickup Hub & Store Information Tests', () {
    test('1. Order.fromFirestore parses top-level pickup fields accurately',
        () {
      final data = <String, dynamic>{
        'orderCode': 'ORD888',
        'status': 'Pending',
        'items': [],
        'subtotal': 100.0,
        'totalAmount': 100.0,
        'deliveryAddress': sampleAddress.toMap(),
        'pickupLocation': 'Palasia Fulfillment Center',
        'pickupPhone': '+91 731 555 1234',
        'pickupLatitude': 22.7200,
        'pickupLongitude': 75.8800,
      };

      final order = Order.fromFirestore(data, 'order_dyn_1');

      expect(order.pickupLocation, 'Palasia Fulfillment Center');
      expect(order.pickupPhone, '+91 731 555 1234');
      expect(order.pickupLatitude, 22.7200);
      expect(order.pickupLongitude, 75.8800);
    });

    test('2. Order.fromFirestore supports nested pickup map format', () {
      final data = <String, dynamic>{
        'orderCode': 'ORD999',
        'status': 'Pending',
        'items': [],
        'subtotal': 100.0,
        'totalAmount': 100.0,
        'deliveryAddress': sampleAddress.toMap(),
        'pickup': {
          'name': 'Annapurna Depot',
          'phone': '+91 731 777 8888',
          'latitude': 22.6950,
          'longitude': 75.8350,
        },
      };

      final order = Order.fromFirestore(data, 'order_dyn_2');

      expect(order.pickupLocation, 'Annapurna Depot');
      expect(order.pickupPhone, '+91 731 777 8888');
      expect(order.pickupLatitude, 22.6950);
      expect(order.pickupLongitude, 75.8350);
    });

    test(
        '3. Order.fromFirestore supports fallback keys (storeName, storePhone, pickupLat)',
        () {
      final data = <String, dynamic>{
        'orderCode': 'ORD777',
        'status': 'Pending',
        'items': [],
        'subtotal': 100.0,
        'totalAmount': 100.0,
        'deliveryAddress': sampleAddress.toMap(),
        'storeName': 'Bhawarkua Store Hub',
        'storePhone': '+91 731 222 3333',
        'pickupLat': 22.6900,
        'pickupLng': 75.8650,
      };

      final order = Order.fromFirestore(data, 'order_dyn_3');

      expect(order.pickupLocation, 'Bhawarkua Store Hub');
      expect(order.pickupPhone, '+91 731 222 3333');
      expect(order.pickupLatitude, 22.6900);
      expect(order.pickupLongitude, 75.8650);
    });

    test(
        '4. Order serialization preserves pickupLocation, pickupPhone, and coordinates',
        () {
      final order = createBaseOrder(
        id: 'ord_serialize_test',
        pickupLocation: 'Rau Outlet',
        pickupPhone: '+91 731 999 0000',
        pickupLatitude: 22.6300,
        pickupLongitude: 75.8100,
      );

      final map = order.toFirestore();

      expect(map['pickupLocation'], 'Rau Outlet');
      expect(map['pickupPhone'], '+91 731 999 0000');
      expect(map['pickupLatitude'], 22.6300);
      expect(map['pickupLongitude'], 75.8100);
    });

    test(
        '5. Distinct orders yield distinct dynamic pickup locations (no single hardcoding)',
        () {
      final orderA = createBaseOrder(
        id: 'order_A',
        pickupLocation: 'Palasia Depot #4',
        pickupPhone: '+91 731 111 2222',
        pickupLatitude: 22.7210,
        pickupLongitude: 75.8820,
      );

      final orderB = createBaseOrder(
        id: 'order_B',
        pickupLocation: 'Rajwada Distribution Center',
        pickupPhone: '+91 731 333 4444',
        pickupLatitude: 22.7180,
        pickupLongitude: 75.8560,
      );

      final deliveryOrderA = deliveryOrderFromOrder(orderA);
      final deliveryOrderB = deliveryOrderFromOrder(orderB);

      // Verify Order A
      expect(deliveryOrderA.pickupLocation, 'Palasia Depot #4');
      expect(deliveryOrderA.pickupPhone, '+91 731 111 2222');
      expect(deliveryOrderA.pickupLatitude, 22.7210);
      expect(deliveryOrderA.pickupLongitude, 75.8820);
      expect(deliveryOrderA.hasValidPickupCoordinates, isTrue);

      // Verify Order B
      expect(deliveryOrderB.pickupLocation, 'Rajwada Distribution Center');
      expect(deliveryOrderB.pickupPhone, '+91 731 333 4444');
      expect(deliveryOrderB.pickupLatitude, 22.7180);
      expect(deliveryOrderB.pickupLongitude, 75.8560);
      expect(deliveryOrderB.hasValidPickupCoordinates, isTrue);

      // Verify they are NOT identical
      expect(deliveryOrderA.pickupLocation,
          isNot(equals(deliveryOrderB.pickupLocation)));
      expect(deliveryOrderA.pickupPhone,
          isNot(equals(deliveryOrderB.pickupPhone)));
      expect(deliveryOrderA.pickupLatitude,
          isNot(equals(deliveryOrderB.pickupLatitude)));
    });

    test(
        '6. Missing/null pickup data uses legitimate default dairy hub fallback',
        () {
      final orderWithNull = createBaseOrder(
        id: 'order_null_pickup',
        pickupLocation: null,
        pickupPhone: null,
      );

      final deliveryOrder = deliveryOrderFromOrder(orderWithNull);

      expect(deliveryOrder.pickupLocation, 'Sawariya Dairy Hub, Vijay Nagar');
      expect(deliveryOrder.pickupPhone, '+91 731 400 5000');
      expect(deliveryOrder.pickupLatitude, 22.7255);
      expect(deliveryOrder.pickupLongitude, 75.8800);
      expect(deliveryOrder.hasValidPickupCoordinates, isTrue);
    });

    test(
        '7. Empty pickup data displays "Not specified" and does not display misleading hub information',
        () {
      final orderWithEmpty = createBaseOrder(
        id: 'order_empty_pickup',
        pickupLocation: '   ',
        pickupPhone: '',
      );

      final deliveryOrder = deliveryOrderFromOrder(orderWithEmpty);

      expect(deliveryOrder.pickupLocation, 'Not specified');
      expect(deliveryOrder.pickupPhone, '—');
      expect(deliveryOrder.pickupLatitude, isNull);
      expect(deliveryOrder.pickupLongitude, isNull);
      expect(deliveryOrder.hasValidPickupCoordinates, isFalse);
    });

    test(
        '8. Custom pickup location without coordinates does NOT invent fake coordinates',
        () {
      final orderNoCoords = createBaseOrder(
        id: 'order_no_coords',
        pickupLocation: 'Khandwa Road Dairy Center',
        pickupPhone: '+91 731 444 5555',
        pickupLatitude: null,
        pickupLongitude: null,
      );

      final deliveryOrder = deliveryOrderFromOrder(orderNoCoords);

      expect(deliveryOrder.pickupLocation, 'Khandwa Road Dairy Center');
      expect(deliveryOrder.pickupPhone, '+91 731 444 5555');
      expect(deliveryOrder.pickupLatitude, isNull);
      expect(deliveryOrder.pickupLongitude, isNull);
      expect(deliveryOrder.hasValidPickupCoordinates, isFalse);
    });

    test(
        '9. hasValidPickupCoordinates validates bounds and rejects 0,0 / NaN / Infinite',
        () {
      final validOrder = createBaseOrder(id: '1').copyWith(
        pickupLocation: 'Hub A',
      );
      final deliveryOrder = deliveryOrderFromOrder(validOrder);

      final zeroOrder =
          deliveryOrder.copyWith(pickupLatitude: 0.0, pickupLongitude: 0.0);
      expect(zeroOrder.hasValidPickupCoordinates, isFalse);

      final nanOrder = deliveryOrder.copyWith(
          pickupLatitude: double.nan, pickupLongitude: 75.88);
      expect(nanOrder.hasValidPickupCoordinates, isFalse);

      final infOrder = deliveryOrder.copyWith(
          pickupLatitude: 22.72, pickupLongitude: double.infinity);
      expect(infOrder.hasValidPickupCoordinates, isFalse);

      final outOfBounds =
          deliveryOrder.copyWith(pickupLatitude: 95.0, pickupLongitude: 75.88);
      expect(outOfBounds.hasValidPickupCoordinates, isFalse);

      final validCoordsOrder = deliveryOrder.copyWith(
          pickupLatitude: 22.7500, pickupLongitude: 75.8900);
      expect(validCoordsOrder.hasValidPickupCoordinates, isTrue);
    });
  });
}
