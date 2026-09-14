import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';

class DairyCategory {
  final String id;
  final String name;
  final String description;
  final int productCount;
  final IconData icon;
  final Color color;
  final String emoji;
  final String imageUrl;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DairyCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.productCount,
    required this.icon,
    required this.color,
    required this.emoji,
    this.imageUrl = '',
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  String get resolvedImageUrl =>
      AppAssets.categoryImage(imageUrl: imageUrl, categoryKey: id) ?? '';

  DairyCategory copyWith({
    String? id,
    String? name,
    String? description,
    int? productCount,
    IconData? icon,
    Color? color,
    String? emoji,
    String? imageUrl,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DairyCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      productCount: productCount ?? this.productCount,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DairyPayment {
  final String id;
  final String customerName;
  final String orderOrWalletId;
  final double amount;
  final String
      method; // 'UPI', 'Razorpay', 'Cash On Delivery', 'Wallet Auto-Debit'
  final String status; // 'Success', 'Pending', 'Failed'
  final String timestamp;

  const DairyPayment({
    required this.id,
    required this.customerName,
    required this.orderOrWalletId,
    required this.amount,
    required this.method,
    required this.status,
    required this.timestamp,
  });
}
