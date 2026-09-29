import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/user_provider.dart';
import '../../services/account_deletion_service.dart';

/// Screen allowing customers to permanently delete their account and personal data.
class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  bool _confirmedUnderstanding = false;
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _handleDeleteAccount() async {
    if (!_confirmedUnderstanding || _isDeleting) return;

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Account Deletion',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppColors.statusCancelled,
          ),
        ),
        content: Text(
          'Are you absolutely sure you want to permanently delete your account? All active subscriptions will be cancelled immediately.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCancelled,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Delete Account'),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    final service = AccountDeletionService();
    final result = await service.deleteAccount();

    if (!mounted) return;

    setState(() => _isDeleting = false);

    if (result.isSuccess) {
      await ref.read(userProvider.notifier).clearSession();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Account Deleted',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Your Sawariya Dairy account and personal data have been deleted successfully.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Return to Login'),
            ),
          ],
        ),
      );
    } else if (result.status ==
        AccountDeletionResultStatus.requiresRecentLogin) {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    } else {
      setState(() {
        _errorMessage =
            result.errorMessage ?? 'An error occurred while deleting account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Delete Account',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning Banner
                Container(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.statusCancelled,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permanent Action',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Deleting your account is permanent and cannot be undone. Please review what happens below before proceeding.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF7F1D1D),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.p24),

                // Current Account Card
                Container(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name.isEmpty ? 'Customer' : user.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              user.phone.isEmpty
                                  ? 'Active Session'
                                  : user.phone,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.p24),

                Text(
                  'What happens when you delete your account:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                _buildBulletPoint(
                  icon: Icons.cancel_outlined,
                  title: 'Active Subscriptions Cancelled',
                  description:
                      'All recurring daily milk and dairy product subscriptions will be stopped immediately.',
                ),
                _buildBulletPoint(
                  icon: Icons.location_off_outlined,
                  title: 'Saved Addresses Removed',
                  description:
                      'Your saved home, office, and other delivery addresses will be permanently deleted.',
                ),
                _buildBulletPoint(
                  icon: Icons.lock_outline_rounded,
                  title: 'Authentication Credentials Revoked',
                  description:
                      'Your login identity will be erased from Firebase Authentication. You will be signed out immediately.',
                ),
                _buildBulletPoint(
                  icon: Icons.receipt_long_outlined,
                  title: 'Statutory Order Records De-identified',
                  description:
                      'Historical invoices and transaction amounts are anonymized and retained strictly to comply with Indian accounting and tax regulations.',
                ),
                const SizedBox(height: AppSizes.p24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSizes.p12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p16),
                ],

                // Checkbox confirmation
                CheckboxListTile(
                  value: _confirmedUnderstanding,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.statusCancelled,
                  title: Text(
                    'I understand that deleting my account is permanent and all active subscriptions will be cancelled.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onChanged: _isDeleting
                      ? null
                      : (val) {
                          setState(
                              () => _confirmedUnderstanding = val ?? false);
                        },
                ),
                const SizedBox(height: AppSizes.p24),

                // Delete Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_confirmedUnderstanding && !_isDeleting)
                        ? _handleDeleteAccount
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusCancelled,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.statusCancelled.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isDeleting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Permanently Delete Account',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSizes.p16),

                // External web link disclosure
                Center(
                  child: Text(
                    'Web account deletion request: ${AppStrings.accountDeletionUrl}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
