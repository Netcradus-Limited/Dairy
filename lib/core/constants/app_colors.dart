import 'package:flutter/material.dart';

/// Sawariya Dairy Centralized Color Palette
abstract class AppColors {
  // Brand Colors (Logo & Banner Palette: Forest Green & Soft Cream)
  static const Color primaryBlue = Color(0xFF28541C);
  static const Color secondaryBlue = Color(0xFF437D2A);
  static const Color lightBlue = Color(0xFFE8F2DD);
  static const Color accentBlue = Color(0xFF62A044);

  // Surface & Background Colors
  static const Color background = Color(0xFFF6FAF0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // State & Status Colors
  static const Color success = Color(0xFF22A06B);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF28541C);

  // Border & Divider Colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF28541C);
  static const Color divider = Color(0xFFEEF2F6);

  // Accent & Decorative Colors
  static const Color discountTag = Color(0xFFE53935);
  static const Color ratingStar = Color(0xFFFFB800);
  static const Color freshGreen = Color(0xFF10B981);
  static const Color shadow = Color(0x0C172033);

  // Dark Theme Palette
  static const Color darkBackground = Color(0xFF0A1C14);
  static const Color darkSurface = Color(0xFF11261B);
  static const Color darkCard = Color(0xFF11261B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF1B3B2B);

  // Sidebar Colors (Green theme - consistent in both modes for a premium admin feel)
  static const Color sidebarBg = Color(0xFF081F14);
  static const Color sidebarBgDarker = Color(0xFF04120B);
  static const Color sidebarText = Color(0xFF94A3B8);
  static const Color sidebarActive = Color(0xFF28541C);
  static const Color sidebarActiveText = Color(0xFFFFFFFF);
  static const Color sidebarHover = Color(0xFF0E2F1E);
  static const Color sidebarBorder = Color(0xFF1B3B2B);

  // Light Theme Palette aliases / additions
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEBF0F7);

  // Dark Theme Palette additions
  static const Color darkCardBg = Color(0xFF122C20);
  static const Color darkCardBorder = Color(0xFF1B3E2F);
  static const Color darkDivider = Color(0xFF1B3B2B);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Primary brand
  static const Color primary = Color(0xFF28541C);
  static const Color primaryLight = Color(0xFFE8F2DD);
  static const Color primaryDark = Color(0xFF16320F);

  // KPI Card Theme Colors
  static const Color revenueGreen = Color(0xFF437D2A);
  static const Color revenueGreenBg = Color(0xFFE8F2DD);

  static const Color ordersBlue = Color(0xFF28541C);
  static const Color ordersBlueBg = Color(0xFFE8F2DD);

  static const Color customersOrange = Color(0xFFF97316);
  static const Color customersOrangeBg = Color(0xFFFFF4EC);

  static const Color deliveriesPurple = Color(0xFF8B5CF6);
  static const Color deliveriesPurpleBg = Color(0xFFF6F3FF);

  // Donut Chart & Status Colors
  static const Color statusPending = Color(0xFFF97316);
  static const Color statusConfirmed = Color(0xFFEA580C);
  static const Color statusPreparing = Color(0xFFA855F7);
  static const Color statusOutForDelivery = Color(0xFF0284C7);
  static const Color statusDelivered = Color(0xFF10B981);
  static const Color statusCancelled = Color(0xFF64748B);
  static const Color statusOnRoute = Color(0xFF0284C7);

  static const Color textWhite = Color(0xFFFFFFFF);

  // Dynamic Theme-Aware Getters
  static Color bgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBackground
          : background;

  static Color cardBgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCardBg : cardBg;

  static Color cardBorderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCardBorder
          : cardBorder;

  static Color dividerOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkDivider : divider;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : textSecondary;

  static Color textMutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextMuted
          : textMuted;

  // Surface Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // ── Layered Premium Shadow System ──────────────────────────────────────────
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get cardShadowSm => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadowMd => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get cardShadowLg => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get navShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, -6),
        ),
      ];

  static List<BoxShadow> get primaryShadow => [
        BoxShadow(
          color: primaryBlue.withValues(alpha: 0.28),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get primaryShadowSm => [
        BoxShadow(
          color: primaryBlue.withValues(alpha: 0.22),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];

  // ── Brand Gradients ────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradientVertical = LinearGradient(
    colors: [primary, primaryBlue],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
