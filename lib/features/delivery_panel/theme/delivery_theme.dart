import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized visual design system for the Sawariya Dairy Delivery Agent Panel.
/// Accurately reflects the green dairy/nature aesthetic, soft gradients,
/// rounded card elevations, and clean typography from the reference design.
abstract class DeliveryTheme {
  // ─── Primary Brand Palette ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF43A047);
  static const Color primaryDark = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF66BB6A);
  static const Color primaryMint = Color(0xFFE8F5E9);
  static const Color primarySurface = Color(0xFFF4F8F4);
  static const Color background = Color(0xFFF7FAF7);
  static const Color cardBg = Colors.white;

  // ─── Text Colors ────────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF17281D);
  static const Color textSecondary = Color(0xFF5F7164);
  static const Color textMuted = Color(0xFF94A398);

  // ─── Status Colors (Matches Reference Image) ────────────────────────────────
  // "Next" & "Delivered": Green
  static const Color statusNextText = Color(0xFF2E7D32);
  static const Color statusNextBg = Color(0xFFE8F5E9);

  // "In Progress": Amber / Warm Orange
  static const Color statusProgressText = Color(0xFFE65100);
  static const Color statusProgressBg = Color(0xFFFFF3E0);

  // "Pending": Soft Red / Pink
  static const Color statusPendingText = Color(0xFFD32F2F);
  static const Color statusPendingBg = Color(0xFFFFEBEE);

  // "Cancelled" / "Failed": Vibrant Red
  static const Color statusCancelledText = Color(0xFFC62828);
  static const Color statusCancelledBg = Color(0xFFFFCDD2);

  // ─── Metric Card Colors ─────────────────────────────────────────────────────
  // 1. Today's Orders (Blue)
  static const Color metricOrdersIcon = Color(0xFF1976D2);
  static const Color metricOrdersBg = Color(0xFFE3F2FD);

  // 2. Delivered (Green)
  static const Color metricDeliveredIcon = Color(0xFF43A047);
  static const Color metricDeliveredBg = Color(0xFFE8F5E9);

  // 3. In Progress (Amber)
  static const Color metricProgressIcon = Color(0xFFF57C00);
  static const Color metricProgressBg = Color(0xFFFFF3E0);

  // 4. Pending (Red)
  static const Color metricPendingIcon = Color(0xFFE53935);
  static const Color metricPendingBg = Color(0xFFFFEBEE);

  // ─── Header & Banner Gradients ──────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF388E3C),
      Color(0xFF4CAF50),
      Color(0xFF66BB6A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient promoBannerGradient = LinearGradient(
    colors: [
      Color(0xFF43A047),
      Color(0xFF66BB6A),
      Color(0xFF81C784),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient softMintGradient = LinearGradient(
    colors: [
      Color(0xFFE8F5E9),
      Color(0xFFF1F8E9),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Card Styling ───────────────────────────────────────────────────────────
  static const double cardRadius = 16.0;
  static const double buttonRadius = 24.0;

  static BoxDecoration cardDecoration({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? cardBg,
      borderRadius: borderRadius ?? BorderRadius.circular(cardRadius),
      border: border ?? Border.all(color: const Color(0xFFE5ECE5), width: 1.0),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A17281D),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  // ─── Typography Helpers ─────────────────────────────────────────────────────
  static TextStyle titleLarge({Color color = textDark}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.3,
      );

  static TextStyle titleMedium({Color color = textDark}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle bodyMedium({Color color = textSecondary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle caption({Color color = textMuted}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
      );
}

/// Custom painter for soft botanical leaf curves in headers, banners, or footers.
class BotanicalLeafPainter extends CustomPainter {
  final Color leafColor;
  final bool isRightAligned;

  const BotanicalLeafPainter({
    this.leafColor = const Color(0x1F4CAF50),
    this.isRightAligned = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isRightAligned) {
      // Top right leaves
      path.moveTo(size.width, 0);
      path.quadraticBezierTo(
        size.width - 60,
        10,
        size.width - 70,
        45,
      );
      path.quadraticBezierTo(
        size.width - 30,
        60,
        size.width,
        35,
      );
      path.close();

      // Second smaller leaf
      final path2 = Path();
      path2.moveTo(size.width - 20, 0);
      path2.quadraticBezierTo(
        size.width - 90,
        30,
        size.width - 110,
        70,
      );
      path2.quadraticBezierTo(
        size.width - 50,
        80,
        size.width - 10,
        50,
      );
      path2.close();

      canvas.drawPath(path, paint);
      canvas.drawPath(path2, paint);
    } else {
      // Bottom left leaves
      path.moveTo(0, size.height);
      path.quadraticBezierTo(
        60,
        size.height - 10,
        70,
        size.height - 45,
      );
      path.quadraticBezierTo(
        30,
        size.height - 60,
        0,
        size.height - 35,
      );
      path.close();

      final path2 = Path();
      path2.moveTo(20, size.height);
      path2.quadraticBezierTo(
        90,
        size.height - 30,
        110,
        size.height - 70,
      );
      path2.quadraticBezierTo(
        50,
        size.height - 80,
        10,
        size.height - 50,
      );
      path2.close();

      canvas.drawPath(path, paint);
      canvas.drawPath(path2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BotanicalLeafPainter oldDelegate) =>
      oldDelegate.leafColor != leafColor ||
      oldDelegate.isRightAligned != isRightAligned;
}
