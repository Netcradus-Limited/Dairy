import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';

/// Prominent in-app disclosure shown to Delivery Partners before the Android
/// location permission prompt appears.
///
/// The app requests only foreground location (`ACCESS_FINE_LOCATION` /
/// `ACCESS_COARSE_LOCATION`) and never `ACCESS_BACKGROUND_LOCATION`. Tracking
/// runs inside a `location` foreground service started while the app is
/// visible, which keeps sharing active if the rider minimises the app or locks
/// the screen during a duty session. This dialog states that behaviour plainly
/// so the disclosure matches what the app actually does.
///
/// "Continue" is an affirmative opt-in; the OS permission prompt is only shown
/// afterwards. "Not Now" cancels without starting any tracking.
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
              const Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sawariya Dairy shares your location with our delivery team to coordinate dispatch, show your live route and send delivery updates to the customers assigned to you.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: 14),
                      _DisclosurePoint(
                        icon: Icons.play_circle_outline,
                        text:
                            'Sharing starts only when you choose to go On Duty or start tracking. It never starts on its own.',
                      ),
                      _DisclosurePoint(
                        icon: Icons.phone_android_outlined,
                        text:
                            'While you are On Duty, sharing keeps running if you minimise the app or lock your screen, so customers keep seeing live updates while you are on the road.',
                      ),
                      _DisclosurePoint(
                        icon: Icons.notifications_active_outlined,
                        text:
                            'An ongoing notification stays in your notification area the whole time your location is being shared.',
                      ),
                      _DisclosurePoint(
                        icon: Icons.stop_circle_outlined,
                        text:
                            'Sharing stops as soon as you go Offline, end your duty session, stop tracking or log out.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap Continue to allow location access on the next screen. Tap Not Now to cancel — nothing will be shared.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
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

/// A single bullet line inside [ForegroundLocationRationaleDialog].
class _DisclosurePoint extends StatelessWidget {
  const _DisclosurePoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Persisted, per-delivery-agent record of the Android 13+ notification
/// permission prompt, so the app does not repeatedly re-trigger the OS dialog
/// after the partner has declined it once.
///
/// There is no background-location consent state here: the app does not
/// declare or request ACCESS_BACKGROUND_LOCATION. Live delivery tracking runs
/// in a `location` foreground service started while the app is on screen,
/// which needs foreground permission only.
class DeliveryPermissionPrefs {
  const DeliveryPermissionPrefs._();

  static String _notifDeclinedPrefKey(String agentId) =>
      'delivery_notif_permission_declined_${agentId.trim()}';

  /// Legacy keys written by earlier builds that requested background location.
  /// Cleared on first use so no stale consent record survives the migration.
  static const List<String> _legacyKeyPrefixes = <String>[
    'delivery_bg_location_disclosure_agreed_',
    'delivery_bg_location_disclosure_declined_',
    'delivery_bg_location_disclosure_ts_',
  ];

  /// Returns true if notification permission was previously declined for
  /// [agentId], so the coordinator does not spam Android's OS prompt.
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

  /// Deletes background-location consent flags written by previous versions.
  static Future<void> purgeLegacyBackgroundConsent(String agentId) async {
    final cleanId = agentId.trim();
    if (cleanId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final prefix in _legacyKeyPrefixes) {
        await prefs.remove('$prefix$cleanId');
      }
    } catch (_) {}
  }
}
