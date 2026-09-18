import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:intl/intl.dart';

import '../models/customer_delivery_record.dart';
import '../models/customer_model.dart';
import '../models/order.dart';
import '../models/payment_model.dart';
import '../models/subscription.dart';
import 'order_service.dart';
import 'payment_service.dart';
import 'subscription_service.dart';

/// Service responsible for fetching and consolidating customer history,
/// subscription delivery schedules, and payment ledger details in the Admin Panel.
class CustomerProfileService {
  final FirebaseFirestore? _customFirestore;
  final OrderService? _customOrderService;
  final PaymentService? _customPaymentService;
  final SubscriptionService? _customSubscriptionService;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  OrderService get _orderService =>
      _customOrderService ?? OrderService(firestore: _customFirestore);

  PaymentService get _paymentService =>
      _customPaymentService ?? PaymentService(firestore: _customFirestore);

  SubscriptionService get _subscriptionService =>
      _customSubscriptionService ??
      (_customFirestore != null
          ? SubscriptionService(_customFirestore)
          : SubscriptionService());

  CustomerProfileService({
    FirebaseFirestore? firestore,
    OrderService? orderService,
    PaymentService? paymentService,
    SubscriptionService? subscriptionService,
  })  : _customFirestore = firestore,
        _customOrderService = orderService,
        _customPaymentService = paymentService,
        _customSubscriptionService = subscriptionService;

  /// Stream of orders placed by this customer
  Stream<List<Order>> streamCustomerOrders(String customerId) {
    if (customerId.trim().isEmpty) return Stream.value([]);
    return _orderService.streamOrdersForUser(customerId.trim());
  }

  /// Stream of payment transactions for this customer
  Stream<List<DairyPayment>> streamCustomerPayments(String customerId) {
    if (customerId.trim().isEmpty) return Stream.value([]);
    return _paymentService.streamPaymentsForUser(customerId.trim());
  }

  /// Stream of current active/past subscription for this customer
  Stream<Subscription?> streamCustomerSubscription(String customerId) {
    if (customerId.trim().isEmpty) return Stream.value(null);
    return _subscriptionService.streamCurrentSubscription(customerId.trim());
  }

  /// Stream of all subscriptions for this customer
  Stream<List<Subscription>> streamCustomerSubscriptions(String customerId) {
    if (customerId.trim().isEmpty) return Stream.value([]);
    return _subscriptionService.streamSubscriptionsForUser(customerId.trim());
  }

