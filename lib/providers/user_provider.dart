import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/auth/app_role.dart';
import '../core/router/auth_refresh.dart';
import '../models/user.dart';

const User guestUser = User(
  id: '',
  name: 'Guest Customer',
  phone: '',
  email: '',
  role: UserRole.customerValue,
);

/// Utility for normalizing and generating phone number variations for Firestore lookups.
class PhoneAuthUtils {
  /// Extracts the standard 10-digit Indian mobile number if possible,
  /// or stripped digits.
  static String normalize(String? phone) {
    if (phone == null) return '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return digits;
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Generates all common queryable representations of a phone number:
  /// e.g. ["+919999999999", "9999999999", "+91 9999999999", "919999999999", "09999999999", ...]
  static List<String> generateVariants(String? phone) {
    if (phone == null || phone.trim().isEmpty) return [];
    final raw = phone.trim();
    final digits = normalize(raw);
    final variants = <String>{};
    variants.add(raw);
    if (digits.isNotEmpty) {
      variants.add(digits);
      variants.add('+91$digits');
      variants.add('91$digits');
      variants.add('0$digits');
      if (digits.length == 10) {
        variants.add('+91 $digits');
        variants.add('${digits.substring(0, 5)} ${digits.substring(5)}');
      }
    }
    return variants.take(10).toList();
  }
}

/// Current user profile state notifier that supports SharedPreferences persistence and Firestore sync.
class UserNotifier extends StateNotifier<User> {
  static const String _sessionKey = 'user_session';
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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  UserNotifier() : super(guestUser) {
    loadSession();
    debugPrint(
        '[PROFILE DEBUG T0] UserNotifier initialized, initial state.profileImageUrl: ${state.profileImageUrl}');
  }

  static String? _extractProfileImageUrl(Map<String, dynamic> data) {
    final candidate = data['profileImageUrl'] ??
        data['photoUrl'] ??
        data['photoURL'] ??
        data['profileImage'] ??
        data['imageUrl'] ??
        data['avatar'];
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
    return null;
  }

