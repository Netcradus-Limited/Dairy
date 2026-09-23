import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service responsible for querying and requesting Android battery optimization
/// exemptions to safeguard background/continuous GPS tracking for delivery agents.
class BatteryOptimizationService {
  static const MethodChannel _defaultChannel =
      MethodChannel('com.example.dairy_app/battery_optimization');

  final MethodChannel _channel;
  final TargetPlatform? _targetPlatformOverride;

  BatteryOptimizationService({
    MethodChannel? channel,
    TargetPlatform? targetPlatformOverride,
  })  : _channel = channel ?? _defaultChannel,
        _targetPlatformOverride = targetPlatformOverride;

  TargetPlatform get _platform =>
      _targetPlatformOverride ?? defaultTargetPlatform;

  /// Checks whether the application is exempt from Android battery optimizations
  /// (i.e. running unrestricted / ignoring optimizations).
  ///
  /// On non-Android platforms or web, returns `true` (optimization does not restrict GPS).
  /// If platform call fails or throws, gracefully fails safe by returning `true`.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || _platform != TargetPlatform.android) {
      return true;
    }
    if (WidgetsBinding.instance == null) {
      return true;
    }
    try {
      final bool? isIgnoring =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return isIgnoring ?? true;
    } on MissingPluginException {
      // In unit test or unmocked channel environments, fail safe
      return true;
    } on PlatformException catch (e) {
      debugPrint('BatteryOptimizationService: isIgnoringBatteryOptimizations failed: $e');
      return true;
    } catch (e) {
      debugPrint('BatteryOptimizationService: unexpected error: $e');
      return true;
    }
  }

  /// Convenience method that returns `true` if Android battery optimization is
  /// currently RESTRICTING background execution (i.e. NOT ignoring optimizations).
  Future<bool> isBatteryOptimizationRestricted() async {
    final isIgnoring = await isIgnoringBatteryOptimizations();
    return !isIgnoring;
  }

  /// Requests the user to disable battery optimizations or opens the relevant
  /// system battery settings page using Android cascading intents.
  ///
  /// Returns `true` if the intent was successfully opened, `false` otherwise.
  /// Never throws.
  Future<bool> openBatteryOptimizationSettings() async {
    if (kIsWeb || _platform != TargetPlatform.android) {
      return false;
    }
    if (WidgetsBinding.instance == null) {
      return false;
    }
    try {
      final bool? opened =
          await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('BatteryOptimizationService: openBatteryOptimizationSettings failed: $e');
      return false;
    } catch (e) {
      debugPrint('BatteryOptimizationService: unexpected error: $e');
      return false;
    }
  }
}

/// Riverpod provider exposing the singleton [BatteryOptimizationService].
final batteryOptimizationServiceProvider =
    Provider<BatteryOptimizationService>((ref) {
  return BatteryOptimizationService();
});
