import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_assets.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/app_network_image.dart';
import '../core/widgets/category_image.dart';
import '../providers/admin_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';

class NavItemData {
  final String title;
  final IconData icon;

  const NavItemData({required this.title, required this.icon});
}

class SidebarNavigation extends ConsumerWidget {
  final bool isDrawer;

  const SidebarNavigation({super.key, this.isDrawer = false});

  static const List<NavItemData> navItems = [
    NavItemData(title: 'Dashboard', icon: Icons.dashboard_rounded),
    NavItemData(title: 'Customers', icon: Icons.people_alt_outlined),
    NavItemData(title: 'Subscriptions', icon: Icons.calendar_month_rounded),
    NavItemData(title: 'Products', icon: Icons.inventory_2_outlined),
    NavItemData(title: 'Categories', icon: Icons.grid_view_rounded),
    NavItemData(title: 'Orders', icon: Icons.receipt_long_rounded),
    NavItemData(
        title: 'Delivery Management', icon: Icons.local_shipping_outlined),
    NavItemData(title: 'Delivery Staff', icon: Icons.directions_bike_rounded),
    NavItemData(title: 'Payments', icon: Icons.credit_card_rounded),
    NavItemData(title: 'Notifications', icon: Icons.notifications_none_rounded),
    NavItemData(
        title: 'Support / Complaints', icon: Icons.chat_bubble_outline_rounded),
    NavItemData(title: 'Admin Profile', icon: Icons.account_circle_outlined),
    NavItemData(title: 'Staff & Roles', icon: Icons.manage_accounts_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = context.watch<AdminProvider>();
    final user = ref.watch(userProvider);

    return Container(
      width: 260,
      height: double.infinity,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Brand Logo Header with Sawariya Dairy branding
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.sidebarBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sidebarActive.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/newlogo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Center(
                      child: CategoryImage(
                        imageUrl: AppAssets.milkPlaceholder,
                        size: 28,
                        radius: 7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sawariya Dairy',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textWhite,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Premium Milk Products',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.sidebarBorder, height: 1),
          // Navigation Items Scrollable List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: navItems.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 4),
              itemBuilder: (ctx, idx) {
                final item = navItems[idx];
                final isSelected = provider.selectedNavIndex == idx;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      provider.setNavIndex(idx);
                      if (isDrawer) {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.sidebarActive
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 19,
                            color: isSelected
                                ? AppColors.sidebarActiveText
                                : AppColors.sidebarText,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.sidebarActiveText
                                    : AppColors.sidebarText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.title == 'Subscriptions' &&
                              provider.activeSubscriptionsCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.freshGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${provider.activeSubscriptionsCount}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Light / Dark Mode Toggle Row
          const Divider(color: AppColors.sidebarBorder, height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.sidebarBgDarker,
            child: Row(
              children: [
                Icon(
                  provider.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  size: 18,
                  color:
                      provider.isDarkMode ? Colors.amber : Colors.orangeAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    provider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textWhite,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: provider.isDarkMode,
                    activeThumbColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                    onChanged: (val) => provider.toggleTheme(),
                  ),
                ),
              ],
            ),
          ),
          // User Profile Card Footer
          const Divider(color: AppColors.sidebarBorder, height: 1),
          Material(
            color: provider.selectedNavIndex == 11
                ? AppColors.sidebarHover
                : AppColors.sidebarBgDarker,
            child: InkWell(
              onTap: () {
                provider.setNavIndex(11);
                if (isDrawer) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.sidebarHover,
                      child: ClipOval(
                        child: (user.profileImageUrl != null &&
                                user.profileImageUrl!.trim().isNotEmpty)
                            ? AppNetworkImage(
                                imageUrl: user.profileImageUrl!.trim(),
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.name.trim().isNotEmpty &&
                                    user.name.trim() != 'Guest Customer'
                                ? user.name.trim()
                                : 'Sawariya Admin',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textWhite,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.isAdmin ? 'Super Admin' : 'Admin User',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.sidebarText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.sidebarText,
                      ),
                      tooltip: 'Sign Out',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () async {
                        final container = ProviderScope.containerOf(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text(
                              'Are you sure you want to log out of the admin panel?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Sign Out',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          container.read(cartProvider.notifier).clearLocalCart();
                          container.read(userProvider.notifier).clearSession();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
