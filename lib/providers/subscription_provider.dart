import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';
import '../services/subscription_service.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  final user = ref.watch(userProvider);
  return SubscriptionNotifier(service: service, user: user);
});

/// State class for subscription Riverpod provider
class SubscriptionState {
  final bool loading;
  final bool hasError;
  final String? errorMessage;
  final List<Subscription> subscriptions;
  final Subscription? subscription;
  final bool? hasActiveSubscription;
  final bool? hasExpiredSubscription;
  final bool? hasCancelledSubscription;

  const SubscriptionState({
    this.loading = false,
    this.hasError = false,
    this.errorMessage,
    this.subscriptions = const [],
    this.subscription,
    this.hasActiveSubscription,
    this.hasExpiredSubscription,
    this.hasCancelledSubscription,
  });

  List<Subscription> get activeSubscriptions =>
      subscriptions.where((s) => s.isActiveAndValid).toList();
  List<Subscription> get pausedSubscriptions =>
      subscriptions.where((s) => s.isPaused).toList();
  List<Subscription> get cancelledSubscriptions =>
      subscriptions.where((s) => s.isCancelled).toList();

  SubscriptionState copyWith({
    bool? loading,
    bool? hasError,
    String? errorMessage,
    List<Subscription>? subscriptions,
    Subscription? subscription,
    bool? hasActiveSubscription,
    bool? hasExpiredSubscription,
    bool? hasCancelledSubscription,
  }) {
    return SubscriptionState(
      loading: loading ?? this.loading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      subscriptions: subscriptions ?? this.subscriptions,
      subscription: subscription ?? this.subscription,
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      hasExpiredSubscription:
          hasExpiredSubscription ?? this.hasExpiredSubscription,
      hasCancelledSubscription:
          hasCancelledSubscription ?? this.hasCancelledSubscription,
    );
  }
}

