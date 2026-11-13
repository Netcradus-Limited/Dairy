import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_live_location_provider.dart';
import '../../../providers/delivery_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/location_service.dart';
import '../widgets/delivery_location_disclosure_dialog.dart';

/// Centralized controller enforcing Google Play-compliant sequential location
/// disclosures, affirmative consent, and OS permissions across ALL mobile and
/// desktop delivery-partner duty and tracking entry points.
class DeliveryLocationCoordinator {
  const DeliveryLocationCoordinator._();

  static String _resolveUid(WidgetRef ref) {
    final agentId = ref.read(deliveryAgentProvider).id.trim();
    if (agentId.isNotEmpty) return agentId;
    final userId = ref.read(userProvider).id.trim();
    if (userId.isNotEmpty) return userId;
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Toggles the delivery partner's On Duty / Offline state cleanly.
  /// - Going Offline immediately stops location tracking without prompts.
  /// - Going Online executes the full 4-step compliant permission & consent sequence.
  static Future<void> toggleDutyWithConsent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final isCurrentlyOnline =
        ref.read(deliveryAgentProvider).status == DeliveryStatus.onDuty;

    if (isCurrentlyOnline) {
      ref.read(agentLiveLocationProvider.notifier).stopTracking();
      await ref.read(deliveryAgentProvider.notifier).setDuty(false);
      return;
    }

    await _activateWithConsentFlow(
      context,
      ref,
      updateDutyState: true,
      forceBackgroundPrompt: false,
    );
  }

  /// Enables live GPS tracking (or upgrades from foreground-only / consentRequired)
  /// without turning duty off.
  static Future<void> enableTrackingWithConsent(
    BuildContext context,
    WidgetRef ref, {
    bool forceBackgroundPrompt = false,
  }) async {
    await _activateWithConsentFlow(
      context,
      ref,
      updateDutyState: false,
      forceBackgroundPrompt: forceBackgroundPrompt,
    );
  }

