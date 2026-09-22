import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/services/auth_video_service.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/subscription_test_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode && kIsWeb) {
    setupSubscriptionWebBridge();
  }

  // Register the background message handler as early as possible. It must not
  // depend on the Riverpod container.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Preload authentication videos early for seamless playback
  AuthVideoService.instance.preload();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize FCM + local notifications exactly once (permission + listeners).
    ref.watch(fcmInitProvider);

    // Also initialize the traditional notification service (orderAlertProvider etc).
    ref.watch(notificationInitProvider);

    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);

    // Keep the global tr() lookup in sync with the persisted language choice.
    // Watching settingsProvider here also rebuilds MaterialApp (and the whole
    // widget tree below it) whenever the user switches language.
    AppLanguage.setLanguage(settings.languageCode);

    return MaterialApp.router(
      title: 'Sawariya Dairy',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      locale: Locale(settings.languageCode),
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}