/// Subscription notifier that connects to Firestore and manages multi-subscription lifecycle
class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionService _service;
  final User _user;
  StreamSubscription<List<Subscription>>? _streamSub;

  SubscriptionNotifier({
    required SubscriptionService service,
    required User user,
  })  : _service = service,
        _user = user,
        super(const SubscriptionState()) {
    if (_effectiveUid.isNotEmpty) {
      loadSubscription();
      _listenToSubscriptions();
    }
  }

  String get _effectiveUid {
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    } catch (_) {}
    return _user.id;
  }

  void _listenToSubscriptions() {
    final uid = _effectiveUid;
    if (uid.isEmpty) return;

    _streamSub?.cancel();
    _streamSub = _service.streamSubscriptionsForUser(uid).listen(
      (subs) {
        final hasActive = subs.any((s) => s.isActiveAndValid);
        final hasExpired =
            subs.any((s) => !s.isActiveAndValid && !s.isCancelled);
        final hasCancelled = subs.any((s) => s.isCancelled);
        final primary = subs.isNotEmpty
            ? subs.firstWhere((s) => s.isActiveAndValid,
                orElse: () => subs.first)
            : null;

        state = state.copyWith(
          loading: false,
          subscriptions: subs,
          subscription: primary,
          hasActiveSubscription: hasActive,
          hasExpiredSubscription: hasExpired,
          hasCancelledSubscription: hasCancelled,
          hasError: false,
          errorMessage: null,
        );
      },
      onError: (err) {
        state = state.copyWith(
          loading: false,
          hasError: true,
          errorMessage: err.toString(),
        );
      },
    );
  }

  /// Load the current user's subscriptions from Firestore
  Future<void> loadSubscription() async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: 'No authenticated user',
      );
      return;
    }

    state = state.copyWith(loading: true);
    try {
      final subs = await _service.getSubscriptionsForUser(uid);
      final hasActive = subs.any((s) => s.isActiveAndValid);
      final hasExpired = subs.any((s) => !s.isActiveAndValid && !s.isCancelled);
      final hasCancelled = subs.any((s) => s.isCancelled);
      final primary = subs.isNotEmpty
          ? subs.firstWhere((s) => s.isActiveAndValid, orElse: () => subs.first)
          : null;

      state = state.copyWith(
        loading: false,
        subscriptions: subs,
        subscription: primary,
        hasActiveSubscription: hasActive,
        hasExpiredSubscription: hasExpired,
        hasCancelledSubscription: hasCancelled,
        hasError: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Refresh the subscription state from Firestore
  Future<void> refresh() async {
    await loadSubscription();
  }

  /// Create a new subscription in Firestore
  Future<void> createSubscription(Subscription subscription) async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      throw Exception('No authenticated user found to create subscription.');
    }

    state = state.copyWith(loading: true);
    try {
      final created = await _service.createSubscription(uid, subscription);
      final updatedList = [
        created,
        ...state.subscriptions.where((s) => s.id != created.id),
      ];
      state = state.copyWith(
        loading: false,
        subscriptions: updatedList,
        subscription: created,
        hasActiveSubscription: true,
        hasError: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Update an existing subscription in Firestore
  Future<void> updateSubscription(Subscription subscription) async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      throw Exception('No authenticated user found to update subscription.');
    }

    state = state.copyWith(loading: true);
    try {
      final updated = await _service.updateSubscription(uid, subscription);
      final updatedList = state.subscriptions
          .map((s) => s.id == updated.id ? updated : s)
          .toList();
      if (!updatedList.any((s) => s.id == updated.id)) {
        updatedList.insert(0, updated);
      }
      state = state.copyWith(
        loading: false,
        subscriptions: updatedList,
        subscription: updated,
        hasActiveSubscription: updatedList.any((s) => s.isActiveAndValid),
        hasError: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Cancel the subscription in Firestore (sets status to cancelled, preserves doc)
  Future<void> cancelSubscription([String? subscriptionId]) async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      throw Exception('No authenticated user found to cancel subscription.');
    }

    final targetId = subscriptionId ?? state.subscription?.id;
    if (targetId == null || targetId.isEmpty) {
      throw Exception('No subscription found to cancel.');
    }

    state = state.copyWith(loading: true);
    try {
      final cancelled =
          await _service.cancelSubscription(uid, subscriptionId: targetId);
      final updatedList = state.subscriptions
          .map((s) => s.id == targetId ? cancelled : s)
          .toList();
      state = state.copyWith(
        loading: false,
        subscriptions: updatedList,
        subscription: cancelled,
        hasCancelledSubscription: true,
        hasActiveSubscription: updatedList.any((s) => s.isActiveAndValid),
        hasError: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Skip the next scheduled delivery
  Future<void> skipNextDelivery([String? subscriptionId]) async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      throw Exception('No authenticated user found to skip delivery.');
    }

    final targetId = subscriptionId ?? state.subscription?.id;
    state = state.copyWith(loading: true);
    try {
      final updated =
          await _service.skipNextDelivery(uid, subscriptionId: targetId);
      final updatedList = state.subscriptions
          .map((s) => s.id == updated.id ? updated : s)
          .toList();
      state = state.copyWith(
        loading: false,
        subscriptions: updatedList,
        subscription: updated,
        hasActiveSubscription: updatedList.any((s) => s.isActiveAndValid),
        hasError: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Pause the subscription (status -> paused)
  Future<void> pauseSubscription([String? subscriptionId]) async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      throw Exception('No authenticated user found to pause subscription.');
    }

    final targetId = subscriptionId ?? state.subscription?.id;
    state = state.copyWith(loading: true);
    try {
      final updated =
          await _service.pauseSubscription(uid, subscriptionId: targetId);
      final updatedList = state.subscriptions
          .map((s) => s.id == updated.id ? updated : s)
          .toList();
      state = state.copyWith(
        loading: false,
        subscriptions: updatedList,
        subscription: updated,
        hasActiveSubscription: updatedList.any((s) => s.isActiveAndValid),
        hasError: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Resume the subscription (status -> active)
  Future<void> resumeSubscription([String? subscriptionId]) async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      throw Exception('No authenticated user found to resume subscription.');
    }

    final targetId = subscriptionId ?? state.subscription?.id;
    state = state.copyWith(loading: true);
    try {
      final updated =
          await _service.resumeSubscription(uid, subscriptionId: targetId);
      final updatedList = state.subscriptions
          .map((s) => s.id == updated.id ? updated : s)
          .toList();
      state = state.copyWith(
        loading: false,
        subscriptions: updatedList,
        subscription: updated,
        hasActiveSubscription: updatedList.any((s) => s.isActiveAndValid),
        hasError: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Renew the subscription in Firestore
  Future<void> renewSubscription(
      {String? subscriptionId, Duration? duration}) async {
    final uid = _effectiveUid;
    if (uid.isEmpty) {
      throw Exception('No authenticated user found to renew subscription.');
    }

    final targetId = subscriptionId ?? state.subscription?.id;
    state = state.copyWith(loading: true);
    try {
      final renewed = await _service.renewSubscription(uid,
          subscriptionId: targetId, duration: duration);
      final updatedList = state.subscriptions
          .map((s) => s.id == renewed.id ? renewed : s)
          .toList();
      state = state.copyWith(
        loading: false,
        subscriptions: updatedList,
        subscription: renewed,
        hasActiveSubscription: updatedList.any((s) => s.isActiveAndValid),
        hasError: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}
