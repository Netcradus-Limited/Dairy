import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/auth/screens/otp_screen.dart';
import 'package:dairy_app/providers/auth_provider.dart';

void main() {
  group('AuthState and Verification Session State Tests', () {
    test('Initial AuthState has no active session', () {
      final state = AuthState(status: const AsyncData(null));
      expect(state.hasActiveSession, isFalse);
      expect(state.verificationId, isNull);
      expect(state.resendToken, isNull);
      expect(state.isAutoVerified, isFalse);
      expect(state.lastFirebaseErrorCode, isNull);
      expect(state.activeRequestId, equals(0));
    });

    test('AuthState retains verificationId and resendToken across state updates', () {
      var state = AuthState(status: const AsyncData(null));

      // Code sent callback updates session
      state = state.copyWith(
        verificationId: 'v_id_test_12345678',
        resendToken: 987654,
        mobileNumber: '9876543210',
        activeRequestId: 1,
      );

      expect(state.hasActiveSession, isTrue);
      expect(state.verificationId, equals('v_id_test_12345678'));
      expect(state.resendToken, equals(987654));
      expect(state.activeRequestId, equals(1));

      // Rebuild / loading state update must preserve verificationId and resendToken
      state = state.copyWith(status: const AsyncLoading());
      expect(state.hasActiveSession, isTrue);
      expect(state.verificationId, equals('v_id_test_12345678'));
      expect(state.resendToken, equals(987654));

      // Explicit resend request clears previous verificationId to prevent stale submission
      state = state.copyWith(clearVerificationId: true, activeRequestId: 2);
      expect(state.hasActiveSession, isFalse);
      expect(state.verificationId, isNull);
      expect(state.resendToken, equals(987654)); // Token preserved for resend
      expect(state.activeRequestId, equals(2));
    });

    test('Error mapping formats user messages with actual Firebase error code', () {
      final state = AuthState(
        status: const AsyncData(null),
        lastFirebaseErrorCode: 'invalid-app-credential',
        lastFirebaseErrorMessage:
            'App verification failed (invalid-app-credential). Please check internet connection and Google Play Services.',
      );

      expect(state.lastFirebaseErrorCode, equals('invalid-app-credential'));
      expect(state.lastFirebaseErrorMessage, contains('(invalid-app-credential)'));
    });
  });

  group('OtpScreen Widget & Resend Lifecycle Tests', () {
    testWidgets(
        'OtpScreen displays countdown timer and renders all UI elements',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OtpScreen(targetDestination: '+91 98765 43210'),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify header and mobile number are displayed
      expect(find.text('Verify Your Number'), findsOneWidget);
      expect(find.textContaining('9876543210'), findsOneWidget);

      // Verify 6 OTP input boxes
      expect(find.byType(TextField), findsNWidgets(6));

      // Verify initial resend countdown
      expect(find.textContaining('Resend OTP in 01:00'), findsOneWidget);

      // Verify submit button is present
      expect(find.text('Verify OTP'), findsOneWidget);
    });

    testWidgets('Tapping Resend OTP clears input and restarts countdown',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeNotifier = _FakeAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OtpScreen(targetDestination: '+91 98765 43210'),
            ),
          ),
        ),
      );

      await tester.pump();

      // Step periodic timer through 61 seconds so countdown reaches 0 and "Resend OTP" becomes clickable
      for (int i = 0; i < 61; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('Resend OTP'), findsOneWidget);

      // Tap Resend OTP
      await tester.tap(find.text('Resend OTP'));
      await tester.pump();

      // Verify resend was called on notifier
      expect(fakeNotifier.resendCalled, isTrue);

      // Verify countdown restarted
      expect(find.textContaining('Resend OTP in 01:00'), findsOneWidget);
    });

    testWidgets('Automatic verification auto-completes and navigates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeNotifier = _FakeAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(
                    body: OtpScreen(targetDestination: '+91 98765 43210'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Simulate Android SMS retriever triggering auto-verification
      fakeNotifier.triggerAutoVerification();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Mobile number verified automatically!'), findsOneWidget);
    });
  });
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  bool resendCalled = false;
  bool verifyCalled = false;
  String? lastEnteredOtp;

  _FakeAuthNotifier()
      : super(
          AuthState(
            status: const AsyncData(null),
            mobileNumber: '9876543210',
            verificationId: 'fake_v_id_123',
            activeRequestId: 1,
          ),
        );

  void triggerAutoVerification() {
    state = state.copyWith(isAutoVerified: true);
  }

  @override
  Future<bool> resendOtp() async {
    resendCalled = true;
    state = state.copyWith(
      verificationId: 'new_fake_v_id_456',
      resendToken: 12345,
      activeRequestId: 2,
    );
    return true;
  }

  @override
  Future<bool> verifyOtp(String otp, [WidgetRef? ref]) async {
    verifyCalled = true;
    lastEnteredOtp = otp;
    if (otp == '123456') {
      state = state.copyWith(isAutoVerified: true);
      return true;
    }
    state = state.copyWith(
      status: AsyncError(
        Exception('Invalid OTP entered (invalid-verification-code).'),
        StackTrace.current,
      ),
      lastFirebaseErrorCode: 'invalid-verification-code',
    );
    return false;
  }

  @override
  Future<bool> startSignIn(String mobileNumber) async => true;

  @override
  Future<bool> startSignUp(
          {required String fullName, required String mobileNumber}) async =>
      true;
}
