import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';

void main() {
  const sampleProduct = Product(
    id: 'prod_1',
    title: 'Buffalo Milk',
    categoryId: 'cat_milk',
    categoryName: 'Milk',
    price: 70.0,
    unit: '1L',
    imageUrl: '',
  );

  Address createAddress({
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: 'addr_test',
      label: 'Home',
      fullName: 'Customer Test',
      mobileNumber: '+91 99999 88888',
      houseFlat: 'Flat 101',
      streetArea: 'South Tukoganj',
      city: 'Indore',
      state: 'Madhya Pradesh',
      pinCode: '452001',
      latitude: latitude,
      longitude: longitude,
    );
  }

  Order createOrder({
    required String id,
    double? pickupLat,
    double? pickupLng,
    double? customerLat,
    double? customerLng,
    String? estimatedDeliveryTime,
  }) {
    return Order(
      id: id,
      orderCode: 'ORD999',
      items: [
        const CartItem(product: sampleProduct, quantity: 1),
      ],
      subtotal: 70.0,
      deliveryCharge: 20.0,
      totalAmount: 90.0,
      status: OrderStatus.placed,
      orderDate: DateTime(2026, 3, 1, 8, 0),
      deliveryAddress: createAddress(latitude: customerLat, longitude: customerLng),
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      estimatedDeliveryTime: estimatedDeliveryTime ?? 'Today by 7:30 AM',
    );
  }

  group('Task 3 — Dynamic Distance & ETA Service & Calculation Tests', () {
    test('1. Valid pickup and customer coordinates calculate dynamic distance and ETA', () {
      // Pickup at Vijay Nagar Hub (22.7533, 75.8937)
      // Customer at Palasia (22.7244, 75.8839)
      final distKm = DeliveryTrackingService.calculateDistanceKm(
        22.7533,
        75.8937,
        22.7244,
        75.8839,
      );

      expect(distKm, isNotNull);
      expect(distKm!, greaterThan(3.0));
      expect(distKm, lessThan(4.0));

      final formattedDist = DeliveryTrackingService.formatDistance(distKm);
      expect(formattedDist, contains('km'));

      final eta = DeliveryTrackingService.calculateEstimatedTime(distKm);
      expect(eta, startsWith('~'));
      expect(eta, endsWith('min'));
    });

    test('2. Changing pickup coordinates changes the calculated distance', () {
      const custLat = 22.7196;
      const custLng = 75.8577;

      // Pickup 1: Close (South Tukoganj, ~1 km)
      final dist1 = DeliveryTrackingService.calculateDistanceKm(
        22.7250,
        75.8650,
        custLat,
        custLng,
      );

      // Pickup 2: Far (Vijay Nagar, ~5 km)
      final dist2 = DeliveryTrackingService.calculateDistanceKm(
        22.7550,
        75.8950,
        custLat,
        custLng,
      );

      expect(dist1, isNotNull);
      expect(dist2, isNotNull);
      expect(dist2!, greaterThan(dist1!));
      expect(dist1, isNot(equals(dist2)));
    });

    test('3. Changing customer coordinates changes the calculated distance', () {
      const pickupLat = 22.7255;
      const pickupLng = 75.8800;

      // Customer 1: Near
      final distNear = DeliveryTrackingService.calculateDistanceKm(
        pickupLat,
        pickupLng,
        22.7280,
        75.8820,
      );

      // Customer 2: Far
      final distFar = DeliveryTrackingService.calculateDistanceKm(
        pickupLat,
        pickupLng,
        22.7800,
        75.9200,
      );

      expect(distNear, isNotNull);
      expect(distFar, isNotNull);
      expect(distFar!, greaterThan(distNear!));
    });

    test('4. ETA changes proportionally when distance changes', () {
      final etaShort = DeliveryTrackingService.calculateEstimatedTime(1.0);
      final etaMedium = DeliveryTrackingService.calculateEstimatedTime(3.2);
      final etaLong = DeliveryTrackingService.calculateEstimatedTime(10.0);

      // Extract numeric minutes
      final int minShort = int.parse(etaShort.replaceAll(RegExp(r'[^0-9]'), ''));
      final int minMedium = int.parse(etaMedium.replaceAll(RegExp(r'[^0-9]'), ''));
      final int minLong = int.parse(etaLong.replaceAll(RegExp(r'[^0-9]'), ''));

      expect(minShort, lessThan(minMedium));
      expect(minMedium, lessThan(minLong));
      expect(etaMedium, '~12 min');
    });

    test('5. Invalid coordinates are handled safely without crashing', () {
      // (0,0) placeholder
      expect(DeliveryTrackingService.calculateDistanceKm(0.0, 0.0, 22.7, 75.8), isNull);
      // NaN
      expect(DeliveryTrackingService.calculateDistanceKm(double.nan, 75.8, 22.7, 75.8), isNull);
      // Infinity
      expect(DeliveryTrackingService.calculateDistanceKm(22.7, double.infinity, 22.7, 75.8), isNull);
      // Out of bounds
      expect(DeliveryTrackingService.calculateDistanceKm(95.0, 75.8, 22.7, 75.8), isNull);
      // Null
      expect(DeliveryTrackingService.calculateDistanceKm(null, 75.8, 22.7, 75.8), isNull);
    });

    test('6. Missing/null coordinates fall back gracefully to delivery slot or dash', () {
      final formattedDist = DeliveryTrackingService.formatDistance(null);
      expect(formattedDist, '—');

      final fallbackEta = DeliveryTrackingService.calculateEstimatedTime(
        null,
        fallbackSlot: 'Today by 7:30 AM',
      );
      expect(fallbackEta, 'Today by 7:30 AM');

      final defaultDashEta = DeliveryTrackingService.calculateEstimatedTime(null);
      expect(defaultDashEta, '—');
    });
  });

  group('Task 3 — Delivery Panel deliveryOrderFromOrder Dynamic Distance & ETA Tests', () {
    test('7. Order with coordinates yields dynamic distance, ETA, and distanceKm', () {
      final order = createOrder(
        id: 'ord_1',
        pickupLat: 22.7255,
        pickupLng: 75.8800,
        customerLat: 22.7196,
        customerLng: 75.8577,
      );

      final deliveryOrder = deliveryOrderFromOrder(order);

      expect(deliveryOrder.distance, isNot('—'));
      expect(deliveryOrder.distance, contains('km'));
      expect(deliveryOrder.distanceKm, isNotNull);
      expect(deliveryOrder.distanceKm!, greaterThan(0));
      expect(deliveryOrder.estimatedTime, startsWith('~'));
      expect(deliveryOrder.estimatedTime, endsWith('min'));
    });

    test('8. Two distinct orders produce different distances and ETAs', () {
      final orderNear = createOrder(
        id: 'ord_near',
        pickupLat: 22.7255,
        pickupLng: 75.8800,
        customerLat: 22.7300,
        customerLng: 75.8820,
      );

      final orderFar = createOrder(
        id: 'ord_far',
        pickupLat: 22.7255,
        pickupLng: 75.8800,
        customerLat: 22.6800,
        customerLng: 75.8200,
      );

      final deliveryOrderNear = deliveryOrderFromOrder(orderNear);
      final deliveryOrderFar = deliveryOrderFromOrder(orderFar);

      expect(deliveryOrderNear.distance, isNot(equals(deliveryOrderFar.distance)));
      expect(deliveryOrderNear.estimatedTime, isNot(equals(deliveryOrderFar.estimatedTime)));
      expect(deliveryOrderNear.distanceKm!, lessThan(deliveryOrderFar.distanceKm!));
    });

    test('9. Missing customer coordinates falls back gracefully without crashing', () {
      final orderNoCustomerCoords = createOrder(
        id: 'ord_no_customer_coords',
        pickupLat: 22.7255,
        pickupLng: 75.8800,
        customerLat: null,
        customerLng: null,
        estimatedDeliveryTime: 'Today by 7:30 AM',
      );

      final deliveryOrder = deliveryOrderFromOrder(orderNoCustomerCoords);

      expect(deliveryOrder.distance, '—');
      expect(deliveryOrder.distanceKm, isNull);
      expect(deliveryOrder.estimatedTime, 'Today by 7:30 AM');
    });

    test('10. DeliveryOrder copyWith preserves and updates distanceKm correctly', () {
      final order = createOrder(
        id: 'ord_copy',
        pickupLat: 22.7255,
        pickupLng: 75.8800,
        customerLat: 22.7196,
        customerLng: 75.8577,
      );

      final deliveryOrder = deliveryOrderFromOrder(order);
      final copied = deliveryOrder.copyWith(distanceKm: 5.5, distance: '5.5 km');

      expect(copied.distanceKm, 5.5);
      expect(copied.distance, '5.5 km');
      expect(copied.orderId, deliveryOrder.orderId);
    });
  });
}
