import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../screens/notifications/notifications_screen.dart';
import '../theme/delivery_theme.dart';

/// Top header for Delivery Home screen matching Screen 1 in reference design.
class DeliveryHomeHeader extends ConsumerWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;

  const DeliveryHomeHeader({
    super.key,
    this.onMenuTap,
    this.onProfileTap,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(deliveryAgentProvider);
    final isOnline = agent.status == DeliveryStatus.onDuty;
    final unreadCountAsync = ref.watch(firestoreUnreadCountProvider);
    final unreadCount = unreadCountAsync.value ?? 0;

    // Use agent name or fallback
    final displayName = agent.name.trim().isNotEmpty
        ? agent.name.trim().split(' ').first
        : 'Partner';

    return Container(
      decoration: const BoxDecoration(
        gradient: DeliveryTheme.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          // Leaf decoration in corner
          const Positioned(
            top: 0,
            right: 0,
            width: 140,
            height: 90,
            child: CustomPaint(
              painter: BotanicalLeafPainter(
                leafColor: Color(0x2EFFFFFF),
                isRightAligned: true,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar: Menu icon & Notifications bell
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: onMenuTap ??
                            () {
                              Scaffold.maybeOf(context)?.openDrawer();
                            },
                        icon: const Icon(Icons.menu_rounded,
                            color: Colors.white, size: 26),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      // Notification bell with unread badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.notifications_none_rounded,
                                color: Colors.white, size: 26),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Greeting & Avatar Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getTimeGreeting(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFD7ECD7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$displayName 👋',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Delivering Freshness Together',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFC8E6C9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Agent Avatar & Online/Offline Pill
                      InkWell(
                        onTap: onProfileTap,
                        borderRadius: BorderRadius.circular(30),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFE8F5E9),
                                backgroundImage: agent.profileImageUrl !=
                                            null &&
                                        agent.profileImageUrl!.isNotEmpty
                                    ? NetworkImage(agent.profileImageUrl!)
                                    : null,
                                child: agent.profileImageUrl == null ||
                                        agent.profileImageUrl!.isEmpty
                                    ? const Icon(Icons.person_rounded,
                                        size: 26, color: DeliveryTheme.primary)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Online/Offline pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isOnline
                                      ? const Color(0xFFA5D6A7)
                                      : const Color(0xFFFFCDD2),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isOnline
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFE53935),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOnline ? 'Online' : 'Offline',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isOnline
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard curved green header for other screens (My Orders, Details, History, Earnings, Settings).
class DeliveryStandardHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final double bottomRadius;
  final Widget? bottom;

  const DeliveryStandardHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bottomRadius = 20,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: DeliveryTheme.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(bottomRadius),
          bottomRight: Radius.circular(bottomRadius),
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            width: 120,
            height: 70,
            child: CustomPaint(
              painter: BotanicalLeafPainter(
                leafColor: Color(0x24FFFFFF),
                isRightAligned: true,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      leading ??
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 20),
                          ),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (actions != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!,
                        )
                      else
                        const SizedBox(width: 48), // balance leading
                    ],
                  ),
                ),
                if (bottom != null) bottom!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
