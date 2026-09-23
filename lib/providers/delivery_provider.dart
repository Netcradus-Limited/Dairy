import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/delivery_boy_model.dart';
import '../models/earning_model.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/delivery_tracking_service.dart';
import '../services/earnings_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/order_service.dart';
import 'package:latlong2/latlong.dart';
import 'user_provider.dart';

/// Maps a Firestore [Order] into the delivery panel's [DeliveryOrder] view
/// model. Resolves dynamic pickup hub/store information per order with
/// graceful fallback to the legitimate default dairy hub.
DeliveryOrder deliveryOrderFromOrder(Order order) {
  const defaultHub = 'Sawariya Dairy Hub, Vijay Nagar';
  const defaultHubPhone = '+91 731 400 5000';
  const defaultHubLat = 22.7255;
  const defaultHubLng = 75.8800;

  final String resolvedPickupLocation;
  final String resolvedPickupPhone;
  final double? resolvedPickupLat;
  final double? resolvedPickupLng;

  if (order.pickupLocation == null) {
    // Missing / null pickup data: use project's existing legitimate default hub
    resolvedPickupLocation = defaultHub;
    resolvedPickupPhone = defaultHubPhone;
    resolvedPickupLat = defaultHubLat;
    resolvedPickupLng = defaultHubLng;
  } else if (order.pickupLocation!.trim().isEmpty) {
    // Explicitly empty pickup data: do not display misleading information
    resolvedPickupLocation = 'Not specified';
    resolvedPickupPhone = (order.pickupPhone != null && order.pickupPhone!.trim().isNotEmpty)
        ? order.pickupPhone!.trim()
        : '—';
    resolvedPickupLat = null;
    resolvedPickupLng = null;
  } else {
    // Valid pickup data from order
    resolvedPickupLocation = order.pickupLocation!.trim();
    resolvedPickupPhone = (order.pickupPhone != null && order.pickupPhone!.trim().isNotEmpty)
        ? order.pickupPhone!.trim()
        : defaultHubPhone;

    // Use order's pickup coordinates if available; do not invent coordinates if missing
    if (order.pickupLatitude != null &&
        order.pickupLongitude != null &&
        DeliveryTrackingService.isValidCoordinates(
            order.pickupLatitude, order.pickupLongitude)) {
      resolvedPickupLat = order.pickupLatitude;
      resolvedPickupLng = order.pickupLongitude;
    } else {
      resolvedPickupLat = null;
      resolvedPickupLng = null;
    }
  }

  DeliveryOrderStatus status = DeliveryOrderStatus.pendingAcceptance;
  switch (order.status) {
    case OrderStatus.placed:
      // A freshly placed order is a delivery request awaiting driver acceptance.
      status = DeliveryOrderStatus.pendingAcceptance;
    case OrderStatus.confirmed:
      status = DeliveryOrderStatus.accepted;
    case OrderStatus.preparing:
      status = DeliveryOrderStatus.pickup;
    case OrderStatus.outForDelivery:
      status = DeliveryOrderStatus.outForDelivery;
    case OrderStatus.delivered:
      status = DeliveryOrderStatus.delivered;
    case OrderStatus.cancelled:
      status = DeliveryOrderStatus.cancelled;
  }

  final double? customerLat = (order.deliveryAddress.hasCoordinates &&
          DeliveryTrackingService.isValidCoordinates(
              order.deliveryAddress.latitude,
              order.deliveryAddress.longitude))
      ? order.deliveryAddress.latitude
      : null;
  final double? customerLng = (order.deliveryAddress.hasCoordinates &&
          DeliveryTrackingService.isValidCoordinates(
              order.deliveryAddress.latitude,
              order.deliveryAddress.longitude))
      ? order.deliveryAddress.longitude
      : null;

  final double? distanceKm = DeliveryTrackingService.calculateDistanceKm(
    resolvedPickupLat,
    resolvedPickupLng,
    customerLat,
    customerLng,
  );
  final String formattedDistance =
      DeliveryTrackingService.formatDistance(distanceKm);
  final String formattedEta = DeliveryTrackingService.calculateEstimatedTime(
    distanceKm,
    fallbackSlot: order.estimatedDeliveryTime,
  );

  String? productImageUrl;
  if (order.items.isNotEmpty) {
    final p = order.items.first.product;
    productImageUrl = p.resolvedImageUrl.isNotEmpty ? p.resolvedImageUrl : p.imageUrl;
  }

  return DeliveryOrder(
    id: order.id,
    orderId: order.id,
    orderCode: order.displayOrderCode,
    customerName: order.deliveryAddress.fullName.trim().isNotEmpty
        ? order.deliveryAddress.fullName.trim()
        : 'Customer',
    customerPhone: order.deliveryAddress.mobileNumber.trim().isNotEmpty
        ? order.deliveryAddress.mobileNumber.trim()
        : '—',
    customerAddress: order.deliveryAddress.fullAddressText
            .replaceAll(RegExp(r'[, \-]'), '')
            .trim()
            .isNotEmpty
        ? order.deliveryAddress.fullAddressText.trim()
        : 'Address not specified',
    pickupLocation: resolvedPickupLocation,
    pickupPhone: resolvedPickupPhone,
    pickupLatitude: resolvedPickupLat,
    pickupLongitude: resolvedPickupLng,
    items: order.items
        .map((ci) => '${ci.product.title} ${ci.product.unit} x${ci.quantity}')
        .toList(),
    amount: order.totalAmount,
    deliveryFee: order.deliveryCharge,
    status: status,
    orderTime: order.orderDate,
    acceptedTime: order.acceptedAt,
    deliveredTime: order.deliveredAt,
    distance: formattedDistance,
    estimatedTime: formattedEta,
    distanceKm: distanceKm,
    latitude: customerLat,
    longitude: customerLng,
    assignedAgentId: order.assignedAgentId,
    orderType: order.orderType,
    subscriptionId: order.subscriptionId,
    deliveryDate: order.deliveryDate,
    deliverySlot: order.deliverySlot ??
        (order.isSubscription ? order.estimatedDeliveryTime : null),
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    productImageUrl: productImageUrl,
    cancellationReason: order.cancellationReason,
  );
}


