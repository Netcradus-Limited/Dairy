// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredTypes = <String>{};

Widget createPlatformNetworkImage({
  required String url,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder,
}) {
  final viewType = 'img-${url.hashCode.abs()}';

  if (!_registeredTypes.contains(viewType)) {
    _registeredTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final img = html.ImageElement()
          ..src = url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = _fitToCss(fit)
          ..style.border = 'none'
          ..style.display = 'block';
        return img;
      },
    );
  }

  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(
      key: ValueKey(viewType),
      viewType: viewType,
    ),
  );
}

String _fitToCss(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.fitWidth:
    case BoxFit.fitHeight:
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.none:
      return 'none';
    case BoxFit.cover:
      return 'cover';
  }
}
