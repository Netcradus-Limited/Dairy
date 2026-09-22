import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Determines whether an error is transient and safe to retry automatically.
bool isTransientError(Object error) {
  if (error is StateError ||
      error is ArgumentError ||
      error is AssertionError ||
      error is FormatException ||
      error is TypeError) {
    return false;
  }

  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return true;
  }

  if (error is FirebaseException) {
    switch (error.code.toLowerCase()) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'internal':
        return true;
      case 'permission-denied':
      case 'not-found':
      case 'already-exists':
      case 'failed-precondition':
      case 'unauthenticated':
        return false;
      default:
        // Check message for connectivity cues
        final msg = (error.message ?? '').toLowerCase();
        return msg.contains('network') ||
            msg.contains('offline') ||
            msg.contains('timeout') ||
            msg.contains('unavailable');
    }
  }

  final str = error.toString().toLowerCase();
  return str.contains('socket') ||
      str.contains('network') ||
      str.contains('connection') ||
      str.contains('offline') ||
      str.contains('timed out') ||
      str.contains('timeout') ||
      str.contains('deadline-exceeded') ||
      str.contains('unavailable');
}

/// Executes [operation] with safe exponential backoff retries for transient errors.
///
/// Throws the last encountered error immediately if it is a non-retryable error
/// (e.g. [StateError] or permission rejection) or if [maxAttempts] is exceeded.
Future<T> retryOperation<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 300),
  double backoffMultiplier = 2.0,
  bool Function(Object error)? shouldRetry,
}) async {
  int attempt = 0;
  Duration delay = initialDelay;

  while (true) {
    attempt++;
    try {
      return await operation();
    } catch (e) {
      final retryPredicate = shouldRetry ?? isTransientError;
      if (attempt >= maxAttempts || !retryPredicate(e)) {
        rethrow;
      }
      await Future.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
      );
    }
  }
}
