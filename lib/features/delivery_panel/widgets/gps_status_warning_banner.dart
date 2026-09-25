import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/delivery_live_location_provider.dart';
import '../../../providers/delivery_provider.dart';
import '../../../models/delivery_boy_model.dart';
import '../../../services/location_service.dart';

/// Clean, colorful, responsive, non-blocking warning banner displayed in the
/// Delivery Panel when GPS hardware is turned off or location permissions are missing.
class GpsStatusWarningBanner extends ConsumerStatefulWidget {
  const GpsStatusWarningBanner({super.key});

  @override
  ConsumerState<GpsStatusWarningBanner> createState() =>
      _GpsStatusWarningBannerState();
}

class _GpsStatusWarningBannerState
    extends ConsumerState<GpsStatusWarningBanner> {
  bool _dismissed = false;
  GpsTrackingStatus? _lastStatus;

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(deliveryAgentProvider);
    final isOnline = agent.status == DeliveryStatus.onDuty;
    final gpsStatus = ref.watch(gpsTrackingStatusProvider);

    // If status changes (e.g. from error to servicesDisabled), reset dismissal
    if (_lastStatus != gpsStatus) {
      _lastStatus = gpsStatus;
      _dismissed = false;
    }

    // Only show if the agent is on-duty and GPS has an active error/disabled state
    if (!isOnline ||
        _dismissed ||
        gpsStatus == GpsTrackingStatus.active ||
        gpsStatus == GpsTrackingStatus.idle) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String title;
    final String message;
    final String actionLabel;
    final IconData iconData;
    final Color accentColor;
    final VoidCallback onAction;

    switch (gpsStatus) {
      case GpsTrackingStatus.servicesDisabled:
        title = 'GPS is Turned Off';
        message =
            'Device location services are disabled. Turn on GPS to allow real-time delivery tracking.';
        actionLabel = 'Turn on GPS';
        iconData = Icons.location_off_rounded;
        accentColor = const Color(0xFFDC2626); // Strong red alert
        onAction = () async {
          await ref.read(locationServiceProvider).openLocationSettings();
        };
        break;

      case GpsTrackingStatus.permissionDeniedForever:
        title = 'Location Permission Disabled';
        message =
            'Location permission is permanently denied. Allow location access in App Settings to enable delivery tracking.';
        actionLabel = 'Open Settings';
        iconData = Icons.app_settings_alt_rounded;
        accentColor = const Color(0xFFD97706); // Amber alert
        onAction = () async {
          await ref.read(locationServiceProvider).openAppSettings();
        };
        break;

      case GpsTrackingStatus.permissionDenied:
        title = 'Location Permission Required';
        message =
            'Location access is required to track active deliveries and navigate customer routes.';
        actionLabel = 'Grant Permission';
        iconData = Icons.near_me_disabled_rounded;
        accentColor = const Color(0xFFD97706);
        onAction = () async {
          await ref.read(agentLiveLocationProvider.notifier).startTracking();
        };
        break;

      case GpsTrackingStatus.error:
      default:
        title = 'Location Unavailable';
        message =
            'Unable to acquire GPS satellite fix. Please verify device location signal and retry.';
        actionLabel = 'Retry GPS';
        iconData = Icons.gps_off_rounded;
        accentColor = const Color(0xFFD97706);
        onAction = () async {
          await ref.read(agentLiveLocationProvider.notifier).refreshStatus();
        };
        break;
    }

    final bgColor = isDark
        ? (accentColor == const Color(0xFFDC2626)
            ? const Color(0xFF331111)
            : const Color(0xFF291B07))
        : (accentColor == const Color(0xFFDC2626)
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFFFFBEB));

    final borderColor = isDark
        ? (accentColor == const Color(0xFFDC2626)
            ? const Color(0xFF7F1D1D)
            : const Color(0xFF5E3A06))
        : (accentColor == const Color(0xFFDC2626)
            ? const Color(0xFFFECACA)
            : const Color(0xFFFDE68A));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          final iconWidget = Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              size: 20,
              color: accentColor,
            ),
          );

          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? borderColor : accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFF3F4F6) : AppColors.textPrimary,
                ),
              ),
            ],
          );

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.settings_outlined, size: 14),
                label: Text(
                  actionLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss',
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  setState(() {
                    _dismissed = true;
                  });
                },
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconWidget,
                    const SizedBox(width: 10),
                    Expanded(child: textContent),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Dismiss',
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        setState(() {
                          _dismissed = true;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: FilledButton.icon(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 14),
                    label: Text(
                      actionLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 10),
              Expanded(child: textContent),
              const SizedBox(width: 10),
              actionButtons,
            ],
          );
        },
      ),
    );
  }
}
