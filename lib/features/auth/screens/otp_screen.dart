import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
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
  late Timer _timer;
  int _startSeconds = 30;
  bool _canResend = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _startSeconds = 30;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds == 0) {
        setState(() {
          _canResend = true;
          _timer.cancel();
        });
      } else {
        setState(() {
          _startSeconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    // Prevent duplicate verification requests
    if (_isVerifying || ref.read(authProvider).status.isLoading) return;

    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit OTP code'),
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
      final success = await authNotifier.verifyOtp(_otpCode, ref);

      if (!mounted) return;

      if (success) {
        // Complete OS autofill session smoothly
        TextInput.finishAutofillContext();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP Verified successfully!'),
            backgroundColor: AppColors.freshGreen,
          ),
        );

        // session is saved, GoRouter redirect will automatically handle routing
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
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend) return;

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
      _startResendTimer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to resend OTP. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              context.pop();
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
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive the OTP? ",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: _handleResendOtp,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Resend OTP in 00:${_startSeconds.toString().padLeft(2, '0')}s',
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
            onPressed: (isLoading || _isVerifying) ? null : _handleVerifyOtp,
          ),

          const SizedBox(height: 8),

          // Back to Login Link
          Center(
            child: TextButton(
              onPressed: () {
                context.go('/login');
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