  /// Authoritatively determines the user's role by querying:
  /// 1. `admins` collection (doc ID == uid, `uid` field == uid, or `phone` matching normalized variants)
  /// 2. `delivery_agents` collection (doc ID == uid, `uid` field, or `phone` matching variants)
  /// 3. `users` collection (doc ID == uid)
  /// 4. Defaults securely to 'customer'
  Future<String> _resolveAuthoritativeRole({
    required String uid,
    String? phone,
    String? currentRole,
  }) async {
    final firestore = _firestore;
    final fbUser = _auth?.currentUser;
    final effectivePhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : (fbUser?.phoneNumber ?? '');
    final normalizedPhone = PhoneAuthUtils.normalize(effectivePhone);
    final phoneVariants = PhoneAuthUtils.generateVariants(effectivePhone);

    debugPrint('[AUTH ROLE DEBUG] Authenticated UID: $uid');
    debugPrint(
        '[AUTH ROLE DEBUG] Firebase phoneNumber: ${fbUser?.phoneNumber ?? effectivePhone}');
    debugPrint(
        '[AUTH ROLE DEBUG] Normalized phone number: $normalizedPhone');

    // 1. Check phone-based role (historical & standard: 9999999999/8888888888 -> admin, 7777777777 -> delivery)
    final phoneRole = UserRole.fromPhone(effectivePhone);
    if (phoneRole != UserRole.customer) {
      debugPrint(
          '[AUTH ROLE DEBUG] Admin lookup result: FOUND by phone number ($effectivePhone -> normalized: $normalizedPhone, role: ${phoneRole.value})');
      debugPrint('[AUTH ROLE DEBUG] Detected role: ${phoneRole.value}');
      return phoneRole.value;
    }

    // 2. Check explicit privileged role if already present
    if (currentRole != null && currentRole.trim().isNotEmpty) {
      final parsed = UserRole.fromString(currentRole);
      if (parsed != UserRole.customer) {
        debugPrint(
            '[AUTH ROLE DEBUG] Admin lookup result: FOUND by explicit role string ($currentRole -> role: ${parsed.value})');
        debugPrint('[AUTH ROLE DEBUG] Detected role: ${parsed.value}');
        return parsed.value;
      }
    }

    if (firestore == null || uid.isEmpty) {
      final safeRole = UserRole.fromPhoneAndRole(phone: effectivePhone, role: currentRole).value;
      debugPrint(
          '[AUTH ROLE DEBUG] Admin lookup result: Firestore unavailable or empty UID. Falling back to: $safeRole');
      debugPrint('[AUTH ROLE DEBUG] Detected role: $safeRole');
      return safeRole;
    }

    // 3. Check `admins` collection
    try {
      // 1a. Check by direct doc ID == uid
      final adminDocByUid =
          await firestore.collection('admins').doc(uid).get();
      if (adminDocByUid.exists && adminDocByUid.data() != null) {
        final data = adminDocByUid.data()!;
        final rawRole = (data['role'] as String?)?.trim() ?? 'admin';
        final resolvedRole = UserRole.fromString(rawRole).value;
        debugPrint(
            '[AUTH ROLE DEBUG] Admin lookup result: FOUND in admins collection by doc ID (docId: $uid, data: $data)');
        debugPrint('[AUTH ROLE DEBUG] Detected role: $resolvedRole');
        return resolvedRole;
      }

      // 1b. Check by `uid` field
      final adminQueryByUid = await firestore
          .collection('admins')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (adminQueryByUid.docs.isNotEmpty) {
        final doc = adminQueryByUid.docs.first;
        final data = doc.data();
        final rawRole = (data['role'] as String?)?.trim() ?? 'admin';
        final resolvedRole = UserRole.fromString(rawRole).value;
        debugPrint(
            '[AUTH ROLE DEBUG] Admin lookup result: FOUND in admins collection by uid field (docId: ${doc.id}, data: $data)');
        debugPrint('[AUTH ROLE DEBUG] Detected role: $resolvedRole');
        return resolvedRole;
      }

      // 1c. Check by phone field match (e.g. test_admin doc with phone: "+919999999999")
      if (phoneVariants.isNotEmpty) {
        final adminQueryByPhone = await firestore
            .collection('admins')
            .where('phone', whereIn: phoneVariants)
            .limit(1)
            .get();
        if (adminQueryByPhone.docs.isNotEmpty) {
          final doc = adminQueryByPhone.docs.first;
          final data = doc.data();
          final rawRole = (data['role'] as String?)?.trim() ?? 'admin';
          final resolvedRole = UserRole.fromString(rawRole).value;
          debugPrint(
              '[AUTH ROLE DEBUG] Admin lookup result: FOUND in admins collection by phone field match (docId: ${doc.id}, matchedPhone: ${data['phone']}, role: $rawRole)');
          debugPrint('[AUTH ROLE DEBUG] Detected role: $resolvedRole');
          return resolvedRole;
        }

        // 1d. Check by doc ID == normalized phone
        if (normalizedPhone.isNotEmpty) {
          final adminDocByPhone = await firestore
              .collection('admins')
              .doc(normalizedPhone)
              .get();
          if (adminDocByPhone.exists && adminDocByPhone.data() != null) {
            final data = adminDocByPhone.data()!;
            final rawRole = (data['role'] as String?)?.trim() ?? 'admin';
            final resolvedRole = UserRole.fromString(rawRole).value;
            debugPrint(
                '[AUTH ROLE DEBUG] Admin lookup result: FOUND in admins collection by doc ID==phone (docId: ${adminDocByPhone.id}, data: $data)');
            debugPrint('[AUTH ROLE DEBUG] Detected role: $resolvedRole');
            return resolvedRole;
          }
        }
      }
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] Admin lookup error: $e');
    }

    // 2. Check `delivery_agents` collection
    try {
      // 2a. Check by direct doc ID == uid
      final agentDocByUid =
          await firestore.collection('delivery_agents').doc(uid).get();
      if (agentDocByUid.exists && agentDocByUid.data() != null) {
        debugPrint(
            '[AUTH ROLE DEBUG] Admin lookup result: NOT admin. FOUND in delivery_agents by doc ID ($uid)');
        debugPrint('[AUTH ROLE DEBUG] Detected role: delivery');
        return UserRole.deliveryValue;
      }

      // 2b. Check by `uid` field
      final agentQueryByUid = await firestore
          .collection('delivery_agents')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (agentQueryByUid.docs.isNotEmpty) {
        debugPrint(
            '[AUTH ROLE DEBUG] Admin lookup result: NOT admin. FOUND in delivery_agents by uid field (${agentQueryByUid.docs.first.id})');
        debugPrint('[AUTH ROLE DEBUG] Detected role: delivery');
        return UserRole.deliveryValue;
      }

      // 2c. Check by phone field match
      if (phoneVariants.isNotEmpty) {
        final agentQueryByPhone = await firestore
            .collection('delivery_agents')
            .where('phone', whereIn: phoneVariants)
            .limit(1)
            .get();
        if (agentQueryByPhone.docs.isNotEmpty) {
          debugPrint(
              '[AUTH ROLE DEBUG] Admin lookup result: NOT admin. FOUND in delivery_agents by phone field match (${agentQueryByPhone.docs.first.id})');
          debugPrint('[AUTH ROLE DEBUG] Detected role: delivery');
          return UserRole.deliveryValue;
        }
      }
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] Delivery agent lookup error: $e');
    }

