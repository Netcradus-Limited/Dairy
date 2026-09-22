import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/app_network_image.dart';
import '../../models/delivery_staff_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_badge.dart';

class DeliveryStaffScreen extends StatelessWidget {
  const DeliveryStaffScreen({super.key});

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

    final filteredRiders = provider.riders.where((r) {
      if (provider.searchQuery.isEmpty) return true;
      final q = provider.searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) ||
          r.phone.contains(q) ||
          r.email.toLowerCase().contains(q) ||
          r.assignedZone.toLowerCase().contains(q) ||
          r.vehicle.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          if (isMobile) ...[
            Text(
              'Delivery Staff & Fleet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Fleet drivers, electric delivery vehicles, assigned zones, and live duty status.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRiderDialog(context, provider, null),
                icon: const Icon(Icons.person_add_alt_1_rounded,
                    size: 18, color: Colors.white),
                label: Text(
                  'Add Delivery Staff',
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
                        'Delivery Staff & Fleet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fleet drivers, electric delivery vehicles, assigned zones, and live duty status.',
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
                  onPressed: () => _showRiderDialog(context, provider, null),
                  icon: const Icon(Icons.person_add_alt_1_rounded,
                      size: 18, color: Colors.white),
                  label: Text(
                    'Add Delivery Staff',
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
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Error Banner
          if (provider.usersError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF87171)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.usersError!,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Grid / List View
          provider.usersLoading && provider.riders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : filteredRiders.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 48.0),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_bike_rounded,
                              size: 48,
                              color: AppColors.textMutedOf(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              provider.searchQuery.isEmpty
                                  ? 'No delivery staff registered yet.'
                                  : 'No delivery staff matching "${provider.searchQuery}".',
                              style: GoogleFonts.plusJakartaSans(
                                color: textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Click "Add Delivery Staff" to register a driver or fleet agent.',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textMutedOf(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRiders.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 2 : 1,
                        mainAxisExtent: isMobile ? 225 : 195,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (ctx, idx) {
                        final rider = filteredRiders[idx];
                        return InkWell(
                          onTap: () =>
                              _showRiderDetailsDialog(context, provider, rider),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.primaryLight
                                          .withValues(alpha: 0.2),
                                      child: rider.profileImageUrl != null &&
                                              rider.profileImageUrl!.isNotEmpty
                                          ? ClipOval(
                                              child: AppNetworkImage(
                                                imageUrl:
                                                    rider.profileImageUrl!,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Text(
                                                  rider.name.isNotEmpty
                                                      ? rider.name
                                                          .substring(0, 1)
                                                          .toUpperCase()
                                                      : 'D',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              rider.name.isNotEmpty
                                                  ? rider.name
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                  : 'D',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rider.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${rider.phone}${rider.assignedZone.isNotEmpty ? ' • ${rider.assignedZone}' : ''}',
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
                                    StatusBadge.fromString(
                                      rider.isOnline ? 'Online' : rider.status,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.electric_rickshaw_outlined,
                                        size: 16, color: textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        rider.vehicle.isNotEmpty
                                            ? '${rider.vehicle}${rider.vehicleNumber.isNotEmpty ? ' (${rider.vehicleNumber})' : ''}'
                                            : (rider.vehicleNumber.isNotEmpty
                                                ? rider.vehicleNumber
                                                : 'Vehicle not set'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(color: dividerColor),
                                if (isMobile) ...[
                                  Text(
                                    'Deliveries: ${rider.totalDeliveriesToday} done (${rider.pendingDeliveries} pending)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              size: 16, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            rider.rating != null
                                                ? '${rider.rating!.toStringAsFixed(1)} Rating'
                                                : '— Rating',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined,
                                                size: 16,
                                                color: AppColors.ordersBlue),
                                            tooltip: 'Edit Staff',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 24, minHeight: 24),
                                            onPressed: () => _showRiderDialog(
                                                context, provider, rider),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: Color(0xFFEF4444)),
                                            tooltip: 'Delete Staff',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 24, minHeight: 24),
                                            onPressed: () =>
                                                _showDeleteConfirmation(
                                                    context, provider, rider),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Deliveries: ${rider.totalDeliveriesToday} done (${rider.pendingDeliveries} pending)',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              size: 16, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            rider.rating != null
                                                ? '${rider.rating!.toStringAsFixed(1)} Rating'
                                                : '— Rating',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 16,
                                                color: AppColors.ordersBlue),
                                            tooltip: 'Edit Staff',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 24, minHeight: 24),
                                            onPressed: () => _showRiderDialog(
                                                context, provider, rider),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: Color(0xFFEF4444)),
                                            tooltip: 'Delete Staff',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 24, minHeight: 24),
                                            onPressed: () =>
                                                _showDeleteConfirmation(
                                                    context, provider, rider),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  void _showRiderDetailsDialog(
      BuildContext context, AdminProvider provider, DeliveryRider rider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
              child: rider.profileImageUrl != null &&
                      rider.profileImageUrl!.isNotEmpty
                  ? ClipOval(
                      child: AppNetworkImage(
                        imageUrl: rider.profileImageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          rider.name.isNotEmpty
                              ? rider.name.substring(0, 1).toUpperCase()
                              : 'D',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      rider.name.isNotEmpty
                          ? rider.name.substring(0, 1).toUpperCase()
                          : 'D',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rider.name,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Agent ID: ${rider.id}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textMutedOf(context),
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge.fromString(rider.isOnline ? 'Online' : rider.status),
          ],
        ),
        content: SizedBox(
          width: math.min(460.0, MediaQuery.sizeOf(context).width - 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(
                    context, Icons.phone_outlined, 'Phone', rider.phone.isNotEmpty ? rider.phone : '—'),
                const SizedBox(height: 10),
                _buildDetailRow(context, Icons.email_outlined, 'Email',
                    rider.email.isNotEmpty ? rider.email : '—'),
                const SizedBox(height: 10),
                _buildDetailRow(context, Icons.map_outlined, 'Assigned Zone',
                    rider.assignedZone.isNotEmpty ? rider.assignedZone : '—'),
                const SizedBox(height: 10),
                _buildDetailRow(
                    context,
                    Icons.electric_rickshaw_outlined,
                    'Vehicle / Mode',
                    rider.vehicle.isNotEmpty
                        ? '${rider.vehicle}${rider.vehicleNumber.isNotEmpty ? ' (${rider.vehicleNumber})' : ''}'
                        : (rider.vehicleNumber.isNotEmpty
                            ? rider.vehicleNumber
                            : '—')),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  Icons.wifi_rounded,
                  'Live Duty Status',
                  rider.isOnline ? 'Online (Available)' : 'Offline / Off-Duty',
                  valueColor: rider.isOnline
                      ? AppColors.revenueGreen
                      : AppColors.textMutedOf(context),
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                    context,
                    Icons.local_shipping_outlined,
                    'Deliveries Today',
                    '${rider.totalDeliveriesToday} Completed'),
                const SizedBox(height: 10),
            _buildDetailRow(
    context,
    Icons.star_rounded,
    'Customer Rating',
    rider.rating != null
        ? '${rider.rating!.toStringAsFixed(1)} / 5.0'
        : '—'),
const SizedBox(height: 10),
_buildDetailRow(
    context,
    Icons.calendar_today_outlined,
    'Joined Date',
    rider.joinedDate),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showRiderDialog(context, provider, rider);
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteConfirmation(context, provider, rider);
            },
            icon: const Icon(Icons.delete_outline_rounded,
                size: 16, color: Colors.white),
            label: const Text('Delete', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '—',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _showRiderDialog(
      BuildContext context, AdminProvider provider, DeliveryRider? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final vehicleCtrl = TextEditingController(text: existing?.vehicle ?? '');
    final vehicleNumCtrl =
        TextEditingController(text: existing?.vehicleNumber ?? '');
    final zoneCtrl =
        TextEditingController(text: existing?.assignedZone ?? '');
    final ratingCtrl = TextEditingController(
        text: existing?.rating != null ? existing!.rating!.toString() : '');
    String selectedStatus = existing?.status ?? 'Active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isNarrow = MediaQuery.sizeOf(ctx).width < 500;
          return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEdit ? 'Edit Delivery Staff' : 'Register New Delivery Staff',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: math.min(440.0, MediaQuery.sizeOf(ctx).width - 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Staff Full Name *'),
                  ),
                  const SizedBox(height: 12),
                  if (isNarrow) ...[
                    TextField(
                      controller: phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Phone Number *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Email Address'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: vehicleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Vehicle Model / Type'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: vehicleNumCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Registration No.'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: zoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Assigned Delivery Zone'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ratingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Rating (optional)'),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Phone Number *'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: emailCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Email Address'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: vehicleCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Vehicle Model / Type'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: vehicleNumCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Registration No.'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: zoneCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Assigned Delivery Zone'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: ratingCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Rating (optional)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Active', child: Text('Active / On Duty')),
                      DropdownMenuItem(value: 'Break', child: Text('On Break')),
                      DropdownMenuItem(
                          value: 'Offline', child: Text('Offline / Off-Duty')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedStatus = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final isOnline = selectedStatus.toLowerCase() == 'active';
                  final ratingText = ratingCtrl.text.trim();
                  final rating = ratingText.isNotEmpty
                      ? double.tryParse(ratingText)
                      : null;

                  if (isEdit) {
                    await provider.updateRider(
                      existing.copyWith(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        vehicle: vehicleCtrl.text.trim(),
                        vehicleNumber: vehicleNumCtrl.text.trim().toUpperCase(),
                        assignedZone: zoneCtrl.text.trim(),
                        status: selectedStatus,
                        rating: rating,
                        isOnline: isOnline,
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Staff "${nameCtrl.text}" updated successfully!')),
                      );
                    }
                  } else {
                    final riderId =
                        'RDR-${DateTime.now().millisecondsSinceEpoch}';
                    await provider.addRider(
                      DeliveryRider(
                        id: riderId,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty
                            ? '${nameCtrl.text.toLowerCase().replaceAll(' ', '')}@sawariyadairy.com'
                            : emailCtrl.text.trim(),
                        vehicle: vehicleCtrl.text.trim(),
                        vehicleNumber: vehicleNumCtrl.text.trim().toUpperCase(),
                        assignedZone: zoneCtrl.text.trim(),
                        totalDeliveriesToday: 0,
                        pendingDeliveries: 0,
                        rating: rating,
                        status: selectedStatus,
                        isOnline: isOnline,
                        joinedDate:
                            DateFormat('dd MMM yyyy').format(DateTime.now()),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Staff member "${nameCtrl.text}" added successfully!')),
                      );
                    }
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isEdit ? 'Save Changes' : 'Register Staff',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    ),
  );
}

  void _showDeleteConfirmation(
      BuildContext context, AdminProvider provider, DeliveryRider rider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Remove Delivery Staff',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove delivery staff "${rider.name}" (${rider.id}) from Firestore? Active order assignments will need to be reassigned.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondaryOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteRider(rider.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Staff member "${rider.name}" removed successfully.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
