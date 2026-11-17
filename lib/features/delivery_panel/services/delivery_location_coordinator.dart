import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
import '../widgets/delivery_location_permission_dialogs.dart';

/// Centralized controller enforcing the sequential location rationale and OS
/// permission flow across ALL mobile and desktop delivery-partner duty and
/// tracking entry points.
///
/// The sequence is: GPS hardware check -> foreground location rationale ->
/// foreground location permission -> notification permission -> start the
/// location foreground service. There is no background-location step, because
/// the app does not declare ACCESS_BACKGROUND_LOCATION.
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
    );
  }

  /// Enables live GPS tracking (or upgrades from foreground-only / consentRequired)
  /// without turning duty off.
  static Future<void> enableTrackingWithConsent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _activateWithConsentFlow(
      context,
      ref,
      updateDutyState: false,
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
    );
  }

  static Future<void> _activateWithConsentFlow(
    BuildContext context,
    WidgetRef ref, {
    required bool updateDutyState,
  }) async {
    // Role guard: Only verified delivery partners may initiate background shift tracking.
    final currentUser = ref.read(userProvider);
    if (currentUser.id.isNotEmpty && !currentUser.isDelivery) {
      return;
    }

    final uid = _resolveUid(ref);
    if (uid.isEmpty) return;

    // One-time cleanup: delete background-location consent flags persisted by
    // builds that still requested ACCESS_BACKGROUND_LOCATION.
    unawaited(DeliveryPermissionPrefs.purgeLegacyBackgroundConsent(uid));

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
      await DeliveryPermissionPrefs.clearNotificationDeclinedForAgent(
          uid);
    } else {
      final alreadyDeclinedNotif =
          await DeliveryPermissionPrefs.hasDeclinedNotificationForAgent(
              uid);
      if (!alreadyDeclinedNotif) {
        final granted = await location.requestNotificationPermission();
        if (!context.mounted) return;
        ref.read(notificationPermissionDeniedProvider.notifier).state =
            !granted;
        if (granted) {
          await DeliveryPermissionPrefs
              .clearNotificationDeclinedForAgent(uid);
        } else {
          await DeliveryPermissionPrefs
              .markNotificationDeclinedForAgent(uid);
        }
      } else {
        ref.read(notificationPermissionDeniedProvider.notifier).state = true;
      }
    }

    // No background-location step exists. Live tracking runs inside geolocator's
    // `location` foreground service, started here while the delivery panel is
    // on screen, which keeps GPS alive when the app is minimised or the screen
    // is locked using foreground permission alone. The app neither declares nor
    // requests ACCESS_BACKGROUND_LOCATION.

    // Activate duty & start stream ONLY after explicit consent and checks complete
    if (updateDutyState) {
      await ref.read(deliveryAgentProvider.notifier).setDuty(true);
    }

    await ref
        .read(agentLiveLocationProvider.notifier)
        .startTracking(explicitUserAction: true);
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
}
