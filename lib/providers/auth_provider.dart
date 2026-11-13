import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/app_role.dart';
import '../models/user.dart';
import 'user_provider.dart';

/// Provider for FirebaseAuth instance
final firebaseAuthProvider = Provider<fb.FirebaseAuth>(
  (ref) => fb.FirebaseAuth.instance,
);

/// State containing status of the auth requests
class AuthState {
  final AsyncValue<void> status;
  final String? mobileNumber;
  final String? tempFullName;
  final bool isSignUpFlow;
  final String? verificationId;
  final int? resendToken;
  final bool isAutoVerified;
  final String? lastFirebaseErrorCode;
  final String? lastFirebaseErrorMessage;
  final int activeRequestId;

  AuthState({
    required this.status,
    this.mobileNumber,
    this.tempFullName,
    this.isSignUpFlow = false,
    this.verificationId,
    this.resendToken,
    this.isAutoVerified = false,
    this.lastFirebaseErrorCode,
    this.lastFirebaseErrorMessage,
    this.activeRequestId = 0,
  });

  bool get isLoading => status.isLoading;

  /// Whether there is an active Firebase verification session available for OTP submission.
  bool get hasActiveSession =>
      (verificationId != null && verificationId!.isNotEmpty) ||
      (kIsWeb && status.hasValue);

  AuthState copyWith({
    AsyncValue<void>? status,
    String? mobileNumber,
    String? tempFullName,
    bool? isSignUpFlow,
    String? verificationId,
    bool clearVerificationId = false,
    int? resendToken,
    bool clearResendToken = false,
    bool? isAutoVerified,
    String? lastFirebaseErrorCode,
    bool clearErrorCode = false,
    String? lastFirebaseErrorMessage,
    bool clearErrorMessage = false,
    int? activeRequestId,
  }) {
    return AuthState(
      status: status ?? this.status,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      tempFullName: tempFullName ?? this.tempFullName,
      isSignUpFlow: isSignUpFlow ?? this.isSignUpFlow,
      verificationId:
          clearVerificationId ? null : (verificationId ?? this.verificationId),
      resendToken: clearResendToken ? null : (resendToken ?? this.resendToken),
      isAutoVerified: isAutoVerified ?? this.isAutoVerified,
      lastFirebaseErrorCode: clearErrorCode
          ? null
          : (lastFirebaseErrorCode ?? this.lastFirebaseErrorCode),
      lastFirebaseErrorMessage: clearErrorMessage
          ? null
          : (lastFirebaseErrorMessage ?? this.lastFirebaseErrorMessage),
      activeRequestId: activeRequestId ?? this.activeRequestId,
    );
  }
}

/// Auth State Notifier for managing Firebase Phone Auth
class AuthNotifier extends StateNotifier<AuthState> {
  final fb.FirebaseAuth _auth;
  final Ref _ref;
  String? _verificationId;
  int? _resendToken;
  fb.ConfirmationResult? _webConfirmationResult;
  int _activeRequestId = 0;

  AuthNotifier(this._auth, this._ref)
      : super(AuthState(status: const AsyncData(null)));

