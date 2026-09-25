import '../core/constants/app_assets.dart';
import 'product_model.dart';

/// Product Model for Sawariya Dairy
class Product {
  final String id;
  final String title;
  final String categoryId;
  final String categoryName;
  final double price;
  final double? originalPrice;
  final String unit; // e.g. "500 ml", "1 L", "200 g", "1 kg"
  final String imageUrl;
  final String description;
  final double rating;
  final int reviewCount;
  final bool isFreshDeal;
  final bool isBestSeller;
  final bool isA2CowMilk;
  final bool inStock;
  final bool subscriptionEnabled;

  const Product({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    this.originalPrice,
    required this.unit,
    required this.imageUrl,
    this.description = '',
    this.rating = 4.8,
    this.reviewCount = 120,
    this.isFreshDeal = false,
    this.isBestSeller = false,
    this.isA2CowMilk = false,
    this.inStock = true,
    this.subscriptionEnabled = true,
  });

  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  /// The image source to render: a valid network/asset URL is returned
  /// untouched, otherwise this falls back to the product's category default.
  String get resolvedImageUrl =>
      AppAssets.productImage(
        imageUrl: imageUrl,
        categoryKey: categoryId,
        productId: id,
        productTitle: title,
      ) ??
      '';

  int get discountPercentage {
    if (!hasDiscount) return 0;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }

  Product copyWith({
    String? id,
    String? title,
    String? categoryId,
    String? categoryName,
    double? price,
    double? originalPrice,
    String? unit,
    String? imageUrl,
    String? description,
    double? rating,
    int? reviewCount,
    bool? isFreshDeal,
    bool? isBestSeller,
    bool? isA2CowMilk,
    bool? inStock,
    bool? subscriptionEnabled,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFreshDeal: isFreshDeal ?? this.isFreshDeal,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      isA2CowMilk: isA2CowMilk ?? this.isA2CowMilk,
      inStock: inStock ?? this.inStock,
      subscriptionEnabled: subscriptionEnabled ?? this.subscriptionEnabled,
    );
  }

