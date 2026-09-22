import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/utils/validators.dart';
import '../../models/staff_member.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_badge.dart';

class StaffRolesScreen extends StatefulWidget {
  const StaffRolesScreen({super.key});

  @override
  State<StaffRolesScreen> createState() => _StaffRolesScreenState();
}

class _StaffRolesScreenState extends State<StaffRolesScreen> {
  String _searchQuery = '';
  String _roleFilter = 'All';
  String _statusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);
    final dividerColor = AppColors.dividerOf(context);

    // Filter staff members based on search and selected filters
    final allStaff = provider.staffMembers;
    final filteredStaff = allStaff.where((staff) {
      // 1. Role filter
      if (_roleFilter != 'All') {
        if (_roleFilter == 'Admin' && !staff.isSuperAdmin) return false;
        if (_roleFilter == 'Manager' && staff.role != 'manager') return false;
        if (_roleFilter == 'Dispatcher' && staff.role != 'dispatcher') {
          return false;
        }
        if (_roleFilter == 'Staff' && staff.role != 'staff') return false;
      }

      // 2. Status filter
      if (_statusFilter != 'All') {
        if (staff.status.toLowerCase() != _statusFilter.toLowerCase()) {
          return false;
        }
      }

      // 3. Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = staff.name.toLowerCase().contains(q);
        final matchEmail = staff.email.toLowerCase().contains(q);
        final matchPhone = staff.phone.toLowerCase().contains(q);
        final matchRole = staff.roleTitle.toLowerCase().contains(q);
        if (!matchName && !matchEmail && !matchPhone && !matchRole) {
          return false;
        }
      }

      return true;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header & Add Button ──────────────────────────────────────────
          if (isMobile) ...[
            Text(
              'Staff & Role Permissions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage administrative access, dispatcher routes, and granular permission matrices.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showAddEditStaffDialog(context, provider, null),
                icon: const Icon(Icons.person_add_rounded,
                    size: 18, color: Colors.white),
                label: Text(
                  'Add Staff Member',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff & Role Permissions',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage administrative access, dispatcher routes, and granular permission matrices.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showAddEditStaffDialog(context, provider, null),
                  icon: const Icon(Icons.person_add_rounded,
                      size: 18, color: Colors.white),
                  label: Text(
                    'Add Staff Member',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // ─── Summary KPI Cards ─────────────────────────────────────────────
          _buildKpiSummary(
            context,
            isDesktop,
            cardBg,
            cardBorder,
            textPrimary,
            textSecondary,
            allStaff,
          ),
          const SizedBox(height: 20),

          // ─── Search & Filters Bar ──────────────────────────────────────────
          _buildFilterBar(
            context,
            isDesktop,
            cardBg,
            cardBorder,
            textPrimary,
            textSecondary,
          ),
          const SizedBox(height: 16),

          // ─── Main Content (Table / Cards / Empty) ──────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: _buildStaffContent(
              context,
              isDesktop,
              provider,
              filteredStaff,
              dividerColor,
              textPrimary,
              textSecondary,
              textMuted,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// KPI Summary Grid (Total Staff, Active, Managers, Dispatchers)
  Widget _buildKpiSummary(
    BuildContext context,
    bool isDesktop,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    List<StaffMember> staff,
  ) {
    final total = staff.length;
    final active = staff.where((s) => s.isActive).length;
    final managers = staff.where((s) => s.role == 'manager').length;
    final dispatchers = staff.where((s) => s.role == 'dispatcher').length;

    final kpis = [
      (
        title: 'Total Staff',
        value: '$total',
        icon: Icons.badge_outlined,
        color: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
      ),
      (
        title: 'Active Members',
        value: '$active',
        icon: Icons.verified_user_outlined,
        color: AppColors.freshGreen,
        bgColor: const Color(0xFFE8FAF2),
      ),
      (
        title: 'Operations Managers',
        value: '$managers',
        icon: Icons.supervisor_account_outlined,
        color: const Color(0xFF7B1FA2),
        bgColor: const Color(0xFFF3E5F5),
      ),
      (
        title: 'Route Dispatchers',
        value: '$dispatchers',
        icon: Icons.alt_route_rounded,
        color: const Color(0xFFE65100),
        bgColor: const Color(0xFFFFF3E0),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: kpis.map((kpi) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kpi.bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(kpi.icon, color: kpi.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kpi.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            kpi.value,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((kpi) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kpi.bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(kpi.icon, color: kpi.color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kpi.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            kpi.value,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Search and Filtering Controls
  Widget _buildFilterBar(
    BuildContext context,
    bool isDesktop,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final searchField = SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by name, email, phone, or role...',
          hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12.5, color: textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: AppColors.primaryLight.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );

    final filterControls = Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Role Filter
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Role: ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            DropdownButton<String>(
              value: _roleFilter,
              underline: const SizedBox(),
              isDense: true,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              items: ['All', 'Admin', 'Manager', 'Dispatcher', 'Staff']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _roleFilter = val);
              },
            ),
          ],
        ),

        // Status Filter
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Status: ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            DropdownButton<String>(
              value: _statusFilter,
              underline: const SizedBox(),
              isDense: true,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              items: ['All', 'Active', 'Inactive']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _statusFilter = val);
              },
            ),
          ],
        ),
      ],
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(flex: 3, child: searchField),
          const SizedBox(width: 20),
          filterControls,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchField,
        const SizedBox(height: 10),
        filterControls,
      ],
    );
  }

  /// Main Content Builder
  Widget _buildStaffContent(
    BuildContext context,
    bool isDesktop,
    AdminProvider provider,
    List<StaffMember> staff,
    Color dividerColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (staff.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline_rounded,
                  size: 48, color: textMuted.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(
                'No Staff Members Found',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _searchQuery.isNotEmpty ||
                        _roleFilter != 'All' ||
                        _statusFilter != 'All'
                    ? 'Try adjusting your filters or search terms.'
                    : 'Get started by adding administrative staff members.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staff.length,
      separatorBuilder: (ctx, idx) => Divider(height: 1, color: dividerColor),
      itemBuilder: (ctx, idx) {
        final member = staff[idx];
        return _buildStaffTile(
          context,
          isDesktop,
          provider,
          member,
          textPrimary,
          textSecondary,
          textMuted,
        );
      },
    );
  }

  /// Staff Row / Tile
  Widget _buildStaffTile(
    BuildContext context,
    bool isDesktop,
    AdminProvider provider,
    StaffMember staff,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final roleColor = staff.isSuperAdmin
        ? const Color(0xFF1565C0)
        : (staff.role == 'manager'
            ? const Color(0xFF7B1FA2)
            : (staff.role == 'dispatcher'
                ? const Color(0xFFE65100)
                : AppColors.primary));

    final roleBg = roleColor.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: roleBg,
            child: Icon(
              staff.isSuperAdmin
                  ? Icons.shield_rounded
                  : (staff.role == 'manager'
                      ? Icons.supervisor_account_rounded
                      : (staff.role == 'dispatcher'
                          ? Icons.alt_route_rounded
                          : Icons.badge_outlined)),
              color: roleColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Name, Email & Phone
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          staff.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          staff.roleTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    staff.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: roleBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      staff.roleTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${staff.email}${staff.phone.isNotEmpty ? " • ${staff.phone}" : ""}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Permissions pill on desktop
          if (isDesktop)
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      staff.isSuperAdmin
                          ? 'Full Access (All Permissions)'
                          : '${staff.permissions.length} Permissions Assigned',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Status Badge
          StatusBadge.fromString(staff.status),
          const SizedBox(width: 8),

          // Action Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textSecondary, size: 20),
            onSelected: (action) {
              if (action == 'edit') {
                _showAddEditStaffDialog(context, provider, staff);
              } else if (action == 'permissions') {
                _showPermissionsDialog(context, provider, staff);
              } else if (action == 'toggle') {
                _confirmToggleStatus(context, provider, staff);
              } else if (action == 'delete') {
                _confirmDeleteStaff(context, provider, staff);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Details & Role'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'permissions',
                child: Row(
                  children: [
                    Icon(Icons.security_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Manage Permissions'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      staff.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: staff.isActive
                          ? const Color(0xFFF57C00)
                          : AppColors.freshGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(staff.isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Revoke Access',
                        style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Add / Edit Staff Dialog ─────────────────────────────────────────────
  void _showAddEditStaffDialog(
    BuildContext context,
    AdminProvider provider,
    StaffMember? existingStaff,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existingStaff?.name ?? '');
    final emailCtrl = TextEditingController(text: existingStaff?.email ?? '');
    final phoneCtrl = TextEditingController(text: existingStaff?.phone ?? '');
    String selectedRole = existingStaff?.role ?? 'staff';
    String selectedStatus = existingStaff?.status ?? 'Active';

    // Copy initial permissions or load default for role
    List<String> selectedPermissions = existingStaff != null
        ? List.from(existingStaff.permissions)
        : StaffRolePresets.getPermissionsForRole(selectedRole);

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDesktop = ResponsiveLayout.isDesktop(context);
            final cardBg = AppColors.cardBgOf(context);
            final cardBorder = AppColors.cardBorderOf(context);
            final textPrimary = AppColors.textPrimaryOf(context);
            final textSecondary = AppColors.textSecondaryOf(context);

            final screenWidth = MediaQuery.sizeOf(context).width;
            final dialogWidth = math.min(680.0, screenWidth - 32);

            return Dialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cardBorder),
              ),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.90,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dialog Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                existingStaff == null
                                    ? 'Add New Staff Member'
                                    : 'Edit Staff Member',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(dialogCtx),
                              icon: const Icon(Icons.close_rounded),
                              color: textSecondary,
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Form Fields in Scrollable Body
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Full Name
                                Text(
                                  'Full Name *',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: nameCtrl,
                                  validator: (v) =>
                                      AppValidators.validateFullName(v ?? ''),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Ramesh Chandra',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Email & Phone
                                if (isDesktop) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildEmailField(
                                            emailCtrl, textPrimary),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _buildPhoneField(
                                            phoneCtrl, textPrimary),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  _buildEmailField(emailCtrl, textPrimary),
                                  const SizedBox(height: 14),
                                  _buildPhoneField(phoneCtrl, textPrimary),
                                ],
                                const SizedBox(height: 14),

                                // Role & Status Selection
                                if (isDesktop) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildRoleField(
                                          selectedRole,
                                          textPrimary,
                                          (r) {
                                            if (r != null) {
                                              setModalState(() {
                                                selectedRole = r;
                                                selectedPermissions =
                                                    StaffRolePresets
                                                        .getPermissionsForRole(
                                                            r);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _buildStatusField(
                                          selectedStatus,
                                          textPrimary,
                                          (s) {
                                            if (s != null) {
                                              setModalState(() {
                                                selectedStatus = s;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  _buildRoleField(
                                    selectedRole,
                                    textPrimary,
                                    (r) {
                                      if (r != null) {
                                        setModalState(() {
                                          selectedRole = r;
                                          selectedPermissions =
                                              StaffRolePresets
                                                  .getPermissionsForRole(r);
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildStatusField(
                                    selectedStatus,
                                    textPrimary,
                                    (s) {
                                      if (s != null) {
                                        setModalState(() {
                                          selectedStatus = s;
                                        });
                                      }
                                    },
                                  ),
                                ],
                                const SizedBox(height: 20),

                                // Permissions Matrix Accordion
                                Text(
                                  'Permissions Matrix (${selectedPermissions.length} / ${StaffPermission.allPermissions.length} Active)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedRole == 'admin'
                                      ? 'Super Admins automatically receive unrestricted access to all modules.'
                                      : 'Customize module permissions for this staff member:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                _buildPermissionsAccordion(
                                  context,
                                  selectedPermissions,
                                  selectedRole == 'admin',
                                  (updatedPerms) {
                                    setModalState(() {
                                      selectedPermissions = updatedPerms;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 20),

                        // Dialog Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(dialogCtx),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      setModalState(() => isSubmitting = true);

                                      try {
                                        if (existingStaff == null) {
                                          await provider.addStaffMember(
                                            name: nameCtrl.text.trim(),
                                            email: emailCtrl.text.trim(),
                                            phone: phoneCtrl.text.trim(),
                                            role: selectedRole,
                                            permissions: selectedPermissions,
                                          );
                                        } else {
                                          await provider.updateStaffMember(
                                            staffId: existingStaff.id,
                                            name: nameCtrl.text.trim(),
                                            email: emailCtrl.text.trim(),
                                            phone: phoneCtrl.text.trim(),
                                            role: selectedRole,
                                            permissions: selectedPermissions,
                                            status: selectedStatus,
                                          );
                                        }

                                        if (dialogCtx.mounted) {
                                          Navigator.pop(dialogCtx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(existingStaff == null
                                                  ? 'Staff member "${nameCtrl.text.trim()}" onboarded successfully!'
                                                  : 'Staff member updated successfully!'),
                                              backgroundColor:
                                                  AppColors.success,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(
                                            () => isSubmitting = false);
                                        if (dialogCtx.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to save staff member: $e'),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      existingStaff == null
                                          ? 'Add Staff'
                                          : 'Save Changes',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmailField(
      TextEditingController emailCtrl, Color textPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Email is required';
            }
            if (!v.contains('@') || !v.contains('.')) {
              return 'Invalid email format';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'staff@sawariyadairy.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(
      TextEditingController phoneCtrl, Color textPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+91 98765 43210',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleField(String selectedRole, Color textPrimary,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned Role *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedRole,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: [
            ('admin', 'Super Admin'),
            ('manager', 'Operations Manager'),
            ('dispatcher', 'Route Dispatcher'),
            ('staff', 'Staff Member'),
          ]
              .map((r) => DropdownMenuItem(
                    value: r.$1,
                    child: Text(r.$2),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildStatusField(String selectedStatus, Color textPrimary,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Status *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedStatus,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: ['Active', 'Inactive']
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ─── Manage Permissions Dialog ───────────────────────────────────────────
  void _showPermissionsDialog(
    BuildContext context,
    AdminProvider provider,
    StaffMember staff,
  ) {
    List<String> selectedPermissions = List.from(staff.permissions);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cardBg = AppColors.cardBgOf(context);
            final cardBorder = AppColors.cardBorderOf(context);
            final textPrimary = AppColors.textPrimaryOf(context);
            final textSecondary = AppColors.textSecondaryOf(context);

            final screenWidth = MediaQuery.sizeOf(context).width;
            final dialogWidth = math.min(680.0, screenWidth - 32);

            return Dialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cardBorder),
              ),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Manage Permissions',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${staff.name} (${staff.roleTitle})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded),
                            color: textSecondary,
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildPermissionsAccordion(
                            context,
                            selectedPermissions,
                            staff.isSuperAdmin,
                            (updatedPerms) {
                              setModalState(() {
                                selectedPermissions = updatedPerms;
                              });
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(dialogCtx),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: isSaving || staff.isSuperAdmin
                                ? null
                                : () async {
                                    setModalState(() => isSaving = true);
                                    try {
                                      await provider.updateStaffMember(
                                        staffId: staff.id,
                                        name: staff.name,
                                        email: staff.email,
                                        phone: staff.phone,
                                        role: staff.role,
                                        permissions: selectedPermissions,
                                        status: staff.status,
                                      );

                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Permissions updated successfully!'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setModalState(() => isSaving = false);
                                      if (dialogCtx.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Failed to update permissions: $e'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Save Permissions',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
          },
        );
      },
    );
  }

  /// Permissions Category Accordion & Checkbox Builder
  Widget _buildPermissionsAccordion(
    BuildContext context,
    List<String> currentPermissions,
    bool isSuperAdmin,
    ValueChanged<List<String>> onChanged,
  ) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final cardBorder = AppColors.cardBorderOf(context);

    return Column(
      children: StaffPermission.categorizedPermissions.entries.map((entry) {
        final categoryName = entry.key;
        final perms = entry.value;
        final allKeys = perms.map((p) => p.key).toSet();
        final activeCount =
            perms.where((p) => currentPermissions.contains(p.key)).length;
        final isAllActive = activeCount == perms.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: cardBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExpansionTile(
            title: Text(
              categoryName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            subtitle: Text(
              isSuperAdmin
                  ? 'All permissions enabled (Super Admin)'
                  : '$activeCount / ${perms.length} enabled',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: activeCount > 0
                    ? AppColors.primary
                    : textSecondary,
              ),
            ),
            trailing: isSuperAdmin
                ? const Icon(Icons.lock_outline_rounded, size: 18)
                : null,
            children: [
              if (!isSuperAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          final updated = List<String>.from(currentPermissions);
                          if (isAllActive) {
                            updated.removeWhere((k) => allKeys.contains(k));
                          } else {
                            for (final k in allKeys) {
                              if (!updated.contains(k)) updated.add(k);
                            }
                          }
                          onChanged(updated);
                        },
                        child: Text(
                          isAllActive ? 'Deselect All' : 'Select All',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ...perms.map((perm) {
                final isChecked =
                    isSuperAdmin || currentPermissions.contains(perm.key);
                return CheckboxListTile(
                  value: isChecked,
                  enabled: !isSuperAdmin,
                  onChanged: (val) {
                    final updated = List<String>.from(currentPermissions);
                    if (val == true) {
                      if (!updated.contains(perm.key)) updated.add(perm.key);
                    } else {
                      updated.remove(perm.key);
                    }
                    onChanged(updated);
                  },
                  title: Text(
                    perm.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    perm.desc,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: textSecondary,
                    ),
                  ),
                  dense: true,
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Confirm Toggle Status ───────────────────────────────────────────────
  void _confirmToggleStatus(
    BuildContext context,
    AdminProvider provider,
    StaffMember staff,
  ) {
    final nextStatus = staff.isActive ? 'Inactive' : 'Active';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          staff.isActive
              ? 'Deactivate Staff Member?'
              : 'Activate Staff Member?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          staff.isActive
              ? 'Deactivating "${staff.name}" will immediately prevent them from logging in or performing actions in the Admin Panel.'
              : 'Activating "${staff.name}" will restore their administrative portal access.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.toggleStaffStatus(staff.id, nextStatus);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Staff status updated to $nextStatus'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update status: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: staff.isActive
                  ? const Color(0xFFF57C00)
                  : AppColors.freshGreen,
            ),
            child: Text(
              staff.isActive ? 'Deactivate' : 'Activate',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Confirm Delete Staff ────────────────────────────────────────────────
  void _confirmDeleteStaff(
    BuildContext context,
    AdminProvider provider,
    StaffMember staff,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Revoke Administrative Access?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.error,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently revoke administrative access for "${staff.name}" (${staff.email})? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.deleteStaffMember(staff.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Access revoked for "${staff.name}". Account removed.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete staff member: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(
              'Revoke Access',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
