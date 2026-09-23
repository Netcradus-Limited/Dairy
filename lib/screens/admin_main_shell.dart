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
import 'package:google_fonts/google_fonts.dart';
import '../models/staff_member.dart';
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

class AdminMainShell extends ConsumerStatefulWidget {
  const AdminMainShell({super.key});

  @override
  ConsumerState<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends ConsumerState<AdminMainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final bgColor = AppColors.bgOf(context);

    // Defense-in-depth: Ensure only authenticated admins/staff can render admin screens
    if (!user.canAccessAdminPortal) {
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
                  'You do not have administrative or staff privileges to access the admin portal.',
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
          return user.hasPermission(StaffPermission.viewDashboard)
              ? const DashboardScreen()
              : const _PermissionDeniedCard(moduleName: 'Dashboard');
        case 1:
          return user.hasPermission(StaffPermission.viewCustomers)
              ? const CustomersScreen()
              : const _PermissionDeniedCard(moduleName: 'Customers');
        case 2:
          return user.hasPermission(StaffPermission.viewSubscriptions)
              ? const AdminSubscriptionsScreen()
              : const _PermissionDeniedCard(moduleName: 'Subscriptions');
        case 3:
          return user.hasPermission(StaffPermission.viewProducts)
              ? const ProductsScreen()
              : const _PermissionDeniedCard(moduleName: 'Products');
        case 4:
          return user.hasPermission(StaffPermission.viewCategories)
              ? const CategoriesScreen()
              : const _PermissionDeniedCard(moduleName: 'Categories');
        case 5:
          return user.hasPermission(StaffPermission.viewOrders)
              ? const OrdersScreen()
              : const _PermissionDeniedCard(moduleName: 'Orders');
        case 6:
          return user.hasPermission(StaffPermission.viewDelivery)
              ? const DeliveryManagementScreen()
              : const _PermissionDeniedCard(moduleName: 'Delivery Management');
        case 7:
          return user.hasPermission(StaffPermission.manageDelivery)
              ? const DeliveryStaffScreen()
              : const _PermissionDeniedCard(moduleName: 'Delivery Staff');
        case 8:
          return user.hasPermission(StaffPermission.viewPayments)
              ? const PaymentsScreen()
              : const _PermissionDeniedCard(moduleName: 'Payments');
        case 9:
          return user.hasPermission(StaffPermission.viewNotifications)
              ? const NotificationsScreen()
              : const _PermissionDeniedCard(moduleName: 'Notifications');
        case 10:
          return user.hasPermission(StaffPermission.viewComplaints)
              ? const SupportScreen()
              : const _PermissionDeniedCard(moduleName: 'Support');
        case 11:
          return const AdminProfileScreen();
        case 12:
          return (user.hasPermission(StaffPermission.viewStaff) ||
                  user.hasPermission(StaffPermission.manageRoles))
              ? const StaffRolesScreen()
              : const _PermissionDeniedCard(moduleName: 'Staff & Roles');
        default:
          return const DashboardScreen();
      }
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: bgColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight <= 1.0 || constraints.maxWidth <= 1.0) {
              return const SizedBox.shrink();
            }
            return Row(
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
            );
          },
        ),
      );
    } else {
      // Mobile / Tablet with Drawer Navigation
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: bgColor,
        drawer: const Drawer(
          child: SidebarNavigation(isDrawer: true),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight <= 1.0 || constraints.maxWidth <= 1.0) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  AppHeader(
                    onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: getActiveScreen(adminProv.selectedNavIndex),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }
  }
}

class _PermissionDeniedCard extends StatelessWidget {
  final String moduleName;
  const _PermissionDeniedCard({required this.moduleName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_person_rounded, size: 56, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            Text(
              'Access Restricted: $moduleName',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your assigned staff role does not have permission to access the $moduleName module.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