  /// Creates a [Product] from a Firestore document map.
  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    final original = data['originalPrice'];
    final rawImageUrl = (data['imageUrl'] as String?) ??
        (data['image'] as String?) ??
        (data['productImage'] as String?) ??
        (data['imagePath'] as String?) ??
        (data['productImageUrl'] as String?) ??
        (data['image_url'] as String?) ??
        (data['imageURL'] as String?) ??
        (data['photoUrl'] as String?) ??
        '';
    return Product(
      id: id,
      title: (data['title'] as String?) ?? (data['name'] as String?) ?? '',
      categoryId: (data['categoryId'] as String?) ??
          (data['category'] as String?) ??
          '',
      categoryName: (data['categoryName'] as String?) ??
          (data['category'] as String?) ??
          '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: original == null ? null : (original as num).toDouble(),
      unit: (data['unit'] as String?) ?? '',
      imageUrl: rawImageUrl.trim(),
      description: (data['description'] as String?) ??
          (data['subtitle'] as String?) ??
          '',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      isFreshDeal: (data['isFreshDeal'] as bool?) ?? false,
      isBestSeller: (data['isBestSeller'] as bool?) ?? false,
      isA2CowMilk: (data['isA2CowMilk'] as bool?) ?? false,
      inStock: (data['inStock'] as bool?) ?? true,
      subscriptionEnabled: (data['subscriptionEnabled'] as bool?) ??
          (!(((data['categoryId'] as String?) ??
                      (data['category'] as String?) ??
                      '')
                  .toLowerCase()
                  .contains('uple') ||
              ((data['categoryId'] as String?) ??
                      (data['category'] as String?) ??
                      '')
                  .toLowerCase()
                  .contains('water') ||
              ((data['categoryId'] as String?) ??
                      (data['category'] as String?) ??
                      '')
                  .toLowerCase()
                  .contains('pooja') ||
              ((data['title'] as String?) ?? (data['name'] as String?) ?? '')
                  .toLowerCase()
                  .contains('uple') ||
              ((data['title'] as String?) ?? (data['name'] as String?) ?? '')
                  .toLowerCase()
                  .contains('water bottle') ||
              ((data['title'] as String?) ?? (data['name'] as String?) ?? '')
                  .toLowerCase()
                  .contains('cow dung'))),
    );
  }

  /// Serializes this [Product] for SharedPreferences / general-purpose use.
  /// Includes [id] (unlike [toFirestore] which omits it).
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'price': price,
        'originalPrice': originalPrice,
        'unit': unit,
        'imageUrl': imageUrl,
        'description': description,
        'rating': rating,
        'reviewCount': reviewCount,
        'isFreshDeal': isFreshDeal,
        'isBestSeller': isBestSeller,
        'isA2CowMilk': isA2CowMilk,
        'inStock': inStock,
        'subscriptionEnabled': subscriptionEnabled,
      };

  /// Restores a [Product] from a map produced by [toMap].
  factory Product.fromMap(Map<String, dynamic> map) {
    final original = map['originalPrice'];
    final rawImageUrl = (map['imageUrl'] as String?) ??
        (map['image'] as String?) ??
        (map['image_url'] as String?) ??
        (map['imageURL'] as String?) ??
        (map['photoUrl'] as String?) ??
        '';
    return Product(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? (map['name'] as String?) ?? '',
      categoryId:
          (map['categoryId'] as String?) ?? (map['category'] as String?) ?? '',
      categoryName: (map['categoryName'] as String?) ??
          (map['category'] as String?) ??
          '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: original == null ? null : (original as num).toDouble(),
      unit: (map['unit'] as String?) ?? '',
      imageUrl: rawImageUrl.trim(),
      description:
          (map['description'] as String?) ?? (map['subtitle'] as String?) ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isFreshDeal: (map['isFreshDeal'] as bool?) ?? false,
      isBestSeller: (map['isBestSeller'] as bool?) ?? false,
      isA2CowMilk: (map['isA2CowMilk'] as bool?) ?? false,
      inStock: (map['inStock'] as bool?) ?? true,
      subscriptionEnabled: (map['subscriptionEnabled'] as bool?) ??
          (!(((map['categoryId'] as String?) ??
                      (map['category'] as String?) ??
                      '')
                  .toLowerCase()
                  .contains('uple') ||
              ((map['categoryId'] as String?) ??
                      (map['category'] as String?) ??
                      '')
                  .toLowerCase()
                  .contains('water') ||
              ((map['categoryId'] as String?) ??
                      (map['category'] as String?) ??
                      '')
                  .toLowerCase()
                  .contains('pooja') ||
              ((map['title'] as String?) ?? (map['name'] as String?) ?? '')
                  .toLowerCase()
                  .contains('uple') ||
              ((map['title'] as String?) ?? (map['name'] as String?) ?? '')
                  .toLowerCase()
                  .contains('water bottle') ||
              ((map['title'] as String?) ?? (map['name'] as String?) ?? '')
                  .toLowerCase()
                  .contains('cow dung'))),
    );
  }

  /// Serializes this [Product] for writing to Firestore.
  Map<String, dynamic> toFirestore() => {
        'title': title,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'price': price,
        'originalPrice': originalPrice,
        'unit': unit,
        'imageUrl': imageUrl,
        'description': description,
        'rating': rating,
        'reviewCount': reviewCount,
        'isFreshDeal': isFreshDeal,
        'isBestSeller': isBestSeller,
        'isA2CowMilk': isA2CowMilk,
        'inStock': inStock,
        'subscriptionEnabled': subscriptionEnabled,
      };

  DairyProduct toDairyProduct() => DairyProduct(
        id: id,
        name: title,
        subtitle: description,
        category: categoryName.isNotEmpty ? categoryName : categoryId,
        unit: unit,
        price: price,
        inStock: inStock,
        isBestSeller: isBestSeller,
        imageUrl: imageUrl,
      );

  factory Product.fromDairyProduct(DairyProduct dp) => Product(
        id: dp.id,
        title: dp.name,
        categoryId: dp.category,
        categoryName: dp.category,
        price: dp.price,
        unit: dp.unit,
        imageUrl: dp.imageUrl,
        description: dp.subtitle,
        inStock: dp.inStock,
        isBestSeller: dp.isBestSeller,
        subscriptionEnabled: !(dp.category.toLowerCase().contains('uple') ||
            dp.category.toLowerCase().contains('water') ||
            dp.category.toLowerCase().contains('pooja') ||
            dp.name.toLowerCase().contains('uple') ||
            dp.name.toLowerCase().contains('water bottle') ||
            dp.name.toLowerCase().contains('cow dung')),
      );
}