  static String formatE164(String input) {
    String cleaned = input.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length == 10) {
      return '+91$cleaned';
    }
    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      return '+$cleaned';
    }
    return '+$cleaned';
  }

  /// Masks verification identifiers for safe debug logging without exposing credentials
  static String _maskId(String? id) {
    if (id == null) return 'null';
    if (id.length <= 8) return '***';
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  /// Helper to get current ISO timestamp
  static String _now() => DateTime.now().toIso8601String();

  /// Maps Firebase exceptions to clear user messages that include the actual error code.
  String _mapFirebaseAuthErrorMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The provided phone number is not valid (${e.code}).';
      case 'too-many-requests':
        return 'Too many requests (${e.code}). Please wait a moment and try again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded (${e.code}). Please try again later.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed (${e.code}). Please try again.';
      case 'invalid-app-credential':
        return 'App verification failed (${e.code}). Please check internet connection and Google Play Services.';
      case 'app-not-authorized':
        return 'App is not authorized to use Firebase Authentication (${e.code}). Check SHA certificate configuration.';
      case 'invalid-verification-code':
        return 'Invalid OTP entered (${e.code}). Please check the code and try again.';
      case 'invalid-verification-id':
        return 'Verification session is invalid (${e.code}). Please tap "Resend OTP" to request a new code.';
      case 'session-expired':
        return 'Verification session has expired (${e.code}). Please tap "Resend OTP" to request a new code.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled for this project (${e.code}).';
      default:
        final rawMsg = e.message;
        if (rawMsg != null && rawMsg.trim().isNotEmpty) {
          return '$rawMsg (${e.code})';
        }
        return 'Authentication error (${e.code}). Please try again.';
    }
  }

  bool _isCompletingSession = false;

  /// Completes session persistence in UserNotifier and resets temporary state.
  Future<bool> _completeUserSession(fb.User firebaseUser,
      {required int requestId}) async {
    if (_isCompletingSession) {
      debugPrint(
          '[AUTH][${_now()}][req_$requestId] _completeUserSession already in progress. Skipping duplicate invocation.');
      return true;
    }
    _isCompletingSession = true;
    try {
      final now = _now();
      final mobile =
          (state.mobileNumber != null && state.mobileNumber!.trim().isNotEmpty)
              ? state.mobileNumber!.trim()
              : (firebaseUser.phoneNumber ?? '');
      final verifiedMobile = (firebaseUser.phoneNumber != null &&
              firebaseUser.phoneNumber!.trim().isNotEmpty)
          ? firebaseUser.phoneNumber!.trim()
          : mobile;
      // ZERO-TRUST RULE (BUG-004): Default to customer initially; never grant privileged access from client phone string.
      const detectedRole = UserRole.customerValue;

      debugPrint(
          '[AUTH][$now][req_$requestId] Completing user session. UID=${firebaseUser.uid}, detectedRole=$detectedRole');

      final fullName =
          (state.tempFullName != null && state.tempFullName!.trim().isNotEmpty)
              ? state.tempFullName!.trim()
              : (detectedRole == 'admin'
                  ? 'Sawariya Admin'
                  : (detectedRole == 'delivery'
                      ? 'Delivery Partner'
                      : 'Sawariya Customer'));

      final user = User(
        id: firebaseUser.uid,
        name: fullName,
        phone: verifiedMobile,
        email: firebaseUser.email?.isNotEmpty == true
            ? firebaseUser.email!
            : (detectedRole == 'admin' ? 'admin@sawariyadairy.com' : ''),
        role: detectedRole,
      );

      await _ref.read(userProvider.notifier).setSession(user);

      _verificationId = null;
      _webConfirmationResult = null;
      _resendToken = null;

      state = state.copyWith(
        status: const AsyncData(null),
        isAutoVerified: true,
        clearVerificationId: true,
        clearResendToken: true,
        clearErrorCode: true,
        clearErrorMessage: true,
      );
      return true;
    } finally {
      _isCompletingSession = false;
    }
  }

  /// Internal unified dispatcher for requesting Firebase OTP.
  Future<bool> _requestFirebaseOtp(
    String mobileNumber, {
    String? fullName,
    required bool isSignUp,
    bool isResend = false,
  }) async {
    final int requestId = ++_activeRequestId;
    final now = _now();

    state = state.copyWith(
      status: const AsyncLoading(),
      mobileNumber: mobileNumber,
      tempFullName: fullName,
      isSignUpFlow: isSignUp,
      clearErrorCode: true,
      clearErrorMessage: true,
      isAutoVerified: false,
      clearVerificationId: isResend,
      activeRequestId: requestId,
    );

    final formattedPhone = formatE164(mobileNumber);
    debugPrint(
        '[AUTH][$now][req_$requestId] OTP request dispatched. Platform: ${kIsWeb ? "Web" : "Native"}, isSignUp: $isSignUp, isResend: $isResend');

    if (kIsWeb) {
      _webConfirmationResult = null;
      try {
        final confirmationResult =
            await _auth.signInWithPhoneNumber(formattedPhone);
        if (requestId != _activeRequestId) {
          debugPrint(
              '[AUTH][${_now()}][req_$requestId] Discarded web confirmation result because a newer request (req_$_activeRequestId) is active.');
          return false;
        }
        _webConfirmationResult = confirmationResult;
        state = state.copyWith(status: const AsyncData(null));
        debugPrint(
            '[AUTH][${_now()}][req_$requestId] Web reCAPTCHA and OTP request succeeded.');
        return true;
      } on fb.FirebaseAuthException catch (e, st) {
        if (requestId != _activeRequestId) return false;
        _webConfirmationResult = null;
        debugPrint(
            '[AUTH][${_now()}][req_$requestId] Web OTP request failed: code=${e.code}');
        final userFriendlyMsg = _mapFirebaseAuthErrorMessage(e);
        state = state.copyWith(
          status: AsyncError(Exception(userFriendlyMsg), st),
          lastFirebaseErrorCode: e.code,
          lastFirebaseErrorMessage: e.message ?? userFriendlyMsg,
        );
        return false;
      } catch (e, st) {
        if (requestId != _activeRequestId) return false;
        _webConfirmationResult = null;
        debugPrint(
            '[AUTH][${_now()}][req_$requestId] Web OTP request unexpected error: $e');
        state = state.copyWith(status: AsyncError(e, st));
        return false;
      }
    } else {
      // Native Android / iOS flow
      if (isResend) {
        _verificationId = null;
      }
      final completer = Completer<bool>();
      debugPrint(
          '[AUTH][$now][req_$requestId] Calling verifyPhoneNumber: timeout=60s, forceResendingTokenPresent=${_resendToken != null}');

      try {
        await _auth.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          timeout: const Duration(seconds: 60),
          forceResendingToken: _resendToken,
          verificationCompleted: (fb.PhoneAuthCredential credential) async {
            final cbTime = _now();
            if (requestId != _activeRequestId) {
              debugPrint(
                  '[AUTH][$cbTime][req_$requestId] Ignored stale verificationCompleted (current active: req_$_activeRequestId).');
              return;
            }
            debugPrint(
                '[AUTH][$cbTime][req_$requestId] verificationCompleted callback: automatic SMS detection triggered by OS.');
            try {
              final userCredential =
                  await _auth.signInWithCredential(credential);
              final fbUser = userCredential.user;
              if (fbUser != null) {
                await _completeUserSession(fbUser, requestId: requestId);
              }
              if (!completer.isCompleted) completer.complete(true);
            } catch (e) {
              debugPrint(
                  '[AUTH][${_now()}][req_$requestId] verificationCompleted: auto-signin failed: $e');
              if (!completer.isCompleted) completer.complete(false);
            }
          },
          verificationFailed: (fb.FirebaseAuthException e) {
            final cbTime = _now();
            if (requestId != _activeRequestId) {
              debugPrint(
                  '[AUTH][$cbTime][req_$requestId] Ignored stale verificationFailed callback (current active: req_$_activeRequestId).');
              return;
            }
            debugPrint(
                '[AUTH][$cbTime][req_$requestId] verificationFailed callback: code=${e.code}, message=${e.message}');
            final userFriendlyMsg = _mapFirebaseAuthErrorMessage(e);
            state = state.copyWith(
              status: AsyncError(
                Exception(userFriendlyMsg),
                StackTrace.current,
              ),
              lastFirebaseErrorCode: e.code,
              lastFirebaseErrorMessage: e.message ?? userFriendlyMsg,
            );
            if (!completer.isCompleted) completer.complete(false);
          },
          codeSent: (String verificationId, int? resendToken) {
            final cbTime = _now();
            if (requestId != _activeRequestId) {
              debugPrint(
                  '[AUTH][$cbTime][req_$requestId] Ignored stale codeSent callback (current active: req_$_activeRequestId).');
              return;
            }
            debugPrint(
                '[AUTH][$cbTime][req_$requestId] codeSent callback: verificationId=${_maskId(verificationId)}, resendTokenPresent=${resendToken != null}');
            _verificationId = verificationId;
            _resendToken = resendToken;
            state = state.copyWith(
              status: const AsyncData(null),
              verificationId: verificationId,
              resendToken: resendToken,
              clearErrorCode: true,
              clearErrorMessage: true,
            );
            if (!completer.isCompleted) completer.complete(true);
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            final cbTime = _now();
            if (requestId != _activeRequestId) {
              debugPrint(
                  '[AUTH][$cbTime][req_$requestId] Ignored stale codeAutoRetrievalTimeout (current active: req_$_activeRequestId).');
              return;
            }
            debugPrint(
                '[AUTH][$cbTime][req_$requestId] codeAutoRetrievalTimeout callback: SMS auto-retrieval window ended, verificationId=${_maskId(verificationId)}');
            if (verificationId.isNotEmpty) {
              _verificationId = verificationId;
              state = state.copyWith(verificationId: verificationId);
            }
          },
        );
        return await completer.future;
      } on fb.FirebaseAuthException catch (e, st) {
        if (requestId != _activeRequestId) return false;
        debugPrint(
            '[AUTH][${_now()}][req_$requestId] verifyPhoneNumber synchronous exception: code=${e.code}, message=${e.message}');
        final userFriendlyMsg = _mapFirebaseAuthErrorMessage(e);
        state = state.copyWith(
          status: AsyncError(Exception(userFriendlyMsg), st),
          lastFirebaseErrorCode: e.code,
          lastFirebaseErrorMessage: e.message ?? userFriendlyMsg,
        );
        return false;
      } catch (e, st) {
        if (requestId != _activeRequestId) return false;
        debugPrint(
            '[AUTH][${_now()}][req_$requestId] verifyPhoneNumber unexpected error: $e');
        state = state.copyWith(status: AsyncError(e, st));
        return false;
      }
    }
  }

  /// Initiates Firebase OTP sending for Sign In
  Future<bool> startSignIn(String mobileNumber) async {
    _resendToken = null;
    // Only sign out residual unauthenticated Firebase user instances if no active app session exists
    final currentUserInApp = _ref.read(userProvider);
    if (currentUserInApp.id.isEmpty && _auth.currentUser != null) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
    return _requestFirebaseOtp(
      mobileNumber,
      fullName: null,
      isSignUp: false,
      isResend: false,
    );
  }

  /// Initiates Firebase OTP sending for Sign Up
  Future<bool> startSignUp({
    required String fullName,
    required String mobileNumber,
  }) async {
    _resendToken = null;
    // Only sign out residual unauthenticated Firebase user instances if no active app session exists
    final currentUserInApp = _ref.read(userProvider);
    if (currentUserInApp.id.isEmpty && _auth.currentUser != null) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
    return _requestFirebaseOtp(
      mobileNumber,
      fullName: fullName,
      isSignUp: true,
      isResend: false,
    );
  }

  /// Resends OTP to the current mobile number while preserving forceResendingToken
  Future<bool> resendOtp() async {
    final mobile = state.mobileNumber;
    if (mobile == null || mobile.trim().isEmpty) {
      debugPrint(
          '[AUTH][${_now()}] resendOtp aborted: No mobile number in state.');
      return false;
    }
    debugPrint(
        '[AUTH][${_now()}][req_${_activeRequestId + 1}] resendOtp requested with existing resendToken=${_resendToken != null}');
    return _requestFirebaseOtp(
      mobile,
      fullName: state.tempFullName,
      isSignUp: state.isSignUpFlow,
      isResend: true,
    );
  }

  /// Verifies the OTP via Firebase and completes the session.
  /// [ref] is optional for backwards-compatibility; notifier holds its own [Ref].
  Future<bool> verifyOtp(String otp, [WidgetRef? ref]) async {
    final now = _now();
    state = state.copyWith(status: const AsyncLoading());
    debugPrint(
        '[AUTH][$now][req_$_activeRequestId] verifyOtp requested. Input length=${otp.length}');

    try {
      // 1. If user is already authenticated via automatic verificationCompleted callback
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final currentPhone = PhoneAuthUtils.normalize(currentUser.phoneNumber);
        final statePhone = PhoneAuthUtils.normalize(state.mobileNumber);
        if (currentPhone.isNotEmpty &&
            statePhone.isNotEmpty &&
            currentPhone == statePhone) {
          debugPrint(
              '[AUTH][$now][req_$_activeRequestId] Firebase user already authenticated via auto-retrieval. Completing session directly.');
          return await _completeUserSession(currentUser,
              requestId: _activeRequestId);
        }
      }

      fb.UserCredential userCredential;

      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          final code = state.lastFirebaseErrorCode ?? 'session-expired';
          final msg = state.lastFirebaseErrorMessage ??
              'Verification session has expired ($code). Please request a new OTP.';
          throw fb.FirebaseAuthException(code: code, message: msg);
        }
        userCredential = await _webConfirmationResult!.confirm(otp);
      } else {
        final activeVerificationId = _verificationId ?? state.verificationId;
        debugPrint(
            '[AUTH][$now][req_$_activeRequestId] Calling signInWithCredential with verificationId=${_maskId(activeVerificationId)}');

        if (activeVerificationId == null || activeVerificationId.isEmpty) {
          final code = state.lastFirebaseErrorCode ?? 'session-expired';
          final msg = state.lastFirebaseErrorMessage ??
              'No active verification session ($code). Please tap "Resend OTP" to request a new code.';
          throw fb.FirebaseAuthException(code: code, message: msg);
        }

        final credential = fb.PhoneAuthProvider.credential(
          verificationId: activeVerificationId,
          smsCode: otp,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final fbUser = userCredential.user;
      if (fbUser != null) {
        debugPrint(
            '[AUTH][${_now()}][req_$_activeRequestId] signInWithCredential succeeded. UID=${fbUser.uid}');
        return await _completeUserSession(fbUser, requestId: _activeRequestId);
      }
      throw Exception('Failed to sign in with Firebase: user was null.');
    } on fb.FirebaseAuthException catch (e, st) {
      debugPrint(
          '[AUTH][${_now()}][req_$_activeRequestId] verifyOtp failed with code=${e.code}, message=${e.message}');
      if (e.code == 'session-expired' || e.code == 'invalid-verification-id') {
        _webConfirmationResult = null;
        _verificationId = null;
        state = state.copyWith(clearVerificationId: true);
      }
      final userFriendlyMsg = _mapFirebaseAuthErrorMessage(e);
      state = state.copyWith(
        status: AsyncError(Exception(userFriendlyMsg), st),
        lastFirebaseErrorCode: e.code,
        lastFirebaseErrorMessage: e.message ?? userFriendlyMsg,
      );
      return false;
    } catch (e, st) {
      debugPrint(
          '[AUTH][${_now()}][req_$_activeRequestId] verifyOtp unexpected error: $e');
      state = state.copyWith(status: AsyncError(e, st));
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(firebaseAuthProvider), ref);
});
