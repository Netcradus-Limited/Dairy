import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

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

          final trustedRole = UserRole.sanitize(data['role'] as String?);

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
                '[PROFILE DEBUG T4] State updated by listener: profileImageUrl=${state.profileImageUrl}');
          } else {
            debugPrint(
                '[PROFILE DEBUG T4] No state change needed: profileImageUrl=${state.profileImageUrl}');
          }
        }
      } else {
        // Document deleted in Firestore: revoke privileged access immediately
        if (state.role != UserRole.customerValue) {
          state = User(
            id: state.id,
            name: state.name,
            phone: state.phone,
            email: state.email,
            profileImageUrl: state.profileImageUrl,
            role: UserRole.customerValue,
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
        state = User.fromMap(map);
        debugPrint(
            '[PROFILE DEBUG] loadSession: restored User.fromMap profileImageUrl = ${state.profileImageUrl}');

        // Sync authoritative role and profile in background & start real-time listener
        if (state.id.isNotEmpty) {
          _syncFromFirestore(state.id);
          _startUserDocListener(state.id);
        }
      }
    } catch (e) {
      // Fallback to guest user on error
      state = guestUser;
    }
    debugPrint(
        '[PROFILE DEBUG] loadSession: final profileImageUrl = ${state.profileImageUrl}');
    notifyAuthStateChanged();
  }

  Future<void> _syncFromFirestore(String uid) async {
    final firestore = _firestore;
    if (firestore == null) return;
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final imageUrl = _extractProfileImageUrl(data);
          final currentImageUrl = state.profileImageUrl;
          final effectiveImageUrl = (imageUrl != null && imageUrl.isNotEmpty)
              ? imageUrl
              : currentImageUrl;

          final trustedRole = UserRole.sanitize(data['role'] as String?);

          debugPrint(
              '[PROFILE DEBUG] _syncFromFirestore: uid=$uid, extracted imageUrl=$imageUrl, current=$currentImageUrl, resolved=$effectiveImageUrl');

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
        // Document deleted in Firestore: revoke privileged access immediately
        if (state.role != UserRole.customerValue) {
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
  /// The user's authoritative role is ALWAYS determined by the Firestore document.
  Future<void> setSession(User user) async {
    final firestore = _firestore;
    if (user.id.isNotEmpty && firestore != null) {
      try {
        final docRef = firestore.collection('users').doc(user.id);
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            // Read authoritative role from Firestore document
            final trustedRole = UserRole.sanitize(data['role'] as String?);
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
              role: trustedRole,
            );
          }
          await docRef.set({
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          // Self-registration: ALWAYS creates a standard Customer profile.
          // Elevated roles (admin / delivery) must be assigned in Firestore.
          const safeRole = UserRole.customerValue;
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
            role: safeRole,
          );
          await docRef.set({
            'uid': user.id,
            if (cleanName.isNotEmpty) 'name': cleanName,
            'phone': user.phone,
            'email': user.email,
            'profileImageUrl': user.profileImageUrl,
            'photoUrl': user.profileImageUrl,
            'role': safeRole,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[PROFILE DEBUG] setSession Firestore sync error: $e');
        // Fallback for offline - ensure user never gets elevated offline
        user = User(
          id: user.id,
          name: (user.name.trim() != 'Guest Customer' &&
                  user.name.trim() != 'Sawariya Customer')
              ? user.name.trim()
              : '',
          phone: user.phone,
          email: user.email,
          profileImageUrl: user.profileImageUrl,
          role: UserRole.sanitize(user.role),
        );
      }
    }

    state = user;
    notifyAuthStateChanged();
    if (user.id.isNotEmpty) {
      _startUserDocListener(user.id);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = jsonEncode(user.toMap());
      await prefs.setString(_sessionKey, sessionJson);
    } catch (_) {}
  }

  /// Clear session on Logout
  Future<void> clearSession() async {
    _userSubscription?.cancel();
    _userSubscription = null;
    state = guestUser;
    notifyAuthStateChanged();
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
