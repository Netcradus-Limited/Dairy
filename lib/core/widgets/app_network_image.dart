import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import 'web_image_stub.dart' if (dart.library.html) 'web_image_web.dart'
    as platform_impl;

/// A cross-platform network image widget that gracefully handles CORS on Web.
/// - If given a local asset path, seamlessly delegates to [Image.asset].
/// - On Mobile & Desktop: renders standard [Image.network].
/// - On Web: renders [HtmlElementView] embedding a native DOM <img> element
///   which browsers allow without CORS restrictions.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return errorBuilder?.call(context, 'Empty image URL', null) ??
          const SizedBox();
    }

    if (trimmed.startsWith('gs://')) {
      return errorBuilder?.call(
            context,
            'Firebase Storage gs:// URI not directly renderable',
            null,
          ) ??
          const SizedBox();
    }

    // If a local asset path was passed, delegate to Image.asset
    if (trimmed.startsWith('assets/') ||
        trimmed.startsWith('images/') ||
        (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))) {
      final normalized = AppAssets.normalizeAssetPath(trimmed);
      return Image.asset(
        normalized,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorBuilder?.call(context, error, stackTrace) ??
            const Icon(Icons.broken_image_outlined,
                size: 24, color: Colors.grey),
      );
    }

    return platform_impl.createPlatformNetworkImage(
      url: trimmed,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
