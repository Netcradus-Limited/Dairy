import '../core/constants/app_assets.dart';
import 'product.dart';

class DairyProduct {
  final String id;
  final String name;
  final String subtitle;
  final String category;
  final String unit;
  final double price;
  final int ordersCount;
  final double totalRevenue;
  final int stockQuantity;
  final String fatContent;
  final String packaging;
  final bool inStock;
  final String emoji;
  final bool isBestSeller;
  final String imageUrl;

  const DairyProduct({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.category,
    required this.unit,
    required this.price,
    this.ordersCount = 0,
    this.totalRevenue = 0.0,
    this.stockQuantity = 0,
    this.fatContent = '',
    this.packaging = '',
    this.inStock = true,
    this.emoji = '🥛',
    this.isBestSeller = false,
    this.imageUrl = '',
  });

  /// The image source to render: a valid network/asset URL is returned
  /// untouched, otherwise this falls back to the product's category default.
  String get resolvedImageUrl =>
      AppAssets.productImage(
        imageUrl: imageUrl,
        categoryKey: category,
        productId: id,
        productTitle: name,
      ) ??
      '';

  DairyProduct copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? category,
    String? unit,
    double? price,
    int? ordersCount,
    double? totalRevenue,
    int? stockQuantity,
    String? fatContent,
    String? packaging,
    bool? inStock,
    String? emoji,
    bool? isBestSeller,
    String? imageUrl,
  }) {
    return DairyProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      ordersCount: ordersCount ?? this.ordersCount,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      fatContent: fatContent ?? this.fatContent,
      packaging: packaging ?? this.packaging,
      inStock: inStock ?? this.inStock,
      emoji: emoji ?? this.emoji,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Product toProduct() => Product(
        id: id,
        title: name,
        categoryId: category,
        categoryName: category,
        price: price,
        unit: unit,
        imageUrl: imageUrl,
        description: subtitle,
        inStock: inStock,
        isBestSeller: isBestSeller,
      );

  factory DairyProduct.fromProduct(Product p) => DairyProduct(
        id: p.id,
        name: p.title,
        subtitle: p.description,
        category: p.categoryName.isNotEmpty ? p.categoryName : p.categoryId,
        unit: p.unit,
        price: p.price,
        imageUrl: p.imageUrl,
        inStock: p.inStock,
        isBestSeller: p.isBestSeller,
      );
}
