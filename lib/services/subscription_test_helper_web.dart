import 'dart:convert';
import 'dart:js' as js;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/product.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';

void setupSubscriptionWebBridge() {
  final service = SubscriptionService();

  js.context['subscriptionBridge'] = js.JsObject.jsify({
    'ensureAuth': (js.JsFunction callback) async {
      try {
        var user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          final cred = await FirebaseAuth.instance.signInAnonymously();
          user = cred.user;
        }
        callback.apply([null, user?.uid]);
      } catch (e) {
        callback.apply([e.toString(), null]);
      }
    },
    'create': (String uid, js.JsFunction callback) {
      final now = DateTime.now();
      const product = Product(
        id: 'prod_fresh_ghee',
        title: 'Sawariya Pure Desi Ghee',
        categoryId: 'ghee',
        categoryName: 'Ghee',
        price: 650.0,
        originalPrice: 720.0,
        unit: '1 Kg',
        imageUrl: 'assets/images/gheen.png',
        description: 'Traditional Vedic Bilona Ghee made from grass-fed cows',
        rating: 4.9,
        reviewCount: 340,
        isFreshDeal: true,
        isBestSeller: true,
        isA2CowMilk: true,
        inStock: true,
      );

      final sub = Subscription(
        id: 'sub_${now.millisecondsSinceEpoch}',
        product: product,
        quantity: 1,
        frequency: SubscriptionFrequency.daily,
        status: SubscriptionStatus.active,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        nextDeliveryDate: now.add(const Duration(days: 1)),
        deliveryTimeSlot: 'Morning (6:00 AM - 9:00 AM)',
        includeIcePack: true,
        planId: 'plan_ghee_monthly',
        planName: 'Sawariya Pure Desi Ghee Monthly Plan',
        autoRenew: true,
        createdAt: now,
        updatedAt: now,
      );

      service.createSubscription(uid, sub).then((res) {
        callback.apply([null, jsonEncode(res.toMap())]);
      }).catchError((err) {
        debugPrint('[SUBSCRIPTION_BRIDGE_ERROR] create: $err');
        callback.apply([err.toString(), null]);
      });
    },
    'get': (String uid, js.JsFunction callback) {
      service.getCurrentSubscription(uid).then((res) {
        callback.apply([null, res != null ? jsonEncode(res.toMap()) : null]);
      }).catchError((err) {
        debugPrint('[SUBSCRIPTION_BRIDGE_ERROR] get: $err');
        callback.apply([err.toString(), null]);
      });
    },
    'cancel': (String uid, js.JsFunction callback) {
      service.cancelSubscription(uid).then((res) {
        callback.apply([null, jsonEncode(res.toMap())]);
      }).catchError((err) {
        debugPrint('[SUBSCRIPTION_BRIDGE_ERROR] cancel: $err');
        callback.apply([err.toString(), null]);
      });
    },
    'renew': (String uid, js.JsFunction callback) {
      service.renewSubscription(uid).then((res) {
        callback.apply([null, jsonEncode(res.toMap())]);
      }).catchError((err) {
        debugPrint('[SUBSCRIPTION_BRIDGE_ERROR] renew: $err');
        callback.apply([err.toString(), null]);
      });
    },
    'pause': (String uid, js.JsFunction callback) {
      service.getCurrentSubscription(uid).then((sub) {
        if (sub == null) {
          callback.apply(['No subscription found', null]);
          return;
        }
        service
            .updateSubscription(
                uid,
                sub.copyWith(
                  status: SubscriptionStatus.paused,
                  updatedAt: DateTime.now(),
                ))
            .then((res) {
          callback.apply([null, jsonEncode(res.toMap())]);
        }).catchError((err) {
          debugPrint('[SUBSCRIPTION_BRIDGE_ERROR] pause: $err');
          callback.apply([err.toString(), null]);
        });
      }).catchError((err) {
        debugPrint('[SUBSCRIPTION_BRIDGE_ERROR] pause: $err');
        callback.apply([err.toString(), null]);
      });
    },
    'resume': (String uid, js.JsFunction callback) {
      service.getCurrentSubscription(uid).then((sub) {
        if (sub == null) {
          callback.apply(['No subscription found', null]);
          return;
        }
        service
            .updateSubscription(
                uid,
                sub.copyWith(
                  status: SubscriptionStatus.active,
                  updatedAt: DateTime.now(),
                ))
            .then((res) {
          callback.apply([null, jsonEncode(res.toMap())]);
        }).catchError((err) {
          debugPrint('[SUBSCRIPTION_BRIDGE_ERROR] resume: $err');
          callback.apply([err.toString(), null]);
        });
      }).catchError((err) {
        debugPrint('[SUBSCRIPTION_BRIDGE_ERROR] resume: $err');
        callback.apply([err.toString(), null]);
      });
    },
  });
}
