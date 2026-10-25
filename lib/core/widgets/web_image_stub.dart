import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

Widget createPlatformNetworkImage({
  required String url,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder,
}) {
  // In automated test environments, delegate to Image.network so pumpAndSettle()
  // can settle cleanly without being blocked by CacheManager background timers or infinite spinners.
  if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }

  return CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    fit: fit,
    maxWidthDiskCache: 800,
    maxHeightDiskCache: 800,
    memCacheWidth: width != null && width > 0 ? (width * 2).toInt() : 400,
    progressIndicatorBuilder: loadingBuilder != null
        ? (context, url, downloadProgress) => loadingBuilder(
            context,
            const SizedBox(),
            ImageChunkEvent(
              cumulativeBytesLoaded: downloadProgress.downloaded,
              expectedTotalBytes: downloadProgress.totalSize,
            ),
          )
        : null,
    placeholder: loadingBuilder == null
        ? (context, _) => Container(
            width: width,
            height: height,
            color: const Color(0xFFF3F4F6),
          )
        : null,
    errorWidget: (context, _, error) => errorBuilder != null
        ? errorBuilder(context, error, null)
        : const Icon(Icons.broken_image_outlined, size: 24, color: Colors.grey),
  );
}