    // 3. Check `users` collection for role
    try {
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final rawRole = data['role'] as String?;
        if (rawRole != null && rawRole.trim().isNotEmpty) {
          final userRole = UserRole.fromString(rawRole).value;
          debugPrint(
              '[AUTH ROLE DEBUG] Admin lookup result: NOT in admins/delivery_agents. Found in users/$uid with role=$rawRole');
          debugPrint('[AUTH ROLE DEBUG] Detected role: $userRole');
          return userRole;
        }
      }
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] User doc role lookup error: $e');
    }

    // 4. Default: Standard customer
    final fallbackRole = UserRole.sanitize(currentRole);
    debugPrint(
        '[AUTH ROLE DEBUG] Admin lookup result: NOT found in privileged collections. Defaulting to: $fallbackRole');
    debugPrint('[AUTH ROLE DEBUG] Detected role: $fallbackRole');
    return fallbackRole;
  }

  void _startUserDocListener(String uid) {
    _userSubscription?.cancel();
    if (uid.isEmpty) return;
    final firestore = _firestore;
    if (firestore == null) return;

    _userSubscription =
        firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final imageUrl = _extractProfileImageUrl(data);
          final currentImageUrl = state.profileImageUrl;
          final effectiveImageUrl = (imageUrl != null && imageUrl.isNotEmpty)
              ? imageUrl
              : currentImageUrl;

          debugPrint(
              '[PROFILE DEBUG T4] Firestore listener fired: uid=$uid, docImageUrl=$imageUrl, currentRiverpod=$currentImageUrl, resolvedEffective=$effectiveImageUrl');

          final trustedRole = UserRole.fromPhoneAndRole(
            phone: (data['phone'] as String?) ?? state.phone,
            role: data['role'] as String?,
          ).value;

          final cleanName = (data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String).trim()
              : (state.name.trim() != 'Guest Customer' &&
                      state.name.trim() != 'Sawariya Customer'
                  ? state.name.trim()
                  : '');

          final updatedUser = User(
            id: uid,
            name: cleanName,
            phone: (data['phone'] as String?)?.trim().isNotEmpty == true
                ? (data['phone'] as String).trim()
                : state.phone,
            email: (data['email'] as String?)?.trim().isNotEmpty == true
                ? (data['email'] as String).trim()
                : state.email,
            profileImageUrl: effectiveImageUrl,
            role: trustedRole,
          );

          if (updatedUser.profileImageUrl != currentImageUrl ||
              updatedUser.name != state.name ||
              updatedUser.phone != state.phone ||
              updatedUser.email != state.email ||
              updatedUser.role != state.role) {
            state = updatedUser;
            notifyAuthStateChanged();
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString(_sessionKey, jsonEncode(updatedUser.toMap()));
            });
            debugPrint(
                '[PROFILE DEBUG T4] State updated by listener: role=${state.role}, profileImageUrl=${state.profileImageUrl}');
          } else {
            debugPrint(
                '[PROFILE DEBUG T4] No state change needed: profileImageUrl=${state.profileImageUrl}');
          }
        }
      } else {
        // Document deleted in Firestore: revoke privileged access immediately (unless recognized by phone)
        final phoneRole = UserRole.fromPhone(state.phone).value;
        if (state.role != phoneRole) {
          state = User(
            id: state.id,
            name: state.name,
            phone: state.phone,
            email: state.email,
            profileImageUrl: state.profileImageUrl,
            role: phoneRole,
          );
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString(_sessionKey, jsonEncode(state.toMap()));
          });
          notifyAuthStateChanged();
        }
      }
    }, onError: (err) {
      debugPrint('[PROFILE DEBUG T4] Firestore listener error: $err');
    });
  }

  /// Load session from SharedPreferences and sync with Firestore in background
  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionKey);
      if (sessionJson != null) {
        final Map<String, dynamic> map = jsonDecode(sessionJson);
        var loadedUser = User.fromMap(map);

        // Ensure restored session respects normalized phone role if stored as default customer
        if (loadedUser.role == UserRole.customerValue && loadedUser.phone.isNotEmpty) {
          final phoneRole = UserRole.fromPhone(loadedUser.phone);
          if (phoneRole != UserRole.customer) {
            loadedUser = User(
              id: loadedUser.id,
              name: loadedUser.name,
              phone: loadedUser.phone,
              email: loadedUser.email,
              profileImageUrl: loadedUser.profileImageUrl,
              role: phoneRole.value,
            );
          }
        }

        state = loadedUser;
        debugPrint(
            '[PROFILE DEBUG] loadSession: restored User.fromMap role=${state.role}, phone=${state.phone}, profileImageUrl = ${state.profileImageUrl}');

        // Sync authoritative role and profile in background & start real-time listener
        if (state.id.isNotEmpty) {
          _syncFromFirestore(state.id);
          _startUserDocListener(state.id);
          _syncFcmToken(state.id);
        }
      }
    } catch (e) {
      // Fallback to guest user on error
      state = guestUser;
    }
    debugPrint(
        '[PROFILE DEBUG] loadSession: final role=${state.role}, profileImageUrl = ${state.profileImageUrl}');
    notifyAuthStateChanged();
  }

  Future<void> _syncFromFirestore(String uid) async {
    final firestore = _firestore;
    if (firestore == null) return;
    try {
      final resolvedRole = await _resolveAuthoritativeRole(
        uid: uid,
        phone: state.phone,
        currentRole: state.role,
      );

      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final imageUrl = _extractProfileImageUrl(data);
          final currentImageUrl = state.profileImageUrl;
          final effectiveImageUrl = (imageUrl != null && imageUrl.isNotEmpty)
              ? imageUrl
              : currentImageUrl;

          debugPrint(
              '[PROFILE DEBUG] _syncFromFirestore: uid=$uid, extracted imageUrl=$imageUrl, current=$currentImageUrl, resolved=$effectiveImageUrl, resolvedRole=$resolvedRole');

          final cleanName = (data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String).trim()
              : (state.name.trim() != 'Guest Customer' &&
                      state.name.trim() != 'Sawariya Customer'
                  ? state.name.trim()
                  : '');

          final updatedUser = User(
            id: uid,
            name: cleanName,
            phone: (data['phone'] as String?)?.trim().isNotEmpty == true
                ? (data['phone'] as String).trim()
                : state.phone,
            email: (data['email'] as String?)?.trim().isNotEmpty == true
                ? (data['email'] as String).trim()
                : state.email,
            profileImageUrl: effectiveImageUrl,
            role: resolvedRole,
          );

          if (updatedUser.name != state.name ||
              updatedUser.phone != state.phone ||
              updatedUser.email != state.email ||
              updatedUser.profileImageUrl != state.profileImageUrl ||
              updatedUser.role != state.role) {
            state = updatedUser;
            final prefs = await SharedPreferences.getInstance();
            final sessionJson = jsonEncode(state.toMap());
            await prefs.setString(_sessionKey, sessionJson);
            debugPrint(
                '[PROFILE DEBUG] _syncFromFirestore: state updated, profileImageUrl=${state.profileImageUrl}');
            notifyAuthStateChanged();
          }
        }
      } else {
        if (resolvedRole != UserRole.customerValue) {
          final updatedUser = User(
            id: uid,
            name: state.name,
            phone: state.phone,
            email: state.email,
            profileImageUrl: state.profileImageUrl,
            role: resolvedRole,
          );
          state = updatedUser;
          final prefs = await SharedPreferences.getInstance();
          final sessionJson = jsonEncode(state.toMap());
          await prefs.setString(_sessionKey, sessionJson);
          notifyAuthStateChanged();
        } else if (state.role != UserRole.customerValue) {
          state = User(
            id: state.id,
            name: state.name,
            phone: state.phone,
            email: state.email,
            profileImageUrl: state.profileImageUrl,
            role: UserRole.customerValue,
          );
          final prefs = await SharedPreferences.getInstance();
          final sessionJson = jsonEncode(state.toMap());
          await prefs.setString(_sessionKey, sessionJson);
          notifyAuthStateChanged();
        }
      }
    } catch (err) {
      debugPrint('[PROFILE DEBUG] _syncFromFirestore error: $err');
    }
  }

  /// Save session to SharedPreferences, update state, and sync/create in Firestore.
  /// The user's authoritative role is ALWAYS determined by the Firestore document / privileged collections.
  Future<void> setSession(User user) async {
    final firestore = _firestore;
    if (user.id.isNotEmpty && firestore != null) {
      try {
        final docRef = firestore.collection('users').doc(user.id);
        final doc = await docRef.get();

        // Perform authoritative multi-source role resolution (admins, delivery_agents, users)
        final resolvedRole = await _resolveAuthoritativeRole(
          uid: user.id,
          phone: user.phone,
          currentRole: doc.exists ? (doc.data()?['role'] as String?) : user.role,
        );

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final imageUrl = _extractProfileImageUrl(data);

            final cleanName = (data['name'] as String?)?.trim().isNotEmpty == true
                ? (data['name'] as String).trim()
                : (user.name.trim().isNotEmpty &&
                        user.name.trim() != 'Guest Customer' &&
                        user.name.trim() != 'Sawariya Customer'
                    ? user.name.trim()
                    : '');

            user = User(
              id: user.id,
              name: cleanName,
              phone: (data['phone'] as String?)?.trim().isNotEmpty == true
                  ? (data['phone'] as String).trim()
                  : user.phone,
              email: (data['email'] as String?)?.trim().isNotEmpty == true
                  ? (data['email'] as String).trim()
                  : user.email,
              profileImageUrl: (imageUrl != null && imageUrl.isNotEmpty)
                  ? imageUrl
                  : user.profileImageUrl,
              role: resolvedRole,
            );
          }
          await docRef.set({
            'role': resolvedRole,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          final cleanName = (user.name.trim().isNotEmpty &&
                  user.name.trim() != 'Guest Customer' &&
                  user.name.trim() != 'Sawariya Customer')
              ? user.name.trim()
              : '';
          user = User(
            id: user.id,
            name: cleanName,
            phone: user.phone,
            email: user.email,
            profileImageUrl: user.profileImageUrl,
            role: resolvedRole,
          );
          await docRef.set({
            'uid': user.id,
            if (cleanName.isNotEmpty) 'name': cleanName,
            'phone': user.phone,
            'email': user.email,
            'profileImageUrl': user.profileImageUrl,
            'photoUrl': user.profileImageUrl,
            'role': resolvedRole,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[PROFILE DEBUG] setSession Firestore sync error: $e');
        final resolvedRole = await _resolveAuthoritativeRole(
          uid: user.id,
          phone: user.phone,
          currentRole: user.role,
        );
        user = User(
          id: user.id,
          name: (user.name.trim() != 'Guest Customer' &&
                  user.name.trim() != 'Sawariya Customer')
              ? user.name.trim()
              : '',
          phone: user.phone,
          email: user.email,
          profileImageUrl: user.profileImageUrl,
          role: resolvedRole,
        );
      }
    }

    state = user;
    notifyAuthStateChanged();
    if (user.id.isNotEmpty) {
      _startUserDocListener(user.id);
      _syncFcmToken(user.id);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = jsonEncode(user.toMap());
      await prefs.setString(_sessionKey, sessionJson);
    } catch (_) {}
  }

  /// Synchronizes FCM token with user profile in Firestore
  Future<void> _syncFcmToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      final firestore = _firestore;
      if (token != null && token.isNotEmpty && firestore != null) {
        await firestore.collection('users').doc(uid).set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM TOKEN] Successfully registered token for user $uid');
      }
    } catch (e) {
      debugPrint('[FCM TOKEN] Failed to sync token on session start: $e');
    }
  }

  /// Clears FCM token association upon logout
  Future<void> _clearFcmToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      final firestore = _firestore;
      if (token != null && token.isNotEmpty && firestore != null) {
        await firestore.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
          'fcmToken': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
      try {
        await messaging.deleteToken();
      } catch (_) {}
      debugPrint('[FCM TOKEN] Successfully cleared token for user $uid');
    } catch (e) {
      debugPrint('[FCM TOKEN] Failed to clear token on logout: $e');
    }
  }

  /// Clear session on Logout
  Future<void> clearSession() async {
    final prevId = state.id;
    _userSubscription?.cancel();
    _userSubscription = null;
    state = guestUser;
    notifyAuthStateChanged();
    if (prevId.isNotEmpty) {
      _clearFcmToken(prevId);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
    try {
      await _auth?.signOut();
    } catch (_) {}
  }

  /// Developer-only helper (used by debug toggles) to switch the current
  /// user's role so the Delivery Panel can be tested. Persists like a normal
  /// session change.
  Future<void> setRole(String role) async {
    final updatedUser = User(
      id: state.id,
      name: state.name,
      phone: state.phone,
      email: state.email,
      profileImageUrl: state.profileImageUrl,
      role: UserRole.sanitize(role),
    );
    await setSession(updatedUser);
  }

  /// Updates profile in Firestore first, then keeps local state synchronized.
  /// Strictly preserves the user's authoritative role.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? profileImageUrl,
    String? vehicle,
    String? vehicleType,
    String? vehicleNumber,
    String? assignedZone,
  }) async {
    final authUid = _auth?.currentUser?.uid;
    final targetUid = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : (state.id.isNotEmpty ? state.id : '');
    if (targetUid.isEmpty) {
      throw Exception('No authenticated user session found.');
    }

    debugPrint(
        '[PROFILE DEBUG T2] updateProfile: starting, state.profileImageUrl before=${state.profileImageUrl}, incoming profileImageUrl=$profileImageUrl');

    final trimmedName = name?.trim();
    final trimmedPhone = phone?.trim();
    final trimmedEmail = email?.trim();
    final trimmedImage = profileImageUrl?.trim();
    final trimmedVehicle = vehicle?.trim();
    final trimmedVehicleType = vehicleType?.trim();
    final trimmedVehicleNum = vehicleNumber?.trim();
    final trimmedZone = assignedZone?.trim();

    final updatedUser = User(
      id: targetUid,
      name: (trimmedName != null && trimmedName.isNotEmpty) ? trimmedName : state.name,
      phone: (trimmedPhone != null && trimmedPhone.isNotEmpty) ? trimmedPhone : state.phone,
      email: (trimmedEmail != null && trimmedEmail.isNotEmpty) ? trimmedEmail : state.email,
      profileImageUrl: (trimmedImage != null && trimmedImage.isNotEmpty)
          ? trimmedImage
          : state.profileImageUrl,
      role: state.role, // role is strictly preserved and never mutated here
    );

    // Update in Firestore first using set with merge so it succeeds whether the document exists or not.
    // Strictly omit 'role' so non-admin users cannot mutate role and comply with firestore.rules.
    final firestore = _firestore;
    if (firestore != null) {
      final docRef = firestore.collection('users').doc(targetUid);
      final fieldsToUpdate = <String, dynamic>{
        'uid': targetUid,
        if (trimmedName != null && trimmedName.isNotEmpty) 'name': trimmedName,
        if (trimmedPhone != null && trimmedPhone.isNotEmpty) 'phone': trimmedPhone,
        if (trimmedEmail != null && trimmedEmail.isNotEmpty) 'email': trimmedEmail,
        if (trimmedVehicle != null && trimmedVehicle.isNotEmpty) 'vehicle': trimmedVehicle,
        if (trimmedVehicleType != null && trimmedVehicleType.isNotEmpty) 'vehicleType': trimmedVehicleType,
        if (trimmedVehicleNum != null && trimmedVehicleNum.isNotEmpty) 'vehicleNumber': trimmedVehicleNum,
        if (trimmedZone != null && trimmedZone.isNotEmpty) 'assignedZone': trimmedZone,
        if (trimmedImage != null && trimmedImage.isNotEmpty) ...{
          'profileImageUrl': trimmedImage,
          'photoUrl': trimmedImage,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };
      debugPrint(
          'UserNotifier: Writing to users/$targetUid with fields: ${fieldsToUpdate.keys.toList()}');
      await docRef.set(fieldsToUpdate, SetOptions(merge: true));

      debugPrint(
          '[PROFILE DEBUG T2] updateProfile: Firestore write succeeded on users/$targetUid');
    }

    // Update local state
    state = updatedUser;
    debugPrint(
        '[PROFILE DEBUG T3] updateProfile: Riverpod local state updated, profileImageUrl=${state.profileImageUrl}');
    notifyAuthStateChanged();
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = jsonEncode(updatedUser.toMap());
    await prefs.setString(_sessionKey, sessionJson);
    debugPrint(
        '[PROFILE DEBUG T3] updateProfile: session saved to SharedPreferences, profileImageUrl=${updatedUser.profileImageUrl}');
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}

final userProvider = StateNotifierProvider<UserNotifier, User>((ref) {
  return UserNotifier();
});
