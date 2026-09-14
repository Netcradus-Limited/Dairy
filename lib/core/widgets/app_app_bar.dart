import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../localization/app_language.dart';
import '../responsive/responsive.dart';
import '../../providers/product_provider.dart';
import '../../providers/navigation_provider.dart';

/// Clean Production Header Bar for Mobile, Tablet & Desktop
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
    this.cartItemCount = 2,
    this.showSearch,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72.0);

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return tr('Good morning, 👋');
    if (h < 17) return tr('Good afternoon, 👋');
    return tr('Good evening, 👋');
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final currentIndex = ref.watch(navigationProvider);
    final showSearch =
        widget.showSearch ?? (currentIndex != 2 && currentIndex != 3);

    ref.listen<String>(productSearchQueryProvider, (prev, next) {
      if (_searchController.text != next) {
        _searchController.text = next;
        setState(() {});
      }
    });

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1.0)),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: widget.preferredSize.height,
          padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHorizontalPadding,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Brand Logo & Title on Desktop / Greeting on Mobile
              if (isDesktop) ...[
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
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            'assets/images/newlogo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.eco_rounded,
                              color: Color(0xFF063A24),
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
                                color: Color(0xFF063A24),
                                letterSpacing: 0.6,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              tr('Pure Milk. Pure Trust.'),
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ] else if (!_isMobileSearchOpen) ...[
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppTopAppBar._greeting(),
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

              // Location Pill (Deliver to dynamic location)
              if (isDesktop) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onLocationTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tr('Deliver to'),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  widget.deliveryLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Top Navigation Options (Home, Shop, Orders, Profile)
              if (isDesktop) ...[
                const SizedBox(width: 8),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TopNavButton(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: tr('Home'),
                        isSelected: currentIndex == 0,
                        onTap: () {
                          ref.read(navigationProvider.notifier).setIndex(0);
                        },
                      ),
                      const SizedBox(width: 4),
                      _TopNavButton(
                        icon: Icons.grid_view_outlined,
                        activeIcon: Icons.grid_view_rounded,
                        label: tr('Shop'),
                        isSelected: currentIndex == 1,
                        onTap: () {
                          ref.read(navigationProvider.notifier).setIndex(1);
                        },
                      ),
                      const SizedBox(width: 4),
                      _TopNavButton(
                        icon: Icons.local_shipping_outlined,
                        activeIcon: Icons.local_shipping_rounded,
                        label: tr('Orders'),
                        isSelected: currentIndex == 2,
                        onTap: () {
                          ref.read(navigationProvider.notifier).setIndex(2);
                        },
                      ),
                      const SizedBox(width: 4),
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
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 8),
              ],

              // Search Field
              if (showSearch) ...[
                if (isDesktop)
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 200, minWidth: 100),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
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
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
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
                else if (_isMobileSearchOpen)
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
                const SizedBox(width: AppSizes.p8),
              ],

              // Notification Button
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                  size: 23,
                ),
                onPressed: widget.onNotificationTap,
              ),

              const SizedBox(width: AppSizes.p4),

              // Cart Button with Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.textPrimary,
                      size: 23,
                    ),
                    onPressed: widget.onCartTap,
                  ),
                  if (widget.cartItemCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        child: Text(
                          '${widget.cartItemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
              ? const Color(0xFF063A24)
              : (_isHovered ? const Color(0xFFE2EBE5) : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF063A24).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? widget.activeIcon : widget.icon,
                    color: active
                        ? Colors.white
                        : (_isHovered
                            ? const Color(0xFF063A24)
                            : AppColors.textSecondary),
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active
                          ? Colors.white
                          : (_isHovered
                              ? const Color(0xFF063A24)
                              : AppColors.textSecondary),
                      letterSpacing: 0.15,
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
