import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';

/// Foreground-only rationale dialog shown to Delivery Partners prior to
/// requesting standard foreground location access (`ACCESS_FINE_LOCATION` /
/// `ACCESS_COARSE_LOCATION`). Kept strictly separate from background consent.
class ForegroundLocationRationaleDialog extends StatelessWidget {
  const ForegroundLocationRationaleDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ForegroundLocationRationaleDialog(),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
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
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Location Needed\nfor Active Deliveries',
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
                'Sawariya Dairy uses your device location while you are using the Delivery Partner app to show your live route, calculate delivery distances, and share ETA updates with customers assigned to you.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
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
                        'Continue',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent in-app disclosure dialog for delivery staff prior to requesting
/// background location permission (`ACCESS_BACKGROUND_LOCATION`) on Android 10+,
/// complying with Google Play User Data and Background Location Policies.
class DeliveryLocationDisclosureDialog extends StatelessWidget {
  const DeliveryLocationDisclosureDialog({super.key});

  static String _agreedPrefKey(String agentId) =>
      'delivery_bg_location_disclosure_agreed_${agentId.trim()}';

  static String _declinedPrefKey(String agentId) =>
      'delivery_bg_location_disclosure_declined_${agentId.trim()}';

  static String _agreedTimestampKey(String agentId) =>
      'delivery_bg_location_disclosure_ts_${agentId.trim()}';

  static String _notifDeclinedPrefKey(String agentId) =>
      'delivery_notif_permission_declined_${agentId.trim()}';

  /// Returns true if notification permission was previously declined for [agentId]
  /// so the coordinator does not repeatedly spam Android's OS prompt without user action.
  static Future<bool> hasDeclinedNotificationForAgent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_notifDeclinedPrefKey(cleanId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markNotificationDeclinedForAgent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notifDeclinedPrefKey(cleanId), true);
    } catch (_) {}
  }

  static Future<void> clearNotificationDeclinedForAgent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notifDeclinedPrefKey(cleanId));
    } catch (_) {}
  }

  /// Checks whether THIS authenticated delivery agent UID has explicitly
  /// consented to background location disclosure. Never falls back to global
  /// keys or stored online status.
  static Future<bool> hasAcknowledgedForAgent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_agreedPrefKey(cleanId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether the delivery agent explicitly declined background location
  /// so the app falls back cleanly without repeatedly nagging.
  static Future<bool> hasDeclinedForAgent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_declinedPrefKey(cleanId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persists explicit affirmative consent bound to the delivery-agent UID.
  static Future<void> markAcknowledgedForAgent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_agreedPrefKey(cleanId), true);
      await prefs.setBool(_declinedPrefKey(cleanId), false);
      await prefs.setString(_agreedTimestampKey(cleanId),
          DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
  }

  /// Persists explicit decline for this UID so we respect the user's choice.
  static Future<void> markDeclinedForAgent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_agreedPrefKey(cleanId), false);
      await prefs.setBool(_declinedPrefKey(cleanId), true);
    } catch (_) {}
  }

  /// Clears saved background disclosure preferences for an agent (e.g. on
  /// explicit reset or permission revocation handling).
  static Future<void> clearConsentForAgent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_agreedPrefKey(cleanId));
      await prefs.remove(_declinedPrefKey(cleanId));
      await prefs.remove(_agreedTimestampKey(cleanId));
    } catch (_) {}
  }

  /// Legacy compatibility wrapper delegating strictly to UID-scoped checks.
  static Future<bool> hasAcknowledged({String agentId = ''}) =>
      hasAcknowledgedForAgent(agentId);

  /// Shows the prominent background location disclosure modal on Android.
  /// Returns `true` ONLY when the user taps "Agree & Continue" (or if already
  /// consented and `forceShow` is false), and `false` on "Not Now".
  static Future<bool> showIfNeeded(
    BuildContext context, {
    String agentId = '',
    bool forceShow = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final cleanId = agentId.trim();
    if (!forceShow && cleanId.isNotEmpty) {
      final alreadyAgreed = await hasAcknowledgedForAgent(cleanId);
      if (alreadyAgreed) return true;
    }

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const DeliveryLocationDisclosureDialog(),
    );

    if (result == true) {
      if (cleanId.isNotEmpty) {
        await markAcknowledgedForAgent(cleanId);
      }
      return true;
    } else {
      if (cleanId.isNotEmpty) {
        await markDeclinedForAgent(cleanId);
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
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
                      'Background Location\nfor Delivery Partners',
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
                'Sawariya Dairy collects foreground and background location data to support live delivery route tracking, dispatch coordination, and customer ETA updates while you are On Duty / Online (including between consecutive deliveries during your active shift), even when the app is minimized or the screen is locked.',
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
                'Customers awaiting their currently active assigned delivery and authorized Sawariya Dairy dispatch admins.',
              ),
              const SizedBox(height: 10),
              _buildBulletPoint(
                Icons.toggle_on_outlined,
                'When tracking operates:',
                'ONLY after your consent and while you are toggled "On Duty / Online", accompanied by an ongoing tracking notification.',
              ),
              const SizedBox(height: 10),
              _buildBulletPoint(
                Icons.stop_circle_outlined,
                'When tracking stops:',
                'Immediately when you switch "Offline", take a break, log out, or close your shift/app.',
              ),
              const SizedBox(height: 10),
              _buildBulletPoint(
                Icons.security_outlined,
                'Customer privacy:',
                'Customer accounts are NEVER tracked in the background.',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('disclosure_not_now_button'),
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
                      key: const Key('disclosure_agree_button'),
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
