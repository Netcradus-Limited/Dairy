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
import '../models/staff_member.dart';
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
  /// 3. `users` collection (doc ID == uid, or phone match with self-healing orphaned staff doc migration)
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

    if (firestore == null || uid.isEmpty) {
      final safeRole = UserRole.fromPhoneAndRole(phone: effectivePhone, role: currentRole).value;
      debugPrint(
          '[AUTH ROLE DEBUG] Admin lookup result: Firestore unavailable or empty UID. Falling back to: $safeRole');
      debugPrint('[AUTH ROLE DEBUG] Detected role: $safeRole');
      return safeRole;
    }

    // 2. Check `admins` collection
    try {
      Future<String> linkAdminMatch(Map<String, dynamic> data, String sourceDocId) async {
        final rawRole = (data['role'] as String?)?.trim() ?? 'admin';
        final resolvedRole = UserRole.sanitize(rawRole);
        final roleTitle = data['roleTitle'] as String? ??
            StaffRolePresets.getDisplayTitleForRole(resolvedRole);
        final perms = data['permissions'] is List
            ? (data['permissions'] as List)
                .map((p) => p.toString().trim())
                .where((p) => p.isNotEmpty)
                .toList()
            : StaffRolePresets.getPermissionsForRole(resolvedRole);
        final status = (data['status'] as String? ?? 'Active').trim();
        final name = (data['name'] as String? ?? '').trim();
        final email = (data['email'] as String? ?? '').trim();

        debugPrint(
            '[AUTH ROLE DEBUG] Linking admin/staff match (docId: $sourceDocId, role: $resolvedRole, perms: ${perms.length}) to auth user $uid');

        try {
          await firestore.collection('users').doc(uid).set({
            'uid': uid,
            'role': resolvedRole,
            'roleTitle': roleTitle,
            'permissions': perms,
            'status': status,
            'isAdmin': resolvedRole == 'admin',
            if (name.isNotEmpty) 'name': name,
            if (email.isNotEmpty) 'email': email,
            if (effectivePhone.isNotEmpty) 'phone': effectivePhone,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await firestore.collection('admins').doc(uid).set({
            'uid': uid,
            'role': resolvedRole == 'admin' ? 'superadmin' : resolvedRole,
            'roleTitle': roleTitle,
            'permissions': perms,
            'status': status,
            if (name.isNotEmpty) 'name': name,
            if (email.isNotEmpty) 'email': email,
            if (effectivePhone.isNotEmpty) 'phone': effectivePhone,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (linkErr) {
          debugPrint('[AUTH ROLE DEBUG] Error auto-linking admin doc: $linkErr');
        }

        return resolvedRole;
      }

      // 2a. Check by direct doc ID == uid
      final adminDocByUid =
          await firestore.collection('admins').doc(uid).get();
      if (adminDocByUid.exists && adminDocByUid.data() != null) {
        final data = adminDocByUid.data()!;
        final resolvedRole = await linkAdminMatch(data, uid);
        debugPrint(
            '[AUTH ROLE DEBUG] Admin lookup result: FOUND in admins collection by doc ID (docId: $uid, data: $data)');
        debugPrint('[AUTH ROLE DEBUG] Detected role: $resolvedRole');
        return resolvedRole;
      }

      // 2b. Check by `uid` field
      final adminQueryByUid = await firestore
          .collection('admins')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (adminQueryByUid.docs.isNotEmpty) {
        final doc = adminQueryByUid.docs.first;
        final data = doc.data();
        final resolvedRole = await linkAdminMatch(data, doc.id);
        debugPrint(
            '[AUTH ROLE DEBUG] Admin lookup result: FOUND in admins collection by uid field (docId: ${doc.id}, data: $data)');
        debugPrint('[AUTH ROLE DEBUG] Detected role: $resolvedRole');
        return resolvedRole;
      }

      // 2c. Check by phone field match (e.g. test_admin doc with phone: "+919999999999")
      if (phoneVariants.isNotEmpty) {
        final adminQueryByPhone = await firestore
            .collection('admins')
            .where('phone', whereIn: phoneVariants)
            .limit(1)
            .get();
        if (adminQueryByPhone.docs.isNotEmpty) {
          final doc = adminQueryByPhone.docs.first;
          final data = doc.data();
          final resolvedRole = await linkAdminMatch(data, doc.id);
          debugPrint(
              '[AUTH ROLE DEBUG] Admin lookup result: FOUND in admins collection by phone field match (docId: ${doc.id}, matchedPhone: ${data['phone']})');
          debugPrint('[AUTH ROLE DEBUG] Detected role: $resolvedRole');
          return resolvedRole;
        }

        // 2d. Check by doc ID == normalized phone
        if (normalizedPhone.isNotEmpty) {
          final adminDocByPhone = await firestore
              .collection('admins')
              .doc(normalizedPhone)
              .get();
          if (adminDocByPhone.exists && adminDocByPhone.data() != null) {
            final data = adminDocByPhone.data()!;
            final resolvedRole = await linkAdminMatch(data, adminDocByPhone.id);
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

    // 3. Check `delivery_agents` collection
    try {
      // 3a. Check by direct doc ID == uid
      final agentDocByUid =
          await firestore.collection('delivery_agents').doc(uid).get();
      if (agentDocByUid.exists && agentDocByUid.data() != null) {
        debugPrint(
            '[AUTH ROLE DEBUG] Admin lookup result: NOT admin. FOUND in delivery_agents by doc ID ($uid)');
        debugPrint('[AUTH ROLE DEBUG] Detected role: delivery');
        return UserRole.deliveryValue;
      }

      // 3b. Check by `uid` field
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

      // 3c. Check by phone field match
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

    // 4. Check `users` collection for role on users/{uid}
    try {
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final rawRole = data['role'] as String?;
        if (rawRole != null && rawRole.trim().isNotEmpty) {
          final cleanRole = UserRole.sanitize(rawRole);
          if (cleanRole != UserRole.customerValue) {
            debugPrint(
                '[AUTH ROLE DEBUG] Role lookup: Found privileged role in users/$uid with role=$rawRole (clean: $cleanRole)');
            debugPrint('[AUTH ROLE DEBUG] Detected role: $cleanRole');
            return cleanRole;
          }
        }
      }
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] User doc role lookup error: $e');
    }

    // 5. Self-Healing Orphaned Staff Document Migration:
    // If an orphaned staff document exists with this phone number (e.g. added via Add Staff before/after signup),
    // atomically copy its role, roleTitle, permissions, status to users/{uid} and safely delete the orphan.
    try {
      if (phoneVariants.isNotEmpty) {
        final staffQuery = await firestore
            .collection('users')
            .where('phone', whereIn: phoneVariants)
            .get();
        for (final sDoc in staffQuery.docs) {
          if (sDoc.id != uid) {
            final sData = sDoc.data();
            final sRoleRaw = sData['role'] as String?;
            if (sRoleRaw != null && sRoleRaw.trim().isNotEmpty) {
              final parsed = UserRole.fromString(sRoleRaw);
              if (parsed == UserRole.admin || parsed == UserRole.staff) {
                final cleanRole = UserRole.sanitize(sRoleRaw);
                final roleTitle = (sData['roleTitle'] as String?) ??
                    (cleanRole == 'dispatcher'
                        ? 'Route Dispatcher'
                        : (cleanRole == 'manager'
                            ? 'Operations Manager'
                            : (cleanRole == 'admin' ? 'Super Admin' : 'Staff Member')));
                final perms = sData['permissions'] is List
                    ? (sData['permissions'] as List)
                        .map((p) => p.toString().trim())
                        .where((p) => p.isNotEmpty)
                        .toList()
                    : <String>[];
                final status = (sData['status'] as String? ?? 'Active').trim();

                debugPrint(
                    '[AUTH ROLE DEBUG] Found orphaned staff doc ${sDoc.id} with role=$cleanRole. Migrating to auth user $uid...');

                await firestore.collection('users').doc(uid).set({
                  'role': cleanRole,
                  'roleTitle': roleTitle,
                  'permissions': perms,
                  'status': status,
                  'isAdmin': parsed == UserRole.admin,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                // Verify the primary doc was updated before removing the orphan
                final verifyDoc = await firestore.collection('users').doc(uid).get();
                if (verifyDoc.exists && verifyDoc.data()?['role'] == cleanRole) {
                  await firestore.collection('users').doc(sDoc.id).delete();
                  debugPrint(
                      '[AUTH ROLE DEBUG] Migration verified & orphaned doc ${sDoc.id} safely removed.');
                }

                return cleanRole;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] Orphaned staff doc migration error: $e');
    }

    // 6. Default: Standard customer
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

          final rawRole = data['role'] as String?;
          final cleanRole = (rawRole != null && rawRole.trim().isNotEmpty)
              ? UserRole.sanitize(rawRole)
              : UserRole.fromPhone(data['phone'] as String? ?? state.phone).value;

          final rawPermissions = data['permissions'];
          List<String> perms = [];
          if (rawPermissions is List) {
            perms = rawPermissions
                .map((p) => p.toString().trim())
                .where((p) => p.isNotEmpty)
                .toList();
          }

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
            role: cleanRole,
            roleTitle: data['roleTitle'] as String?,
            permissions: perms,
            status: (data['status'] as String? ?? 'Active').trim(),
          );

          if (updatedUser.profileImageUrl != currentImageUrl ||
              updatedUser.name != state.name ||
              updatedUser.phone != state.phone ||
              updatedUser.email != state.email ||
              updatedUser.role != state.role ||
              updatedUser.roleTitle != state.roleTitle ||
              updatedUser.permissions.length != state.permissions.length ||
              updatedUser.status != state.status) {
            state = updatedUser;
            notifyAuthStateChanged();
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString(_sessionKey, jsonEncode(updatedUser.toMap()));
            });
            debugPrint(
                '[PROFILE DEBUG T4] State updated by listener: role=${state.role}, roleTitle=${state.roleTitle}, perms=${state.permissions.length}, profileImageUrl=${state.profileImageUrl}');
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
              roleTitle: loadedUser.roleTitle,
              permissions: loadedUser.permissions,
              status: loadedUser.status,
            );
          }
        }

        state = loadedUser;
        debugPrint(
            '[PROFILE DEBUG] loadSession: restored User.fromMap role=${state.role}, roleTitle=${state.roleTitle}, phone=${state.phone}, profileImageUrl = ${state.profileImageUrl}');

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

          final rawPermissions = data['permissions'];
          List<String> perms = [];
          if (rawPermissions is List) {
            perms = rawPermissions
                .map((p) => p.toString().trim())
                .where((p) => p.isNotEmpty)
                .toList();
          }

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
            roleTitle: data['roleTitle'] as String?,
            permissions: perms,
            status: (data['status'] as String? ?? 'Active').trim(),
          );

          if (updatedUser.name != state.name ||
              updatedUser.phone != state.phone ||
              updatedUser.email != state.email ||
              updatedUser.profileImageUrl != state.profileImageUrl ||
              updatedUser.role != state.role ||
              updatedUser.roleTitle != state.roleTitle ||
              updatedUser.permissions.length != state.permissions.length ||
              updatedUser.status != state.status) {
            state = updatedUser;
            final prefs = await SharedPreferences.getInstance();
            final sessionJson = jsonEncode(state.toMap());
            await prefs.setString(_sessionKey, sessionJson);
            debugPrint(
                '[PROFILE DEBUG] _syncFromFirestore: state updated, role=${state.role}, perms=${state.permissions.length}');
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
            roleTitle: state.roleTitle,
            permissions: state.permissions,
            status: state.status,
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

        // Perform authoritative multi-source role resolution (admins, delivery_agents, users, orphaned staff)
        final resolvedRole = await _resolveAuthoritativeRole(
          uid: user.id,
          phone: user.phone,
          currentRole: doc.exists ? (doc.data()?['role'] as String?) : user.role,
        );

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final imageUrl = _extractProfileImageUrl(data);

            final rawPermissions = data['permissions'];
            List<String> perms = [];
            if (rawPermissions is List) {
              perms = rawPermissions
                  .map((p) => p.toString().trim())
                  .where((p) => p.isNotEmpty)
                  .toList();
            } else if (user.permissions.isNotEmpty) {
              perms = user.permissions;
            }

            final roleTitle = data['roleTitle'] as String? ?? user.roleTitle;
            final status = (data['status'] as String? ?? user.status).trim();

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
              roleTitle: roleTitle,
              permissions: perms,
              status: status,
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
            roleTitle: user.roleTitle,
            permissions: user.permissions,
            status: user.status,
          );
          await docRef.set({
            'uid': user.id,
            if (cleanName.isNotEmpty) 'name': cleanName,
            'phone': user.phone,
            'email': user.email,
            'profileImageUrl': user.profileImageUrl,
            'photoUrl': user.profileImageUrl,
            'role': resolvedRole,
            if (user.roleTitle != null) 'roleTitle': user.roleTitle,
            if (user.permissions.isNotEmpty) 'permissions': user.permissions,
            'status': user.status,
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
          roleTitle: user.roleTitle,
          permissions: user.permissions,
          status: user.status,
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