  /// Toggles live location sharing button in the desktop top bar or settings.
  static Future<void> toggleTrackingWithConsent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final isTracking = ref.read(agentLiveLocationProvider);
    if (isTracking) {
      ref.read(agentLiveLocationProvider.notifier).stopTracking();
      return;
    }
    await _activateWithConsentFlow(
      context,
      ref,
      updateDutyState: false,
      forceBackgroundPrompt: true,
    );
  }

  static Future<void> _activateWithConsentFlow(
    BuildContext context,
    WidgetRef ref, {
    required bool updateDutyState,
    required bool forceBackgroundPrompt,
  }) async {
    // Role guard: Only verified delivery partners may initiate background shift tracking.
    final currentUser = ref.read(userProvider);
    if (currentUser.id.isNotEmpty && !currentUser.isDelivery) {
      return;
    }

    final uid = _resolveUid(ref);
    if (uid.isEmpty) return;

    final location = ref.read(locationServiceProvider);

    // Pre-check GPS hardware services
    final isServiceEnabled = await location.isLocationServiceEnabled();
    if (!context.mounted) return;
    if (!isServiceEnabled) {
      ref
          .read(gpsTrackingStatusProvider.notifier)
          .setStatus(GpsTrackingStatus.servicesDisabled);
      await _showEnableGpsDialog(context, location);
      return;
    }

    // ── STEP 1: Foreground Location Permission (Never mixed with background) ──
    var snapshot = await location.getPermissionSnapshot();
    if (!context.mounted) return;

    if (!snapshot.foregroundGranted) {
      final rawPerm = await location.checkPermission();
      if (!context.mounted) return;

      if (rawPerm == LocationPermission.deniedForever) {
        ref
            .read(gpsTrackingStatusProvider.notifier)
            .setStatus(GpsTrackingStatus.permissionDeniedForever);
        await _showOpenSettingsDialog(
          context,
          location,
          title: 'Location Permission Disabled',
          message:
              'Location permission was previously disabled. Please open App Settings and enable Location access to go Online.',
        );
        return;
      }

      final rationaleAccepted =
          await ForegroundLocationRationaleDialog.show(context);
      if (!context.mounted) return;
      if (!rationaleAccepted) {
        ref
            .read(gpsTrackingStatusProvider.notifier)
            .setStatus(GpsTrackingStatus.permissionDenied);
        return;
      }

      final fgResult = await location.requestForegroundLocationOnly();
      if (!context.mounted) return;

      if (fgResult == LocationResultStatus.permissionDeniedForever) {
        ref
            .read(gpsTrackingStatusProvider.notifier)
            .setStatus(GpsTrackingStatus.permissionDeniedForever);
        await _showOpenSettingsDialog(
          context,
          location,
          title: 'Location Permission Required',
          message:
              'Please allow location access in App Settings to enable delivery tracking.',
        );
        return;
      }

      if (fgResult != LocationResultStatus.success) {
        ref
            .read(gpsTrackingStatusProvider.notifier)
            .setStatus(GpsTrackingStatus.permissionDenied);
        return;
      }

      snapshot = await location.getPermissionSnapshot();
      if (!context.mounted) return;
    }

    // ── STEP 2: Android 13+ Notification Permission (Persistent tracking notice) ──
    if (snapshot.notificationGranted) {
      ref.read(notificationPermissionDeniedProvider.notifier).state = false;
      await DeliveryLocationDisclosureDialog.clearNotificationDeclinedForAgent(
          uid);
    } else {
      final alreadyDeclinedNotif =
          await DeliveryLocationDisclosureDialog.hasDeclinedNotificationForAgent(
              uid);
      if (!alreadyDeclinedNotif) {
        final granted = await location.requestNotificationPermission();
        if (!context.mounted) return;
        ref.read(notificationPermissionDeniedProvider.notifier).state =
            !granted;
        if (granted) {
          await DeliveryLocationDisclosureDialog
              .clearNotificationDeclinedForAgent(uid);
        } else {
          await DeliveryLocationDisclosureDialog
              .markNotificationDeclinedForAgent(uid);
        }
      } else {
        ref.read(notificationPermissionDeniedProvider.notifier).state = true;
      }
    }

    // ── STEP 3 & STEP 4: Prominent Background Disclosure + Background Permission ──
    bool useForegroundOnlyFallback = false;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (isAndroid) {
      final hasConsented =
          await DeliveryLocationDisclosureDialog.hasAcknowledgedForAgent(uid);
      final hasDeclined =
          await DeliveryLocationDisclosureDialog.hasDeclinedForAgent(uid);
      if (!context.mounted) return;

      if (!snapshot.backgroundGranted || !hasConsented) {
        if (hasDeclined && !forceBackgroundPrompt) {
          // User previously tapped "Not Now": degrade safely to foreground-only
          // without nagging or silently requesting ACCESS_BACKGROUND_LOCATION.
          useForegroundOnlyFallback = true;
        } else {
          final agreed = await DeliveryLocationDisclosureDialog.showIfNeeded(
            context,
            agentId: uid,
            forceShow: forceBackgroundPrompt || !hasConsented,
          );
          if (!context.mounted) return;

          if (!agreed) {
            // Explicit "Not Now": Never call requestBackgroundLocationPermission!
            useForegroundOnlyFallback = true;
          } else if (!snapshot.backgroundGranted) {
            // On Android 11+ (API 30+), guide user before launching system Location page.
            if (snapshot.sdkInt >= 30) {
              final proceedToSettings =
                  await _showAndroid11AllowAllTheTimeGuide(context);
              if (!context.mounted) return;
              if (!proceedToSettings) {
                useForegroundOnlyFallback = true;
              } else {
                final bgGranted =
                    await location.requestBackgroundLocationPermission();
                if (!context.mounted) return;
                if (!bgGranted) {
                  useForegroundOnlyFallback = true;
                }
              }
            } else {
              // Android 10 (API 29) standalone request
              final bgGranted =
                  await location.requestBackgroundLocationPermission();
              if (!context.mounted) return;
              if (!bgGranted) {
                useForegroundOnlyFallback = true;
              }
            }
          }
        }
      }
    }

    // Activate duty & start stream ONLY after explicit consent and checks complete
    if (updateDutyState) {
      await ref.read(deliveryAgentProvider.notifier).setDuty(true);
    }

    await ref.read(agentLiveLocationProvider.notifier).startTracking(
          explicitUserAction: true,
          foregroundOnlyFallback: useForegroundOnlyFallback,
        );
  }

  static Future<void> _showEnableGpsDialog(
    BuildContext context,
    LocationService location,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Turn On GPS',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Device location services (GPS) are turned off. Enable GPS to go Online and share active delivery tracking.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              location.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open GPS Settings'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showOpenSettingsDialog(
    BuildContext context,
    LocationService location, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
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
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              location.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('App Settings'),
          ),
        ],
      ),
    );
  }

  static Future<bool> _showAndroid11AllowAllTheTimeGuide(
    BuildContext context,
  ) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(
            'Select "Allow all the time"',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'On Android 11 and above, system location settings will open next. To keep delivery tracking working while minimized or screen-locked, choose "Allow all the time".\n\nIf you keep "Allow only while using the app", tracking will work in foreground-only mode.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Use Foreground Only'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue to Settings'),
            ),
          ],
        ),
      ),
    );
    return res == true;
  }
}
