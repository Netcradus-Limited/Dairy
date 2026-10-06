import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/subscription_test_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use path-based URL strategy so deep links like /terms-and-conditions
  // are visible to GoRouter instead of being discarded as base-path segments.
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode && kIsWeb) {
    setupSubscriptionWebBridge();
  }

  // Register the background message handler as early as possible. It must not
  // depend on the Riverpod container.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Deferred background initialization: runs after the first usable frame is painted
    // so notification registration does not block the first visible screen or trigger
    // unnecessary rebuilds of MaterialApp.router.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(fcmInitProvider);
        ref.read(notificationInitProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
