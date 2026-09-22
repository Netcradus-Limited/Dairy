import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/address.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  SubscriptionService([this._customFirestore]);

  static const String _prefPrefix = 'cached_subscription_';
  static const String _prefListPrefix = 'cached_subscriptions_list_';

  User? get _currentAuthUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  String get _currentProjectId {
    try {
      return Firebase.app().options.projectId;
    } catch (_) {
      return '';
    }
  }

  String? get _currentAuthUid {
    return _currentAuthUser?.uid;
  }

  String _resolveEffectiveUid(String uid) {
    if (uid.trim().isNotEmpty) {
      return uid.trim();
    }
    final authUid = _currentAuthUid;
    return (authUid != null && authUid.isNotEmpty) ? authUid : '';
  }

  static String formatOrderDateKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Calculates next delivery date according to frequency
  DateTime calculateNextDeliveryDate(
    SubscriptionFrequency frequency, {
    DateTime? fromDate,
  }) {
    final base = fromDate ?? DateTime.now();
    switch (frequency) {
      case SubscriptionFrequency.daily:
        return base.add(const Duration(days: 1));
      case SubscriptionFrequency.alternateDay:
        return base.add(const Duration(days: 2));
      case SubscriptionFrequency.weekly:
        return base.add(const Duration(days: 7));
    }
  }



  Future<Subscription?> _loadFromLocal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_prefPrefix$uid');
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(str);
        return Subscription.fromMap(data);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveListToLocal(String uid, List<Subscription> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((s) => s.toMap()).toList();
      await prefs.setString('$_prefListPrefix$uid', jsonEncode(jsonList));
      if (list.isNotEmpty) {
        await prefs.setString(
            '$_prefPrefix$uid', jsonEncode(list.first.toMap()));
      }
    } catch (_) {}
  }

  Future<List<Subscription>> _loadListFromLocal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_prefListPrefix$uid');
      if (str != null && str.isNotEmpty) {
        final List<dynamic> data = jsonDecode(str);
        return data
            .map((item) => Subscription.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      final single = await _loadFromLocal(uid);
      if (single != null) {
        return [single];
      }
    } catch (_) {}
    return <Subscription>[];
  }

  /// Stream all subscriptions belonging to a user (real-time from root `subscriptions` collection)
  Stream<List<Subscription>> streamSubscriptionsForUser(String uid) {
    final effectiveUid = _resolveEffectiveUid(uid);
    if (effectiveUid.isEmpty) {
      return Stream.value(<Subscription>[]);
    }
    return _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: effectiveUid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return <Subscription>[];
      final list =
          snapshot.docs.map((doc) => Subscription.fromFirestore(doc)).toList();
      _saveListToLocal(effectiveUid, list);
      return list;
    }).handleError((error) {
      developer.log(
          '[SubscriptionService] streamSubscriptionsForUser Firestore error: $error');
      return Stream.fromFuture(_loadListFromLocal(effectiveUid));
    });
  }

  /// Get all subscriptions for a user (one-time fetch from root `subscriptions`)
  Future<List<Subscription>> getSubscriptionsForUser(String uid) async {
    final effectiveUid = _resolveEffectiveUid(uid);
    if (effectiveUid.isEmpty) {
      return <Subscription>[];
    }
    try {
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: effectiveUid)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final list = snapshot.docs
            .map((doc) => Subscription.fromFirestore(doc))
            .toList();
        await _saveListToLocal(effectiveUid, list);
        return list;
      }
    } catch (e) {
      developer.log(
          '[SubscriptionService] getSubscriptionsForUser Firestore error: $e');
    }

    // Fallback to legacy user subcollection
    try {
      final legacySnap = await _firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('subscription')
          .get();
      if (legacySnap.docs.isNotEmpty) {
        final legacyList = legacySnap.docs
            .where((doc) => doc.id != 'current')
            .map((doc) => Subscription.fromFirestore(doc))
            .toList();
        if (legacyList.isNotEmpty) {
          await _saveListToLocal(effectiveUid, legacyList);
          return legacyList;
        }
      }
    } catch (_) {}

    return _loadListFromLocal(effectiveUid);
  }

  /// Stream all subscriptions for Admin oversight across all customers
  Stream<List<Subscription>> streamAllSubscriptions() {
    return _firestore.collection('subscriptions').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Subscription.fromFirestore(doc))
          .toList();
    });
  }

  /// Get all subscriptions across all users (Admin one-time query)
  Future<List<Subscription>> getAllSubscriptions() async {
    try {
      final snapshot = await _firestore.collection('subscriptions').get();
      return snapshot.docs
          .map((doc) => Subscription.fromFirestore(doc))
          .toList();
    } catch (e) {
      developer
          .log('[SubscriptionService] getAllSubscriptions Firestore error: $e');
      return [];
    }
  }

  /// Get a specific subscription by ID or user's active subscription
  Future<Subscription?> getCurrentSubscription(String uid,
      {String? subscriptionId}) async {
    final effectiveUid = _resolveEffectiveUid(uid);
    if (subscriptionId != null && subscriptionId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('subscriptions')
            .doc(subscriptionId)
            .get();
        if (doc.exists && doc.data() != null) {
          return Subscription.fromFirestore(doc);
        }
      } catch (e) {
        developer.log(
            '[SubscriptionService] getCurrentSubscription direct get error: $e');
      }
    }

    final allSubs = await getSubscriptionsForUser(effectiveUid);
    if (allSubs.isNotEmpty) {
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        final matched = allSubs.where((s) => s.id == subscriptionId).toList();
        if (matched.isNotEmpty) return matched.first;
      }
      return allSubs.firstWhere(
        (s) => s.isActiveAndValid,
        orElse: () => allSubs.first,
      );
    }

    return _loadFromLocal(effectiveUid);
  }

  /// Stream the current/primary subscription for a user
  Stream<Subscription?> streamCurrentSubscription(String uid,
      {String? subscriptionId}) {
    final effectiveUid = _resolveEffectiveUid(uid);
    return streamSubscriptionsForUser(effectiveUid).map((list) {
      if (list.isEmpty) return null;
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        final matched = list.where((s) => s.id == subscriptionId).toList();
        if (matched.isNotEmpty) return matched.first;
      }
      return list.firstWhere(
        (s) => s.isActiveAndValid,
        orElse: () => list.first,
      );
    });
  }

  /// Create a new subscription for a user (stores in root `subscriptions` collection with unique ID)
  Future<Subscription> createSubscription(
      String uid, Subscription subscription) async {
    final now = DateTime.now();
    final effectiveUid = _resolveEffectiveUid(uid);
    final subId = subscription.id.isNotEmpty
        ? subscription.id
        : 'sub_${now.millisecondsSinceEpoch}_${now.microsecond}';

    final initialNextDelivery = subscription.nextDeliveryDate ??
        calculateNextDeliveryDate(subscription.frequency,
            fromDate: subscription.startDate);

    final subscriptionWithTimestamps = subscription.copyWith(
      id: subId,
      userId: effectiveUid,
      nextDeliveryDate: initialNextDelivery,
      createdAt: subscription.createdAt ?? now,
      updatedAt: now,
    );

    final payload = subscriptionWithTimestamps.toFirestore();
    final authUser = _currentAuthUser;
    final projectId = _currentProjectId;

    if (kDebugMode) {
      debugPrint('=== DEBUG CREATE SUBSCRIPTION WRITE ===');
      debugPrint('PROJECT ID: $projectId');
      debugPrint('AUTH UID: ${authUser?.uid}');
      debugPrint('AUTH PHONE: ${authUser?.phoneNumber}');
      debugPrint('IS ANONYMOUS: ${authUser?.isAnonymous}');
      debugPrint('AUTHENTICATED: ${authUser != null}');
      debugPrint('WRITE PATH: subscriptions/$subId');
      debugPrint('PAYLOAD: $payload');
      debugPrint('=======================================');
    }

    developer.log('=== CREATE SUBSCRIPTION WRITE ===');
    developer.log('PROJECT ID: $projectId');
    developer.log('AUTH UID: ${authUser?.uid}');
    developer.log('AUTH PHONE: ${authUser?.phoneNumber}');
    developer.log('IS ANONYMOUS: ${authUser?.isAnonymous}');
    developer.log('AUTHENTICATED: ${authUser != null}');
    developer.log('WRITE PATH: subscriptions/$subId');
    developer.log('PAYLOAD: $payload');
    developer.log('=================================');

    try {
      // 1. Write to root `subscriptions` collection with unique doc ID
      final docRef = _firestore.collection('subscriptions').doc(subId);
      await docRef.set(payload);

      // 2. Mirror to legacy user subcollection for backwards compatibility
      try {
        await _firestore
            .collection('users')
            .doc(effectiveUid)
            .collection('subscription')
            .doc(subId)
            .set(payload);
        await _firestore
            .collection('users')
            .doc(effectiveUid)
            .collection('subscription')
            .doc('current')
            .set(payload);
      } catch (_) {}

      developer.log(
          '[SUBSCRIPTION_DEBUG] Op: CREATE | SUCCESS at subscriptions/$subId');

      final currentList = await _loadListFromLocal(effectiveUid);
      final updatedList = [
        subscriptionWithTimestamps,
        ...currentList.where((s) => s.id != subId)
      ];
      await _saveListToLocal(effectiveUid, updatedList);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('=== FIRESTORE WRITE ERROR ===');
        debugPrint('WRITE PATH: subscriptions/$subId');
        debugPrint('ERROR: $e');
        debugPrint('=============================');
      }
      developer.log(
          '[SUBSCRIPTION_DEBUG] Op: CREATE | FAILURE at subscriptions/$subId: $e');
      developer.log('[SubscriptionService] Firestore set error: $e');
      rethrow;
    }

    return subscriptionWithTimestamps;
  }

  /// Update an existing subscription (updates ONLY `subscriptions/{subscription.id}`)
  Future<Subscription> updateSubscription(
      String uid, Subscription subscription) async {
    final now = DateTime.now();
    final effectiveUid = _resolveEffectiveUid(uid);
    final updatedSubscription = subscription.copyWith(
      userId: effectiveUid,
      updatedAt: now,
    );
    final subId = updatedSubscription.id;
    final payload = updatedSubscription.toFirestore();

    final authUser = _currentAuthUser;
    final projectId = _currentProjectId;

    if (kDebugMode) {
      debugPrint('=== DEBUG UPDATE SUBSCRIPTION WRITE ===');
      debugPrint('PROJECT ID: $projectId');
      debugPrint('AUTH UID: ${authUser?.uid}');
      debugPrint('AUTH PHONE: ${authUser?.phoneNumber}');
      debugPrint('IS ANONYMOUS: ${authUser?.isAnonymous}');
      debugPrint('AUTHENTICATED: ${authUser != null}');
      debugPrint('WRITE PATH: subscriptions/$subId');
      debugPrint('PAYLOAD: $payload');
      debugPrint('=======================================');
    }

    developer.log('=== UPDATE SUBSCRIPTION WRITE ===');
    developer.log('PROJECT ID: $projectId');
    developer.log('AUTH UID: ${authUser?.uid}');
    developer.log('AUTH PHONE: ${authUser?.phoneNumber}');
    developer.log('IS ANONYMOUS: ${authUser?.isAnonymous}');
    developer.log('AUTHENTICATED: ${authUser != null}');
    developer.log('WRITE PATH: subscriptions/$subId');
    developer.log('PAYLOAD: $payload');
    developer.log('=================================');

    try {
      // 1. Update in root `subscriptions` collection
      final docRef = _firestore.collection('subscriptions').doc(subId);
      await docRef.set(payload);

      // 2. Mirror update to user subcollection
      try {
        await _firestore
            .collection('users')
            .doc(effectiveUid)
            .collection('subscription')
            .doc(subId)
            .set(payload);
        await _firestore
            .collection('users')
            .doc(effectiveUid)
            .collection('subscription')
            .doc('current')
            .set(payload);
      } catch (_) {}

      developer.log(
          '[SUBSCRIPTION_DEBUG] Op: UPDATE | SUCCESS at subscriptions/$subId');

      final currentList = await _loadListFromLocal(effectiveUid);
      final updatedList = currentList
          .map((s) => s.id == subId ? updatedSubscription : s)
          .toList();
      if (!updatedList.any((s) => s.id == subId)) {
        updatedList.insert(0, updatedSubscription);
      }
      await _saveListToLocal(effectiveUid, updatedList);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('=== FIRESTORE UPDATE ERROR ===');
        debugPrint('WRITE PATH: subscriptions/$subId');
        debugPrint('ERROR: $e');
        debugPrint('==============================');
      }
      developer.log(
          '[SUBSCRIPTION_DEBUG] Op: UPDATE | FAILURE at subscriptions/$subId: $e');
      developer.log('[SubscriptionService] Firestore update error: $e');
      rethrow;
    }

    return updatedSubscription;
  }

  /// Skip the next scheduled delivery and advance nextDeliveryDate on a subscription
  Future<Subscription> skipNextDelivery(String uid,
      {String? subscriptionId}) async {
    final effectiveUid = _resolveEffectiveUid(uid);
    final sub = await getCurrentSubscription(effectiveUid,
        subscriptionId: subscriptionId);
    if (sub == null) {
      throw Exception('No active subscription found to skip');
    }

    final skipDate = sub.nextDeliveryDate ?? DateTime.now();
    final nextDate =
        calculateNextDeliveryDate(sub.frequency, fromDate: skipDate);
    final dateKey = formatOrderDateKey(skipDate);

    // Save skipped date record to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('skipped_dates')
          .doc(dateKey)
          .set({
        'date': Timestamp.fromDate(skipDate),
        'skippedAt': Timestamp.now(),
        'subscriptionId': sub.id,
      });
    } catch (_) {}

    final updatedSub = sub.copyWith(
      nextDeliveryDate: nextDate,
      updatedAt: DateTime.now(),
    );

    return updateSubscription(effectiveUid, updatedSub);
  }

  /// Pause an active subscription
  Future<Subscription> pauseSubscription(String uid,
      {String? subscriptionId}) async {
    final effectiveUid = _resolveEffectiveUid(uid);
    final sub = await getCurrentSubscription(effectiveUid,
        subscriptionId: subscriptionId);
    if (sub == null) {
      throw Exception('No active subscription found to pause');
    }

    final pausedSub = sub.copyWith(
      status: SubscriptionStatus.paused,
      updatedAt: DateTime.now(),
    );

    return updateSubscription(effectiveUid, pausedSub);
  }

  /// Resume a paused subscription and compute next valid delivery date
  Future<Subscription> resumeSubscription(String uid,
      {String? subscriptionId}) async {
    final effectiveUid = _resolveEffectiveUid(uid);
    final sub = await getCurrentSubscription(effectiveUid,
        subscriptionId: subscriptionId);
    if (sub == null) {
      throw Exception('No active subscription found to resume');
    }

    final now = DateTime.now();
    DateTime nextDate = sub.nextDeliveryDate ?? now;
    if (nextDate.isBefore(now)) {
      nextDate = calculateNextDeliveryDate(sub.frequency, fromDate: now);
    }

    final resumedSub = sub.copyWith(
      status: SubscriptionStatus.active,
      nextDeliveryDate: nextDate,
      updatedAt: now,
    );

    return updateSubscription(effectiveUid, resumedSub);
  }

  /// Cancel a subscription (sets status to "cancelled", does NOT delete document)
  Future<Subscription> cancelSubscription(String uid,
      {String? subscriptionId}) async {
    final now = DateTime.now();
    final effectiveUid = _resolveEffectiveUid(uid);

    developer.log(
        '[SUBSCRIPTION_DEBUG] Op: CANCEL | Target UID: $effectiveUid | Subscription: $subscriptionId');
    Subscription? existing = await getCurrentSubscription(effectiveUid,
        subscriptionId: subscriptionId);
    if (existing != null) {
      final cancelledSub = existing.copyWith(
        status: SubscriptionStatus.cancelled,
        autoRenew: false,
        updatedAt: now,
      );

      return updateSubscription(effectiveUid, cancelledSub);
    }
    throw Exception('No active subscription found to cancel.');
  }

  /// Generates or retrieves the scheduled delivery Order for a subscription on a given targetDate
  Future<Order> generateOrderForSubscription(
    String uid,
    Subscription subscription, {
    DateTime? targetDate,
    Address? deliveryAddress,
    String? customerName,
    String? customerPhone,
    String paymentMethod = 'Subscription',
    String paymentStatus = 'Paid',
  }) async {
    if (subscription.isPaused ||
        subscription.isCancelled ||
        subscription.status != SubscriptionStatus.active) {
      throw StateError(
          'Cannot generate order for paused or inactive subscription');
    }

    final effectiveUid = _resolveEffectiveUid(uid);
    final date =
        targetDate ?? subscription.nextDeliveryDate ?? subscription.startDate;
    final dateKey = formatOrderDateKey(date);
    final orderDocId = 'sub_${subscription.id}_$dateKey';

    // Deduplication check
    final orderDocRef = _firestore.collection('orders').doc(orderDocId);
    final existingDoc = await orderDocRef.get();
    if (existingDoc.exists && existingDoc.data() != null) {
      return Order.fromFirestore(existingDoc.data()!, existingDoc.id);
    }

    // Resolve address
    Address resolvedAddress = deliveryAddress ??
        Address(
          id: 'sub_addr_${subscription.id}',
          label: 'Home',
          fullName: customerName ?? 'Subscription Customer',
          mobileNumber: customerPhone ?? '',
          houseFlat: '',
          streetArea: '',
          city: '',
          state: '',
          pinCode: '',
        );

    final item = CartItem(
      product: subscription.product,
      quantity: subscription.quantity,
    );

    final subtotal = subscription.product.price * subscription.quantity;
    final discount = subtotal * subscription.discountRate;
    final totalAmount = (subtotal - discount).clamp(0.0, double.infinity);

    final order = Order(
      id: orderDocId,
      orderCode: Order.generateRandomOrderCode(),
      items: [item],
      subtotal: subtotal,
      deliveryCharge: 0.0,
      discount: discount,
      totalAmount: totalAmount,
      status: OrderStatus.placed,
      orderDate: date,
      deliveryDate: date,
      deliveryAddress: resolvedAddress,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      estimatedDeliveryTime: subscription.deliveryTimeSlot,
      userId: effectiveUid,
      orderType: 'subscription',
      subscriptionId: subscription.id,
      deliverySlot: subscription.deliveryTimeSlot,
    );

    final orderData = order.toFirestore();
    orderData['id'] = orderDocId;
    orderData['customerName'] = resolvedAddress.fullName;
    orderData['customerPhone'] = resolvedAddress.mobileNumber;
    orderData['productName'] = subscription.product.title;
    orderData['productImage'] = subscription.product.resolvedImageUrl.isNotEmpty
        ? subscription.product.resolvedImageUrl
        : subscription.product.imageUrl;
    orderData['quantity'] = subscription.quantity;
    orderData['createdAt'] = Timestamp.fromDate(date);

    await orderDocRef.set(orderData);
    return order;
  }

  /// Marks a subscription delivery as delivered and advances nextDeliveryDate while keeping subscription Active
  Future<void> completeSubscriptionDelivery(
    String orderId, {
    String? agentId,
    DateTime? deliveredDate,
  }) async {
    final now = deliveredDate ?? DateTime.now();
    final orderDocRef = _firestore.collection('orders').doc(orderId);
    final orderSnap = await orderDocRef.get();

    if (!orderSnap.exists) {
      throw Exception('Order $orderId not found');
    }

    final orderData = orderSnap.data()!;
    final subscriptionId = (orderData['subscriptionId'] as String?);
    final userId = (orderData['userId'] as String?) ?? '';

    // Update order status to delivered
    await orderDocRef.update({
      'status': 'delivered',
      'deliveredAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      if (agentId != null) 'assignedAgentId': agentId,
    });

    // Record in delivery_records
    if (userId.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('delivery_records')
            .doc(orderId)
            .set({
          'orderId': orderId,
          'subscriptionId': subscriptionId,
          'status': 'Delivered',
          'deliveredAt': Timestamp.fromDate(now),
          'agentId': agentId,
        });
      } catch (_) {}

      // Advance subscription nextDeliveryDate
      final sub =
          await getCurrentSubscription(userId, subscriptionId: subscriptionId);
      if (sub != null) {
        final nextDate = calculateNextDeliveryDate(
          sub.frequency,
          fromDate: sub.nextDeliveryDate ?? now,
        );
        final updatedSub = sub.copyWith(
          nextDeliveryDate: nextDate,
          status: SubscriptionStatus.active,
          updatedAt: now,
        );
        await updateSubscription(userId, updatedSub);
      }
    }
  }

  /// Renew a subscription (updates startDate, endDate, status)
  Future<Subscription> renewSubscription(String uid,
      {String? subscriptionId, Duration? duration}) async {
    final now = DateTime.now();
    final effectiveUid = _resolveEffectiveUid(uid);

    developer.log(
        '[SUBSCRIPTION_DEBUG] Op: RENEW | Target UID: $effectiveUid | Subscription: $subscriptionId');
    Subscription? existing = await getCurrentSubscription(effectiveUid,
        subscriptionId: subscriptionId);

    if (existing == null) {
      throw Exception('No current subscription to renew');
    }

    final baseDate =
        (existing.endDate != null && existing.endDate!.isAfter(now))
            ? existing.endDate!
            : now;
    final newEndDate = baseDate.add(duration ?? const Duration(days: 30));

    final renewedSub = existing.copyWith(
      startDate: now,
      endDate: newEndDate,
      status: SubscriptionStatus.active,
      autoRenew: true,
      updatedAt: now,
    );

    return updateSubscription(effectiveUid, renewedSub);
  }

  /// Check if subscription is active (status active AND endDate in future)
  Future<bool> isSubscriptionActive(String uid,
      {String? subscriptionId}) async {
    try {
      final sub =
          await getCurrentSubscription(uid, subscriptionId: subscriptionId);
      return sub?.isActiveAndValid ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get subscription plan name
  Future<String?> getPlanName(String uid, {String? subscriptionId}) async {
    try {
      final sub =
          await getCurrentSubscription(uid, subscriptionId: subscriptionId);
      return sub?.planName;
    } catch (e) {
      return null;
    }
  }

  /// Get subscription status
  Future<SubscriptionStatus?> getSubscriptionStatus(String uid,
      {String? subscriptionId}) async {
    try {
      final sub =
          await getCurrentSubscription(uid, subscriptionId: subscriptionId);
      return sub?.status;
    } catch (e) {
      return null;
    }
  }

  /// Real-time stream of all orders associated with a subscription (Delivery History)
  Stream<List<Order>> streamOrdersForSubscription(String subscriptionId) {
    final cleanId = subscriptionId.trim();
    if (cleanId.isEmpty) return Stream.value(<Order>[]);
    return _firestore
        .collection('orders')
        .where('subscriptionId', isEqualTo: cleanId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Order.fromFirestore(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      return list;
    }).handleError((error) {
      developer.log(
          '[SubscriptionService] streamOrdersForSubscription error: $error');
      return <Order>[];
    });
  }

  /// Admin method: Update any subscription document directly in `subscriptions/{subscription.id}`
  Future<Subscription> adminUpdateSubscription(Subscription subscription) async {
    final now = DateTime.now();
    final updatedSubscription = subscription.copyWith(
      updatedAt: now,
    );
    final subId = updatedSubscription.id.trim();
    if (subId.isEmpty) {
      throw ArgumentError('Subscription ID cannot be empty');
    }

    final payload = updatedSubscription.toFirestore();
    await _firestore
        .collection('subscriptions')
        .doc(subId)
        .set(payload, SetOptions(merge: true));

    // Mirror to user subcollection if userId is available
    if (updatedSubscription.userId != null &&
        updatedSubscription.userId!.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(updatedSubscription.userId)
            .collection('subscription')
            .doc(subId)
            .set(payload, SetOptions(merge: true));
      } catch (_) {}
    }

    return updatedSubscription;
  }

  /// Admin method: Pause a subscription directly by ID
  Future<Subscription> adminPauseSubscription(String subscriptionId) async {
    final cleanId = subscriptionId.trim();
    final doc =
        await _firestore.collection('subscriptions').doc(cleanId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Subscription $cleanId not found');
    }
    final sub = Subscription.fromFirestore(doc);
    final paused = sub.copyWith(
      status: SubscriptionStatus.paused,
      updatedAt: DateTime.now(),
    );
    return adminUpdateSubscription(paused);
  }

  /// Admin method: Resume a subscription directly by ID
  Future<Subscription> adminResumeSubscription(String subscriptionId) async {
    final cleanId = subscriptionId.trim();
    final doc =
        await _firestore.collection('subscriptions').doc(cleanId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Subscription $cleanId not found');
    }
    final sub = Subscription.fromFirestore(doc);
    final now = DateTime.now();
    DateTime nextDate = sub.nextDeliveryDate ?? now;
    if (nextDate.isBefore(now)) {
      nextDate = calculateNextDeliveryDate(sub.frequency, fromDate: now);
    }
    final resumed = sub.copyWith(
      status: SubscriptionStatus.active,
      nextDeliveryDate: nextDate,
      updatedAt: now,
    );
    return adminUpdateSubscription(resumed);
  }

  /// Admin method: Cancel a subscription directly by ID (sets status to "cancelled")
  Future<Subscription> adminCancelSubscription(String subscriptionId) async {
    final cleanId = subscriptionId.trim();
    final doc =
        await _firestore.collection('subscriptions').doc(cleanId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Subscription $cleanId not found');
    }
    final sub = Subscription.fromFirestore(doc);
    final cancelled = sub.copyWith(
      status: SubscriptionStatus.cancelled,
      autoRenew: false,
      updatedAt: DateTime.now(),
    );
    return adminUpdateSubscription(cancelled);
  }
}
