import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/battery_optimization_service.dart';

/// Immutable state describing battery optimization restrictions for delivery tracking.
@immutable
class BatteryOptimizationState {
  /// Whether Android battery optimization is actively restricting background tracking.
  final bool isRestricted;

  /// Whether the user has dismissed the warning banner in the current session.
  final bool isDismissed;

  /// Whether a check is currently in flight.
  final bool isLoading;

  const BatteryOptimizationState({
    this.isRestricted = false,
    this.isDismissed = false,
    this.isLoading = false,
  });

  /// The warning should only be displayed if battery optimization restricts the app
  /// and the delivery agent has not explicitly dismissed the banner.
  bool get shouldShowWarning => isRestricted && !isDismissed;

  BatteryOptimizationState copyWith({
    bool? isRestricted,
    bool? isDismissed,
    bool? isLoading,
  }) {
    return BatteryOptimizationState(
      isRestricted: isRestricted ?? this.isRestricted,
      isDismissed: isDismissed ?? this.isDismissed,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BatteryOptimizationState &&
        other.isRestricted == isRestricted &&
        other.isDismissed == isDismissed &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode => Object.hash(isRestricted, isDismissed, isLoading);

  @override
  String toString() =>
      'BatteryOptimizationState(isRestricted: $isRestricted, isDismissed: $isDismissed, isLoading: $isLoading)';
}

/// StateNotifier that manages battery optimization state across app lifecycle events.
class BatteryOptimizationNotifier
    extends StateNotifier<BatteryOptimizationState> {
  final BatteryOptimizationService _service;

  BatteryOptimizationNotifier(
    this._service, {
    BatteryOptimizationState initial = const BatteryOptimizationState(),
  }) : super(initial);

  /// Probes Android battery optimization status and updates state.
  ///
  /// Safe to call at key lifecycle points (Delivery Panel open, resumed from background,
  /// tracking session start). Does NOT poll continuously.
  Future<void> checkStatus() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    try {
      final isRestricted = await _service.isBatteryOptimizationRestricted();
      if (mounted) {
        state = state.copyWith(
          isRestricted: isRestricted,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('BatteryOptimizationNotifier: error checking status: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
        );
      }
    }
  }

  /// Dismisses the warning banner for the current session without disabling tracking.
  void dismiss() {
    state = state.copyWith(isDismissed: true);
  }

  /// Resets dismissal so the banner can re-appear if desired.
  void resetDismissal() {
    state = state.copyWith(isDismissed: false);
  }

  /// Opens the Android battery optimization settings.
  Future<bool> fixSettings() async {
    return await _service.openBatteryOptimizationSettings();
  }
}

/// Riverpod provider managing battery optimization state.
final batteryOptimizationProvider =
    StateNotifierProvider<BatteryOptimizationNotifier, BatteryOptimizationState>(
        (ref) {
  final service = ref.watch(batteryOptimizationServiceProvider);
  return BatteryOptimizationNotifier(service);
});
