import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../localization/app_language.dart';
import '../responsive/responsive.dart';
import 'app_network_image.dart';
import '../../providers/product_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';

/// Clean Production Header Bar matching Sawariya Dairy modern UI design
class AppTopAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final String title;
  final String deliveryLocation;
  final VoidCallback? onLocationTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onCartTap;
  final int cartItemCount;
  final bool? showSearch;

  const AppTopAppBar({
    super.key,
    this.title = 'Sawariya Dairy',
    this.deliveryLocation = 'Select location',
    this.onLocationTap,
    this.onSearchTap,
    this.onNotificationTap,
    this.onCartTap,
    this.cartItemCount = 3,
    this.showSearch,
  });

  @override
  Size get preferredSize => const Size.fromHeight(82.0);

  static String _greetingText() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  ConsumerState<AppTopAppBar> createState() => _AppTopAppBarState();
}

class _AppTopAppBarState extends ConsumerState<AppTopAppBar> {
  late final TextEditingController _searchController;
  bool _isMobileSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(productSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    ref.read(productSearchQueryProvider.notifier).state = val;
    if (ref.read(navigationProvider) != 1) {
      ref.read(navigationProvider.notifier).setIndex(1);
    }
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(productSearchQueryProvider.notifier).state = '';
    setState(() {});
  }

