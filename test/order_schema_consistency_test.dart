import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/services/order_service.dart';

void main() {
  group('Order Schema Consistency Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late OrderService orderService;

    const testProduct = Product(
      id: 'prod_milk_1',
      title: 'Fresh Cow Milk 1L',
      categoryId: 'milk',
      categoryName: 'Milk',
      price: 65.0,
      originalPrice: 70.0,
      unit: '1L',
      imageUrl: 'https://cdn.sawariya.com/milk.png',
      description: 'Pure cow milk',
      rating: 4.8,
      reviewCount: 150,
    );

    const testAddress = Address(
      id: 'addr_101',
      label: 'Home',
      fullName: 'Aarav Patel',
      mobileNumber: '+91 9876543210',
      houseFlat: 'Flat 402, Tower B',
      streetArea: 'Sector 62',
      city: 'Noida',
      state: 'Uttar Pradesh',
      pinCode: '201301',
      latitude: 28.6280,
      longitude: 77.3649,
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      orderService = OrderService(firestore: fakeFirestore);
    });

    test('Order.toFirestore writes customerName and customerPhone at root while preserving deliveryAddress', () {
      final order = Order(
        id: 'ord_test_001',
        orderCode: 'SWD101',
        items: [const CartItem(product: testProduct, quantity: 2)],
        subtotal: 130.0,
        deliveryCharge: 30.0,
        discount: 0.0,
        totalAmount: 160.0,
        status: OrderStatus.placed,
        orderDate: DateTime(2026, 9, 22),
        deliveryDate: DateTime(2026, 9, 22),
        deliveryAddress: testAddress,
        userId: 'user_aarav_1',
      );

      final firestoreMap = order.toFirestore();

      // Root level consistency
      expect(firestoreMap['customerName'], 'Aarav Patel');
      expect(firestoreMap['customerPhone'], '+91 9876543210');
      expect(firestoreMap['userId'], 'user_aarav_1');
      expect(firestoreMap['orderCode'], 'SWD101');

      // Nested deliveryAddress preservation
      final nestedAddr = firestoreMap['deliveryAddress'] as Map<String, dynamic>;
      expect(nestedAddr['fullName'], 'Aarav Patel');
      expect(nestedAddr['mobileNumber'], '+91 9876543210');
      expect(nestedAddr['houseFlat'], 'Flat 402, Tower B');
      expect(nestedAddr['streetArea'], 'Sector 62');
      expect(nestedAddr['city'], 'Noida');
      expect(nestedAddr['state'], 'Uttar Pradesh');
      expect(nestedAddr['pinCode'], '201301');
      expect(nestedAddr['latitude'], 28.6280);
      expect(nestedAddr['longitude'], 77.3649);
    });

    test('placeOrder writes root-level customerName and customerPhone into Firestore order document', () async {
      final placedOrder = await orderService.placeOrder(
        userId: 'user_aarav_1',
        items: [const CartItem(product: testProduct, quantity: 3)],
        deliveryAddress: testAddress,
        paymentMethod: 'Cash on Delivery',
      );

      expect(placedOrder.id, isNotEmpty);

      // Verify Firestore persisted document
      final orderDoc = await fakeFirestore.collection('orders').doc(placedOrder.id).get();
      expect(orderDoc.exists, isTrue);

      final data = orderDoc.data()!;
      expect(data['userId'], 'user_aarav_1');
      expect(data['customerName'], 'Aarav Patel');
      expect(data['customerPhone'], '+91 9876543210');
      expect(data['status'], 'Pending');

      // Verify nested deliveryAddress is preserved in Firestore doc
      final addrMap = data['deliveryAddress'] as Map<String, dynamic>;
      expect(addrMap['fullName'], 'Aarav Patel');
      expect(addrMap['mobileNumber'], '+91 9876543210');
      expect(addrMap['houseFlat'], 'Flat 402, Tower B');
      expect(addrMap['streetArea'], 'Sector 62');
      expect(addrMap['city'], 'Noida');
      expect(addrMap['pinCode'], '201301');
      expect(addrMap['latitude'], 28.6280);
      expect(addrMap['longitude'], 77.3649);

      // Verify payment record in payments collection has matching customer info
      final paymentDoc = await fakeFirestore.collection('payments').doc('PAY_${placedOrder.id}').get();
      expect(paymentDoc.exists, isTrue);
      final paymentData = paymentDoc.data()!;
      expect(paymentData['customerName'], 'Aarav Patel');
      expect(paymentData['customerPhone'], '+91 9876543210');
      expect(paymentData['userId'], 'user_aarav_1');
    });

    test('Order deserializes smoothly even when root customerName/customerPhone are absent (legacy fallback)', () {
      final legacyData = <String, dynamic>{
        'orderCode': 'LEG123',
        'userId': 'user_legacy',
        'status': 'Pending',
        'subtotal': 65.0,
        'deliveryCharge': 30.0,
        'discount': 0.0,
        'totalAmount': 95.0,
        'createdAt': Timestamp.now(),
        'items': [
          {
            'productId': 'prod_milk_1',
            'title': 'Fresh Cow Milk 1L',
            'unit': '1L',
            'price': 65.0,
            'quantity': 1,
            'totalPrice': 65.0,
          }
        ],
        'deliveryAddress': {
          'fullName': 'Legacy Customer',
          'mobileNumber': '9998887776',
          'houseFlat': 'House 1',
          'streetArea': 'Main Road',
          'city': 'Delhi',
          'state': 'Delhi',
          'pinCode': '110001',
        },
      };

      final order = Order.fromFirestore(legacyData, 'ord_legacy_001');
      expect(order.deliveryAddress.fullName, 'Legacy Customer');
      expect(order.deliveryAddress.mobileNumber, '9998887776');
    });
  });
}
