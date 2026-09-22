import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Callback type for verifying remote internet connectivity.
typedef ConnectivityChecker = Future<bool> Function();

/// Service responsible for testing and monitoring network availability without
/// introducing third-party native plugin dependencies.
class NetworkConnectivityService {
  final ConnectivityChecker _checker;
  final Duration checkInterval;

  NetworkConnectivityService({
    ConnectivityChecker? checker,
    this.checkInterval = const Duration(seconds: 15),
  }) : _checker = checker ?? _defaultChecker;

  static Future<bool> _defaultChecker() async {
    try {
      if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return true;
      final result = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// Performs a one-off connectivity check.
  Future<bool> checkConnectivity() async {
    try {
      return await _checker();
    } catch (_) {
      return false;
    }
  }

  /// Creates a periodic stream emitting connectivity state changes.
  Stream<bool> periodicStream() async* {
    yield await checkConnectivity();
    while (true) {
      await Future.delayed(checkInterval);
      yield await checkConnectivity();
    }
  }
}

/// Provider exposing the singleton [NetworkConnectivityService].
final networkConnectivityServiceProvider =
    Provider<NetworkConnectivityService>((ref) {
  return NetworkConnectivityService();
});

/// Riverpod StateNotifier tracking the delivery app's live network connectivity.
/// `true` = online/connected, `false` = offline.
class NetworkConnectivityNotifier extends StateNotifier<bool> {
  final NetworkConnectivityService _service;
  Timer? _timer;

  NetworkConnectivityNotifier(this._service, [bool initial = true])
      : super(initial) {
    _init();
  }

  void _init() {
    // Probe initial connectivity asynchronously
    checkNow();
    // Periodically verify connectivity
    _timer = Timer.periodic(_service.checkInterval, (_) => checkNow());
  }

  /// Explicitly sets the network status (useful for unit tests or manual override).
  void setOnline(bool isOnline) {
    if (state != isOnline) {
      state = isOnline;
    }
  }

  /// Immediately probes internet availability and updates [state].
  Future<bool> checkNow() async {
    final isConnected = await _service.checkConnectivity();
    if (mounted && state != isConnected) {
      state = isConnected;
    }
    return isConnected;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for network connectivity: returns `true` when online,
/// `false` when offline.
final networkConnectivityProvider =
    StateNotifierProvider<NetworkConnectivityNotifier, bool>((ref) {
  final service = ref.watch(networkConnectivityServiceProvider);
  return NetworkConnectivityNotifier(service);
});