  void _showUserDropdown(BuildContext context) {
    final user = ref.read(userProvider);
    final displayName = user.name.trim().isNotEmpty &&
            user.name.trim() != 'Guest Customer' &&
            user.name.trim() != 'Sawariya Customer'
        ? user.name.trim()
        : 'Akash';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 76),
        alignment: Alignment.topRight,
        child: Container(
          width: 260,
          margin: const EdgeInsets.only(right: 20, top: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF072E1C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1B6B4C), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Header Card
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1B6B4C),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: (user.profileImageUrl != null &&
                                user.profileImageUrl!.trim().isNotEmpty)
                            ? AppNetworkImage(
                                imageUrl: user.profileImageUrl!.trim(),
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFFC7E2D6),
                                    size: 24,
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF0D4830),
                                child: const Center(
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFFC7E2D6),
                                    size: 24,
                                  ),
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
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (user.phone.isNotEmpty ||
                              (user.email != null && user.email!.isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                user.phone.isNotEmpty
                                    ? user.phone
                                    : (user.email ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFFC7E2D6),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF0F4E34), height: 1),
              // View Profile Option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(navigationProvider.notifier).setIndex(3);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            color: Color(0xFFC7E2D6), size: 19),
                        const SizedBox(width: 10),
                        Text(
                          tr('My Profile'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFC7E2D6), size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(color: Color(0xFF0F4E34), height: 1),
              // Log Out Option
              Material(
                color: Colors.transparent,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: InkWell(
                  borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLogoutDialog(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded,
                            color: Color(0xFFFF7B7B), size: 19),
                        const SizedBox(width: 10),
                        Text(
                          tr('Log Out'),
                          style: const TextStyle(
                            color: Color(0xFFFF7B7B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 10),
            Text(tr('Log Out'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          tr('Are you sure you want to log out of Sawariya Dairy?'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              tr('Cancel'),
              style: const TextStyle(
                  color: Color(0xFF4A5568), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).clearLocalCart();
              ref.read(userProvider.notifier).clearSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              tr('Log Out'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final screenWidth = MediaQuery.of(context).size.width;
    final currentIndex = ref.watch(navigationProvider);
    final showSearch =
        widget.showSearch ?? (currentIndex != 2 && currentIndex != 3);
    final user = ref.watch(userProvider);
    final unreadNotificationCount = ref.watch(unreadNotificationsCountProvider);

    String displayName = 'Akash';
    if (user.name.trim().isNotEmpty &&
        user.name.trim() != 'Guest Customer' &&
        user.name.trim() != 'Sawariya Customer') {
      displayName = user.name.trim().split(' ').first;
    }

    ref.listen<String>(productSearchQueryProvider, (prev, next) {
      if (_searchController.text != next) {
        _searchController.text = next;
        setState(() {});
      }
    });

    Widget leftSection = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand Logo & Title
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              ref.read(navigationProvider.notifier).setIndex(0);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 38,
                  width: 38,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/newlogo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.eco_rounded,
                      color: Color(0xFF0F4A2F),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SAWARIYA DAIRY',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F4A2F),
                        letterSpacing: 0.4,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('Pure Milk. Pure Trust.'),
                      style: const TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Location Pill (Deliver to Anandibai Joshi Road, Pune)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onLocationTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 17,
                    color: Color(0xFF0F4A2F),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('Deliver to'),
                          style: const TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          widget.deliveryLocation.isNotEmpty
                              ? widget.deliveryLocation
                              : 'Anandibai Joshi Road, Pune',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    Widget centerSection = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopNavButton(
          icon: Icons.home_rounded,
          activeIcon: Icons.home_rounded,
          label: tr('Home'),
          isSelected: currentIndex == 0,
          onTap: () {
            ref.read(navigationProvider.notifier).setIndex(0);
          },
        ),
        const SizedBox(width: 6),
        _TopNavButton(
          icon: Icons.grid_view_rounded,
          activeIcon: Icons.grid_view_rounded,
          label: tr('Shop'),
          isSelected: currentIndex == 1,
          onTap: () {
            ref.read(navigationProvider.notifier).setIndex(1);
          },
        ),
        const SizedBox(width: 6),
        _TopNavButton(
          icon: Icons.local_shipping_outlined,
          activeIcon: Icons.local_shipping_rounded,
          label: tr('Orders'),
          isSelected: currentIndex == 2,
          onTap: () {
            ref.read(navigationProvider.notifier).setIndex(2);
          },
        ),
        const SizedBox(width: 6),
        _TopNavButton(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: tr('Profile'),
          isSelected: currentIndex == 3,
          onTap: () {
            ref.read(navigationProvider.notifier).setIndex(3);
          },
        ),
      ],
    );

    Widget rightSection = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Field
        if (showSearch) ...[
          SizedBox(
            width: screenWidth > 1300 ? 175 : 140,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 12.0,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: tr('Search products...'),
                hintStyle: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 17,
                  color: Color(0xFF64748B),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 15,
                          color: Color(0xFF64748B),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        splashRadius: 14,
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF0F4A2F),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Notification Button with red dot badge
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onNotificationTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF1E293B),
                    size: 19,
                  ),
                  if (unreadNotificationCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        // Cart Button with Orange Count Badge
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onCartTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    color: Color(0xFF1E293B),
                    size: 19,
                  ),
                  if (widget.cartItemCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '${widget.cartItemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // User Greeting Pill with uploaded profile photo and logout menu
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showUserDropdown(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4A2F),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F4A2F).withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFC7E2D6),
                    ),
                    child: ClipOval(
                      child: (user.profileImageUrl != null &&
                              user.profileImageUrl!.trim().isNotEmpty)
                          ? AppNetworkImage(
                              imageUrl: user.profileImageUrl!.trim(),
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'T',
                                  style: const TextStyle(
                                    color: Color(0xFF0F4A2F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'T',
                                style: const TextStyle(
                                  color: Color(0xFF0F4A2F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(AppTopAppBar._greetingText()),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Right Tagline (Fresh & Natural for a Healthier You) on wider desktop screens
        if (screenWidth >= 1200) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fresh & Natural',
                    style: GoogleFonts.caveat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F4A2F),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFF1B6B4C),
                    size: 13,
                  ),
                ],
              ),
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'for a Healthier You',
                      style: GoogleFonts.caveat(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F4A2F),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    left: 0,
                    child: Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B6B4C).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );

    Widget desktopContent = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leftSection,
        Flexible(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: centerSection,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: rightSection,
        ),
      ],
    );

    Widget mobileContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!_isMobileSearchOpen) ...[
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(AppTopAppBar._greetingText()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('Fresh dairy, delivered daily!'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Search Field on Mobile
        if (showSearch) ...[
          if (_isMobileSearchOpen)
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: tr('Search milk, curd, paneer, ghee...'),
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _isMobileSearchOpen = false;
                        });
                      },
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            splashRadius: 16,
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 0.8,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 0.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF005F38),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.search_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () {
                ref.read(navigationProvider.notifier).setIndex(1);
                setState(() {
                  _isMobileSearchOpen = true;
                });
                widget.onSearchTap?.call();
              },
            ),
          const SizedBox(width: 8),
        ],

        // Notification Button on Mobile
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onNotificationTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF1E293B),
                    size: 19,
                  ),
                  if (unreadNotificationCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        // Cart Button on Mobile
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onCartTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    color: Color(0xFF1E293B),
                    size: 19,
                  ),
                  if (widget.cartItemCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '${widget.cartItemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      height: widget.preferredSize.height,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bghome.png'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          height: widget.preferredSize.height,
          padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHorizontalPadding.clamp(10.0, 24.0),
            vertical: 6,
          ),
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isDesktop ? desktopContent : mobileContent,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNavButton extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopNavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TopNavButton> createState() => _TopNavButtonState();
}

class _TopNavButtonState extends State<_TopNavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1B6B4C)
              : (_isHovered ? const Color(0xFFF1F5F9) : Colors.transparent),
          borderRadius: BorderRadius.circular(24),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF1B6B4C).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: active ? 16 : 10,
                vertical: 7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? widget.activeIcon : widget.icon,
                    color: active ? Colors.white : const Color(0xFF1E293B),
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
