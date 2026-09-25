import 'package:flutter/material.dart';
import '../theme/delivery_theme.dart';

/// Reusable Delivery Agent Avatar widget with safe image loading and fallback.
/// Handles network failures (CORS, 404, invalid URLs) without crashing or
/// leaving a blank avatar. Never logs private access tokens or storage signatures.
class DeliveryAgentAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;

  const DeliveryAgentAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.backgroundColor = const Color(0xFFE8F5E9),
    this.iconColor = DeliveryTheme.primary,
    this.iconSize = 26,
  });

  Widget _buildFallbackIcon() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl?.trim() ?? '';
    if (cleanUrl.isEmpty) {
      return _buildFallbackIcon();
    }

    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: backgroundColor,
        child: Image.network(
          cleanUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Sanitized debug logging: never log signed tokens or query params
            final sanitizedPath = Uri.tryParse(cleanUrl)?.path ?? 'avatar';
            debugPrint('[AVATAR] Failed to load agent avatar from $sanitizedPath: $error');
            return _buildFallbackIcon();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: radius * 0.7,
                height: radius * 0.7,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DeliveryTheme.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
