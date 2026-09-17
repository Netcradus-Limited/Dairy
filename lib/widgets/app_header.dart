import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_assets.dart';
import '../core/constants/app_colors.dart';
import '../core/responsive/responsive_layout.dart';
import '../core/widgets/category_image.dart';
import '../providers/admin_provider.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onOpenDrawer;

  const AppHeader({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final provider = context.watch<AdminProvider>();
    final formattedDate = DateFormat('d MMMM yyyy').format(DateTime.now());

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 24 : 16,
      ),
      child: isDesktop
          ? _buildDesktopHeader(context, provider, formattedDate)
          : _buildMobileHeader(context, provider, formattedDate),
    );
  }

  static String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning, Admin!';
    } else if (hour < 17) {
      return 'Good Afternoon, Admin!';
    } else {
      return 'Good Evening, Admin!';
    }
  }

  Widget _buildDesktopHeader(
      BuildContext context, AdminProvider provider, String formattedDate) {
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _getGreeting(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('👋', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Here's what's happening with Sawariya Dairy operations today.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Date Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Search Input
        SizedBox(
          width: 200,
          height: 42,
          child: TextField(
            onChanged: provider.setSearchQuery,
            style:
                GoogleFonts.plusJakartaSans(fontSize: 13, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Search anything...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              fillColor: cardBg,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cardBorder),
              ),
            ),
          ),
        ),
        // Notifications Bell
        _buildNotificationBell(context, provider),
      ],
    );
  }

  Widget _buildMobileHeader(
      BuildContext context, AdminProvider provider, String formattedDate) {
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onOpenDrawer != null)
              IconButton(
                onPressed: onOpenDrawer,
                icon: Icon(Icons.menu_rounded, color: textPrimary),
                style: IconButton.styleFrom(
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: cardBorder),
                  ),
                ),
              ),
            if (onOpenDrawer != null) const SizedBox(width: 10),
            // Logo Image in Mobile Header
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/newlogo.png',
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const CategoryImage(
                  imageUrl: AppAssets.milkPlaceholder,
                  size: 20,
                  radius: 5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sawariya Dairy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    formattedDate,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Mobile Theme Toggle removed
            _buildNotificationBell(context, provider),
          ],
        ),
        const SizedBox(height: 12),
        // Search Input for Mobile
        TextField(
          onChanged: provider.setSearchQuery,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Search anything...',
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            fillColor: cardBg,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cardBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell(BuildContext context, AdminProvider provider) {
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
            boxShadow: AppColors.cardShadow,
          ),
          child: IconButton(
            icon: Icon(Icons.notifications_none_rounded,
                size: 20, color: textSecondary),
            onPressed: () {
              provider.clearNotifications();
              showModalBottomSheet(
                context: context,
                backgroundColor: cardBg,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Alerts & Updates',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.ordersBlueBg,
                          child: Icon(Icons.local_shipping,
                              color: AppColors.primary, size: 20),
                        ),
                        title: Text('Morning Dispatch Complete'),
                        subtitle:
                            Text('486 milk packets delivered successfully.'),
                      ),
                      const ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.customersOrangeBg,
                          child: Icon(Icons.person_add,
                              color: AppColors.customersOrange, size: 20),
                        ),
                        title: Text('New Subscription Added'),
                        subtitle:
                            Text('Rahul Sharma subscribed to 2L A2 Cow Milk.'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (provider.unreadNotifications > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              alignment: Alignment.center,
              child: Text(
                '${provider.unreadNotifications}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
