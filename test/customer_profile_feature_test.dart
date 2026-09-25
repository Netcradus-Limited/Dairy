import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/customer_delivery_record.dart';
import 'package:dairy_app/models/customer_model.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/payment_model.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/subscription.dart';
import 'package:dairy_app/services/customer_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer Delivery Record & Calculation Tests', () {
    const sampleProduct = Product(
      id: 'prod_cow_milk',
      title: 'Farm Fresh Cow Milk',
      categoryId: 'cat_milk',
      categoryName: 'Milk',
      price: 60.0,
      originalPrice: 65.0,
      unit: '1 Litre',
      imageUrl: 'assets/images/nnd.png',
      description: 'Pure A2 Cow Milk',
    );

    const sampleAddress = Address(
      id: 'addr_1',
      label: 'Home',
      fullName: 'Ramesh Sharma',
      mobileNumber: '+91 9876543210',
      houseFlat: 'Flat 402',
      streetArea: 'Green Meadows, Sector 62',
      city: 'Noida',
      state: 'Uttar Pradesh',
      pinCode: '201301',
      latitude: 28.6139,
      longitude: 77.2090,
      isDefault: true,
    );

    const testCustomer = DairyCustomer(
      id: 'CUST_101',
      name: 'Ramesh Sharma',
      phone: '+91 9876543210',
      email: 'ramesh@example.com',
      address: 'Sector 62, Noida',
      deliveryZone: 'Zone A - Noida East',
      subscriptionPlan: 'Daily Morning (2 L)',
      milkPreference: 'A2 Cow Milk',
      walletBalance: 450.0,
      status: 'Active',
      joinedDate: '01 Jan 2026',
    );

    test('1. CustomerDeliveryRecord.fromOrder converts Order items accurately',
        () {
      final now = DateTime.now();
      final order = Order(
        id: 'ORD_999',
        orderCode: 'SAW999',
        items: const [
          CartItem(product: sampleProduct, quantity: 2),
        ],
        subtotal: 120.0,
        totalAmount: 120.0,
        status: OrderStatus.delivered,
        orderDate: now,
        deliveryDate: now,
        deliveryAddress: sampleAddress,
        paymentMethod: 'Cash on Delivery',
        userId: 'CUST_101',
      );

      final records = CustomerDeliveryRecord.fromOrder(order);
      expect(records.length, 1);
      expect(records.first.customerId, 'CUST_101');
      expect(records.first.orderId, 'ORD_999');
      expect(records.first.orderCode, 'SAW999');
      expect(records.first.productName, 'Farm Fresh Cow Milk');
      expect(records.first.quantity, 2);
      expect(records.first.totalAmount, 120.0);
      expect(records.first.deliveryStatus, 'Delivered');
      expect(records.first.paymentStatus, 'Paid');
      expect(records.first.isDelivered, isTrue);
    });

    test(
        '2. Subscription daily delivery schedule generates correctly across dates',
        () {
      final startDate = DateTime(2026, 9, 1);
      final sub = Subscription(
        id: 'SUB_001',
        product: sampleProduct,
        quantity: 2,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: startDate,
        deliveryTimeSlot: 'Morning (6:00 AM - 9:00 AM)',
        discountRate: 0.10, // 10% discount: 120 - 12 = 108
      );

      // On 15 Sep 2026
      final recSep15 = CustomerDeliveryRecord.fromSubscriptionForDate(
        subscription: sub,
        customerId: 'CUST_101',
        targetDate: DateTime(2026, 9, 15),
      );

      expect(recSep15, isNotNull);
      expect(recSep15!.productId, 'prod_cow_milk');
      expect(recSep15.quantity, 2);
      expect(recSep15.totalAmount, 108.0);
      expect(recSep15.deliverySlot, 'Morning');

      // Before start date (31 Aug 2026) -> should be null
      final recBefore = CustomerDeliveryRecord.fromSubscriptionForDate(
        subscription: sub,
        customerId: 'CUST_101',
        targetDate: DateTime(2026, 8, 31),
      );
      expect(recBefore, isNull);
    });

    test('3. Alternate Day & Weekly subscription frequency matching', () {
      final startDate = DateTime(2026, 9, 1); // Tuesday
      final alternateSub = Subscription(
        id: 'SUB_ALT',
        product: sampleProduct,
        quantity: 1,
        frequency: SubscriptionFrequency.alternateDay,
        status: SubscriptionStatus.active,
        startDate: startDate,
      );

      // Day 0 (Sep 1) -> Match
      expect(
          CustomerDeliveryRecord.fromSubscriptionForDate(
            subscription: alternateSub,
            customerId: 'CUST_101',
            targetDate: DateTime(2026, 9, 1),
          ),
          isNotNull);

      // Day 1 (Sep 2) -> No match
      expect(
          CustomerDeliveryRecord.fromSubscriptionForDate(
            subscription: alternateSub,
            customerId: 'CUST_101',
            targetDate: DateTime(2026, 9, 2),
          ),
          isNull);

      // Day 2 (Sep 3) -> Match
      expect(
          CustomerDeliveryRecord.fromSubscriptionForDate(
            subscription: alternateSub,
            customerId: 'CUST_101',
            targetDate: DateTime(2026, 9, 3),
          ),
          isNotNull);
    });

    test(
        '4. Skipped delivery dates are marked as Skipped and excluded from monthly billing',
        () {
      final service = CustomerProfileService();
      final startDate = DateTime(2026, 9, 1);
      final sub = Subscription(
        id: 'SUB_001',
        product: sampleProduct,
        quantity: 1, // 60 - 6 = 54
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: startDate,
      );

      final skippedDates = [
        DateTime(2026, 9, 5),
        DateTime(2026, 9, 10),
      ];

      // On skipped date Sep 5
      final recSkipped = CustomerDeliveryRecord.fromSubscriptionForDate(
        subscription: sub,
        customerId: 'CUST_101',
        targetDate: DateTime(2026, 9, 5),
        skippedDates: skippedDates,
      );

      expect(recSkipped, isNotNull);
      expect(recSkipped!.deliveryStatus, 'Skipped');
      expect(recSkipped.isSkipped, isTrue);

      // On regular date Sep 6
      final recNormal = CustomerDeliveryRecord.fromSubscriptionForDate(
        subscription: sub,
        customerId: 'CUST_101',
        targetDate: DateTime(2026, 9, 6),
        skippedDates: skippedDates,
      );
      expect(recNormal!.isSkipped, isFalse);

      // Monthly Total Calculation for reference date Sep 15
      final monthlyTotal = service.getMonthlyDeliveredTotal(
        customerId: 'CUST_101',
        orders: [],
        subscription: sub,
        skippedDates: skippedDates,
        customRecords: [],
        referenceMonth: DateTime(2026, 9, 15),
      );

      // From Sep 1 to Sep 15 is 15 days, minus 2 skipped days = 13 delivered days * 54 = 702
      expect(monthlyTotal, 13 * 54.0);
    });

    test(
        '5. Customer Isolation: Records for Customer A do not appear for Customer B',
        () {
      final service = CustomerProfileService();
      final orderCustA = Order(
        id: 'ORD_A',
        items: const [CartItem(product: sampleProduct, quantity: 1)],
        subtotal: 60.0,
        totalAmount: 60.0,
        status: OrderStatus.delivered,
        orderDate: DateTime(2026, 9, 10),
        deliveryAddress: sampleAddress,
        userId: 'CUST_101',
      );

      final orderCustB = Order(
        id: 'ORD_B',
        items: const [CartItem(product: sampleProduct, quantity: 5)],
        subtotal: 300.0,
        totalAmount: 300.0,
        status: OrderStatus.delivered,
        orderDate: DateTime(2026, 9, 10),
        deliveryAddress: sampleAddress,
        userId: 'CUST_202',
      );

      final listCustA = service.getConsolidatedDeliveries(
        customerId: 'CUST_101',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
        orders: [orderCustA, orderCustB],
        subscription: null,
        skippedDates: [],
        customRecords: [],
      );

      expect(listCustA.length, 1);
      expect(listCustA.first.customerId, 'CUST_101');
      expect(listCustA.first.orderId, 'ORD_A');
      expect(listCustA.any((r) => r.customerId == 'CUST_202'), isFalse);
    });

    test(
        '6. Specific date query answers "What did customer buy on a particular date?"',
        () {
      final service = CustomerProfileService();
      final targetDate = DateTime(2026, 9, 12);

      final orderOnTargetDate = Order(
        id: 'ORD_12',
        items: const [CartItem(product: sampleProduct, quantity: 3)],
        subtotal: 180.0,
        totalAmount: 180.0,
        status: OrderStatus.delivered,
        orderDate: targetDate,
        deliveryAddress: sampleAddress,
        userId: 'CUST_101',
      );

      final orderOnDifferentDate = Order(
        id: 'ORD_14',
        items: const [CartItem(product: sampleProduct, quantity: 1)],
        subtotal: 60.0,
        totalAmount: 60.0,
        status: OrderStatus.delivered,
        orderDate: DateTime(2026, 9, 14),
        deliveryAddress: sampleAddress,
        userId: 'CUST_101',
      );

      final results = service.getDeliveriesForDate(
        targetDate: targetDate,
        customerId: 'CUST_101',
        orders: [orderOnTargetDate, orderOnDifferentDate],
        subscription: null,
        skippedDates: [],
        customRecords: [],
      );

      expect(results.length, 1);
      expect(results.first.orderId, 'ORD_12');
      expect(results.first.quantity, 3);
      expect(results.first.totalAmount, 180.0);
    });

    test(
        '7. Ledger summary computes purchases, paid, pending, and wallet balance',
        () {
      final service = CustomerProfileService();

      final deliveredOrder = Order(
        id: 'ORD_DEL',
        items: const [CartItem(product: sampleProduct, quantity: 2)],
        subtotal: 120.0,
        totalAmount: 120.0,
        status: OrderStatus.delivered,
        orderDate: DateTime.now(),
        deliveryAddress: sampleAddress,
        paymentMethod: 'Prepaid Wallet',
        userId: 'CUST_101',
      );

      final pendingOrder = Order(
        id: 'ORD_PEN',
        items: const [CartItem(product: sampleProduct, quantity: 1)],
        subtotal: 60.0,
        totalAmount: 60.0,
        status: OrderStatus.confirmed,
        orderDate: DateTime.now(),
        deliveryAddress: sampleAddress,
        paymentMethod: 'Cash on Delivery',
        userId: 'CUST_101',
      );

      final payments = [
        const DairyPayment(
          id: 'PAY_1',
          customerName: 'Ramesh Sharma',
          orderOrWalletId: '#ORD_DEL',
          amount: 120.0,
          method: 'Prepaid Wallet',
          status: 'Success',
          timestamp: '10 Sep 2026',
        ),
      ];

      final ledger = service.computeLedgerSummary(
        customer: testCustomer,
        orders: [deliveredOrder, pendingOrder],
        payments: payments,
        monthlyDeliveredAmount: 120.0,
      );

      expect(ledger.totalPurchases, 180.0);
      expect(ledger.totalPaid, 120.0);
      expect(ledger.pendingAmount, 60.0);
      expect(ledger.walletBalance, 450.0);
    });

    test(
        '8. Zero payments in Firestore shows Total Paid ₹0 without fabricating records',
        () {
      final service = CustomerProfileService();

      final order1 = Order(
        id: 'ORD_1',
        items: const [CartItem(product: sampleProduct, quantity: 1)],
        subtotal: 60.0,
        totalAmount: 60.0,
        status: OrderStatus.delivered,
        orderDate: DateTime(2026, 9, 2),
        deliveryAddress: sampleAddress,
        paymentMethod: 'Cash on Delivery',
        userId: 'CUST_101',
      );

      final ledger = service.computeLedgerSummary(
        customer: testCustomer,
        orders: [order1],
        payments: const [], // Zero payment records in Firestore
        monthlyDeliveredAmount: 60.0,
      );

      expect(ledger.totalPaid, 0.0);
      expect(ledger.totalPurchases, 60.0);
      expect(ledger.pendingAmount, 60.0);
    });

    test(
        '9. Full Data Consistency Scenario: Purchases, Monthly Delivered, Total Due, Paid Reconcile',
        () {
      final service = CustomerProfileService();

      // Delivered order in current month (₹60)
      final ordDeliveredThisMonth = Order(
        id: 'ORD_DEL_MONTH',
        items: const [CartItem(product: sampleProduct, quantity: 1)],
        subtotal: 60.0,
        totalAmount: 60.0,
        status: OrderStatus.delivered,
        orderDate: DateTime(2026, 9, 5),
        deliveryAddress: sampleAddress,
        paymentMethod: 'Online',
        userId: 'CUST_101',
      );

      // Delivered order in previous month (₹150)
      final ordDeliveredPrevMonth = Order(
        id: 'ORD_DEL_PAST',
        items: const [CartItem(product: sampleProduct, quantity: 2)],
        subtotal: 150.0,
        totalAmount: 150.0,
        status: OrderStatus.delivered,
        orderDate: DateTime(2026, 8, 15),
        deliveryAddress: sampleAddress,
        paymentMethod: 'Online',
        userId: 'CUST_101',
      );

      // Pending unpaid order (₹245)
      final ordPending = Order(
        id: 'ORD_PENDING',
        items: const [CartItem(product: sampleProduct, quantity: 4)],
        subtotal: 245.0,
        totalAmount: 245.0,
        status: OrderStatus.confirmed,
        orderDate: DateTime(2026, 9, 16),
        deliveryAddress: sampleAddress,
        paymentMethod: 'Cash on Delivery',
        userId: 'CUST_101',
      );

      // Cancelled order (₹100) -> should be excluded
      final ordCancelled = Order(
        id: 'ORD_CANCELLED',
        items: const [CartItem(product: sampleProduct, quantity: 2)],
        subtotal: 100.0,
        totalAmount: 100.0,
        status: OrderStatus.cancelled,
        orderDate: DateTime(2026, 9, 10),
        deliveryAddress: sampleAddress,
        paymentMethod: 'Online',
        userId: 'CUST_101',
      );

      final allOrders = [
        ordDeliveredThisMonth,
        ordDeliveredPrevMonth,
        ordPending,
        ordCancelled
      ];

      // Total Purchases = 60 + 150 + 245 = 455.0 (cancelled excluded)
      final ledgerNoPayments = service.computeLedgerSummary(
        customer: testCustomer,
        orders: allOrders,
        payments: const [],
        monthlyDeliveredAmount: 60.0,
      );

      expect(ledgerNoPayments.totalPurchases, 455.0);
      expect(ledgerNoPayments.totalPaid, 0.0);
      expect(ledgerNoPayments.pendingAmount, 245.0);

      // Monthly calculation for Sep 2026: only Sep delivered order (60.0)
      final sepDelivered = service.getMonthlyDeliveredTotal(
        customerId: 'CUST_101',
        orders: allOrders,
        subscription: null,
        skippedDates: const [],
        customRecords: const [],
        referenceMonth: DateTime(2026, 9, 17),
      );
      expect(sepDelivered, 60.0);
    });
  });
}
