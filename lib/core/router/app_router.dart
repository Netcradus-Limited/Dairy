import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider;

import '../theme/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../screens/admin_main_shell.dart';

import '../../features/address/add_address_screen.dart';
import '../../features/address/address_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/delivery_panel/delivery_panel_screen.dart';
import '../../features/delivery_map/delivery_map_screen.dart';
import '../../features/main_layout/main_layout_screen.dart';
import '../../features/orders/order_details_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/product/product_details_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/profile/customer_support_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../models/product.dart';
import '../../providers/user_provider.dart';
import '../../features/subscription/subscriptions_screen.dart';
import '../../features/subscription/edit_subscription_screen.dart';
import 'auth_refresh.dart';

/// Global root navigator key for deep-link / push notification navigation.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

/// Central GoRouter configuration provider for Sawariya Dairy.
///
/// The router is created ONCE (not rebuilt on every auth state change). Auth
/// changes are observed via [refreshListenable] so redirection re-runs without
/// disposing/recreating the router (which would reset navigation to
/// [GoRouter.initialLocation] and can trigger mid-build constraint assertions).
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authRefreshNotifier,
    redirect: (context, state) {
      final user = ref.read(userProvider);
      final isLoggedIn = user.id.isNotEmpty;
      final isAdmin = user.isAdmin;
      final isDelivery = user.isDelivery;

      final path = state.matchedLocation;
      final isAuthPath = path == '/login' ||
          path == '/register' ||
          path == '/otp' ||
          path == '/splash' ||
          path == '/onboarding' ||
          path == '/forgot-password' ||
          path == '/reset-password';

      // 1. Unauthenticated users: redirect any protected path to /login
      if (!isLoggedIn) {
        return isAuthPath ? null : '/login';
      }

      // 2. Authenticated users:
      // If currently on an auth/onboarding screen, redirect to their role's home panel
      if (isAuthPath) {
        if (isAdmin) return '/admin';
        if (isDelivery) return '/delivery';
        return '/home';
      }

      // 3. Admin-only routes: strictly enforce Admin authorization
      final isAdminRoute = path == '/admin' || path.startsWith('/admin/');
      if (isAdminRoute && !isAdmin) {
        return isDelivery ? '/delivery' : '/home';
      }

      // 4. Delivery-only routes: strictly enforce Delivery Agent authorization
      final isDeliveryRoute = path == '/delivery' ||
          path == '/delivery-map' ||
          path.startsWith('/delivery/');
      if (isDeliveryRoute && !isDelivery) {
        return isAdmin ? '/admin' : '/home';
      }

      // 5. Role confinement: Admin and Delivery are routed to their respective panels
      final isCustomerRoute = path == '/home' ||
          path == '/shop' ||
          path == '/product-details' ||
          path == '/cart' ||
          path == '/address' ||
          path == '/add-address' ||
          path == '/checkout' ||
          path == '/settings' ||
          path == '/support' ||
          path.startsWith('/orders');

      if (isCustomerRoute) {
        if (isAdmin) return '/admin';
        if (isDelivery) return '/delivery';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return OtpScreen(
              targetDestination: extra['targetDestination'] as String?,
              isPasswordResetFlow:
                  extra['isPasswordResetFlow'] as bool? ?? false,
            );
          } else if (extra is String) {
            return OtpScreen(targetDestination: extra);
          }
          return const OtpScreen();
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainLayoutScreen(),
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) => const ShopScreen(),
      ),
      GoRoute(
        path: '/product-details',
        builder: (context, state) {
          final product = state.extra as Product;
          return ProductDetailsScreen(product: product);
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/address',
        builder: (context, state) => const AddressScreen(),
      ),
      GoRoute(
        path: '/add-address',
        builder: (context, state) => const AddAddressScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/orders/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderDetailsRouteScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const CustomerSupportScreen(),
      ),
      GoRoute(
        path: '/subscriptions',
        builder: (context, state) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: '/edit-subscription',
        builder: (context, state) => const EditSubscriptionScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => provider.MultiProvider(
          providers: [
            provider.ChangeNotifierProvider(create: (_) => AdminProvider()),
          ],
          child: provider.Consumer<AdminProvider>(
            builder: (context, adminProvider, child) {
              return Theme(
                data: adminProvider.isDarkMode
                    ? AdminTheme.darkTheme
                    : AdminTheme.lightTheme,
                child: const AdminMainShell(),
              );
            },
          ),
        ),
      ),
      GoRoute(
        path: '/delivery',
        builder: (context, state) => const DeliveryPanelScreen(),
      ),
      GoRoute(
        path: '/delivery-map',
        builder: (context, state) => const DeliveryMapScreen(),
      ),
    ],
  );
});
