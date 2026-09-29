import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';

/// Prominent in-app disclosure dialog for delivery staff prior to requesting
/// background location permission on Android devices, complying with Google Play
/// User Data and Background Location Policies.
class DeliveryLocationDisclosureDialog extends StatelessWidget {
  const DeliveryLocationDisclosureDialog({super.key});

  static const String _prefKey = 'delivery_bg_location_disclosure_agreed';

  /// Checks if the disclosure has already been acknowledged on this device.
  static Future<bool> hasAcknowledged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sets the acknowledgment flag.
  static Future<void> markAcknowledged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {}
  }

  /// Shows the disclosure dialog if running on Android and not yet acknowledged.
  /// Returns `true` if already acknowledged or if the user clicks Agree.
  /// Returns `false` if user cancels or declines.
  static Future<bool> showIfNeeded(BuildContext context) async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final alreadyAgreed = await hasAcknowledged();
    if (alreadyAgreed) return true;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const DeliveryLocationDisclosureDialog(),
    );

    if (result == true) {
      await markAcknowledged();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Location Access\nfor Delivery Staff',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Sawariya Dairy collects real-time location data to enable live route dispatch, customer delivery updates, and order ETA calculation even when the app is closed or running in the background.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            _buildBulletPoint(
              Icons.visibility_outlined,
              'Who can see your location:',
              'Assigned customers waiting for their delivery and Sawariya Dairy dispatch managers.',
            ),
            const SizedBox(height: 10),
            _buildBulletPoint(
              Icons.toggle_on_outlined,
              'When tracking occurs:',
              'ONLY when you toggle your status to "On Duty / Online".',
            ),
            const SizedBox(height: 10),
            _buildBulletPoint(
              Icons.stop_circle_outlined,
              'When tracking stops:',
              'Immediately when you go "Offline" or your delivery shift ends.',
            ),
            const SizedBox(height: 10),
            _buildBulletPoint(
              Icons.security_outlined,
              'Customer Privacy:',
              'Customer accounts are NEVER tracked in the background.',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Not Now',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Agree & Continue',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildBulletPoint(IconData icon, String boldText, String normalText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$boldText ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(text: normalText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
