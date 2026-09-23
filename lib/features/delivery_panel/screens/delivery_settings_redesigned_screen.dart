import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/battery_optimization_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/delivery_live_location_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/battery_optimization_service.dart';
import '../theme/delivery_theme.dart';
import '../widgets/delivery_header.dart';

/// Screen 8 — Settings Screen matching the reference design.
class DeliverySettingsRedesignedScreen extends ConsumerStatefulWidget {
  const DeliverySettingsRedesignedScreen({super.key});

  @override
  ConsumerState<DeliverySettingsRedesignedScreen> createState() =>
      _DeliverySettingsRedesignedScreenState();
}

class _DeliverySettingsRedesignedScreenState
    extends ConsumerState<DeliverySettingsRedesignedScreen> {
  bool _locationServicesEnabled = true;

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.logout_rounded,
                color: DeliveryTheme.statusCancelledText, size: 24),
            const SizedBox(width: 8),
            Text(
              'Confirm Logout',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out? Live GPS tracking will be safely terminated.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: DeliveryTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Clean GPS termination (Task 5 hardening)
              ref.read(agentLiveLocationProvider.notifier).stopTracking();
              ref.read(cartProvider.notifier).clearLocalCart();
              await ref.read(userProvider.notifier).clearSession();
              // Router handles redirect to /login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DeliveryTheme.statusCancelledText,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showBatteryOptimizationDialog() {
    final batteryState = ref.read(batteryOptimizationProvider);
    final isUnrestricted = !batteryState.isRestricted;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isUnrestricted
                  ? Icons.battery_charging_full_rounded
                  : Icons.battery_alert_rounded,
              color: isUnrestricted ? DeliveryTheme.primary : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              'Battery Optimization',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUnrestricted
                  ? 'Battery optimization is already disabled. Background GPS tracking runs reliably during deliveries.'
                  : 'Battery optimization may restrict background GPS tracking when the app is minimized. We recommend disabling it in Android Settings.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(
                color: DeliveryTheme.textSecondary,
              ),
            ),
          ),
          if (!isUnrestricted)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(batteryOptimizationServiceProvider)
                    .openBatteryOptimizationSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DeliveryTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Open Settings',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.plusJakartaSans(
                color: DeliveryTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsEnabled =
        ref.watch(settingsProvider.select((s) => s.notificationsEnabled));

    return Scaffold(
      backgroundColor: DeliveryTheme.background,
      body: Column(
        children: [
          // Header matching Screen 8
          DeliveryStandardHeader(
            title: 'Settings',
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
          ),

          // Settings Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                Container(
                  decoration: DeliveryTheme.cardDecoration(),
                  child: Column(
                    children: [
                      // 1. Notifications toggle (Persisted via SettingsProvider)
                      _buildSwitchTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        value: notificationsEnabled,
                        onChanged: (val) {
                          ref
                              .read(settingsProvider.notifier)
                              .updateNotifications(val);
                        },
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),

                      // 2. Location Services
                      _buildSwitchTile(
                        icon: Icons.location_on_outlined,
                        title: 'Location Services',
                        value: _locationServicesEnabled,
                        onChanged: (val) {
                          setState(() => _locationServicesEnabled = val);
                          if (val) {
                            ref
                                .read(agentLiveLocationProvider.notifier)
                                .startTracking();
                          } else {
                            ref
                                .read(agentLiveLocationProvider.notifier)
                                .stopTracking();
                          }
                        },
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),

                      // 3. Battery Optimization
                      _buildNavigationTile(
                        icon: Icons.battery_charging_full_rounded,
                        title: 'Battery Optimization',
                        trailingText: 'Configured',
                        onTap: _showBatteryOptimizationDialog,
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),

                      // 4. Privacy Policy
                      _buildNavigationTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: () => _showInfoDialog(
                          'Privacy Policy',
                          'Sawariya Dairy values your privacy. We collect location data during active delivery hours only to optimize deliveries and customer tracking.',
                        ),
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),

                      // 7. Terms & Conditions
                      _buildNavigationTile(
                        icon: Icons.article_outlined,
                        title: 'Terms & Conditions',
                        onTap: () => _showInfoDialog(
                          'Terms & Conditions',
                          'Delivery partners must adhere to dairy safety, hygiene, and scheduled delivery window standards at all times.',
                        ),
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),

                      // 8. About Sawariya Dairy
                      _buildNavigationTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About Sawariya Dairy',
                        onTap: () => _showInfoDialog(
                          'Sawariya Dairy',
                          'Sawariya Dairy v2.5.0\nPure dairy goodness delivered directly from farm to doorstep.',
                        ),
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),

                      // 9. Logout
                      ListTile(
                        onTap: _showLogoutDialog,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: DeliveryTheme.statusCancelledText,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Logout',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: DeliveryTheme.statusCancelledText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Bottom Branding matching Screen 8: "Delivering Freshness Always ♡"
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Delivering\nFreshness Always ♡',
                        style: GoogleFonts.caveat(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: DeliveryTheme.primary,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(
                        width: 60,
                        height: 25,
                        child: CustomPaint(
                          painter: BotanicalLeafPainter(
                            leafColor: Color(0x334CAF50),
                            isRightAligned: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: DeliveryTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DeliveryTheme.textDark,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: DeliveryTheme.primary,
        activeTrackColor: const Color(0xFFA5D6A7),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: DeliveryTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DeliveryTheme.textDark,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: DeliveryTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
          ],
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFB0BEC5),
            size: 20,
          ),
        ],
      ),
    );
  }
}
