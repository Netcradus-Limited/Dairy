import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/loading_button.dart';
import '../widgets/otp_input_field.dart';

/// Sawariya Dairy OTP Verification Screen Component
class OtpScreen extends ConsumerStatefulWidget {
  final String? targetDestination;

  const OtpScreen({
    super.key,
    this.targetDestination,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _otpCode = '';
  Timer? _timer;
  int _startSeconds = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;
  int _inputKeyCounter = 0;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer(60);
  }

  void _startResendTimer([int seconds = 60]) {
    _timer?.cancel();
    setState(() {
      _startSeconds = seconds;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds <= 1) {
        setState(() {
          _startSeconds = 0;
          _canResend = true;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _startSeconds--;
        });
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigateToDestination() {
    if (_hasNavigated || !mounted) return;

    // Complete OS autofill session smoothly
    TextInput.finishAutofillContext();

    if (Navigator.of(context).canPop()) {
      _hasNavigated = true;
      Navigator.of(context).pop();
    } else {
      final user = ref.read(userProvider);
      final destination = widget.targetDestination ??
          (user.canAccessAdminPortal
              ? '/admin'
              : (user.isDelivery ? '/delivery' : '/home'));

      final router = GoRouter.maybeOf(context);
      if (router != null) {
        _hasNavigated = true;
        context.go(destination);
      } else {
        debugPrint(
            '[OTP NAVIGATION] GoRouter not found in widget tree; Navigator cannot pop.');
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final authState = ref.read(authProvider);

    // Prevent duplicate verification requests
    if (_isVerifying || _isResending || authState.status.isLoading || _hasNavigated) {
      return;
    }

    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit OTP code'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Do not treat UI countdown as proof that Firebase's verification session is valid
    if (!authState.hasActiveSession && !kIsWeb && !authState.isAutoVerified) {
      final code = authState.lastFirebaseErrorCode ?? 'session-expired';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No active verification session ($code). Please tap "Resend OTP" to request a new code.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.verifyOtp(_otpCode);

      if (!mounted) return;

      if (success) {
        if (!_hasNavigated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP Verified successfully!'),
              backgroundColor: AppColors.freshGreen,
            ),
          );
          _navigateToDestination();
        }
      } else {
        final errorState = ref.read(authProvider);
        final errorMsg =
            errorState.status.error?.toString() ?? 'Invalid OTP code';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg.replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[OTP VERIFICATION ERROR] Failed to verify OTP: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Verification error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend || _isResending || _isVerifying) return;

    setState(() {
      _isResending = true;
      _otpCode = '';
      // Force recreation of OtpInputField to clear all 6 input text fields
      _inputKeyCounter++;
    });

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.resendOtp();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new OTP has been sent.'),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
        _startResendTimer(60);
      } else {
        final errorState = ref.read(authProvider);
        final errorMsg = errorState.status.error?.toString() ??
            'Failed to resend OTP. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg.replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[OTP RESEND ERROR] Failed to resend OTP: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Resend error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for automatic OS SMS retrieval verification completion
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAutoVerified && (previous?.isAutoVerified != true)) {
        if (!_hasNavigated && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mobile number verified automatically!'),
              backgroundColor: AppColors.freshGreen,
            ),
          );
          _navigateToDestination();
        }
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState.status.isLoading;
    final displayDestination =
        authState.mobileNumber ?? widget.targetDestination ?? '+91 98765 43210';

    return AuthCard(
      videoPath: 'assets/images/otpv.mp4',
      featureTitle: 'Secure Account Verification',
      featureSubtitle:
          'We ensure 100% security for all Sawariya Dairy customer transactions and orders.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          AuthHeader(
            title: 'Verify Your Number',
            subtitle: 'Enter the 6-digit OTP sent to $displayDestination.',
          ),

          const SizedBox(height: 8),

          // Change Number Option
          GestureDetector(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/login');
              }
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined,
                    size: 14, color: AppColors.primaryBlue),
                SizedBox(width: 4),
                Text(
                  'Change Number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 6-Digit Pin Input Field
          OtpInputField(
            key: ValueKey('otp_field_$_inputKeyCounter'),
            onChanged: (code) {
              setState(() {
                _otpCode = code;
              });
            },
            onCompleted: (code) {
              setState(() {
                _otpCode = code;
              });
              _handleVerifyOtp();
            },
          ),

          const SizedBox(height: 12),

          // Countdown Timer & Resend Option
          Center(
            child: _canResend
                ? Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive the OTP? ",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: (_isResending || isLoading)
                            ? null
                            : _handleResendOtp,
                        child: Text(
                          _isResending ? 'Sending...' : 'Resend OTP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: (_isResending || isLoading)
                                ? AppColors.textMuted
                                : AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Resend OTP in ${_formatTimer(_startSeconds)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          // Submit Verify Button
          LoadingButton(
            text: 'Verify OTP',
            isLoading: isLoading || _isVerifying,
            onPressed: (isLoading || _isVerifying || _isResending)
                ? null
                : _handleVerifyOtp,
          ),

          const SizedBox(height: 8),

          // Back to Login Link
          Center(
            child: TextButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go('/login');
                }
              },
              child: const Text(
                'Back to Login',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
