// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dairy_app/services/route_service.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/product.dart';

// ---------------------------------------------------------------------------
// Shared test fixtures
// ---------------------------------------------------------------------------

const _agentPos = LatLng(22.7300, 75.8900); // agent current location
const _pickupPos = LatLng(22.7255, 75.8800); // pickup / hub
const _customerPos = LatLng(22.7196, 75.8577); // customer delivery address

// Slightly different position within the 50 m threshold (≈ 5 m away)
const _agentPosNearlyUnchanged = LatLng(22.7300451, 75.8900451);

// Position clearly outside the 50 m threshold
const _agentPosFarAway = LatLng(22.7350, 75.8950);

// Invalid coordinate sentinels
const _zeroPos = LatLng(0.0, 0.0);
const _nanLat = LatLng(double.nan, 75.8800);
const _infLng = LatLng(22.7255, double.infinity);
const _outOfBounds = LatLng(95.0, 75.8800); // lat > 90

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DeliveryOrder _makeOrder({
  double? pickupLat = 22.7255,
  double? pickupLng = 75.8800,
  double? customerLat = 22.7196,
  double? customerLng = 75.8577,
  String? pickupLocation = 'Dynamic Pickup Hub',
}) {
  const product = Product(
    id: 'prod_1',
    title: 'Milk',
    categoryId: 'cat_1',
    categoryName: 'Dairy',
    price: 60.0,
    unit: '1L',
    imageUrl: '',
  );
  final address = Address(
    id: 'addr_1',
    label: 'Home',
    fullName: 'Test Customer',
    mobileNumber: '+91 98765 43210',
    houseFlat: '101',
    streetArea: 'South Tukoganj',
    city: 'Indore',
    state: 'Madhya Pradesh',
    pinCode: '452001',
    latitude: customerLat,
    longitude: customerLng,
  );
  final order = Order(
    id: 'order_test_01',
    orderCode: 'TST001',
    items: [const CartItem(product: product, quantity: 1)],
    subtotal: 60.0,
    deliveryCharge: 20.0,
    totalAmount: 80.0,
    status: OrderStatus.placed,
    orderDate: DateTime(2026, 9, 1, 8, 0),
    deliveryAddress: address,
    pickupLocation: pickupLocation,
    pickupLatitude: pickupLat,
    pickupLongitude: pickupLng,
  );
  return deliveryOrderFromOrder(order);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Group 1: RouteService.buildStraightLineRoute
  // ─────────────────────────────────────────────────────────────────────────

  group('Task 6 — RouteService.buildStraightLineRoute', () {
    // Test 1: valid coordinates produce route/polyline data
    test('1. Valid agent + pickup + customer → drawable 3-point route', () {
      final result = RouteService.buildStraightLineRoute(
        agentPos: _agentPos,
        pickupPos: _pickupPos,
        customerPos: _customerPos,
      );

      expect(result, isNotNull);
      expect(result!.isDrawable, isTrue);
      expect(result.points.length, 3);
      expect(result.isStraightLineFallback, isTrue,
          reason:
              'No road-routing API is configured; must be marked as fallback');
    });

    // Test 2: agent → pickup → customer ordering is correct
    test('2. Points are ordered: agent → pickup → customer', () {
      final result = RouteService.buildStraightLineRoute(
        agentPos: _agentPos,
        pickupPos: _pickupPos,
        customerPos: _customerPos,
      );

      expect(result, isNotNull);
      expect(result!.points[0], equals(_agentPos),
          reason: 'First point must be agent position');
      expect(result.points[1], equals(_pickupPos),
          reason: 'Second point must be pickup position');
      expect(result.points[2], equals(_customerPos),
          reason: 'Third point must be customer position');
    });

    // Test 3: missing agent coordinate is handled safely
    test('3. Missing agent → pickup → customer (2 points, no crash)', () {
      final result = RouteService.buildStraightLineRoute(
        agentPos: null,
        pickupPos: _pickupPos,
        customerPos: _customerPos,
      );

      expect(result, isNotNull,
          reason: 'Should still draw pickup → customer segment');
      expect(result!.isDrawable, isTrue);
      expect(result.points.length, 2);
      expect(result.points[0], equals(_pickupPos));
      expect(result.points[1], equals(_customerPos));
      expect(result.segmentDescription, contains('Pickup'));
      expect(result.segmentDescription, contains('Customer'));
    });

    // Test 4: missing pickup coordinate is handled safely
    test('4. Missing pickup → agent → customer (2 points, no crash)', () {
      final result = RouteService.buildStraightLineRoute(
        agentPos: _agentPos,
        pickupPos: null,
        customerPos: _customerPos,
      );

      expect(result, isNotNull,
          reason: 'Should still draw agent → customer segment');
      expect(result!.isDrawable, isTrue);
      expect(result.points.length, 2);
      expect(result.points[0], equals(_agentPos));
      expect(result.points[1], equals(_customerPos));
      expect(result.segmentDescription, contains('Agent'));
      expect(result.segmentDescription, contains('Customer'));
    });

    // Test 5: missing customer coordinate is handled safely
    test('5. Missing customer → agent → pickup (2 points, no crash)', () {
      final result = RouteService.buildStraightLineRoute(
        agentPos: _agentPos,
        pickupPos: _pickupPos,
        customerPos: null,
      );

      expect(result, isNotNull,
          reason: 'Should still draw agent → pickup segment');
      expect(result!.isDrawable, isTrue);
      expect(result.points.length, 2);
      expect(result.points[0], equals(_agentPos));
      expect(result.points[1], equals(_pickupPos));
      expect(result.segmentDescription, contains('Agent'));
      expect(result.segmentDescription, contains('Pickup'));
    });

    // Test 6: invalid coordinates do not create a route
    test('6. Invalid coordinates are rejected — no route produced', () {
      // (0, 0) placeholder
      expect(
        RouteService.buildStraightLineRoute(
          agentPos: _zeroPos,
          pickupPos: _zeroPos,
          customerPos: _zeroPos,
        ),
        isNull,
        reason: '(0, 0) sentinel should be treated as missing',
      );

      // NaN latitude
      expect(
        RouteService.buildStraightLineRoute(
          agentPos: _nanLat,
          pickupPos: _nanLat,
          customerPos: _customerPos,
        ),
        // Only customerPos is valid; need ≥ 2 valid for a route
        isNull,
      );

      // Infinite longitude
      expect(
        RouteService.buildStraightLineRoute(
          agentPos: _infLng,
          pickupPos: _pickupPos,
          customerPos: _infLng,
        ),
        // Only pickupPos is valid — need ≥ 2 valid
        isNull,
      );

      // Out-of-bounds latitude (> 90)
      expect(
        RouteService.buildStraightLineRoute(
          agentPos: _outOfBounds,
          pickupPos: _outOfBounds,
          customerPos: _outOfBounds,
        ),
        isNull,
      );

      // All null
      expect(
        RouteService.buildStraightLineRoute(
          agentPos: null,
          pickupPos: null,
          customerPos: null,
        ),
        isNull,
      );
    });

    // Test 7: routing/network failure does not crash the map
    // RouteService is pure (no network calls); verify graceful null return
    // and that RouteResult.isDrawable correctly gates rendering.
    test('7. null RouteResult is handled safely (isDrawable is false)', () {
      // Simulate what the map widget checks before rendering
      final result = RouteService.buildStraightLineRoute(
        agentPos: null,
        pickupPos: null,
        customerPos: null,
      );

      // Map widget gate: `result != null && result.isDrawable`
      final shouldDraw = result != null && result.isDrawable;
      expect(shouldDraw, isFalse,
          reason: 'Map must not try to draw when no valid route exists');

      // A 1-point result is also not drawable (edge case guard)
      final onePoint = RouteService.buildStraightLineRoute(
        agentPos: null,
        pickupPos: null,
        customerPos: _customerPos,
      );
      expect(onePoint, isNull,
          reason: 'A single coordinate does not form a drawable segment');
    });

    // Test 8: dynamic pickup coordinates are used (not hardcoded hub)
    test('8. Dynamic pickup coordinates are used per order', () {
      const dynamicPickup = LatLng(22.7400, 75.9000); // not the default hub
      const defaultHub = LatLng(22.7255, 75.8800);

      final resultDynamic = RouteService.buildStraightLineRoute(
        agentPos: _agentPos,
        pickupPos: dynamicPickup,
        customerPos: _customerPos,
      );
      final resultHub = RouteService.buildStraightLineRoute(
        agentPos: _agentPos,
        pickupPos: defaultHub,
        customerPos: _customerPos,
      );

      expect(resultDynamic, isNotNull);
      expect(resultHub, isNotNull);

      // The pickup waypoint must differ between the two results
      expect(resultDynamic!.points[1], equals(dynamicPickup));
      expect(resultHub!.points[1], equals(defaultHub));
      expect(resultDynamic.points[1], isNot(equals(resultHub.points[1])),
          reason:
              'Route must use the actual per-order pickup coords, not a constant');
    });

    // Test 9: route is not unnecessarily recalculated for unchanged coords
    test('9. hasCoordinatesChangedEnough: no rebuild within 50 m threshold',
        () {
      // Same position → no movement → threshold NOT crossed
      expect(
        RouteService.hasCoordinatesChangedEnough(_agentPos, _agentPos),
        isFalse,
        reason: 'Identical positions should not trigger a rebuild',
      );

      // Nearly unchanged (≈ 5 m away) → threshold NOT crossed
      expect(
        RouteService.hasCoordinatesChangedEnough(
            _agentPos, _agentPosNearlyUnchanged),
        isFalse,
        reason: 'Movement < 50 m should not trigger a rebuild',
      );

      // Far away (> 50 m) → threshold IS crossed
      expect(
        RouteService.hasCoordinatesChangedEnough(_agentPos, _agentPosFarAway),
        isTrue,
        reason: 'Movement > 50 m should trigger a rebuild',
      );

      // null old position → always treat as changed (first reading)
      expect(
        RouteService.hasCoordinatesChangedEnough(null, _agentPos),
        isTrue,
        reason: 'First GPS reading (old = null) must always trigger rebuild',
      );

      // null new position → treat as changed (lost signal)
      expect(
        RouteService.hasCoordinatesChangedEnough(_agentPos, null),
        isTrue,
        reason: 'Lost GPS signal (new = null) must trigger rebuild',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 2: RouteService + deliveryOrderFromOrder integration
  // (exercises dynamic pickup coords round-trip)
  // ─────────────────────────────────────────────────────────────────────────

  group('Task 6 — RouteService + deliveryOrderFromOrder integration', () {
    test('8b. Dynamic pickup from order flows correctly into RouteService', () {
      final deliveryOrder = _makeOrder(
        pickupLat: 22.7400,
        pickupLng: 75.9000,
        pickupLocation: 'Annapurna Dynamic Hub',
      );

      expect(deliveryOrder.hasValidPickupCoordinates, isTrue,
          reason: 'Order-level dynamic pickup coords must be valid');

      final pickupPos = LatLng(
        deliveryOrder.pickupLatitude!,
        deliveryOrder.pickupLongitude!,
      );
      final customerPos = deliveryOrder.hasValidCoordinates
          ? LatLng(deliveryOrder.latitude!, deliveryOrder.longitude!)
          : null;

      final result = RouteService.buildStraightLineRoute(
        agentPos: _agentPos,
        pickupPos: pickupPos,
        customerPos: customerPos,
      );

      expect(result, isNotNull);
      expect(result!.points[1].latitude, closeTo(22.7400, 0.0001),
          reason:
              'Pickup waypoint must come from the order, not the hardcoded hub');
    });

    test('9b. No rebuild when order id unchanged and agent within threshold',
        () {
      // Simulate two consecutive build() calls with nearly identical agent pos
      String? lastOrderId;
      LatLng? lastAgentPos;

      void simulateMaybeRebuild(LatLng? agentPos, String? orderId) {
        final orderIdChanged = orderId != lastOrderId;
        final agentMovedEnough =
            RouteService.hasCoordinatesChangedEnough(lastAgentPos, agentPos);
        if (!orderIdChanged && !agentMovedEnough) return; // skip
        lastOrderId = orderId;
        lastAgentPos = agentPos;
      }

      // First call: always rebuilds (lastOrderId is null)
      simulateMaybeRebuild(_agentPos, 'order_01');
      expect(lastOrderId, 'order_01');

      // Second call: same order, agent barely moved (< 50 m)
      final beforeLastAgentPos = lastAgentPos;
      simulateMaybeRebuild(_agentPosNearlyUnchanged, 'order_01');
      // Guards should have prevented an update
      expect(lastAgentPos, equals(beforeLastAgentPos),
          reason: 'Agent position guard should prevent unnecessary rebuild');

      // Third call: same order, agent moved far (> 50 m) → must rebuild
      simulateMaybeRebuild(_agentPosFarAway, 'order_01');
      expect(lastAgentPos, equals(_agentPosFarAway),
          reason: 'Agent moving > 50 m must trigger rebuild');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 3: Coordinate validation (DeliveryTrackingService, used by RouteService)
  // ─────────────────────────────────────────────────────────────────────────

  group('Task 6 — Coordinate validation foundation', () {
    test(
        '10. DeliveryTrackingService.isValidCoordinates rejects all invalid forms',
        () {
      expect(DeliveryTrackingService.isValidCoordinates(null, null), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(0.0, 0.0), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(double.nan, 75.8),
          isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(22.7, double.infinity),
          isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(95.0, 75.8), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(-95.0, 75.8), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(22.7, 185.0), isFalse);
      // Valid
      expect(
          DeliveryTrackingService.isValidCoordinates(22.7255, 75.8800), isTrue);
      expect(DeliveryTrackingService.isValidCoordinates(-33.8688, 151.2093),
          isTrue);
    });

    test('10b. hasValidCoordinates on DeliveryOrder rejects invalid forms', () {
      final validOrder = _makeOrder();
      expect(validOrder.hasValidCoordinates, isTrue);
      expect(validOrder.hasValidPickupCoordinates, isTrue);

      final noCustomer = _makeOrder(customerLat: null, customerLng: null);
      expect(noCustomer.hasValidCoordinates, isFalse);

      final zeroCustomer = _makeOrder(customerLat: 0.0, customerLng: 0.0);
      expect(zeroCustomer.hasValidCoordinates, isFalse);

      final noPickup = _makeOrder(
          pickupLat: null, pickupLng: null, pickupLocation: 'Custom Hub');
      expect(noPickup.hasValidPickupCoordinates, isFalse);
    });
  });
}