String _resolveAgentId(Ref ref) {
  final sessionUserId = ref.watch(userProvider.select((u) => u.id));
  try {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) return authUid;
  } catch (_) {}
  return sessionUserId;
}

/// Streams the authenticated delivery agent's real-time geographic position from Firestore.
/// Emits `null` if the agent has not reported a location, or if unauthenticated.
final deliveryAgentLocationStreamProvider =
    StreamProvider.autoDispose<LatLng?>((ref) {
  final agentId = _resolveAgentId(ref);
  if (agentId.isEmpty) {
    return Stream.value(null);
  }
  return ref
      .watch(deliveryTrackingServiceProvider)
      .agentLocationStream(agentId);
});

/// Single source of truth for the delivery panel: a live Firestore stream of the
/// orders relevant to THIS agent — pending orders awaiting acceptance plus any
/// order already assigned to the agent — mapped into [DeliveryOrder]s. The
/// Requests, Active and History tabs all derive their lists from this one
/// stream.
final deliveryOrdersStreamProvider = StreamProvider<List<DeliveryOrder>>((ref) {
  final agentId = _resolveAgentId(ref);
  return ref
      .watch(orderServiceProvider)
      .streamDeliveryOrdersForAgent(agentId)
      .map<List<DeliveryOrder>>((List<Order> orders) =>
          orders.map<DeliveryOrder>(deliveryOrderFromOrder).toList());
});

/// Live Firestore stream of the agent's active (accepted / in-progress) orders,
/// derived from the unified agent stream. Used by the Active tab and the
/// tracking map.
final deliveryActiveOrdersStreamProvider =
    StreamProvider.autoDispose<List<DeliveryOrder>>((ref) {
  final agentId = _resolveAgentId(ref);
  return ref
      .watch(orderServiceProvider)
      .streamDeliveryOrdersForAgent(agentId)
      .map<List<DeliveryOrder>>((List<Order> orders) => orders
          .map<DeliveryOrder>(deliveryOrderFromOrder)
          .where((DeliveryOrder o) =>
              o.status == DeliveryOrderStatus.accepted ||
              o.status == DeliveryOrderStatus.pickup ||
              o.status == DeliveryOrderStatus.outForDelivery)
          .toList());
});

/// Orders awaiting driver acceptance (Requests tab), derived from the unified
/// agent stream.
final deliveryRequestsStreamProvider =
    Provider.autoDispose<List<DeliveryOrder>>((ref) {
  final asyncOrders = ref.watch(deliveryOrdersStreamProvider);
  return asyncOrders.when(
    data: (orders) => orders
        .where((o) => o.status == DeliveryOrderStatus.pendingAcceptance)
        .toList(),
    loading: () => const [],
    error: (_, stackTrace) => const [],
  );
});

/// Completed / cancelled orders (History tab), derived from the unified agent
/// stream.
final deliveryHistoryStreamProvider =
    Provider.autoDispose<AsyncValue<List<DeliveryOrder>>>((ref) {
  final asyncOrders = ref.watch(deliveryOrdersStreamProvider);
  return asyncOrders.whenData(
    (orders) {
      // 1. Strict status filtering: only completed (delivered) or cancelled orders
      final filtered = orders.where((o) =>
          o.status == DeliveryOrderStatus.delivered ||
          o.status == DeliveryOrderStatus.cancelled);

      // 2. Prevent duplicate history entries
      final seenIds = <String>{};
      final deduplicated = <DeliveryOrder>[];
      for (final order in filtered) {
        final key = order.orderId.isNotEmpty ? order.orderId : order.id;
        if (key.isNotEmpty && seenIds.add(key)) {
          deduplicated.add(order);
        } else if (key.isEmpty) {
          deduplicated.add(order);
        }
      }

      // 3. Sort consistently by the most relevant delivery/order date (newest first)
      deduplicated.sort((a, b) {
        final dateA = a.deliveredTime ?? a.deliveryDate ?? a.orderTime;
        final dateB = b.deliveredTime ?? b.deliveryDate ?? b.orderTime;
        return dateB.compareTo(dateA);
      });

      return deduplicated;
    },
  );
});

