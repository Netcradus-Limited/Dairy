import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../providers/settings_provider.dart';
import '../../core/localization/app_language.dart';
import '../../widgets/settings_tile.dart';
import '../../features/profile/legal_policies_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDesktop = context.isDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr('App Settings')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHorizontalPadding,
          vertical: 20,
        ),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 700 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(tr('Notifications')),
                _card([
                  SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: tr('Notifications'),
                    subtitle: tr('Manage notification preferences'),
                    onTap: null,
                    trailing: Switch(
                      value: settings.notificationsEnabled,
                      activeColor: AppColors.primary,
                      onChanged: notifier.updateNotifications,
                    ),
                  ),
                  if (settings.notificationsEnabled) ...[
                    const _Divider(),
                    SettingsTile(
                      icon: Icons.notifications_active_outlined,
                      title: tr('Push Notifications'),
                      subtitle: tr('Order & delivery alerts on this device'),
                      enabled: settings.notificationsEnabled,
                      trailing: Switch(
                        value: settings.pushNotifications,
                        activeColor: AppColors.primary,
                        onChanged: settings.notificationsEnabled
                            ? notifier.updatePushNotifications
                            : null,
                      ),
                    ),
                    const _Divider(),
                    SettingsTile(
                      icon: Icons.email_outlined,
                      title: tr('Email Notifications'),
                      subtitle: tr('Summary & promotional emails'),
                      enabled: settings.notificationsEnabled,
                      trailing: Switch(
                        value: settings.emailNotifications,
                        activeColor: AppColors.primary,
                        onChanged: settings.notificationsEnabled
                            ? notifier.updateEmailNotifications
                            : null,
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 16),
                _sectionTitle(tr('Preferences')),
                _card([
                  SettingsTile(
                    icon: Icons.map_outlined,
                    title: tr('Navigation'),
                    subtitle: _navigationLabel(settings.navigationApp),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () => _showNavigationDialog(context, ref),
                  ),
                  const _Divider(),
                  SettingsTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    subtitle: _languageLabel(settings.languageCode),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () => _showLanguageDialog(context, ref),
                  ),
                  const _Divider(),
                  SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: _themeLabel(settings.themeMode),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () => _showThemeDialog(context, ref),
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionTitle('Legal & Privacy'),
                _card([
                  SettingsTile(
                    icon: Icons.policy_outlined,
                    title: 'Legal & Policies',
                    subtitle: 'Privacy Policy, Terms, Refunds & Delivery',
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalPoliciesScreen(),
                        ),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  String _navigationLabel(NavigationApp app) {
    switch (app) {
      case NavigationApp.googleMaps:
        return 'Google Maps';
      case NavigationApp.appleMaps:
        return 'Apple Maps';
      case NavigationApp.waze:
        return 'Waze';
    }
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'hi':
        return 'हिंदी (Hindi)';
      default:
        return 'English';
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _showNavigationDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).navigationApp;
    showDialog<NavigationApp>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Default Navigation App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: NavigationApp.values.map((app) {
            return RadioListTile<NavigationApp>(
              title: Text(_navigationLabel(app)),
              value: app,
              groupValue: current,
              activeColor: AppColors.primary,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateNavigationApp(value);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).languageCode;
    const options = [
      ('en', 'English'),
      ('hi', 'हिंदी (Hindi)'),
    ];
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<String>(
              title: Text(option.$2),
              value: option.$1,
              groupValue: current,
              activeColor: AppColors.primary,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).updateLanguage(value);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).themeMode;
    const options = [
      (ThemeMode.system, 'System Default'),
      (ThemeMode.light, 'Light'),
      (ThemeMode.dark, 'Dark'),
    ];
    showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<ThemeMode>(
              title: Text(option.$2),
              value: option.$1,
              groupValue: current,
              activeColor: AppColors.primary,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).updateThemeMode(value);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Thin divider used between tiles inside a settings card.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 14,
      endIndent: 14,
      color: AppColors.border,
    );
  }
}
