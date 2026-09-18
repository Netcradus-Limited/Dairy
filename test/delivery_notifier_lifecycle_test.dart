import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';

class TestUserNotifier extends StateNotifier<User> implements UserNotifier {
  TestUserNotifier(super.state);

  @override
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? profileImageUrl,
    String? vehicle,
    String? vehicleType,
    String? vehicleNumber,
    String? assignedZone,
  }) async {
    // Simulate async Firestore operation
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = User(
      id: state.id,
      name: name ?? state.name,
      phone: phone ?? state.phone,
      email: email ?? state.email,
      profileImageUrl: profileImageUrl ?? state.profileImageUrl,
      role: state.role,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestDeliveryNotifier extends DeliveryNotifier {
  final Completer<void> beforeStateCompleter = Completer<void>();
  final Completer<void> afterStateCompleter = Completer<void>();
  bool stateAssignmentAttemptedWhileUnmounted = false;

  TestDeliveryNotifier(super.ref, super.user);

  /// Simulates an async profile update method that waits for an external signal,
  /// allows checking mounted status, and performs state assignment safely.
  Future<void> runAsyncProfileUpdateWithPause() async {
    // Phase 1: Wait for signal (during which container/provider might be disposed)
    await beforeStateCompleter.future;

    // Phase 2: Attempt safe state assignment guarded by mounted
    if (!mounted) {
      stateAssignmentAttemptedWhileUnmounted = true;
      return;
    }

    state = state.copyWith(name: 'Updated Name');
    afterStateCompleter.complete();
  }
}

void main() {
  group('DeliveryNotifier & deliveryAgentProvider Lifecycle Tests', () {
    test(
        'deliveryAgentProvider does NOT dispose or recreate DeliveryNotifier when User profile details change',
        () async {
      const initialUser = User(
        id: 'delivery_agent_uid_1',
        name: 'Initial Name',
        phone: '+91 9876543210',
        role: 'delivery',
      );

      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => TestUserNotifier(initialUser)),
        ],
      );
      addTearDown(container.dispose);

      // Read initial notifier instance
      final notifierBefore = container.read(deliveryAgentProvider.notifier);
      expect(notifierBefore.mounted, isTrue);

      // Perform a profile update on userProvider (name/phone changed, but ID remains identical)
      await container.read(userProvider.notifier).updateProfile(
            name: 'Updated Profile Name',
            phone: '+91 9999988888',
          );

      // Verify userProvider state changed
      expect(container.read(userProvider).name, equals('Updated Profile Name'));

      // Read notifier after userProvider update
      final notifierAfter = container.read(deliveryAgentProvider.notifier);

      // The notifier MUST be the exact same instance and MUST remain mounted
      expect(
        identical(notifierBefore, notifierAfter),
        isTrue,
        reason:
            'deliveryAgentProvider must not dispose or recreate DeliveryNotifier when profile details change.',
      );
      expect(
        notifierBefore.mounted,
        isTrue,
        reason: 'DeliveryNotifier must remain mounted after user profile update.',
      );
    });

    test(
        'deliveryAgentProvider DOES recreate DeliveryNotifier when User ID changes (e.g. logout/relogin)',
        () async {
      const initialUser = User(
        id: 'delivery_agent_uid_1',
        name: 'Agent One',
        phone: '+91 9876543210',
        role: 'delivery',
      );

      final userNotifier = TestUserNotifier(initialUser);
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => userNotifier),
        ],
      );
      addTearDown(container.dispose);

      final notifierBefore = container.read(deliveryAgentProvider.notifier);
      expect(notifierBefore.mounted, isTrue);

      // Change user to a different user ID
      userNotifier.state = const User(
        id: 'delivery_agent_uid_2',
        name: 'Agent Two',
        phone: '+91 9876543211',
        role: 'delivery',
      );

      final notifierAfter = container.read(deliveryAgentProvider.notifier);

      // Because user.id changed, provider recreation SHOULD happen
      expect(
        identical(notifierBefore, notifierAfter),
        isFalse,
        reason:
            'deliveryAgentProvider should recreate DeliveryNotifier when user ID changes.',
      );
      expect(notifierBefore.mounted, isFalse);
      expect(notifierAfter.mounted, isTrue);
    });

    test(
        'Async operation completing after DeliveryNotifier is disposed does NOT throw "Tried to use DeliveryNotifier after dispose was called"',
        () async {
      const initialUser = User(
        id: 'delivery_agent_uid_1',
        name: 'Initial Name',
        phone: '+91 9876543210',
        role: 'delivery',
      );

      TestDeliveryNotifier? testNotifier;

      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => TestUserNotifier(initialUser)),
          deliveryAgentProvider.overrideWith((ref) {
            testNotifier = TestDeliveryNotifier(ref, initialUser);
            return testNotifier!;
          }),
        ],
      );

      // Initialize provider
      container.read(deliveryAgentProvider);
      expect(testNotifier, isNotNull);
      expect(testNotifier!.mounted, isTrue);

      // Start async operation which pauses before state assignment
      final asyncOperation = testNotifier!.runAsyncProfileUpdateWithPause();

      // Dispose the container (and thus the notifier) while the async operation is suspended
      container.dispose();
      expect(testNotifier!.mounted, isFalse);

      // Resume the async operation after disposal
      testNotifier!.beforeStateCompleter.complete();

      // Await async operation completion: it MUST complete cleanly without throwing StateError
      await expectLater(asyncOperation, completes);
      expect(testNotifier!.stateAssignmentAttemptedWhileUnmounted, isTrue);
    });
  });
}