class DeliveryNotifier extends StateNotifier<DeliveryAgent> {
  final Ref _ref;
  final User _user;
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  StreamSubscription? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _subscription;

  DeliveryNotifier(this._ref, this._user)
      : super(DeliveryAgent.empty(() {
          try {
            return FirebaseAuth.instance.currentUser?.uid ?? _user.id;
          } catch (_) {
            return _user.id;
          }
        }())) {
    // Listen to Firebase Auth state changes so when user logs in / out,
    // the listener is automatically attached or reset.
    try {
      _authSubscription =
          _auth?.authStateChanges().listen((fbUser) {
        if (fbUser != null && fbUser.uid.isNotEmpty) {
          _listenToAgentDoc(fbUser.uid);
        } else {
          _subscription?.cancel();
          _subscription = null;
          if (!mounted) return;
          state = DeliveryAgent.empty('').copyWith(isLoaded: true);
        }
      });
    } catch (_) {}

    String? currentUid;
    try {
      currentUid = _auth?.currentUser?.uid;
    } catch (_) {}

    if (currentUid != null && currentUid.isNotEmpty) {
      _listenToAgentDoc(currentUid);
    } else if (_user.id.isNotEmpty) {
      _listenToAgentDoc(_user.id);
    }
  }

  User get _currentUser {
    try {
      return _ref.read(userProvider);
    } catch (_) {
      return _user;
    }
  }

  String get _effectiveUid {
    try {
      final authUid = _auth?.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    } catch (_) {}
    if (_currentUser.id.isNotEmpty) return _currentUser.id;
    return '';
  }

  static bool _isLegacyMockName(String? val) {
    if (val == null) return false;
    final s = val.trim().toLowerCase();
    return s == 'rajesh kumar' ||
        s == 'delivery agent mock';
  }

  static bool _isLegacyMockPhone(String? val) {
    if (val == null) return false;
    final digits = val.replaceAll(RegExp(r'\D'), '');
    return digits == '917777777777' ||
        digits == '7777777777' ||
        digits == '919876543210' ||
        digits == '9876543210' ||
        digits == '919876500000' ||
        digits == '9876500000' ||
        digits == '1234567890' ||
        digits == '911234567890';
  }

  static String _maskPhone(String phone) {
    final clean = phone.trim();
    if (clean.length <= 4) return '***';
    return '***-***-${clean.substring(clean.length - 4)}';
  }

  static bool _isLegacyMockVehicle(String? val) {
    if (val == null) return false;
    final s = val.trim().toLowerCase();
    return s == 'electric delivery vehicle';
  }

  static bool _isLegacyMockVehicleNumber(String? val) {
    if (val == null) return false;
    final s = val.replaceAll(RegExp(r'\s'), '').toLowerCase();
    return s == 'up16de4412';
  }

  static bool _isLegacyMockZone(String? val) {
    if (val == null) return false;
    final s = val.trim().toLowerCase();
    return s == 'delivery zone' ||
        s == 'noida express zone';
  }

