import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dairy_app/firebase_options.dart';
import 'package:dairy_app/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QA & Production Firebase Isolation Tests', () {
    test('Production options default strictly to sawariya-7efd4 on Android',
        () {
      final prodOptions = DefaultFirebaseOptions.optionsForEnvironment(
        isQa: false,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
      );

      expect(prodOptions.projectId, equals('sawariya-7efd4'));
      expect(
        prodOptions.appId,
        equals('1:325042169664:android:56d2e62240c424841d7ca5'),
      );
      expect(prodOptions.messagingSenderId, equals('325042169664'));
      expect(
        prodOptions.storageBucket,
        equals('sawariya-7efd4.firebasestorage.app'),
      );
      expect(
        prodOptions.apiKey,
        equals('AIzaSyCz0VKzg-CmNoFZz0j73dsyb_VHfwwcboo'),
      );
    });

    test('QA options isolate cleanly to sawariya-dairy-qa on Android', () {
      final qaOptions = DefaultFirebaseOptions.optionsForEnvironment(
        isQa: true,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
      );

      expect(qaOptions.projectId, equals('sawariya-dairy-qa'));
      expect(
        qaOptions.appId,
        equals('1:1044268289363:android:36510653ba9d5e4f2665a6'),
      );
      expect(qaOptions.messagingSenderId, equals('1044268289363'));
      expect(
        qaOptions.storageBucket,
        equals('sawariya-dairy-qa.firebasestorage.app'),
      );
      expect(
        qaOptions.apiKey,
        equals('AIzaSyB2W5-KJS5ht8uovmbI8Ui7ZzJ0k7GGTog'),
      );
    });

    test('Non-Android platforms retain existing production configurations', () {
      final iosQa = DefaultFirebaseOptions.optionsForEnvironment(
        isQa: true,
        isWebOverride: false,
        platformOverride: TargetPlatform.iOS,
      );
      final webQa = DefaultFirebaseOptions.optionsForEnvironment(
        isQa: true,
        isWebOverride: true,
        platformOverride: TargetPlatform.android,
      );

      expect(iosQa.projectId, equals('sawariya-7efd4'));
      expect(webQa.projectId, equals('sawariya-7efd4'));
    });

    test(
        'DefaultFirebaseOptions.currentPlatform obeys QA_FIREBASE dart-define on Android',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final current = DefaultFirebaseOptions.currentPlatform;
        if (DefaultFirebaseOptions.isQaFirebase) {
          expect(current.projectId, equals('sawariya-dairy-qa'));
          expect(
            current.appId,
            equals('1:1044268289363:android:36510653ba9d5e4f2665a6'),
          );
        } else {
          expect(current.projectId, equals('sawariya-7efd4'));
          expect(
            current.appId,
            equals('1:325042169664:android:56d2e62240c424841d7ca5'),
          );
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test(
        'Cloud Functions resolver fails closed with StateError when Firebase is uninitialized',
        () {
      expect(
        () => UserNotifier.resolveFunctionsProjectId(),
        throwsA(isA<StateError>()),
      );
      expect(
        () => UserNotifier.buildCallableLinkingUri('linkStaffAccount'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => UserNotifier.resolveFunctionsProjectId(
          isQaOverride: false,
          activeProjectIdProvider: () =>
              throw StateError('No Firebase App initialized'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => UserNotifier.resolveFunctionsProjectId(
          isQaOverride: true,
          activeProjectIdProvider: () =>
              throw StateError('No Firebase App initialized'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'Cloud Functions resolver fails closed with StateError when project ID is empty',
        () {
      expect(
        () => UserNotifier.resolveFunctionsProjectId(
          isQaOverride: false,
          projectIdOverride: '',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => UserNotifier.resolveFunctionsProjectId(
          isQaOverride: true,
          projectIdOverride: '   ',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => UserNotifier.buildCallableLinkingUri(
          'linkStaffAccount',
          isQaOverride: false,
          activeProjectIdProvider: () => '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'Production routing resolves sawariya-7efd4 and rejects mismatched project IDs',
        () {
      expect(
        UserNotifier.resolveFunctionsProjectId(
          isQaOverride: false,
          activeProjectIdProvider: () => 'sawariya-7efd4',
        ),
        equals('sawariya-7efd4'),
      );
      expect(
        UserNotifier.buildCallableLinkingUri(
          'linkStaffAccount',
          isQaOverride: false,
          activeProjectIdProvider: () => 'sawariya-7efd4',
        ).toString(),
        equals(
          'https://asia-south2-sawariya-7efd4.cloudfunctions.net/linkStaffAccount',
        ),
      );
      expect(
        UserNotifier.buildCallableLinkingUri(
          'linkDeliveryAgentAccount',
          isQaOverride: false,
          activeProjectIdProvider: () => 'sawariya-7efd4',
        ).toString(),
        equals(
          'https://asia-south2-sawariya-7efd4.cloudfunctions.net/linkDeliveryAgentAccount',
        ),
      );

      expect(
        () => UserNotifier.buildCallableLinkingUri(
          'linkStaffAccount',
          isQaOverride: false,
          activeProjectIdProvider: () => 'sawariya-dairy-qa',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'QA routing resolves only sawariya-dairy-qa and rejects production or unknown projects',
        () {
      expect(
        UserNotifier.resolveFunctionsProjectId(
          isQaOverride: true,
          activeProjectIdProvider: () => 'sawariya-dairy-qa',
        ),
        equals('sawariya-dairy-qa'),
      );
      expect(
        UserNotifier.buildCallableLinkingUri(
          'linkStaffAccount',
          isQaOverride: true,
          activeProjectIdProvider: () => 'sawariya-dairy-qa',
        ).toString(),
        equals(
          'https://asia-south2-sawariya-dairy-qa.cloudfunctions.net/linkStaffAccount',
        ),
      );
      expect(
        UserNotifier.buildCallableLinkingUri(
          'linkDeliveryAgentAccount',
          isQaOverride: true,
          activeProjectIdProvider: () => 'sawariya-dairy-qa',
        ).toString(),
        equals(
          'https://asia-south2-sawariya-dairy-qa.cloudfunctions.net/linkDeliveryAgentAccount',
        ),
      );

      expect(
        () => UserNotifier.buildCallableLinkingUri(
          'linkStaffAccount',
          isQaOverride: true,
          activeProjectIdProvider: () => 'sawariya-7efd4',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => UserNotifier.buildCallableLinkingUri(
          'linkDeliveryAgentAccount',
          isQaOverride: true,
          activeProjectIdProvider: () => 'unexpected-project',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'Cloud Functions URL obeys compile-time QA_FIREBASE flag and rejects mismatch',
        () {
      const expectedProjectId = DefaultFirebaseOptions.isQaFirebase
          ? 'sawariya-dairy-qa'
          : 'sawariya-7efd4';
      const mismatchedProjectId = DefaultFirebaseOptions.isQaFirebase
          ? 'sawariya-7efd4'
          : 'sawariya-dairy-qa';

      expect(
        UserNotifier.buildCallableLinkingUri(
          'linkStaffAccount',
          activeProjectIdProvider: () => expectedProjectId,
        ).toString(),
        equals(
          'https://asia-south2-$expectedProjectId.cloudfunctions.net/linkStaffAccount',
        ),
      );
      expect(
        () => UserNotifier.buildCallableLinkingUri(
          'linkStaffAccount',
          activeProjectIdProvider: () => mismatchedProjectId,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
