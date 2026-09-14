import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dairy_app/features/delivery_map/delivery_map_screen.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';

class MockDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  MockDeliveryNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = 0;
  @override
  bool persistentConnection = false;
  @override
  bool bufferOutput = false;

  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
  @override
  Future<HttpClientResponse> get done async => _FakeHttpClientResponse();
  @override
  Future flush() async {}
  @override
  void write(Object? obj) {}
  @override
  void writeAll(Iterable objects, [String separator = ""]) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? obj = ""]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  List<String>? operator [](String name) => _headers[name];

  @override
  String? value(String name) {
    final list = _headers[name];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => kTransparentPng.length;
  @override
  HttpHeaders get headers => _FakeHttpHeaders();
  @override
  bool get isRedirect => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.value(kTransparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  group('Delivery Location & Coordinate Validation Tests', () {
    test('isValidCoordinates correctly validates real geographic boundaries and rejects placeholders', () {
      // Valid coordinates
      expect(DeliveryTrackingService.isValidCoordinates(22.7255, 75.8800), isTrue);
      expect(DeliveryTrackingService.isValidCoordinates(28.6139, 77.2090), isTrue);
      expect(DeliveryTrackingService.isValidCoordinates(-33.8688, 151.2093), isTrue);
      expect(DeliveryTrackingService.isValidCoordinates(90.0, 180.0), isTrue);
      expect(DeliveryTrackingService.isValidCoordinates(-90.0, -180.0), isTrue);

      // Null coordinates
      expect(DeliveryTrackingService.isValidCoordinates(null, 75.8800), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(22.7255, null), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(null, null), isFalse);

      // Zero placeholder coordinates
      expect(DeliveryTrackingService.isValidCoordinates(0.0, 0.0), isFalse);

      // Out of bounds
      expect(DeliveryTrackingService.isValidCoordinates(90.0001, 75.8800), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(-90.0001, 75.8800), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(22.7255, 180.0001), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(22.7255, -180.0001), isFalse);

      // NaN and Infinite
      expect(DeliveryTrackingService.isValidCoordinates(double.nan, 75.8800), isFalse);
      expect(DeliveryTrackingService.isValidCoordinates(double.infinity, 75.8800), isFalse);
    });

    test('parseCoordinates parses diverse Firestore coordinate formats and rejects invalid values', () {
      // List format
      final listResult = DeliveryTrackingService.parseCoordinates([22.7255, 75.8800]);
      expect(listResult, isNotNull);
      expect(listResult!.latitude, 22.7255);
      expect(listResult.longitude, 75.8800);

      // GeoPoint format
      final geoResult = DeliveryTrackingService.parseCoordinates(const GeoPoint(22.7255, 75.8800));
      expect(geoResult, isNotNull);
      expect(geoResult!.latitude, 22.7255);
      expect(geoResult.longitude, 75.8800);

      // Map format with 'latitude' and 'longitude'
      final mapResult1 = DeliveryTrackingService.parseCoordinates({
        'latitude': 22.7255,
        'longitude': 75.8800,
      });
      expect(mapResult1, isNotNull);
      expect(mapResult1!.latitude, 22.7255);
      expect(mapResult1.longitude, 75.8800);

      // Map format with 'lat' and 'lng'
      final mapResult2 = DeliveryTrackingService.parseCoordinates({
        'lat': '28.6139',
        'lng': '77.2090',
      });
      expect(mapResult2, isNotNull);
      expect(mapResult2!.latitude, 28.6139);
      expect(mapResult2.longitude, 77.2090);

      // Invalid / zero coordinates
      expect(DeliveryTrackingService.parseCoordinates([0.0, 0.0]), isNull);
      expect(DeliveryTrackingService.parseCoordinates(const GeoPoint(0.0, 0.0)), isNull);
      expect(DeliveryTrackingService.parseCoordinates({'latitude': 999.0, 'longitude': 0.0}), isNull);
      expect(DeliveryTrackingService.parseCoordinates(null), isNull);
      expect(DeliveryTrackingService.parseCoordinates('invalid string'), isNull);
    });

    test('DeliveryOrder hasValidCoordinates works as expected', () {
      final validOrder = DeliveryOrder(
        id: 'ord_1',
        orderId: 'ord_1',
        customerName: 'Aarav',
        customerPhone: '9876543210',
        customerAddress: 'Indore',
        pickupLocation: 'Hub',
        pickupPhone: '1234567890',
        items: const ['Milk 1L'],
        amount: 60.0,
        deliveryFee: 15.0,
        status: DeliveryOrderStatus.accepted,
        orderTime: DateTime(2026, 3, 1),
        distance: '2 km',
        estimatedTime: '15 mins',
        latitude: 22.7255,
        longitude: 75.8800,
      );
      expect(validOrder.hasValidCoordinates, isTrue);

      final zeroOrder = validOrder.copyWith(latitude: 0.0, longitude: 0.0);
      expect(zeroOrder.hasValidCoordinates, isFalse);

      final nullOrder = DeliveryOrder(
        id: 'ord_null',
        orderId: 'ord_null',
        customerName: 'Aarav',
        customerPhone: '9876543210',
        customerAddress: 'Indore',
        pickupLocation: 'Hub',
        pickupPhone: '1234567890',
        items: const ['Milk 1L'],
        amount: 60.0,
        deliveryFee: 15.0,
        status: DeliveryOrderStatus.accepted,
        orderTime: DateTime(2026, 3, 1),
        distance: '2 km',
        estimatedTime: '15 mins',
        latitude: null,
        longitude: null,
      );
      expect(nullOrder.hasValidCoordinates, isFalse);

      final outOfBoundsOrder = validOrder.copyWith(latitude: 95.0, longitude: 200.0);
      expect(outOfBoundsOrder.hasValidCoordinates, isFalse);
    });

    test('deliveryOrderFromOrder populates coordinates only when real and valid', () {
      final realOrder = Order(
        id: 'real_ord_1',
        orderCode: 'REAL01',
        items: const [],
        subtotal: 100,
        deliveryCharge: 20,
        discount: 0,
        totalAmount: 120,
        status: OrderStatus.confirmed,
        orderDate: DateTime(2026, 3, 1),
        deliveryAddress: const Address(
          id: 'addr_1',
          fullName: 'Vikram',
          mobileNumber: '9999999999',
          houseFlat: '101',
          streetArea: 'Scheme 54',
          city: 'Indore',
          state: 'MP',
          pinCode: '452010',
          latitude: 22.7533,
          longitude: 75.8937,
        ),
      );

      final deliveryOrder = deliveryOrderFromOrder(realOrder);
      expect(deliveryOrder.latitude, 22.7533);
      expect(deliveryOrder.longitude, 75.8937);
      expect(deliveryOrder.hasValidCoordinates, isTrue);

      final invalidCoordOrder = realOrder.copyWith(
        deliveryAddress: realOrder.deliveryAddress.copyWith(latitude: 0.0, longitude: 0.0),
      );
      final invalidDeliveryOrder = deliveryOrderFromOrder(invalidCoordOrder);
      expect(invalidDeliveryOrder.latitude, isNull);
      expect(invalidDeliveryOrder.longitude, isNull);
      expect(invalidDeliveryOrder.hasValidCoordinates, isFalse);
    });
  });

  group('DeliveryMapScreen Real Location UI Tests', () {
    testWidgets('Renders location unavailable state when agent has no streamed location', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryAgentLocationStreamProvider.overrideWith((ref) => Stream.value(null)),
            deliveryActiveOrdersStreamProvider.overrideWith((ref) => Stream.value([])),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryNotifier(
                  DeliveryAgent.empty('agent_test').copyWith(
                    name: 'Karan Sharma',
                    status: DeliveryStatus.onDuty,
                    isLoaded: true,
                  ),
                )),
          ],
          child: const MaterialApp(
            home: DeliveryMapScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Shows location unavailable indicator
      expect(find.text('NO GPS'), findsOneWidget);
      expect(find.text('Agent location unavailable · Waiting for real GPS stream'), findsOneWidget);

      // Ensure no live marker exists on map
      final markerLayerFinder = find.byType(MarkerLayer);
      expect(markerLayerFinder, findsOneWidget);
      final markerLayer = tester.widget<MarkerLayer>(markerLayerFinder);

      // Only Hub marker exists, no demo agent marker
      expect(markerLayer.markers.length, equals(1));
      expect(markerLayer.markers.first.point, equals(const LatLng(22.7255, 75.8800))); // Hub
      // Old demo coordinate (22.7320, 75.8745) must NOT be present
      expect(markerLayer.markers.any((m) => m.point.latitude == 22.7320), isFalse);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Renders real agent marker when valid real location is streamed from Firestore', (tester) async {
      const realAgentPos = LatLng(28.6139, 77.2090);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryAgentLocationStreamProvider.overrideWith((ref) => Stream.value(realAgentPos)),
            deliveryActiveOrdersStreamProvider.overrideWith((ref) => Stream.value([])),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryNotifier(
                  DeliveryAgent.empty('agent_test').copyWith(
                    name: 'Karan Sharma',
                    status: DeliveryStatus.onDuty,
                    isLoaded: true,
                  ),
                )),
          ],
          child: const MaterialApp(
            home: DeliveryMapScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Shows LIVE status badge
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Agent location unavailable · Waiting for real GPS stream'), findsNothing);

      // Verifies agent marker is placed at the REAL position
      final markerLayerFinder = find.byType(MarkerLayer);
      expect(markerLayerFinder, findsOneWidget);
      final markerLayer = tester.widget<MarkerLayer>(markerLayerFinder);

      // 2 markers: Hub + Real Agent
      expect(markerLayer.markers.length, equals(2));
      expect(markerLayer.markers.any((m) => m.point.latitude == realAgentPos.latitude && m.point.longitude == realAgentPos.longitude), isTrue);

      // Old demo coordinate must NOT be present
      expect(markerLayer.markers.any((m) => m.point.latitude == 22.7320), isFalse);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Selected order marker with highlighted badge renders without RenderFlex overflow', (tester) async {
      final activeOrder = DeliveryOrder(
        id: 'ord_active_1',
        orderId: 'ord_active_1',
        orderCode: 'ORD-2026-0301-1234',
        customerName: 'Rahul Verma',
        customerPhone: '9876543210',
        customerAddress: 'Flat 402, Lotus Pride, Indore',
        pickupLocation: 'Sawariya Dairy Hub',
        pickupPhone: '9999999999',
        items: const ['2x Buffalo Milk 1L'],
        amount: 180.0,
        deliveryFee: 20.0,
        status: DeliveryOrderStatus.accepted, // Blue marker color
        orderTime: DateTime.now(),
        distance: '1.8 km',
        estimatedTime: '12 mins',
        latitude: 22.7300,
        longitude: 75.8850,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryAgentLocationStreamProvider.overrideWith((ref) => Stream.value(const LatLng(22.7255, 75.8800))),
            deliveryActiveOrdersStreamProvider.overrideWith((ref) => Stream.value([activeOrder])),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryNotifier(
                  DeliveryAgent.empty('agent_test').copyWith(
                    name: 'Karan Sharma',
                    status: DeliveryStatus.onDuty,
                    isLoaded: true,
                  ),
                )),
          ],
          child: const MaterialApp(
            home: DeliveryMapScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify order item appears in bottom sheet
      expect(find.text('Rahul Verma'), findsOneWidget);

      // Tap to select the order, activating the highlighted marker with badge label
      await tester.tap(find.text('Rahul Verma'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no overflow exception was logged and label is displayed
      expect(tester.takeException(), isNull);
      expect(find.text('ORD-2026-0301-1234'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