  void _listenToAgentDoc([String? targetUid]) {
    _subscription?.cancel();
    String? currentUid;
    try {
      currentUid = _auth?.currentUser?.uid;
    } catch (_) {}
    final uid = targetUid ?? currentUid ?? _effectiveUid;
    if (uid.isEmpty) {
      if (!mounted) return;
      state = DeliveryAgent.empty('').copyWith(isLoaded: true);
      return;
    }

    final firestore = _firestore;
    if (firestore == null) {
      if (!mounted) return;
      state = state.copyWith(isLoaded: true);
      return;
    }

    _subscription = firestore
        .collection('delivery_agents')
        .doc(uid)
        .snapshots()
        .listen((snapshot) async {
      final authUser = _auth?.currentUser;

      debugPrint('DeliveryNotifier: Agent document path = delivery_agents/$uid');
      debugPrint('DeliveryNotifier: Agent document exists = ${snapshot.exists}');

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        debugPrint('DeliveryNotifier: Agent document fields = ${data.keys.toList()}');
        final isOnline = data['isOnline'] == true || data['isOnDuty'] == true;

        // 1. Name: Check agent doc -> user provider -> authUser displayName
        String realName = '';
        final agentDocName = (data['name'] as String?)?.trim() ?? '';
        if (agentDocName.isNotEmpty && !_isLegacyMockName(agentDocName)) {
          realName = agentDocName;
        } else if (_currentUser.name.trim().isNotEmpty &&
            _currentUser.name.trim() != 'Guest Customer' &&
            _currentUser.name.trim() != 'Sawariya Customer' &&
            !_isLegacyMockName(_currentUser.name)) {
          realName = _currentUser.name.trim();
        } else if (authUser?.displayName != null &&
            authUser!.displayName!.trim().isNotEmpty &&
            authUser.displayName!.trim() != 'Guest Customer' &&
            authUser.displayName!.trim() != 'Sawariya Customer' &&
            !_isLegacyMockName(authUser.displayName)) {
          realName = authUser.displayName!.trim();
        }

        // 2. Phone: Prioritize authenticated Firebase phone number, fallback to agent doc -> user provider
        String realPhone = '';
        final authPhone = authUser?.phoneNumber?.trim();
        final agentDocPhone = (data['phone'] as String?)?.trim() ?? '';

        if (authPhone != null &&
            authPhone.isNotEmpty &&
            !_isLegacyMockPhone(authPhone)) {
          realPhone = authPhone;
          // Synchronize to Firestore if missing or mismatched
          if (agentDocPhone.isEmpty || agentDocPhone != authPhone) {
            try {
              firestore.collection('delivery_agents').doc(uid).set({
                'phone': authPhone,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
          }
        } else if (agentDocPhone.isNotEmpty && !_isLegacyMockPhone(agentDocPhone)) {
          realPhone = agentDocPhone;
        } else if (_currentUser.phone.trim().isNotEmpty &&
            !_isLegacyMockPhone(_currentUser.phone)) {
          realPhone = _currentUser.phone.trim();
        }

        // 3. Email: Check agent doc -> user provider -> authUser email
        String realEmail = '';
        final agentDocEmail = (data['email'] as String?)?.trim() ?? '';
        if (agentDocEmail.isNotEmpty) {
          realEmail = agentDocEmail;
        } else if ((_currentUser.email?.trim() ?? '').isNotEmpty) {
          realEmail = _currentUser.email!.trim();
        } else if (authUser?.email != null &&
            authUser!.email!.trim().isNotEmpty) {
          realEmail = authUser.email!.trim();
        }

        // 4. Vehicle: Check agent doc
        String realVehicle = '';
        final agentDocVehicle =
            ((data['vehicle'] ?? data['vehicleType']) as String?)?.trim() ?? '';
        if (agentDocVehicle.isNotEmpty &&
            !_isLegacyMockVehicle(agentDocVehicle)) {
          realVehicle = agentDocVehicle;
        }

        // 5. Vehicle Number: Check agent doc
        String realVehicleNumber = '';
        final agentDocVehicleNum =
            (data['vehicleNumber'] as String?)?.trim() ?? '';
        if (agentDocVehicleNum.isNotEmpty &&
            !_isLegacyMockVehicleNumber(agentDocVehicleNum)) {
          realVehicleNumber = agentDocVehicleNum;
        }

        // 6. Assigned Zone: Check agent doc
        String realZone = '';
        final agentDocZone =
            ((data['assignedZone'] ?? data['zone']) as String?)?.trim() ?? '';
        if (agentDocZone.isNotEmpty && !_isLegacyMockZone(agentDocZone)) {
          realZone = agentDocZone;
        }

        // 7. Profile Photo URL: Check agent doc -> user provider -> authUser photoURL
        String? realProfileImage;
        final agentDocImage = ((data['profileImageUrl'] ??
                data['photoUrl'] ??
                data['photoURL']) as String?)
            ?.trim();
        if (agentDocImage != null && agentDocImage.isNotEmpty) {
          realProfileImage = agentDocImage;
        } else if (_currentUser.profileImageUrl != null &&
            _currentUser.profileImageUrl!.trim().isNotEmpty) {
          realProfileImage = _currentUser.profileImageUrl!.trim();
        } else if (authUser?.photoURL != null &&
            authUser!.photoURL!.trim().isNotEmpty) {
          realProfileImage = authUser.photoURL!.trim();
        }

        // 8. Cross-check /users/{uid} if any core profile details are missing from /delivery_agents
        if (realName.isEmpty ||
            realPhone.isEmpty ||
            realVehicle.isEmpty ||
            realVehicleNumber.isEmpty ||
            realZone.isEmpty ||
            realProfileImage == null) {
          try {
            final userDoc = await firestore.collection('users').doc(uid).get();
            if (userDoc.exists) {
              final uData = userDoc.data() ?? {};
              if (realName.isEmpty) {
                final uName = (uData['name'] as String?)?.trim() ?? '';
                if (uName.isNotEmpty &&
                    !_isLegacyMockName(uName) &&
                    uName != 'Guest Customer' &&
                    uName != 'Sawariya Customer') {
                  realName = uName;
                }
              }
              if (realPhone.isEmpty) {
                final uPhone = (uData['phone'] as String?)?.trim() ?? '';
                if (uPhone.isNotEmpty && !_isLegacyMockPhone(uPhone)) {
                  realPhone = uPhone;
                }
              }
              if (realVehicle.isEmpty) {
                final uVeh = ((uData['vehicle'] ?? uData['vehicleType'])
                        as String?)
                    ?.trim() ??
                    '';
                if (uVeh.isNotEmpty && !_isLegacyMockVehicle(uVeh)) {
                  realVehicle = uVeh;
                }
              }
              if (realVehicleNumber.isEmpty) {
                final uPlate =
                    (uData['vehicleNumber'] as String?)?.trim() ?? '';
                if (uPlate.isNotEmpty &&
                    !_isLegacyMockVehicleNumber(uPlate)) {
                  realVehicleNumber = uPlate;
                }
              }
              if (realZone.isEmpty) {
                final uZone =
                    ((uData['assignedZone'] ?? uData['zone']) as String?)
                            ?.trim() ??
                        '';
                if (uZone.isNotEmpty && !_isLegacyMockZone(uZone)) {
                  realZone = uZone;
                }
              }
              if (realProfileImage == null || realProfileImage.isEmpty) {
                final uImage = ((uData['profileImageUrl'] ??
                        uData['photoUrl'] ??
                        uData['photoURL']) as String?)
                    ?.trim();
                if (uImage != null && uImage.isNotEmpty) {
                  realProfileImage = uImage;
                }
              }
            }
          } catch (_) {}
        }

        final double? realRating = (data['rating'] as num?)?.toDouble();

        debugPrint('DeliveryNotifier: Loaded name = $realName');
        debugPrint('DeliveryNotifier: Loaded phone = ${_maskPhone(realPhone)}');
        debugPrint('DeliveryNotifier: Loaded vehicle = $realVehicle');
        debugPrint('DeliveryNotifier: Loaded vehicleType = ${(data['vehicleType'] as String?)?.trim() ?? realVehicle}');
        debugPrint('DeliveryNotifier: Loaded vehicleNumber = $realVehicleNumber');
        debugPrint('DeliveryNotifier: Loaded assignedZone = $realZone');
        debugPrint('DeliveryNotifier: Loaded profileImageUrl = $realProfileImage');

        if (!mounted) return;
        state = DeliveryAgent(
          id: uid,
          name: realName,
          phone: realPhone,
          email: realEmail.isNotEmpty ? realEmail : null,
          vehicle: realVehicle,
          vehicleNumber: realVehicleNumber,
          assignedZone: realZone,
          status: isOnline ? DeliveryStatus.onDuty : DeliveryStatus.offDuty,
          totalDeliveriesToday:
              ((data['totalDeliveriesToday'] ?? 0) as num).toInt(),
          completedDeliveriesToday:
              ((data['completedDeliveriesToday'] ?? 0) as num).toInt(),
          earningsToday: ((data['earningsToday'] ?? 0.0) as num).toDouble(),
          rating: realRating,
          profileImageUrl: realProfileImage,
          isLoaded: true,
        );
      } else {
        // Doc in delivery_agents doesn't exist yet; check users/{uid}
        debugPrint('DeliveryNotifier: Doc in delivery_agents does not exist; checking users/$uid');
        try {
          final userDoc = await firestore.collection('users').doc(uid).get();
          if (userDoc.exists) {
            final uData = userDoc.data() ?? {};
            debugPrint('DeliveryNotifier: users doc found, fields = ${uData.keys.toList()}');
            final uName = (uData['name'] as String? ?? _currentUser.name).trim();
            final uPhone = (uData['phone'] as String? ?? _currentUser.phone).trim();
            final uVehicle = (uData['vehicle'] as String? ?? '').trim();
            final uVehicleNumber =
                (uData['vehicleNumber'] as String? ?? '').trim();
            final uZone = ((uData['assignedZone'] ?? uData['zone']) as String? ?? '').trim();
            final double? uRating = (uData['rating'] as num?)?.toDouble();
            final uProfileImage = ((uData['profileImageUrl'] ??
                    uData['photoUrl'] ??
                    uData['photoURL']) as String?)
                ?.trim();

            final cleanName = (_isLegacyMockName(uName) ||
                    uName == 'Guest Customer' ||
                    uName == 'Sawariya Customer')
                ? ''
                : uName;
            final authPhone = authUser?.phoneNumber?.trim();
            final cleanPhone = (authPhone != null &&
                    authPhone.isNotEmpty &&
                    !_isLegacyMockPhone(authPhone))
                ? authPhone
                : (_isLegacyMockPhone(uPhone) ? '' : uPhone);
            final cleanVehicle = _isLegacyMockVehicle(uVehicle) ? '' : uVehicle;
            final cleanVehicleNum =
                _isLegacyMockVehicleNumber(uVehicleNumber) ? '' : uVehicleNumber;
            final cleanZone = _isLegacyMockZone(uZone) ? '' : uZone;

            debugPrint('DeliveryNotifier: Loaded name = $cleanName');
            debugPrint('DeliveryNotifier: Loaded phone = ${_maskPhone(cleanPhone)}');
            debugPrint('DeliveryNotifier: Loaded vehicle = $cleanVehicle');
            debugPrint('DeliveryNotifier: Loaded vehicleType = $cleanVehicle');
            debugPrint('DeliveryNotifier: Loaded vehicleNumber = $cleanVehicleNum');
            debugPrint('DeliveryNotifier: Loaded assignedZone = $cleanZone');
            debugPrint('DeliveryNotifier: Loaded profileImageUrl = $uProfileImage');

            if (!mounted) return;
            state = DeliveryAgent(
              id: uid,
              name: cleanName,
              phone: cleanPhone,
              email: (uData['email'] as String? ?? _currentUser.email)?.trim(),
              vehicle: cleanVehicle,
              vehicleNumber: cleanVehicleNum,
              assignedZone: cleanZone,
              status: DeliveryStatus.offDuty,
              totalDeliveriesToday: 0,
              completedDeliveriesToday: 0,
              earningsToday: 0.0,
              rating: uRating,
              profileImageUrl:
                  (uProfileImage != null && uProfileImage.isNotEmpty)
                      ? uProfileImage
                      : _currentUser.profileImageUrl,
              isLoaded: true,
            );
            return;
          }
        } catch (e) {
          debugPrint('DeliveryNotifier: Error fetching users/$uid: $e');
        }

        // Fallback strictly to authenticated User object without fake mock data
        final fallbackName = _currentUser.name.trim() == 'Guest Customer' ||
                _currentUser.name.trim() == 'Sawariya Customer' ||
                !_isLegacyMockName(_currentUser.name)
            ? (authUser?.displayName ?? '')
            : _currentUser.name.trim();

        final authPhone = authUser?.phoneNumber?.trim();
        final fallbackPhone = (authPhone != null &&
                authPhone.isNotEmpty &&
                !_isLegacyMockPhone(authPhone))
            ? authPhone
            : (_isLegacyMockPhone(_currentUser.phone)
                ? (authUser?.phoneNumber ?? '')
                : _currentUser.phone.trim());

        debugPrint('DeliveryNotifier: Loaded name = $fallbackName');
        debugPrint('DeliveryNotifier: Loaded phone = ${_maskPhone(fallbackPhone)}');
        debugPrint('DeliveryNotifier: Loaded vehicle = ');
        debugPrint('DeliveryNotifier: Loaded vehicleType = ');
        debugPrint('DeliveryNotifier: Loaded vehicleNumber = ');
        debugPrint('DeliveryNotifier: Loaded assignedZone = ');
        debugPrint('DeliveryNotifier: Loaded profileImageUrl = ${_currentUser.profileImageUrl ?? authUser?.photoURL}');

        if (!mounted) return;
        state = DeliveryAgent.empty(uid).copyWith(
          name: fallbackName,
          phone: fallbackPhone,
          email: _currentUser.email?.trim() ?? authUser?.email,
          profileImageUrl: _currentUser.profileImageUrl ?? authUser?.photoURL,
          isLoaded: true,
        );
      }
    }, onError: (err) {
      debugPrint(
          'DeliveryNotifier: Stream error on delivery_agents/$uid: $err');
      if (!mounted) return;
      state = state.copyWith(isLoaded: true);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> toggleDuty() async {
    final uid = _effectiveUid;
    if (uid.isEmpty) return;

    final isOnline = state.status != DeliveryStatus.onDuty;
    final newStatus = isOnline ? DeliveryStatus.onDuty : DeliveryStatus.offDuty;

    // Optimistically update local state
    state = state.copyWith(status: newStatus);

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('delivery_agents').doc(uid).set({
          'isOnline': isOnline,
          'isOnDuty': isOnline,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update legacy tracking service
        await _ref
            .read(deliveryTrackingServiceProvider)
            .updateAgentOnlineStatus(uid, isOnline);
      } catch (_) {}
    }
  }

  void startBreak() {
    state = state.copyWith(status: DeliveryStatus.breakTime);
  }

  void endBreak() {
    state = state.copyWith(status: DeliveryStatus.onDuty);
  }

  void updateStats({
    int? totalDeliveries,
    int? completedDeliveries,
    double? earnings,
  }) {
    state = state.copyWith(
      totalDeliveriesToday: totalDeliveries ?? state.totalDeliveriesToday,
      completedDeliveriesToday:
          completedDeliveries ?? state.completedDeliveriesToday,
      earningsToday: earnings ?? state.earningsToday,
    );
  }

  /// Updates profile details in both delivery_agents/{uid} and users/{uid}
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? vehicle,
    String? vehicleNumber,
    String? assignedZone,
    String? profileImageUrl,
  }) async {
    final authUser = _auth?.currentUser;
    final uid = authUser?.uid ?? (_effectiveUid.isNotEmpty ? _effectiveUid : '');
    if (uid.isEmpty) {
      throw StateError('Cannot update profile: user is not authenticated.');
    }

    final trimmedName = name?.trim();
    final trimmedPhone = phone?.trim();
    final trimmedVehicle = vehicle?.trim();
    final trimmedVehicleNumber = vehicleNumber?.trim();
    final trimmedZone = assignedZone?.trim();
    final trimmedImage = profileImageUrl?.trim();

    final authPhone = authUser?.phoneNumber?.trim();
    // Requirements: Phone number must NOT be overwritten by arbitrary user input.
    // Prioritize authenticated Firebase phone number.
    final effectivePhone = (authPhone != null && authPhone.isNotEmpty)
        ? authPhone
        : (trimmedPhone != null && trimmedPhone.isNotEmpty
            ? trimmedPhone
            : state.phone);

    final agentUpdates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (trimmedName != null && trimmedName.isNotEmpty) {
      agentUpdates['name'] = trimmedName;
    }
    if (effectivePhone.isNotEmpty) {
      agentUpdates['phone'] = effectivePhone;
    }
    if (trimmedVehicle != null && trimmedVehicle.isNotEmpty) {
      agentUpdates['vehicle'] = trimmedVehicle;
      agentUpdates['vehicleType'] = trimmedVehicle;
    }
    if (trimmedVehicleNumber != null && trimmedVehicleNumber.isNotEmpty) {
      agentUpdates['vehicleNumber'] = trimmedVehicleNumber;
    }
    if (trimmedZone != null && trimmedZone.isNotEmpty) {
      agentUpdates['assignedZone'] = trimmedZone;
    }
    if (trimmedImage != null && trimmedImage.isNotEmpty) {
      agentUpdates['profileImageUrl'] = trimmedImage;
    }

    // Write to Firestore delivery_agents/{uid} with only allowed fields
    final firestore = _firestore;
    if (firestore != null) {
      debugPrint(
          'DeliveryNotifier: Writing to delivery_agents/$uid with fields: ${agentUpdates.keys.toList()}');
      final agentDocRef = firestore.collection('delivery_agents').doc(uid);
      final agentDoc = await agentDocRef.get();
      if (!agentDoc.exists) {
        // Creation requires uid for rules compliance: request.resource.data.uid == request.auth.uid
        agentUpdates['uid'] = uid;
        if (trimmedImage == null &&
            state.profileImageUrl != null &&
            state.profileImageUrl!.isNotEmpty) {
          agentUpdates['profileImageUrl'] = state.profileImageUrl;
        }
        await agentDocRef.set(agentUpdates);
      } else {
        // Update must strictly contain ONLY allowed profile fields (no uid, no photoUrl)
        await agentDocRef.update(agentUpdates);
      }
    }

    // Synchronize profile details to users/{uid} and userProvider in-sync
    await _ref.read(userProvider.notifier).updateProfile(
          name: trimmedName,
          phone: effectivePhone.isNotEmpty ? effectivePhone : null,
          vehicle: trimmedVehicle,
          vehicleType: trimmedVehicle,
          vehicleNumber: trimmedVehicleNumber,
          assignedZone: trimmedZone,
          profileImageUrl: trimmedImage,
        );

    if (trimmedName != null && trimmedName.isNotEmpty && authUser != null) {
      try {
        await authUser.updateDisplayName(trimmedName);
      } catch (_) {}
    }

    if (!mounted) return;

    // Update local state
    state = state.copyWith(
      name: trimmedName ?? state.name,
      phone: effectivePhone.isNotEmpty ? effectivePhone : state.phone,
      vehicle: trimmedVehicle ?? state.vehicle,
      vehicleNumber: trimmedVehicleNumber ?? state.vehicleNumber,
      assignedZone: trimmedZone ?? state.assignedZone,
      profileImageUrl: trimmedImage ?? state.profileImageUrl,
    );
  }

  /// Uploads profile photo to Firebase Storage and updates profileImageUrl
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    String? contentType,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final uid = authUser?.uid ?? _effectiveUid;
    if (uid.isEmpty || authUser == null) {
      throw StateError('Authentication required: please log in to upload a profile photo.');
    }

    final downloadUrl = await FirebaseStorageService.instance
        .uploadDeliveryAgentProfileImage(
      uid: uid,
      bytes: bytes,
      contentType: contentType,
    );

    try {
      await authUser.updatePhotoURL(downloadUrl);
    } catch (_) {}

    await updateProfile(profileImageUrl: downloadUrl);
    return downloadUrl;
  }
}

final deliveryAgentProvider =
    StateNotifierProvider<DeliveryNotifier, DeliveryAgent>((ref) {
  ref.watch(userProvider.select((u) => u.id));
  final user = ref.read(userProvider);
  return DeliveryNotifier(ref, user);
});

class DeliveryEarningsNotifier extends StateNotifier<List<DeliveryEarnings>> {
  final Ref _ref;

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  StreamSubscription? _authSubscription;
  StreamSubscription<List<EarningModel>>? _subscription;
  String _activeAgentId = '';

  DeliveryEarningsNotifier(this._ref) : super(const []) {
    try {
      _authSubscription = _auth?.authStateChanges().listen((fbUser) {
        _onAgentIdChanged(fbUser?.uid ?? '');
      });
    } catch (_) {}

    _onAgentIdChanged(_currentAgentId);
  }

  String get _currentAgentId {
    try {
      final authUid = _auth?.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    } catch (_) {}
    try {
      final userId = _ref.read(userProvider).id;
      if (userId.isNotEmpty) return userId;
    } catch (_) {}
    return '';
  }

  void _onAgentIdChanged(String agentId) {
    final effectiveId = agentId.isNotEmpty ? agentId : _currentAgentId;
    if (effectiveId == _activeAgentId && _subscription != null) {
      return;
    }
    _subscription?.cancel();
    _subscription = null;
    _activeAgentId = effectiveId;

    if (effectiveId.isEmpty) {
      if (mounted) {
        state = const [];
      }
      return;
    }

    _subscription = _ref
        .read(earningsServiceProvider)
        .getAgentEarnings(effectiveId)
        .listen((earningModels) {
      if (!mounted) return;
      state = _groupEarningsByDate(earningModels);
    }, onError: (_) {
      if (!mounted) return;
      // On error (e.g. permission-denied / unauthorized cross-agent access),
      // ensure stale or unauthorized earnings are not retained.
      state = const [];
    });
  }

  static List<DeliveryEarnings> _groupEarningsByDate(
      List<EarningModel> models) {
    if (models.isEmpty) return const [];

    final Map<String, List<EarningModel>> byDay = {};
    for (final m in models) {
      final d = m.timestamp;
      final dayKey =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(dayKey, () => []).add(m);
    }

    final sortedKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedKeys.map((key) {
      final dayList = byDay[key]!;
      final date = dayList.first.timestamp;
      final base = dayList.fold(0.0, (acc, e) => acc + e.amountEarned);
      final tips = dayList.fold(0.0, (acc, e) => acc + e.tipAmount);
      final count = dayList.length;
      return DeliveryEarnings(
        date: date,
        baseEarnings: base,
        tips: tips,
        bonuses: 0.0,
        deliveriesCount: count,
        total: base + tips,
      );
    }).toList();
  }

  void addEarnings(DeliveryEarnings earnings) {
    state = [earnings, ...state.take(30)].toList();
  }

  double get todayTotal {
    final now = DateTime.now();
    for (final e in state) {
      if (e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day) {
        return e.total;
      }
    }
    return 0.0;
  }

  int get todayDeliveries {
    final now = DateTime.now();
    for (final e in state) {
      if (e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day) {
        return e.deliveriesCount;
      }
    }
    return 0;
  }

  double get weekTotal {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return state
        .where((e) => e.date.isAfter(sevenDaysAgo))
        .fold(0.0, (acc, e) => acc + e.total);
  }

  int get weekDeliveries {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return state
        .where((e) => e.date.isAfter(sevenDaysAgo))
        .fold(0, (acc, e) => acc + e.deliveriesCount);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

final deliveryEarningsProvider =
    StateNotifierProvider<DeliveryEarningsNotifier, List<DeliveryEarnings>>(
        (ref) {
  ref.watch(userProvider.select((u) => u.id));
  return DeliveryEarningsNotifier(ref);
});

class DeliveryHistoryNotifier extends StateNotifier<List<DeliveryHistoryItem>> {
  DeliveryHistoryNotifier() : super(const []);

  void addToHistory(DeliveryHistoryItem item) {
    state = [item, ...state];
  }
}

final deliveryHistoryProvider =
    StateNotifierProvider<DeliveryHistoryNotifier, List<DeliveryHistoryItem>>(
        (ref) {
  return DeliveryHistoryNotifier();
});

class DeliveryPanelTabNotifier extends StateNotifier<int> {
  DeliveryPanelTabNotifier() : super(0);

  void setTab(int index) {
    state = index;
  }
}

final deliveryPanelTabProvider =
    StateNotifierProvider<DeliveryPanelTabNotifier, int>((ref) {
  return DeliveryPanelTabNotifier();
});
