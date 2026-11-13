import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb show FirebaseAuth, User;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../core/auth/app_role.dart';
import '../core/router/auth_refresh.dart';
import '../models/user.dart';
import '../core/constants/fcm_constants.dart';
import '../firebase_options.dart';

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

/// Outcome of authoritative role resolution.
///
/// [userDoc] is the `users/{uid}` snapshot fetched during resolution. It is
/// only populated when resolution performed NO linking/migration writes, so it
/// is safe to reuse instead of re-reading the same document.
class _RoleResolution {
  final String role;
  const _RoleResolution(this.role);
}

/// Current user profile state notifier that supports SharedPreferences persistence and Firestore sync.
class UserNotifier extends StateNotifier<User> {
  static const String _sessionKey = 'user_session';
  bool _isRoleServerVerified = false;
  bool get isRoleServerVerified => _isRoleServerVerified;
  StreamSubscription? _roleDocSubscription;

  void _startRoleDocListener(String uid, String role) {
    _roleDocSubscription?.cancel();
    final firestore = _firestore;
    if (firestore == null || uid.isEmpty) return;

    final isStaffRole = UserRole.fromString(role).canAccessAdminPortal;
    final isDeliveryRole = UserRole.fromString(role).isDelivery;
    if (!isStaffRole && !isDeliveryRole) return;

    final targetCollection = isStaffRole ? 'admins' : 'delivery_agents';
    _roleDocSubscription = firestore
        .collection(targetCollection)
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        debugPrint(
            '[AUTH SECURITY] Authoritative role document at $targetCollection/$uid deleted or missing. Demoting session to customer.');
        _handleRoleRevocation();
        return;
      }
      final data = snapshot.data();
      if (data == null) {
        _handleRoleRevocation();
        return;
      }
      final status = (data['status'] as String? ?? 'Active').trim();
      if (status.toLowerCase() != 'active') {
        debugPrint(
            '[AUTH SECURITY] Authoritative role document status is "$status". Demoting session to customer.');
        _handleRoleRevocation();
        return;
      }
      if (isStaffRole) {
        final docRole =
            (data['role'] as String? ?? 'staff').trim().toLowerCase();
        final rawPerms = data['permissions'];
        final perms = (rawPerms is List)
            ? rawPerms.map((p) => p.toString().trim()).toList()
            : state.permissions;
        if (docRole != state.role || perms.length != state.permissions.length) {
          state = state.copyWith(
            role: docRole,
            roleTitle: data['roleTitle'] as String? ?? state.roleTitle,
            permissions: perms,
            isRoleServerVerified: true,
          );
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString(_sessionKey, jsonEncode(state.toMap()));
          });
          notifyAuthStateChanged();
        }
      }
    }, onError: (err) {
      debugPrint(
          '[AUTH SECURITY] Error listening to authoritative $targetCollection/$uid: $err. Demoting to unverified customer.');
      _handleRoleRevocation();
    });
  }

  void _handleRoleRevocation() {
    _roleDocSubscription?.cancel();
    _roleDocSubscription = null;
    _isRoleServerVerified = false;
    state = state.copyWith(
      role: UserRole.customerValue,
      roleTitle: null,
      permissions: const [],
      isRoleServerVerified: false,
    );
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_sessionKey, jsonEncode(state.toMap()));
    });
    notifyAuthStateChanged();
  }

  static const String productionFirebaseProjectId = 'sawariya-7efd4';
  static const String qaFirebaseProjectId = 'sawariya-dairy-qa';

  static String resolveFunctionsProjectId({
    String? projectIdOverride,
    bool? isQaOverride,
    String Function()? activeProjectIdProvider,
  }) {
    final bool isQa = isQaOverride ?? DefaultFirebaseOptions.isQaFirebase;
    final String expectedProjectId =
        isQa ? qaFirebaseProjectId : productionFirebaseProjectId;

    final String rawProjectId;
    if (projectIdOverride != null) {
      rawProjectId = projectIdOverride;
    } else {
      try {
        rawProjectId = activeProjectIdProvider != null
            ? activeProjectIdProvider()
            : Firebase.app().options.projectId;
      } catch (e) {
        throw StateError(
          'Cannot resolve Cloud Functions project ID: Firebase app is unavailable or not initialized ($e).',
        );
      }
    }

    final String projectId = rawProjectId.trim();
    if (projectId.isEmpty) {
      throw StateError(
        'Cannot resolve Cloud Functions project ID: active Firebase projectId is empty.',
      );
    }

    if (projectId != expectedProjectId) {
      throw StateError(
        'Cannot resolve Cloud Functions project ID: active project "$projectId" '
        'does not match expected ${isQa ? "QA" : "production"} project "$expectedProjectId".',
      );
    }

    return projectId;
  }

  static Uri buildCallableLinkingUri(
    String functionName, {
    String? projectIdOverride,
    bool? isQaOverride,
    String Function()? activeProjectIdProvider,
  }) {
    final String cleanFunctionName = functionName.trim();
    if (cleanFunctionName.isEmpty) {
      throw StateError(
        'Cannot build Cloud Functions URI: functionName is empty.',
      );
    }

    final String projectId = resolveFunctionsProjectId(
      projectIdOverride: projectIdOverride,
      isQaOverride: isQaOverride,
      activeProjectIdProvider: activeProjectIdProvider,
    );
    return Uri.parse(
        'https://asia-south2-$projectId.cloudfunctions.net/$cleanFunctionName');
  }

  Future<Map<String, dynamic>?> _invokeCallableLinking(
      String functionName) async {
    try {
      final fbUser = _auth?.currentUser;
      if (fbUser == null) return null;
      final idToken = await fbUser.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      final url = buildCallableLinkingUri(functionName);
      final resp = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'data': {}}),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['result'] as Map<String, dynamic>?;
        }
      } else {
        debugPrint(
            '[AUTH SECURITY] Callable $functionName returned status ${resp.statusCode}: ${resp.body}');
      }
    } on StateError catch (e) {
      debugPrint(
          '[AUTH SECURITY] Callable $functionName blocked due to invalid Firebase configuration: $e');
      rethrow;
    } catch (e) {
      debugPrint('[AUTH SECURITY] Callable $functionName error: $e');
    }
    return null;
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  fb.FirebaseAuth? get _auth {
    try {
      return fb.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  StreamSubscription<fb.User?>? _authSubscription;
  Future<_RoleResolution>? _inFlightRoleResolution;
  String? _inFlightRoleResolutionUid;
  static const Duration _roleLookupTimeout = Duration(seconds: 7);

  final Completer<void> _sessionLoadedCompleter = Completer<void>();

  /// Future that completes when the initial session has been read from local storage.
  Future<void> get sessionLoaded => _sessionLoadedCompleter.future;

  /// Whether the initial session has finished loading.
  bool get isSessionLoaded => _sessionLoadedCompleter.isCompleted;

  UserNotifier() : super(guestUser) {
    _initAuthListener();
    loadSession();
    debugPrint(
        '[PROFILE DEBUG T0] UserNotifier initialized, initial state.profileImageUrl: ${state.profileImageUrl}');
  }

  void _initAuthListener() {
    try {
      _authSubscription = _auth?.idTokenChanges().listen((fbUser) {
        if (fbUser == null && state.id.isNotEmpty && state != guestUser) {
          debugPrint(
              '[AUTH RECOVERY] Firebase idToken is null (session expired, revoked, or signed out). Resetting session to guest.');
          clearSession();
        }
      }, onError: (err) {
        debugPrint('[AUTH RECOVERY] Auth state listener error: $err');
      });
    } catch (e) {
      debugPrint('[AUTH RECOVERY] Could not attach auth listener: $e');
    }
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
    DocumentSnapshot<Map<String, dynamic>>? prefetchedUserDoc,
  }) async {
    final resolution = await _resolveAuthoritativeRoleDetailed(
      uid: uid,
      phone: phone,
      currentRole: currentRole,
      prefetchedUserDoc: prefetchedUserDoc,
    );
    return resolution.role;
  }

  /// Same resolution as [_resolveAuthoritativeRole], additionally returning the
  /// `users/{uid}` snapshot when it can be safely reused.
  ///
  /// All independent lookups are started concurrently (one network round trip
  /// instead of ~10 sequential ones), but results are evaluated in the exact
  /// same priority order as before, and linking writes are only performed for
  /// the winning match.
  Future<_RoleResolution> _resolveAuthoritativeRoleDetailed({
    required String uid,
    String? phone,
    String? currentRole,
    DocumentSnapshot<Map<String, dynamic>>? prefetchedUserDoc,
  }) async {
    // Deduplication guard: prevent redundant concurrent role queries for the same UID
    if (_inFlightRoleResolution != null && _inFlightRoleResolutionUid == uid) {
      debugPrint(
          '[AUTH ROLE DEBUG] Reusing in-flight role resolution for UID: $uid');
      return _inFlightRoleResolution!;
    }

    final future = _executeRoleResolution(
      uid: uid,
      phone: phone,
      currentRole: currentRole,
      prefetchedUserDoc: prefetchedUserDoc,
    );
    _inFlightRoleResolution = future;
    _inFlightRoleResolutionUid = uid;

    try {
      return await future.timeout(_roleLookupTimeout);
    } on TimeoutException catch (e) {
      debugPrint(
          '[AUTH ROLE DEBUG] Role lookup timed out after ${_roleLookupTimeout.inSeconds}s ($e). Failing closed.');
      final isPredefined =
          UserRole.fromPhone(phone ?? '').value != UserRole.customerValue;
      final safeRole = isPredefined
          ? UserRole.fromPhone(phone ?? '').value
          : UserRole.customerValue;
      return _RoleResolution(safeRole);
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] Role lookup error: $e. Failing closed.');
      final isPredefined =
          UserRole.fromPhone(phone ?? '').value != UserRole.customerValue;
      final safeRole = isPredefined
          ? UserRole.fromPhone(phone ?? '').value
          : UserRole.customerValue;
      return _RoleResolution(safeRole);
    } finally {
      if (_inFlightRoleResolution == future) {
        _inFlightRoleResolution = null;
        _inFlightRoleResolutionUid = null;
      }
    }
  }

  Future<_RoleResolution> _executeRoleResolution({
    required String uid,
    String? phone,
    String? currentRole,
    DocumentSnapshot<Map<String, dynamic>>? prefetchedUserDoc,
  }) async {
    final firestore = _firestore;
    final fbUser = _auth?.currentUser;
    final verifiedPhone = (fbUser?.phoneNumber ?? '').trim();

    // Zero-Trust Security Requirement: Never trust caller-supplied phone numbers for privileged decisions.
    // If no verified phone number exists in active Firebase Auth session, fail closed to customer.
    if (verifiedPhone.isEmpty) {
      debugPrint(
          '[AUTH SECURITY] No verified Firebase Auth phone number found. Failing closed to customer.');
      return const _RoleResolution(UserRole.customerValue);
    }

    if (firestore == null || uid.isEmpty) {
      debugPrint(
          '[AUTH ROLE DEBUG] Firestore unavailable or empty UID. Failing closed to: customer');
      return const _RoleResolution(UserRole.customerValue);
    }

    debugPrint(
        '[AUTH ROLE DEBUG] Authoritative resolution: UID=$uid, verifiedPhone=$verifiedPhone');

    // 1. Authoritative check on /admins collection by UID (Direct Read-Only)
    try {
      final adminDoc = await firestore.collection('admins').doc(uid).get();
      if (adminDoc.exists && adminDoc.data() != null) {
        final data = adminDoc.data()!;
        final status = (data['status'] as String? ?? 'Active').trim();
        if (status.toLowerCase() == 'active') {
          final rawRole = (data['role'] as String?)?.trim() ?? 'admin';
          final resolvedRole = UserRole.sanitize(rawRole);
          debugPrint(
              '[AUTH ROLE DEBUG] Authoritative Admin verified by UID ($uid, role: $resolvedRole)');
          return _RoleResolution(resolvedRole);
        }
      }
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] admins/$uid lookup error: $e');
    }

    // 2. Authoritative check on /delivery_agents collection by UID (Direct Read-Only)
    try {
      final agentDoc =
          await firestore.collection('delivery_agents').doc(uid).get();
      if (agentDoc.exists && agentDoc.data() != null) {
        final data = agentDoc.data()!;
        final status = (data['status'] as String? ?? 'Active').trim();
        if (status.toLowerCase() == 'active') {
          debugPrint(
              '[AUTH ROLE DEBUG] Authoritative Delivery Partner verified by UID ($uid)');
          return const _RoleResolution(UserRole.deliveryValue);
        }
      }
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] delivery_agents/$uid lookup error: $e');
    }

    // 3. First-time account linking via trusted Cloud Functions
    // Flutter client does NOT write directly to admins/delivery_agents collections.
    try {
      debugPrint(
          '[AUTH ROLE DEBUG] Invoking backend linkStaffAccount for UID $uid...');
      final staffLinking = await _invokeCallableLinking('linkStaffAccount');
      if (staffLinking != null) {
        final linkStatus = staffLinking['status'] as String?;
        if (linkStatus == 'linked' || linkStatus == 'already_linked') {
          final rawRole = staffLinking['role'] as String? ?? 'staff';
          final resolvedRole = UserRole.sanitize(rawRole);
          debugPrint(
              '[AUTH ROLE DEBUG] Backend linked staff account successfully: role=$resolvedRole');
          return _RoleResolution(resolvedRole);
        }
      }
    } catch (e) {
      debugPrint('[AUTH ROLE DEBUG] linkStaffAccount callable error: $e');
    }

    try {
      debugPrint(
          '[AUTH ROLE DEBUG] Invoking backend linkDeliveryAgentAccount for UID $uid...');
      final deliveryLinking =
          await _invokeCallableLinking('linkDeliveryAgentAccount');
      if (deliveryLinking != null) {
        final linkStatus = deliveryLinking['status'] as String?;
        if (linkStatus == 'linked' || linkStatus == 'already_linked') {
          debugPrint(
              '[AUTH ROLE DEBUG] Backend linked delivery partner account successfully');
          return const _RoleResolution(UserRole.deliveryValue);
        }
      }
    } catch (e) {
      debugPrint(
          '[AUTH ROLE DEBUG] linkDeliveryAgentAccount callable error: $e');
    }

    // 4. Default: Standard customer (Fail-closed)
    debugPrint(
        '[AUTH ROLE DEBUG] No privileged record verified. Failing closed to standard customer.');
    return const _RoleResolution(UserRole.customerValue);
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
              : UserRole.fromPhone(data['phone'] as String? ?? state.phone)
                  .value;

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
            isRoleServerVerified: true,
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

        // Authenticated UID verification: validate cached session against active Firebase Auth UID
        final currentFbUser = _auth?.currentUser;
        if (currentFbUser == null || currentFbUser.uid != loadedUser.id) {
          debugPrint(
              '[AUTH SECURITY] Cached user session ID ("${loadedUser.id}") does not match active Firebase Auth UID ("${currentFbUser?.uid}"). Clearing session to guest.');
          await clearSession();
          return;
        }

        // Cached sessions remain strictly unverified customer state until authoritative server sync completes
        loadedUser = loadedUser.copyWith(
          role: UserRole.customerValue,
          isRoleServerVerified: false,
        );

        state = loadedUser;
        debugPrint(
            '[PROFILE DEBUG] loadSession: restored User.fromMap unverified customer role=${state.role}, phone=${state.phone}');

        // Sync authoritative role and profile in background & start real-time listener
        if (state.id.isNotEmpty) {
          _syncFromFirestore(state.id);
          _startUserDocListener(state.id);
          // FCM token registration is deferred until after the first frame so
          // getToken() (service worker / VAPID on web) never competes with the
          // first visible screen. FcmService/NotificationService also register
          // the token post-frame; this remains as a best-effort safety net.
          _scheduleDeferredFcmTokenSync(state.id);
        }
      }
    } catch (e) {
      // Fallback to guest user on error
      state = guestUser;
    } finally {
      if (!_sessionLoadedCompleter.isCompleted) {
        _sessionLoadedCompleter.complete();
      }
    }
    debugPrint(
        '[PROFILE DEBUG] loadSession: final role=${state.role}, profileImageUrl = ${state.profileImageUrl}');
    notifyAuthStateChanged();
  }

  Future<void> _syncFromFirestore(String uid) async {
    final firestore = _firestore;
    if (firestore == null) return;
    try {
      final resolution = await _resolveAuthoritativeRoleDetailed(
        uid: uid,
        phone: state.phone,
        currentRole: state.role,
      );
      final resolvedRole = resolution.role;
      _isRoleServerVerified = true;

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
        _startRoleDocListener(uid, resolvedRole);
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
          currentRole:
              doc.exists ? (doc.data()?['role'] as String?) : user.role,
          prefetchedUserDoc: doc,
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

            final cleanName =
                (data['name'] as String?)?.trim().isNotEmpty == true
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
          debugPrint(
              '[AUTH TRACE] users/${user.id} does not exist. Checking for pre-registered data via phone...');
          final phoneVariants = PhoneAuthUtils.generateVariants(user.phone);
          Map<String, dynamic>? existingData;
          String? sourceDocPath;

          // Check if an existing pre-registered document in users exists with this phone
          if (phoneVariants.isNotEmpty) {
            final userQuery = await firestore
                .collection('users')
                .where('phone', whereIn: phoneVariants)
                .limit(1)
                .get();
            if (userQuery.docs.isNotEmpty) {
              final doc = userQuery.docs.first;
              if (doc.id != user.id) {
                existingData = doc.data();
                sourceDocPath = doc.reference.path;
              }
            }
          }

          // If not in users, check delivery_agents
          if (existingData == null && phoneVariants.isNotEmpty) {
            final agentQuery = await firestore
                .collection('delivery_agents')
                .where('phone', whereIn: phoneVariants)
                .limit(1)
                .get();
            if (agentQuery.docs.isNotEmpty) {
              final doc = agentQuery.docs.first;
              existingData = doc.data();
              sourceDocPath = doc.reference.path;
            }
          }

          if (existingData != null) {
            debugPrint(
                '[AUTH TRACE] users/${user.id} was missing, but found existing pre-registered document at $sourceDocPath with data: $existingData. Linking to auth UID ${user.id} without creating duplicate account.');

            final existingName =
                (existingData['name'] as String?)?.trim() ?? '';
            final existingEmail =
                (existingData['email'] as String?)?.trim() ?? '';
            final existingPhone =
                (existingData['phone'] as String?)?.trim() ?? user.phone;
            final existingRole =
                (existingData['role'] as String?)?.trim() ?? resolvedRole;
            final cleanRole = UserRole.sanitize(existingRole);
            final roleTitle =
                existingData['roleTitle'] as String? ?? user.roleTitle;
            final status =
                (existingData['status'] as String? ?? user.status).trim();
            final existingImageUrl =
                _extractProfileImageUrl(existingData) ?? user.profileImageUrl;
            final vehicle = ((existingData['vehicle'] ??
                        existingData['vehicleType']) as String?)
                    ?.trim() ??
                '';
            final vehicleNumber =
                (existingData['vehicleNumber'] as String?)?.trim() ?? '';
            final assignedZone = ((existingData['assignedZone'] ??
                        existingData['zone']) as String?)
                    ?.trim() ??
                '';
            final rating = (existingData['rating'] as num?)?.toDouble();

            user = User(
              id: user.id,
              name: existingName.isNotEmpty ? existingName : user.name,
              phone: existingPhone,
              email: existingEmail.isNotEmpty ? existingEmail : user.email,
              profileImageUrl: existingImageUrl,
              role: cleanRole,
              roleTitle: roleTitle,
              permissions: existingData['permissions'] is List
                  ? (existingData['permissions'] as List)
                      .map((p) => p.toString().trim())
                      .toList()
                  : user.permissions,
              status: status,
            );

            await docRef.set({
              'uid': user.id,
              if (user.name.isNotEmpty) 'name': user.name,
              'phone': user.phone,
              if (user.email != null && user.email!.isNotEmpty)
                'email': user.email!,
              if (user.profileImageUrl != null) ...{
                'profileImageUrl': user.profileImageUrl,
                'photoUrl': user.profileImageUrl,
              },
              'role': cleanRole,
              if (user.roleTitle != null) 'roleTitle': user.roleTitle,
              if (user.permissions.isNotEmpty) 'permissions': user.permissions,
              'status': user.status,
              if (vehicle.isNotEmpty) 'vehicle': vehicle,
              if (vehicleNumber.isNotEmpty) 'vehicleNumber': vehicleNumber,
              if (assignedZone.isNotEmpty) 'assignedZone': assignedZone,
              if (rating != null) 'rating': rating,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

// Direct client writes to delivery_agents removed per zero-trust architecture
          } else {
            debugPrint(
                '[AUTH TRACE] users/${user.id} missing and no pre-registered document found for phone ${user.phone}. Registering new customer record for auth UID ${user.id}.');

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

  /// Runs [_syncFcmToken] after the next frame has been rendered, and only if
  /// the same user is still signed in at that point.
  void _scheduleDeferredFcmTokenSync(String uid) {
    if (uid.isEmpty) return;
    void run() {
      if (mounted && state.id == uid) {
        _syncFcmToken(uid);
      }
    }

    try {
      SchedulerBinding.instance.endOfFrame.then((_) => run());
    } catch (_) {
      // Binding unavailable (e.g. pure unit tests): fall back to async.
      Future<void>.delayed(Duration.zero, run);
    }
  }

  /// Synchronizes FCM token with user profile in Firestore
  Future<void> _syncFcmToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? webVapidPublicKey : null,
      );
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
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? webVapidPublicKey : null,
      );
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
    _roleDocSubscription?.cancel();
    _roleDocSubscription = null;
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
      name: (trimmedName != null && trimmedName.isNotEmpty)
          ? trimmedName
          : state.name,
      phone: (trimmedPhone != null && trimmedPhone.isNotEmpty)
          ? trimmedPhone
          : state.phone,
      email: (trimmedEmail != null && trimmedEmail.isNotEmpty)
          ? trimmedEmail
          : state.email,
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
        if (trimmedPhone != null && trimmedPhone.isNotEmpty)
          'phone': trimmedPhone,
        if (trimmedEmail != null && trimmedEmail.isNotEmpty)
          'email': trimmedEmail,
        if (trimmedVehicle != null && trimmedVehicle.isNotEmpty)
          'vehicle': trimmedVehicle,
        if (trimmedVehicleType != null && trimmedVehicleType.isNotEmpty)
          'vehicleType': trimmedVehicleType,
        if (trimmedVehicleNum != null && trimmedVehicleNum.isNotEmpty)
          'vehicleNumber': trimmedVehicleNum,
        if (trimmedZone != null && trimmedZone.isNotEmpty)
          'assignedZone': trimmedZone,
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
    _authSubscription?.cancel();
    _roleDocSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }
}

final userProvider = StateNotifierProvider<UserNotifier, User>((ref) {
  return UserNotifier();
});
