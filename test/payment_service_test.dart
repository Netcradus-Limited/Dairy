import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dairy_app/models/payment_model.dart';

void main() {
  group('DairyPayment Model & Serialization Tests', () {
    test('Deserializes complete Firestore payment data correctly', () {
      final now = DateTime(2026, 9, 17, 10, 30);
      final rawData = {
        'id': 'PAY_ORD_99182',
        'orderId': 'ORD_99182',
        'orderCode': 'KRT482',
        'userId': 'user_uid_123',
        'customerName': 'Ramesh Patel',
        'customerPhone': '+91 98765 43210',
        'amount': 450.0,
        'method': 'Online (UPI)',
        'paymentMethod': 'Online (UPI)',
        'status': 'Success',
        'paymentStatus': 'Success',
        'transactionId': 'TXN_UPI_998129',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final payment = DairyPayment.fromFirestore(rawData, 'PAY_ORD_99182');

      expect(payment.id, equals('PAY_ORD_99182'));
      expect(payment.orderId, equals('ORD_99182'));
      expect(payment.orderCode, equals('KRT482'));
      expect(payment.orderOrWalletId, equals('#KRT482'));
      expect(payment.userId, equals('user_uid_123'));
      expect(payment.customerName, equals('Ramesh Patel'));
      expect(payment.customerPhone, equals('+91 98765 43210'));
      expect(payment.amount, equals(450.0));
      expect(payment.method, equals('Online (UPI)'));
      expect(payment.status, equals('Success'));
      expect(payment.transactionId, equals('TXN_UPI_998129'));
      expect(payment.createdAt, equals(now));
      expect(payment.updatedAt, equals(now));
    });

    test('Handles missing/null fields with safe defaults gracefully', () {
      final rawData = <String, dynamic>{};

      final payment = DairyPayment.fromFirestore(rawData, 'doc_xyz');

      expect(payment.id, equals('PAY_doc_xyz'));
      expect(payment.customerName, equals('Customer'));
      expect(payment.orderOrWalletId, equals('#ORD'));
      expect(payment.amount, equals(0.0));
      expect(payment.method, equals('Online Payment'));
      expect(payment.status, equals('Success'));
      expect(payment.transactionId, isNull);
      expect(payment.createdAt, isNull);
    });

    test(
        'Correctly handles COD payment with null transactionId and Pending status',
        () {
      final rawData = {
        'id': 'PAY_ORD_COD_01',
        'orderId': 'ORD_COD_01',
        'orderCode': 'COD101',
        'userId': 'user_cod_1',
        'customerName': 'Suresh Kumar',
        'amount': 280.0,
        'method': 'Cash on Delivery',
        'status': 'Pending',
        'transactionId': null,
      };

      final payment = DairyPayment.fromFirestore(rawData, 'PAY_ORD_COD_01');

      expect(payment.method, equals('Cash on Delivery'));
      expect(payment.status, equals('Pending'));
      expect(payment.transactionId, isNull);
    });

    test('Correctly handles Non-COD (Online PG / UPI / Wallet) payments', () {
      final rawData = {
        'id': 'PAY_ORD_RAZORPAY_01',
        'orderId': 'ORD_RP_01',
        'orderCode': 'RPY202',
        'userId': 'user_rp_1',
        'customerName': 'Meena Sharma',
        'amount': 720.50,
        'method': 'Razorpay PG',
        'status': 'Paid',
        'transactionId': 'pay_MNO8392019',
      };

      final payment =
          DairyPayment.fromFirestore(rawData, 'PAY_ORD_RAZORPAY_01');

      expect(payment.method, equals('Razorpay PG'));
      expect(payment.status, equals('Success')); // Normalized from 'Paid'
      expect(payment.transactionId, equals('pay_MNO8392019'));
    });

    test('Status normalization handles various status casing and aliases', () {
      expect(DairyPayment.normalizeStatus('COMPLETED'), equals('Success'));
      expect(DairyPayment.normalizeStatus('paid'), equals('Success'));
      expect(DairyPayment.normalizeStatus('delivered'), equals('Success'));
      expect(DairyPayment.normalizeStatus('placed'), equals('Pending'));
      expect(DairyPayment.normalizeStatus('processing'), equals('Pending'));
      expect(DairyPayment.normalizeStatus('REFUNDED'), equals('Cancelled'));
      expect(DairyPayment.normalizeStatus('declined'), equals('Failed'));
    });

    test('Serializes to Firestore map correctly', () {
      final now = DateTime(2026, 9, 17, 11, 00);
      final payment = DairyPayment(
        id: 'PAY_TEST_01',
        customerName: 'Aarav Gupta',
        orderOrWalletId: '#ORD100',
        amount: 350.0,
        method: 'Cash on Delivery',
        status: 'Pending',
        timestamp: '17 Sep 2026, 11:00 AM',
        createdAt: now,
        userId: 'user_aarav',
        orderId: 'ORDER_100',
        orderCode: 'ORD100',
        customerPhone: '9988776655',
        transactionId: null,
      );

      final map = payment.toFirestore();

      expect(map['id'], equals('PAY_TEST_01'));
      expect(map['customerName'], equals('Aarav Gupta'));
      expect(map['amount'], equals(350.0));
      expect(map['method'], equals('Cash on Delivery'));
      expect(map['paymentMethod'], equals('Cash on Delivery'));
      expect(map['status'], equals('Pending'));
      expect(map['paymentStatus'], equals('Pending'));
      expect(map['userId'], equals('user_aarav'));
      expect(map['orderId'], equals('ORDER_100'));
      expect(map['orderCode'], equals('ORD100'));
      expect(map['customerPhone'], equals('9988776655'));
      expect(map['transactionId'], isNull);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test(
        'Checkout order-creation path generates compliant payment document for COD',
        () {
      const orderDocId = 'ORDER_DOC_9812';
      const orderCode = 'ABC123';
      const userId = 'cust_uid_456';
      const customerName = 'Priya Sharma';
      const customerPhone = '9876543210';
      const totalAmount = 520.0;
      const paymentMethod = 'Cash on Delivery';

      final isCash = paymentMethod.toLowerCase().contains('cash');
      final paymentData = {
        'id': 'PAY_$orderDocId',
        'orderId': orderDocId,
        'orderCode': orderCode,
        'userId': userId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'amount': totalAmount,
        'method': paymentMethod,
        'paymentMethod': paymentMethod,
        'status': isCash ? 'Pending' : 'Success',
        'paymentStatus': isCash ? 'Pending' : 'Success',
        'transactionId': isCash ? null : 'TXN_$orderDocId',
      };

      final payment =
          DairyPayment.fromFirestore(paymentData, 'PAY_$orderDocId');

      expect(payment.id, equals('PAY_ORDER_DOC_9812'));
      expect(payment.orderId, equals('ORDER_DOC_9812'));
      expect(payment.orderCode, equals('ABC123'));
      expect(payment.userId, equals('cust_uid_456'));
      expect(payment.customerName, equals('Priya Sharma'));
      expect(payment.customerPhone, equals('9876543210'));
      expect(payment.amount, equals(520.0));
      expect(payment.method, equals('Cash on Delivery'));
      expect(payment.status, equals('Pending'));
      expect(payment.transactionId, isNull);
    });

    test(
        'Checkout order-creation path generates compliant payment document for Online Payment',
        () {
      const orderDocId = 'ORDER_DOC_9813';
      const orderCode = 'XYZ789';
      const userId = 'cust_uid_789';
      const customerName = 'Amit Verma';
      const customerPhone = '9123456780';
      const totalAmount = 850.0;
      const paymentMethod = 'Online Payment';

      final isCash = paymentMethod.toLowerCase().contains('cash');
      final paymentData = {
        'id': 'PAY_$orderDocId',
        'orderId': orderDocId,
        'orderCode': orderCode,
        'userId': userId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'amount': totalAmount,
        'method': paymentMethod,
        'paymentMethod': paymentMethod,
        'status': isCash ? 'Pending' : 'Success',
        'paymentStatus': isCash ? 'Pending' : 'Success',
        'transactionId': isCash ? null : 'TXN_$orderDocId',
      };

      final payment =
          DairyPayment.fromFirestore(paymentData, 'PAY_$orderDocId');

      expect(payment.id, equals('PAY_ORDER_DOC_9813'));
      expect(payment.orderId, equals('ORDER_DOC_9813'));
      expect(payment.orderCode, equals('XYZ789'));
      expect(payment.userId, equals('cust_uid_789'));
      expect(payment.customerName, equals('Amit Verma'));
      expect(payment.customerPhone, equals('9123456780'));
      expect(payment.amount, equals(850.0));
      expect(payment.method, equals('Online Payment'));
      expect(payment.status, equals('Success'));
      expect(payment.transactionId, equals('TXN_ORDER_DOC_9813'));
    });
  });
}