  /// Stream of skipped subscription dates for this customer
  Stream<List<DateTime>> streamSkippedDates(String customerId) {
    if (customerId.trim().isEmpty) return Stream.value([]);
    try {
      return _firestore
          .collection('users')
          .doc(customerId.trim())
          .collection('skipped_dates')
          .snapshots()
          .map((snap) {
        final List<DateTime> dates = [];
        for (final doc in snap.docs) {
          final data = doc.data();
          final val = data['date'];
          if (val is Timestamp) {
            dates.add(val.toDate());
          } else if (val is String) {
            final p = DateTime.tryParse(val);
            if (p != null) dates.add(p);
          }
        }
        return dates;
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Stream of dedicated delivery records from `/users/{customerId}/delivery_records`
  Stream<List<CustomerDeliveryRecord>> streamDeliveryRecords(String customerId) {
    if (customerId.trim().isEmpty) return Stream.value([]);
    try {
      return _firestore
          .collection('users')
          .doc(customerId.trim())
          .collection('delivery_records')
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((d) => CustomerDeliveryRecord.fromFirestore(d.data(), d.id))
            .toList();
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Combines orders, subscriptions, skipped dates, and dedicated delivery records
  /// into a comprehensive list of delivery/purchase records for a given date range.
  List<CustomerDeliveryRecord> getConsolidatedDeliveries({
    required String customerId,
    required DateTime startDate,
    required DateTime endDate,
    required List<Order> orders,
    required Subscription? subscription,
    required List<DateTime> skippedDates,
    required List<CustomerDeliveryRecord> customRecords,
    DateTime? referenceDate,
  }) {
    final List<CustomerDeliveryRecord> results = [];
    final Set<String> addedRecordKeys = {};

    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    // 1. Add Dedicated Firestore Delivery Records
    for (final rec in customRecords) {
      if (rec.customerId == customerId &&
          !rec.date.isBefore(normalizedStart) &&
          !rec.date.isAfter(normalizedEnd)) {
        final key = '${DateFormat('yyyyMMdd').format(rec.date)}_${rec.productId}_${rec.orderId ?? rec.subscriptionId ?? 'rec'}';
        if (!addedRecordKeys.contains(key)) {
          addedRecordKeys.add(key);
          results.add(rec);
        }
      }
    }

    // 2. Add Records from Customer Orders
    for (final order in orders) {
      if (order.userId != customerId) continue;
      final orderDate = order.deliveryDate ?? order.orderDate;
      if (!orderDate.isBefore(normalizedStart) && !orderDate.isAfter(normalizedEnd)) {
        final orderRecords = CustomerDeliveryRecord.fromOrder(order);
        for (final rec in orderRecords) {
          final key = '${DateFormat('yyyyMMdd').format(rec.date)}_${rec.productId}_${order.id}';
          if (!addedRecordKeys.contains(key)) {
            addedRecordKeys.add(key);
            results.add(rec);
          }
        }
      }
    }

    // 3. Add Generated Records from Active/Existing Subscription
    if (subscription != null) {
      DateTime currentDay = normalizedStart;
      while (!currentDay.isAfter(normalizedEnd)) {
        final subRec = CustomerDeliveryRecord.fromSubscriptionForDate(
          subscription: subscription,
          customerId: customerId,
          targetDate: currentDay,
          skippedDates: skippedDates,
          referenceDate: referenceDate,
        );

        if (subRec != null) {
          final key = '${DateFormat('yyyyMMdd').format(currentDay)}_${subRec.productId}_sub_${subscription.id}';
          if (!addedRecordKeys.contains(key)) {
            addedRecordKeys.add(key);
            results.add(subRec);
          }
        }

        currentDay = currentDay.add(const Duration(days: 1));
      }
    }

    // Sort newest first
    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  /// Calculates Today's scheduled or delivered items for this customer
  List<CustomerDeliveryRecord> getTodaysDeliveries({
    required String customerId,
    required List<Order> orders,
    required Subscription? subscription,
    required List<DateTime> skippedDates,
    required List<CustomerDeliveryRecord> customRecords,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return getConsolidatedDeliveries(
      customerId: customerId,
      startDate: today,
      endDate: today,
      orders: orders,
      subscription: subscription,
      skippedDates: skippedDates,
      customRecords: customRecords,
      referenceDate: now,
    );
  }

  /// Calculates Tomorrow's scheduled items for this customer
  List<CustomerDeliveryRecord> getTomorrowsDeliveries({
    required String customerId,
    required List<Order> orders,
    required Subscription? subscription,
    required List<DateTime> skippedDates,
    required List<CustomerDeliveryRecord> customRecords,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return getConsolidatedDeliveries(
      customerId: customerId,
      startDate: tomorrow,
      endDate: tomorrow,
      orders: orders,
      subscription: subscription,
      skippedDates: skippedDates,
      customRecords: customRecords,
      referenceDate: now,
    );
  }

  /// Calculates deliveries for any specific target date selected by the Admin
  List<CustomerDeliveryRecord> getDeliveriesForDate({
    required DateTime targetDate,
    required String customerId,
    required List<Order> orders,
    required Subscription? subscription,
    required List<DateTime> skippedDates,
    required List<CustomerDeliveryRecord> customRecords,
  }) {
    final day = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return getConsolidatedDeliveries(
      customerId: customerId,
      startDate: day,
      endDate: day,
      orders: orders,
      subscription: subscription,
      skippedDates: skippedDates,
      customRecords: customRecords,
      referenceDate: DateTime.now(),
    );
  }

  /// Calculates the total delivered purchase amount for the current month.
  /// Strictly EXCLUDES skipped or cancelled deliveries.
  double getMonthlyDeliveredTotal({
    required String customerId,
    required List<Order> orders,
    required Subscription? subscription,
    required List<DateTime> skippedDates,
    required List<CustomerDeliveryRecord> customRecords,
    DateTime? referenceMonth,
  }) {
    final now = referenceMonth ?? DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final monthRecords = getConsolidatedDeliveries(
      customerId: customerId,
      startDate: startOfMonth,
      endDate: endOfMonth,
      orders: orders,
      subscription: subscription,
      skippedDates: skippedDates,
      customRecords: customRecords,
      referenceDate: now,
    );

    double sum = 0.0;
    for (final rec in monthRecords) {
      // Only count valid delivered purchases towards delivered bill
      if (rec.isDelivered || rec.deliveryStatus.toLowerCase() == 'delivered') {
        sum += rec.totalAmount;
      }
    }
    return sum;
  }

  /// Computes customer financial ledger metrics
  ({
    double totalPurchases,
    double totalPaid,
    double pendingAmount,
    double walletBalance,
  }) computeLedgerSummary({
    required DairyCustomer customer,
    required List<Order> orders,
    required List<DairyPayment> payments,
    required double monthlyDeliveredAmount,
  }) {
    // Total purchases = delivered/confirmed orders + delivered subscription amount
    final double ordersTotal = orders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold(0.0, (acc, o) => acc + o.totalAmount);

    final double totalPurchases = ordersTotal > 0 ? ordersTotal : monthlyDeliveredAmount;

    // Total Paid = all successful payment records
    final double totalPaid = payments
        .where((p) => p.status.toLowerCase() == 'success')
        .fold(0.0, (acc, p) => acc + p.amount);

    // Pending Amount
    final double pendingFromOrders = orders
        .where((o) =>
            o.status != OrderStatus.cancelled &&
            (o.paymentMethod.toLowerCase().contains('cod') ||
                o.paymentMethod.toLowerCase().contains('cash') ||
                o.status == OrderStatus.placed ||
                o.status == OrderStatus.confirmed) &&
            o.status != OrderStatus.delivered)
        .fold(0.0, (acc, o) => acc + o.totalAmount);

    final double pendingAmount = pendingFromOrders > 0
        ? pendingFromOrders
        : (totalPurchases - totalPaid).clamp(0.0, double.infinity);

    return (
      totalPurchases: totalPurchases,
      totalPaid: totalPaid,
      pendingAmount: pendingAmount,
      walletBalance: customer.walletBalance,
    );
  }

  // ─── Subscription Management Actions ───────────────────────────────────

  /// Pauses customer subscription
  Future<void> pauseSubscription(String customerId, Subscription currentSub) async {
    final updated = currentSub.copyWith(
      status: SubscriptionStatus.paused,
      updatedAt: DateTime.now(),
    );
    await _subscriptionService.updateSubscription(customerId, updated);
  }

  /// Resumes customer subscription
  Future<void> resumeSubscription(String customerId, Subscription currentSub) async {
    final updated = currentSub.copyWith(
      status: SubscriptionStatus.active,
      updatedAt: DateTime.now(),
    );
    await _subscriptionService.updateSubscription(customerId, updated);
  }

  /// Adds a date to customer skipped dates in Firestore
  Future<void> skipSubscriptionDate(String customerId, DateTime date) async {
    final dateKey = DateFormat('yyyyMMdd').format(date);
    await _firestore
        .collection('users')
        .doc(customerId.trim())
        .collection('skipped_dates')
        .doc(dateKey)
        .set({
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'createdAt': FieldValue.serverTimestamp(),
      'reason': 'Admin / Customer Skip Request',
    });
  }

  /// Removes a skipped date
  Future<void> removeSkippedDate(String customerId, DateTime date) async {
    final dateKey = DateFormat('yyyyMMdd').format(date);
    await _firestore
        .collection('users')
        .doc(customerId.trim())
        .collection('skipped_dates')
        .doc(dateKey)
        .delete();
  }
}
