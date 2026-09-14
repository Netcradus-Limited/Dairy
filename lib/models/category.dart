import 'package:flutter/material.dart';
import '../core/constants/app_assets.dart';

class Category {
  static const Map<String, IconData> _iconByName = {
    'milk': Icons.local_drink_rounded,
    'lassi': Icons.local_cafe_rounded,
    'makhan': Icons.rice_bowl_rounded,
    'ghee': Icons.opacity_rounded,
    'paneer': Icons.lunch_dining_rounded,
    'curd': Icons.icecream_rounded,
    'uple': Icons.eco_rounded,
    'water': Icons.water_drop_rounded,
  };

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final IconData? iconData;
  final Color backgroundColor;
  final Color borderColor;
  final Color titleColor;
  final int itemCount;
  final bool isActive;
  final int sortOrder;

  const Category({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.iconData,
    required this.backgroundColor,
    required this.borderColor,
    required this.titleColor,
    required this.itemCount,
    this.isActive = true,
    this.sortOrder = 0,
  });

  /// The image source to render: a valid network/asset URL is returned
  /// untouched, otherwise this falls back to the category's default local asset.
  String get resolvedImageUrl =>
      AppAssets.categoryImage(imageUrl: imageUrl, categoryKey: id) ?? '';

  Category copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    IconData? iconData,
    Color? backgroundColor,
    Color? borderColor,
    Color? titleColor,
    int? itemCount,
    bool? isActive,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      iconData: iconData ?? this.iconData,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      titleColor: titleColor ?? this.titleColor,
      itemCount: itemCount ?? this.itemCount,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Creates a [Category] from a Firestore document map.
  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    final iconName = data['iconName'] as String?;
    final colorValue = data['colorValue'] as int?;
    final title = (data['title'] as String?) ?? (data['name'] as String?) ?? '';
    final subtitle =
        (data['subtitle'] as String?) ?? (data['description'] as String?) ?? '';
    final count = (data['itemCount'] as num?)?.toInt() ??
        (data['productCount'] as num?)?.toInt() ??
        0;
    final active = (data['isActive'] as bool?) ?? true;
    final sort = (data['sortOrder'] as num?)?.toInt() ?? 0;

    return Category(
      id: id,
      title: title,
      subtitle: subtitle,
      imageUrl: (data['imageUrl'] as String?) ?? '',
      iconData: iconName == null ? null : _iconByName[iconName],
      backgroundColor:
          colorValue == null ? const Color(0xFFEAF3FF) : Color(colorValue),
      borderColor: const Color(0xFFB1D5C0),
      titleColor: const Color(0xFF005F38),
      itemCount: count,
      isActive: active,
      sortOrder: sort,
    );
  }

  /// Serializes this [Category] for writing to Firestore.
  Map<String, dynamic> toFirestore() {
    String? iconName;
    if (iconData != null) {
      for (final entry in _iconByName.entries) {
        if (entry.value == iconData) {
          iconName = entry.key;
          break;
        }
      }
    }
    return {
      'title': title,
      'name': title,
      'subtitle': subtitle,
      'description': subtitle,
      'imageUrl': imageUrl,
      'iconName': iconName,
      'colorValue': backgroundColor.toARGB32(),
      'itemCount': itemCount,
      'productCount': itemCount,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }
}
