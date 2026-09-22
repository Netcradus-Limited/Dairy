import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/address_tile.dart';
import '../../models/address.dart';
import '../../providers/address_provider.dart';
import 'add_address_screen.dart';

/// Sawariya Dairy Phase 6 & 8 — Saved Addresses Selection Screen
class AddressScreen extends ConsumerWidget {
  const AddressScreen({super.key});

  Future<void> _onUseCurrentLocation(
      BuildContext context, WidgetRef ref) async {
    final newAddr = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAddressScreen(autoDetectLocation: true),
      ),
    );
    if (newAddr != null && context.mounted) {
      ref.read(selectedAddressIdProvider.notifier).state = newAddr.id;
      Navigator.pop(context, newAddr);
    }
  }

  Future<void> _onAddNewAddress(BuildContext context, WidgetRef ref) async {
    final newAddr = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAddressScreen(),
      ),
    );
    if (newAddr != null && context.mounted) {
      ref.read(selectedAddressIdProvider.notifier).state = newAddr.id;
      Navigator.pop(context, newAddr);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    final selectedId = ref.watch(selectedAddressIdProvider);
    final isLoading = ref.watch(addressLoadingProvider);
    final error = ref.watch(addressErrorProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Delivery Address'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content section
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  padding: EdgeInsets.symmetric(
                      horizontal: context.responsiveHorizontalPadding,
                      vertical: AppSizes.p16),
                  child: Builder(
                    builder: (context) {
                      if (isLoading && addresses.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryBlue,
                          ),
                        );
                      }
                      if (error != null && addresses.isEmpty) {
                        return Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSizes.p24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppColors.error.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 48, color: AppColors.error),
                                const SizedBox(height: 12),
                                const Text(
                                  'Failed to Load Addresses',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.only(bottom: AppSizes.p24),
                        children: [
                          // ── PROMINENT "USE CURRENT LOCATION" OPTION ──
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSizes.p16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryBlue.withValues(alpha: 0.08),
                                  AppColors.lightBlue.withValues(alpha: 0.25),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.35),
                                width: 1.4,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    _onUseCurrentLocation(context, ref),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlue,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.my_location_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Use Current Location',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryBlue,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Auto-detect GPS & fill delivery address',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 14,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ── ADD NEW ADDRESS BUTTON ──
                          OutlinedButton.icon(
                            onPressed: () => _onAddNewAddress(context, ref),
                            icon: const Icon(Icons.add_location_alt_outlined,
                                size: 18),
                            label: const Text(
                              'Add New Address Manually',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryBlue,
                              side: const BorderSide(
                                  color: AppColors.primaryBlue),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.p16),

                          if (addresses.isNotEmpty) ...[
                            // Section header
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'SAVED ADDRESSES',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...addresses.map((address) {
                              return AddressTile(
                                address: address,
                                isSelected: address.id == selectedId,
                                onSelect: () {
                                  ref
                                      .read(selectedAddressIdProvider.notifier)
                                      .state = address.id;
                                  Navigator.pop(context, address);
                                },
                                onEdit: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddAddressScreen(
                                          addressToEdit: address),
                                    ),
                                  );
                                },
                                onDelete: () {
                                  ref
                                      .read(addressesProvider.notifier)
                                      .removeAddress(address.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Address deleted successfully')),
                                  );
                                },
                                onSetDefault: () {
                                  ref
                                      .read(addressesProvider.notifier)
                                      .setDefault(address.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Default address updated')),
                                  );
                                },
                              );
                            }),
                          ] else ...[
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(AppSizes.p24),
                                decoration: const BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: AppSizes.borderLarge,
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_off_outlined,
                                        size: 44,
                                        color: AppColors.textSecondary),
                                    SizedBox(height: 10),
                                    Text(
                                      'No Saved Addresses',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Tap "Use Current Location" above or add an address manually.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
