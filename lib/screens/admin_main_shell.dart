import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider;
import '../core/constants/app_colors.dart';
import '../core/responsive/responsive_layout.dart';
import '../providers/admin_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/app_header.dart';
import '../widgets/sidebar_navigation.dart';
import 'categories/categories_screen.dart';
import 'customers/customers_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'delivery/delivery_management_screen.dart';
import 'delivery_staff/delivery_staff_screen.dart';
import 'notifications/notifications_screen.dart';
import 'orders/orders_screen.dart';
import 'payments/payments_screen.dart';
import 'products/products_screen.dart';
import 'profile/admin_profile_screen.dart';
import 'staff/staff_roles_screen.dart';
import 'subscriptions/admin_subscriptions_screen.dart';
import 'support/support_screen.dart';

class AdminMainShell extends ConsumerWidget {
  const AdminMainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    final bgColor = AppColors.bgOf(context);

    // Defense-in-depth: Ensure only authenticated admins can render admin screens
    if (!user.isAdmin) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gpp_bad_rounded,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You do not have administrative privileges to access the admin portal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    if (user.isDelivery) {
                      context.go('/delivery');
                    } else if (user.id.isNotEmpty) {
                      context.go('/home');
                    } else {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Safe Screen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.freshGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final adminProv = provider.Provider.of<AdminProvider>(context);

    Widget getActiveScreen(int index) {
      switch (index) {
        case 0:
          return const DashboardScreen();
        case 1:
          return const CustomersScreen();
        case 2:
          return const AdminSubscriptionsScreen();
        case 3:
          return const ProductsScreen();
        case 4:
          return const CategoriesScreen();
        case 5:
          return const OrdersScreen();
        case 6:
          return const DeliveryManagementScreen();
        case 7:
          return const DeliveryStaffScreen();
        case 8:
          return const PaymentsScreen();
        case 9:
          return const NotificationsScreen();
        case 10:
          return const SupportScreen();
        case 11:
          return const AdminProfileScreen();
        case 12:
          return const StaffRolesScreen();
        default:
          return const DashboardScreen();
      }
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Row(
          children: [
            // Fixed Persistent Sidebar for Desktop
            const SidebarNavigation(isDrawer: false),
            // Right Main Content Area
            Expanded(
              child: Column(
                children: [
                  const AppHeader(),
                  Expanded(
                    child: getActiveScreen(adminProv.selectedNavIndex),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile / Tablet with Drawer Navigation
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: bgColor,
        drawer: const Drawer(
          child: SidebarNavigation(isDrawer: true),
        ),
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                onOpenDrawer: () => scaffoldKey.currentState?.openDrawer(),
              ),
              Expanded(
                child: getActiveScreen(adminProv.selectedNavIndex),
              ),
            ],
          ),
        ),
      );
    }
  }
}
