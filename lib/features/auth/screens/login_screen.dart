import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../services/auth_video_service.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';

/// Sawariya Dairy Mobile Sign In Screen matching reference image
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ensure both login and OTP videos are warm and ready
    AuthVideoService.instance.preload();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final mobile = _mobileController.text.trim();
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.startSignIn(mobile);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully!'),
          backgroundColor: AppColors.freshGreen,
        ),
      );
      context.push('/otp', extra: mobile);
    } else {
      final errorState = ref.read(authProvider);
      final errorMsg = errorState.status.error?.toString() ??
          'Failed to send OTP. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg.replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status.isLoading;

    return AuthCard(
      featureTitle: 'Pure Dairy at Your Doorstep',
      featureSubtitle:
          'Order farm-fresh A2 milk, ghee, paneer, and butter with daily morning delivery.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const AuthHeader(
              title: 'Welcome Back!',
              subtitle: 'Sign in using your mobile number',
            ),

            const SizedBox(height: 12),

            // Mobile Number Input Field
            Text(
              'Mobile Number',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),

            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSendOtp(),
              validator: AppValidators.validatePhone,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Enter 10-digit mobile number',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryBlue,
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryBlue,
                    width: 1.8,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.8,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Send OTP Primary Button
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.primaryDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Send OTP',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 14),

            // Register Link Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF4A5568),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    context.push('/register');
                  },
                  child: Text(
                    'Register',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
