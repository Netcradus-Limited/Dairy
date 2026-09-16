import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  setupSubscriptionWebBridge();

  // Register the background message handler as early as possible. It must not
  // depend on the Riverpod container.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

    // Wire up app-level FCM message handling: initial message and opened-app
    // notifications. These are listened to once at app start so that taps on
    // notifications when the app was in background/terminated state are handled
    // even before the widget tree fully builds.
    // We use a once-only listener via a provider so it doesn't accumulate.
    registerFCMMessageListeners(ref);

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

/// Listens to FirebaseMessaging initial message and opened-app events once at
/// app start. This ensures that notification taps are handled regardless of
/// timing (e.g. if the listener inside NotificationService.init() runs later).
void registerFCMMessageListeners(WidgetRef ref) {
  try {
    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM] Firebase not initialized; skipping FCM message listeners.');
      return;
    }

    // Get initial message when app is opened from terminated state.
    final initialMessageFuture = FirebaseMessaging.instance.getInitialMessage();
    initialMessageFuture.then((RemoteMessage? message) {
      if (message != null) {
        final orderId = message.data['orderId'] ?? message.data['order_id'];
        if (orderId != null) {
          ref.read(lastTappedOrderIdProvider.notifier).state = orderId;
          debugPrint('[FCM] Initial message: set lastTappedOrderId to $orderId');
        }
      }
    }).catchError((e) {
      debugPrint('[FCM] Error getting initial message: $e');
    });

    // Listen for opened-app events (app was in background/terminated, user tapped notification).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final orderId = message.data['orderId'] ?? message.data['order_id'];
      if (orderId != null) {
        ref.read(lastTappedOrderIdProvider.notifier).state = orderId;
        debugPrint('[FCM] Opened-app message: set lastTappedOrderId to $orderId');
      }
      debugPrint('[FCM] onMessageOpenedApp triggered with data: ${message.data}');
    }).onError((Object error) {
      debugPrint('[FCM] onMessageOpenedApp error: $error');
    });
  } catch (e) {
    debugPrint('[FCM] Error registering FCM message listeners: $e');
  }
}