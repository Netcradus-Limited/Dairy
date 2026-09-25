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

  AuthState({
    required this.status,
    this.mobileNumber,
    this.tempFullName,
    this.isSignUpFlow = false,
  });

  bool get isLoading => status.isLoading;

  AuthState copyWith({
    AsyncValue<void>? status,
    String? mobileNumber,
    String? tempFullName,
    bool? isSignUpFlow,
  }) {
    return AuthState(
      status: status ?? this.status,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      tempFullName: tempFullName ?? this.tempFullName,
      isSignUpFlow: isSignUpFlow ?? this.isSignUpFlow,
    );
  }
}

/// Auth State Notifier for managing Firebase Phone Auth
class AuthNotifier extends StateNotifier<AuthState> {
  final fb.FirebaseAuth _auth;
  String? _verificationId;
  fb.ConfirmationResult? _webConfirmationResult;

  AuthNotifier(this._auth) : super(AuthState(status: const AsyncData(null)));

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

  String _mapFirebaseAuthErrorMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The provided phone number is not valid.';
      case 'too-many-requests':
        return 'Too many requests. Please wait a moment and try again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please try again.';
      case 'invalid-app-credential':
        return 'The reCAPTCHA app verification failed (invalid-app-credential). Please check Firebase authorized domains or reCAPTCHA settings.';
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'Invalid OTP entered. Please check and try again.';
      case 'session-expired':
        return 'Verification session has expired. Please request a new OTP.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled for this project.';
      default:
        return e.message ??
            'Authentication error (${e.code}). Please try again.';
    }
  }

  /// Initiates Firebase OTP sending for Sign In
  Future<bool> startSignIn(String mobileNumber) async {
    state = state.copyWith(status: const AsyncLoading());
    final formattedPhone = formatE164(mobileNumber);

    if (kIsWeb) {
      // Ensure fresh reCAPTCHA for every attempt on Web
      _webConfirmationResult = null;
      try {
        final confirmationResult =
            await _auth.signInWithPhoneNumber(formattedPhone);
        _webConfirmationResult = confirmationResult;
        state = state.copyWith(
          status: const AsyncData(null),
          mobileNumber: mobileNumber,
          isSignUpFlow: false,
        );
        return true;
      } on fb.FirebaseAuthException catch (e, st) {
        _webConfirmationResult = null;
        state = state.copyWith(
          status: AsyncError(Exception(_mapFirebaseAuthErrorMessage(e)), st),
        );
        return false;
      } catch (e, st) {
        _webConfirmationResult = null;
        state = state.copyWith(status: AsyncError(e, st));
        return false;
      }
    } else {
      // Native Android / iOS flow
      _verificationId = null;
      final completer = Completer<bool>();
      try {
        await _auth.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          verificationCompleted: (fb.PhoneAuthCredential credential) async {
            try {
              await _auth.signInWithCredential(credential);
              if (!completer.isCompleted) completer.complete(true);
            } catch (e) {
              if (!completer.isCompleted) completer.complete(false);
            }
          },
          verificationFailed: (fb.FirebaseAuthException e) {
            _verificationId = null;
            state = state.copyWith(
              status: AsyncError(
                Exception(_mapFirebaseAuthErrorMessage(e)),
                StackTrace.current,
              ),
            );
            if (!completer.isCompleted) completer.complete(false);
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
            state = state.copyWith(
              status: const AsyncData(null),
              mobileNumber: mobileNumber,
              isSignUpFlow: false,
            );
            if (!completer.isCompleted) completer.complete(true);
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
        return await completer.future;
      } on fb.FirebaseAuthException catch (e, st) {
        _verificationId = null;
        state = state.copyWith(
          status: AsyncError(Exception(_mapFirebaseAuthErrorMessage(e)), st),
        );
        return false;
      } catch (e, st) {
        _verificationId = null;
        state = state.copyWith(status: AsyncError(e, st));
        return false;
      }
    }
  }

  /// Initiates Firebase OTP sending for Sign Up
  Future<bool> startSignUp({
    required String fullName,
    required String mobileNumber,
  }) async {
    state = state.copyWith(status: const AsyncLoading());
    final formattedPhone = formatE164(mobileNumber);

    if (kIsWeb) {
      // Ensure fresh reCAPTCHA for every attempt on Web
      _webConfirmationResult = null;
      try {
        final confirmationResult =
            await _auth.signInWithPhoneNumber(formattedPhone);
        _webConfirmationResult = confirmationResult;
        state = state.copyWith(
          status: const AsyncData(null),
          mobileNumber: mobileNumber,
          tempFullName: fullName,
          isSignUpFlow: true,
        );
        return true;
      } on fb.FirebaseAuthException catch (e, st) {
        _webConfirmationResult = null;
        state = state.copyWith(
          status: AsyncError(Exception(_mapFirebaseAuthErrorMessage(e)), st),
        );
        return false;
      } catch (e, st) {
        _webConfirmationResult = null;
        state = state.copyWith(status: AsyncError(e, st));
        return false;
      }
    } else {
      // Native Android / iOS flow
      _verificationId = null;
      final completer = Completer<bool>();
      try {
        await _auth.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          verificationCompleted: (fb.PhoneAuthCredential credential) async {
            try {
              await _auth.signInWithCredential(credential);
              if (!completer.isCompleted) completer.complete(true);
            } catch (e) {
              if (!completer.isCompleted) completer.complete(false);
            }
          },
          verificationFailed: (fb.FirebaseAuthException e) {
            _verificationId = null;
            state = state.copyWith(
              status: AsyncError(
                Exception(_mapFirebaseAuthErrorMessage(e)),
                StackTrace.current,
              ),
            );
            if (!completer.isCompleted) completer.complete(false);
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
            state = state.copyWith(
              status: const AsyncData(null),
              mobileNumber: mobileNumber,
              tempFullName: fullName,
              isSignUpFlow: true,
            );
            if (!completer.isCompleted) completer.complete(true);
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
        return await completer.future;
      } on fb.FirebaseAuthException catch (e, st) {
        _verificationId = null;
        state = state.copyWith(
          status: AsyncError(Exception(_mapFirebaseAuthErrorMessage(e)), st),
        );
        return false;
      } catch (e, st) {
        _verificationId = null;
        state = state.copyWith(status: AsyncError(e, st));
        return false;
      }
    }
  }

  /// Resends OTP to the current mobile number
  Future<bool> resendOtp() async {
    final mobile = state.mobileNumber;
    if (mobile == null) return false;
    _verificationId = null;
    _webConfirmationResult = null;
    if (state.isSignUpFlow && state.tempFullName != null) {
      return startSignUp(fullName: state.tempFullName!, mobileNumber: mobile);
    }
    return startSignIn(mobile);
  }

  /// Verifies the OTP via Firebase and completes the session
  Future<bool> verifyOtp(String otp, WidgetRef ref) async {
    state = state.copyWith(status: const AsyncLoading());

    try {
      fb.UserCredential userCredential;

      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          throw fb.FirebaseAuthException(
            code: 'session-expired',
            message:
                'Verification session has expired. Please request a new OTP.',
          );
        }
        userCredential = await _webConfirmationResult!.confirm(otp);
      } else {
        if (_verificationId == null) {
          throw fb.FirebaseAuthException(
            code: 'session-expired',
            message:
                'Verification session has expired. Please request a new OTP.',
          );
        }
        final credential = fb.PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        final mobile = (state.mobileNumber != null &&
                state.mobileNumber!.trim().isNotEmpty)
            ? state.mobileNumber!.trim()
            : (firebaseUser.phoneNumber ?? '');
        final normalized = PhoneAuthUtils.normalize(mobile);
        final detectedRole = UserRole.fromPhoneAndRole(phone: mobile).value;

        debugPrint(
            '[AUTH ROLE DEBUG] Firebase phone number: ${firebaseUser.phoneNumber ?? mobile}');
        debugPrint('[AUTH ROLE DEBUG] normalized phone number: $normalized');
        debugPrint('[AUTH ROLE DEBUG] detected role: $detectedRole');
        debugPrint('[AUTH ROLE DEBUG] authenticated UID: ${firebaseUser.uid}');

        final fullName = (state.tempFullName != null &&
                state.tempFullName!.trim().isNotEmpty)
            ? state.tempFullName!.trim()
            : (detectedRole == 'admin'
                ? 'Sawariya Admin'
                : (detectedRole == 'delivery'
                    ? 'Delivery Partner'
                    : 'Sawariya Customer'));

        final user = User(
          id: firebaseUser.uid,
          name: fullName,
          phone: mobile,
          email: firebaseUser.email?.isNotEmpty == true
              ? firebaseUser.email!
              : (detectedRole == 'admin' ? 'admin@sawariyadairy.com' : ''),
          role: detectedRole,
        );

        await ref.read(userProvider.notifier).setSession(user);

        // Reset verification tokens upon successful confirmation
        _verificationId = null;
        _webConfirmationResult = null;

        state = AuthState(status: const AsyncData(null));
        return true;
      }
      throw Exception('Failed to sign in with Firebase: user was null.');
    } on fb.FirebaseAuthException catch (e, st) {
      if (e.code == 'session-expired') {
        _webConfirmationResult = null;
        _verificationId = null;
      }
      state = state.copyWith(
        status: AsyncError(Exception(_mapFirebaseAuthErrorMessage(e)), st),
      );
      return false;
    } catch (e, st) {
      state = state.copyWith(status: AsyncError(e, st));
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(firebaseAuthProvider));
});
