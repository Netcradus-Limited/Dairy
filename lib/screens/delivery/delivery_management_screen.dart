import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/delivery_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_badge.dart';

class DeliveryManagementScreen extends StatelessWidget {
  const DeliveryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final textMuted = AppColors.textMutedOf(context);
    final dividerColor = AppColors.dividerOf(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Routes & Dispatch',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          Text(
            'Monitor morning milk batches (5:00 AM - 7:00 AM) and evening supply corridors.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          // Today's Delivery Progress Overview
          Text(
            "Today's Delivery Progress",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTodaysProgressCard(
            context,
            isDesktop,
            provider,
            cardBg,
            cardBorder,
            textPrimary,
            textSecondary,
            textMuted,
          ),
          const SizedBox(height: 24),
          // Corridor Cards Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Active Delivery Corridors',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: const Key('add_delivery_route_button'),
                onPressed: () => _showRouteDialog(context, provider, null),
                icon: const Icon(Icons.add_road_rounded,
                    size: 16, color: Colors.white),
                label: Text(
                  'Add Route',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.corridorsLoading && provider.corridors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            )
          else if (provider.corridorsError != null &&
              provider.corridors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.corridorsError!,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (provider.corridors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined, size: 36, color: textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'No active delivery corridors registered yet.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Corridors will appear automatically as delivery staff and customer zones are added.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.corridors.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 2 : 1,
                mainAxisExtent: 140,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (ctx, idx) {
                final corridor = provider.corridors[idx];
                return Container(
                  padding: const EdgeInsets.all(16),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              corridor.routeName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryLight.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${corridor.subscribersCount} Subscriptions',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                                minWidth: 26, minHeight: 26),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            color: textMuted,
                            tooltip: 'Edit Corridor',
                            onPressed: () => _showRouteDialog(
                                context, provider, corridor),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              corridor.zone,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.electric_moped_outlined,
                              size: 16, color: textMuted),
                          const SizedBox(width: 4),
                          Text(
                            corridor.vehicleType,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 16, color: textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Rider: ${corridor.riderName}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            corridor.timing,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.revenueGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          // Batch Progress Table Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Today's Batch Deliveries Progress",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: const Key('create_delivery_batch_button'),
                onPressed: () => _showBatchDialog(context, provider, null),
                icon: const Icon(Icons.add_task_rounded,
                    size: 16, color: Colors.white),
                label: Text(
                  'Create Batch',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.deliveryBatchesLoading &&
              provider.deliveryBatches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            )
          else if (provider.deliveryBatchesError != null &&
              provider.deliveryBatches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.deliveryBatchesError!,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (provider.deliveryBatches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 36, color: textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'No delivery batches dispatched today.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active dispatch batches will appear here as orders are assigned to delivery partners.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.deliveryBatches.length,
                separatorBuilder: (ctx, idx) => Divider(color: dividerColor),
                itemBuilder: (ctx, idx) {
                  final batch = provider.deliveryBatches[idx];
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isDesktop
                        ? Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  batch.deliveryId,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      batch.staffName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      batch.zone,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${batch.completedCount} / ${batch.assignedCount} Delivered',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                        ),
                                        Text(
                                          '${(batch.completionPercentage * 100).toInt()}%',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                      value: batch.completionPercentage,
                                      backgroundColor: cardBorder,
                                      color: batch.completionPercentage >= 1.0
                                          ? AppColors.revenueGreen
                                          : AppColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                      minHeight: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              StatusBadge.fromString(batch.status),
                              const SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                color: textMuted,
                                tooltip: 'Edit Batch',
                                onPressed: () =>
                                    _showBatchDialog(context, provider, batch),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mobile Header: ID + Status + Edit
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      batch.deliveryId,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      StatusBadge.fromString(batch.status),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 28, minHeight: 28),
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 16),
                                        color: textMuted,
                                        tooltip: 'Edit Batch',
                                        onPressed: () => _showBatchDialog(
                                            context, provider, batch),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Rider and Zone Info
                              Text(
                                batch.staffName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                batch.zone,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              // Progress Counter and Bar
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${batch.completedCount} / ${batch.assignedCount} Delivered',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${(batch.completionPercentage * 100).toInt()}%',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: batch.completionPercentage,
                                backgroundColor: cardBorder,
                                color: batch.completionPercentage >= 1.0
                                    ? AppColors.revenueGreen
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 6,
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showRouteDialog(
    BuildContext context,
    AdminProvider provider,
    DeliveryCorridor? existing,
  ) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.routeName ?? '');
    final zoneCtrl = TextEditingController(text: existing?.zone ?? '');
    final subCtrl = TextEditingController(
        text: existing != null ? '${existing.subscribersCount}' : '0');
    final timingCtrl = TextEditingController(
        text: existing?.timing ?? '05:00 AM - 07:00 AM');
    final vehicleCtrl = TextEditingController(
        text: existing?.vehicleType ?? 'Delivery Vehicle');
    final customRiderCtrl = TextEditingController(
        text: existing?.riderName ?? '');

    String? selectedAgentId = existing?.agentId;
    String selectedRiderName = existing?.riderName ?? 'Unassigned';
    String selectedStatus = existing?.status ?? 'Active';

    final riders = provider.riders;
    if (existing == null && riders.isNotEmpty) {
      selectedAgentId = riders.first.id;
      selectedRiderName = riders.first.name;
      if (zoneCtrl.text.isEmpty && riders.first.assignedZone.isNotEmpty) {
        zoneCtrl.text = riders.first.assignedZone;
      }
      if (vehicleCtrl.text == 'Delivery Vehicle' &&
          riders.first.vehicle.isNotEmpty) {
        vehicleCtrl.text = riders.first.vehicle;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'Edit Delivery Corridor' : 'Add Delivery Corridor',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Route / Corridor Name *',
                        hintText: 'e.g. Morning Route 1 — North Zone',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: zoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Zone / Area *',
                              hintText: 'e.g. North Zone',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: subCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Subscribers Count',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (riders.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: riders.any((r) => r.id == selectedAgentId)
                            ? selectedAgentId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Delivery Rider',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Unassigned / Other', overflow: TextOverflow.ellipsis),
                          ),
                          ...riders.map((r) => DropdownMenuItem<String>(
                                value: r.id,
                                child: Text(
                                  '${r.name} (${r.phone})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedAgentId = val;
                            if (val != null) {
                              final matched =
                                  riders.firstWhere((r) => r.id == val);
                              selectedRiderName = matched.name;
                              if (zoneCtrl.text.isEmpty &&
                                  matched.assignedZone.isNotEmpty) {
                                zoneCtrl.text = matched.assignedZone;
                              }
                              if (matched.vehicle.isNotEmpty) {
                                vehicleCtrl.text = matched.vehicle;
                              }
                            } else {
                              selectedRiderName = 'Unassigned';
                            }
                          });
                        },
                      ),
                      if (selectedAgentId == null) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customRiderCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Rider Name (Manual)',
                            hintText: 'e.g. Rajesh Kumar',
                          ),
                          onChanged: (val) => selectedRiderName = val,
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: customRiderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Rider Name',
                          hintText: 'e.g. Rajesh Kumar',
                        ),
                        onChanged: (val) => selectedRiderName = val,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: timingCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Timing',
                              hintText: '05:00 AM - 07:00 AM',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: vehicleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle Type',
                              hintText: 'e.g. EV Bike, Van',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'Inactive', child: Text('Inactive')),
                        DropdownMenuItem(
                            value: 'Completed', child: Text('Completed')),
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
                key: const Key('submit_route_dialog_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final routeName = nameCtrl.text.trim();
                  final zone = zoneCtrl.text.trim();
                  if (routeName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a Route Name'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  if (zone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a Zone / Area'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  final rName = selectedAgentId != null
                      ? selectedRiderName
                      : (customRiderCtrl.text.trim().isNotEmpty
                          ? customRiderCtrl.text.trim()
                          : selectedRiderName);

                  final corridor = DeliveryCorridor(
                    id: isEdit
                        ? existing.id
                        : 'route_${DateTime.now().millisecondsSinceEpoch}',
                    routeName: routeName,
                    zone: zone,
                    riderName: rName,
                    agentId: selectedAgentId,
                    subscribersCount:
                        int.tryParse(subCtrl.text.trim()) ?? 0,
                    completedOrders:
                        isEdit ? existing.completedOrders : 0,
                    timing: timingCtrl.text.trim().isNotEmpty
                        ? timingCtrl.text.trim()
                        : '05:00 AM - 07:00 AM',
                    vehicleType: vehicleCtrl.text.trim().isNotEmpty
                        ? vehicleCtrl.text.trim()
                        : 'Delivery Vehicle',
                    status: selectedStatus,
                    orderIds: isEdit ? existing.orderIds : const [],
                  );

                  try {
                    if (isEdit) {
                      await provider.updateDeliveryRoute(corridor);
                    } else {
                      await provider.addDeliveryRoute(corridor);
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Corridor "$routeName" updated successfully!'
                                : 'Corridor "$routeName" created successfully!',
                          ),
                          backgroundColor: AppColors.revenueGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save corridor: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: Text(isEdit ? 'Save Changes' : 'Create Route'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBatchDialog(
    BuildContext context,
    AdminProvider provider,
    DeliveryBatch? existing,
  ) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final deliveryIdCtrl = TextEditingController(
        text: existing?.deliveryId ??
            '#DLV${DateTime.now().millisecondsSinceEpoch % 10000}');
    final zoneCtrl = TextEditingController(text: existing?.zone ?? '');
    final totalOrdersCtrl = TextEditingController(
        text: existing != null ? '${existing.totalOrders}' : '0');
    final completedOrdersCtrl = TextEditingController(
        text: existing != null ? '${existing.completedOrders}' : '0');
    final customStaffCtrl =
        TextEditingController(text: existing?.staffName ?? '');

    String? selectedAgentId = existing?.agentId;
    String selectedStaffName = existing?.staffName ?? 'Unassigned';
    String selectedStatus = existing?.status ?? 'Pending';

    final riders = provider.riders;
    if (existing == null && riders.isNotEmpty) {
      selectedAgentId = riders.first.id;
      selectedStaffName = riders.first.name;
      if (zoneCtrl.text.isEmpty && riders.first.assignedZone.isNotEmpty) {
        zoneCtrl.text = riders.first.assignedZone;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'Edit Delivery Batch' : 'Create Delivery Batch',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: deliveryIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Batch ID / Code *',
                              hintText: '#DLV101',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Batch Name (optional)',
                              hintText: 'Morning Milk Dispatch',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (riders.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: riders.any((r) => r.id == selectedAgentId)
                            ? selectedAgentId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Delivery Staff',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Unassigned / Other', overflow: TextOverflow.ellipsis),
                          ),
                          ...riders.map((r) => DropdownMenuItem<String>(
                                value: r.id,
                                child: Text(
                                  '${r.name} (${r.phone})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedAgentId = val;
                            if (val != null) {
                              final matched =
                                  riders.firstWhere((r) => r.id == val);
                              selectedStaffName = matched.name;
                              if (zoneCtrl.text.isEmpty &&
                                  matched.assignedZone.isNotEmpty) {
                                zoneCtrl.text = matched.assignedZone;
                              }
                            } else {
                              selectedStaffName = 'Unassigned';
                            }
                          });
                        },
                      ),
                      if (selectedAgentId == null) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customStaffCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Staff Name (Manual)',
                            hintText: 'e.g. Rajesh Kumar',
                          ),
                          onChanged: (val) => selectedStaffName = val,
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: customStaffCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Staff Name',
                          hintText: 'e.g. Rajesh Kumar',
                        ),
                        onChanged: (val) => selectedStaffName = val,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: zoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Zone / Corridor *',
                        hintText: 'e.g. Vijay Nagar',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: totalOrdersCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Orders',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: completedOrdersCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Completed Orders',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'On Route', child: Text('On Route')),
                        DropdownMenuItem(
                            value: 'Completed', child: Text('Completed')),
                        DropdownMenuItem(
                            value: 'Delayed', child: Text('Delayed')),
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
                key: const Key('submit_batch_dialog_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final deliveryId = deliveryIdCtrl.text.trim();
                  final zone = zoneCtrl.text.trim();
                  if (deliveryId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please enter a Batch / Delivery ID'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  if (zone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a Delivery Zone'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  final sName = selectedAgentId != null
                      ? selectedStaffName
                      : (customStaffCtrl.text.trim().isNotEmpty
                          ? customStaffCtrl.text.trim()
                          : selectedStaffName);

                  final total =
                      int.tryParse(totalOrdersCtrl.text.trim()) ?? 0;
                  final completed =
                      int.tryParse(completedOrdersCtrl.text.trim()) ?? 0;
                  final pending = (total - completed).clamp(0, 999999);

                  final batch = DeliveryBatch(
                    id: isEdit
                        ? existing.id
                        : 'batch_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim().isNotEmpty
                        ? nameCtrl.text.trim()
                        : deliveryId,
                    deliveryId: deliveryId,
                    deliveryDate:
                        isEdit ? existing.deliveryDate : DateTime.now(),
                    agentId: selectedAgentId,
                    staffName: sName.isNotEmpty && sName != 'Unassigned'
                        ? sName
                        : 'Delivery Partner',
                    zone: zone,
                    totalOrders: total,
                    completedOrders: completed,
                    pendingOrders: pending,
                    status: selectedStatus,
                    orderIds: isEdit ? existing.orderIds : const [],
                  );

                  try {
                    if (isEdit) {
                      await provider.updateDeliveryBatch(batch);
                    } else {
                      await provider.addDeliveryBatch(batch);
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Batch "$deliveryId" updated successfully!'
                                : 'Batch "$deliveryId" created successfully!',
                          ),
                          backgroundColor: AppColors.revenueGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save batch: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: Text(isEdit ? 'Save Changes' : 'Create Batch'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodaysProgressCard(
    BuildContext context,
    bool isDesktop,
    AdminProvider provider,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (provider.todaysDeliveryProgressLoading && provider.orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
          boxShadow: AppColors.cardShadow,
        ),
        child: const CircularProgressIndicator(),
      );
    }

    if (provider.todaysDeliveryProgressError != null &&
        provider.orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                provider.todaysDeliveryProgressError!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final progress = provider.todaysDeliveryProgress;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Real-Time Dispatch Status',
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
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (progress.completionPercentage >= 100.0 &&
                                    progress.total > 0)
                                ? AppColors.revenueGreen.withValues(alpha: 0.15)
                                : AppColors.primaryLight.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${progress.completionPercentage.toInt()}% Completed',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (progress.completionPercentage >= 100.0 &&
                                      progress.total > 0)
                                  ? AppColors.revenueGreen
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.completed} of ${progress.total} deliveries fulfilled',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Real-Time Dispatch Status',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${progress.completed} of ${progress.total} deliveries fulfilled',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (progress.completionPercentage >= 100.0 &&
                                progress.total > 0)
                            ? AppColors.revenueGreen.withValues(alpha: 0.15)
                            : AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${progress.completionPercentage.toInt()}% Completed',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (progress.completionPercentage >= 100.0 &&
                                  progress.total > 0)
                              ? AppColors.revenueGreen
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress.progressFraction,
            backgroundColor: cardBorder,
            color: (progress.completionPercentage >= 100.0 && progress.total > 0)
                ? AppColors.revenueGreen
                : AppColors.primary,
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 18),
          // KPI Metric Items
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                      child: _buildProgressMetric(
                        label: 'Total Orders',
                        value: '${progress.total}',
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.ordersBlue,
                        bgColor: AppColors.ordersBlueBg,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        label: 'Delivered',
                        value: '${progress.completed}',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.statusDelivered,
                        bgColor: const Color(0xFFE8FAF2),
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        label: 'Pending',
                        value: '${progress.pending}',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.statusPending,
                        bgColor: const Color(0xFFFFF4EC),
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        label: 'Cancelled',
                        value: '${progress.cancelled}',
                        icon: Icons.cancel_outlined,
                        color: AppColors.statusCancelled,
                        bgColor: const Color(0xFFF1F5F9),
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildResponsiveMetricItem(
                      context: context,
                      label: 'Total Orders',
                      value: '${progress.total}',
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.ordersBlue,
                      bgColor: AppColors.ordersBlueBg,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                    _buildResponsiveMetricItem(
                      context: context,
                      label: 'Delivered',
                      value: '${progress.completed}',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.statusDelivered,
                      bgColor: const Color(0xFFE8FAF2),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                    _buildResponsiveMetricItem(
                      context: context,
                      label: 'Pending',
                      value: '${progress.pending}',
                      icon: Icons.pending_actions_rounded,
                      color: AppColors.statusPending,
                      bgColor: const Color(0xFFFFF4EC),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                    _buildResponsiveMetricItem(
                      context: context,
                      label: 'Cancelled',
                      value: '${progress.cancelled}',
                      icon: Icons.cancel_outlined,
                      color: AppColors.statusCancelled,
                      bgColor: const Color(0xFFF1F5F9),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                  ],
                ),
          if (progress.total == 0 && progress.cancelled == 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: textMuted),
                const SizedBox(width: 6),
                Text(
                  'No deliveries scheduled for today yet.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveMetricItem({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final cardWidth = (screenWidth - 32 - 40 - 10) / 2;
        return SizedBox(
          width: cardWidth > 130 ? cardWidth : 130,
          child: _buildProgressMetric(
            label: label,
            value: value,
            icon: icon,
            color: color,
            bgColor: bgColor,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
        );
      },
    );
  }
}
