import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/widgets/app_network_image.dart';
import '../theme/delivery_theme.dart';

/// Reusable Delivery Agent Avatar widget with safe image loading and fallback.
/// Handles network failures (CORS, 404, invalid URLs) without crashing,
/// infinite error spam loops, or leaving a blank avatar.
/// Never logs private access tokens or storage signatures.
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

  /// Sanitises the raw URL string.
  /// Returns null when the URL is invalid / unsupported (triggers fallback icon).
  String? _sanitiseUrl(String? raw) {
    if (raw == null) return null;
    String url = raw.trim();

    // Strip surrounding quotes
    if ((url.startsWith('"') && url.endsWith('"')) ||
        (url.startsWith("'") && url.endsWith("'"))) {
      url = url.substring(1, url.length - 1).trim();
    }

    if (url.isEmpty || url == 'null' || url == 'undefined') return null;

    // gs:// URLs are internal Cloud Storage references â€” cannot load directly
    if (url.startsWith('gs://')) return null;

    // Local asset path support (testing / offline)
    if (url.startsWith('assets/') || url.startsWith('images/')) return url;

    // Must be http or https
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;

    // Validate URI structure
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) return null;

    return url;
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = _sanitiseUrl(imageUrl);

    if (cleanUrl == null) {
      return _buildFallbackIcon();
    }

    // Asset path support (testing / offline environments)
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      return ClipOval(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          color: backgroundColor,
          child: Image.asset(
            cleanUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackIcon(),
          ),
        ),
      );
    }

    // On Flutter Web, CachedNetworkImage and Image.network with custom headers
    // suffer from CORS restrictions with Firebase Storage URLs.
    // Use AppNetworkImage which renders a native HTML <img> element via
    // HtmlElementView without CORS blocking.
    if (kIsWeb) {
      return ClipOval(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          color: backgroundColor,
          child: AppNetworkImage(
            imageUrl: cleanUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackIcon(),
          ),
        ),
      );
    }

    // Android / iOS: use CachedNetworkImage for disk caching and resilience
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: backgroundColor,
        child: CachedNetworkImage(
          imageUrl: cleanUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => Center(
            child: SizedBox(
              width: radius * 0.7,
              height: radius * 0.7,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: DeliveryTheme.primary,
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildFallbackIcon(),
        ),
      ),
    );
  }
}
