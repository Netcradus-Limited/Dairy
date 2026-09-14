import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/core/constants/app_colors.dart';
import 'package:dairy_app/models/category.dart';
import 'package:dairy_app/models/category_model.dart';
import 'package:dairy_app/models/product_model.dart';

void main() {
  group('Task 2 — Category Model & Serialization Tests', () {
    test('Category.fromFirestore handles legacy documents missing isActive and sortOrder', () {
      final legacyData = <String, dynamic>{
        'title': 'Milk',
        'subtitle': '100% Pure',
        'imageUrl': 'assets/images/doodh.png',
        'iconName': 'milk',
        'colorValue': 0xFFEAF5FF,
        'itemCount': 8,
      };

      final category = Category.fromFirestore(legacyData, 'cat_milk');
      expect(category.id, equals('cat_milk'));
      expect(category.title, equals('Milk'));
      expect(category.subtitle, equals('100% Pure'));
      expect(category.isActive, isTrue);
      expect(category.sortOrder, equals(0));
      expect(category.itemCount, equals(8));
    });

    test('Category.fromFirestore handles standard documents with name, description, isActive, sortOrder', () {
      final data = <String, dynamic>{
        'name': 'Ghee & Butter',
        'description': 'Rich traditional ghee',
        'imageUrl': 'https://firebasestorage.googleapis.com/sample.jpg',
        'colorValue': 0xFFFFF9EE,
        'productCount': 4,
        'isActive': false,
        'sortOrder': 5,
      };

      final category = Category.fromFirestore(data, 'cat_ghee_butter');
      expect(category.id, equals('cat_ghee_butter'));
      expect(category.title, equals('Ghee & Butter'));
      expect(category.subtitle, equals('Rich traditional ghee'));
      expect(category.isActive, isFalse);
      expect(category.sortOrder, equals(5));
      expect(category.itemCount, equals(4));
    });

    test('Category.toFirestore writes both standard and legacy field aliases', () {
      const category = Category(
        id: 'cat_sweets',
        title: 'Mithai & Sweets',
        subtitle: 'Authentic Indian Sweets',
        imageUrl: 'assets/images/mithai.png',
        iconData: Icons.cake,
        backgroundColor: Color(0xFFFFF5EA),
        borderColor: Color(0xFF70AD47),
        titleColor: Color(0xFF0C1A30),
        itemCount: 12,
        isActive: true,
        sortOrder: 3,
      );

      final map = category.toFirestore();
      expect(map['name'], equals('Mithai & Sweets'));
      expect(map['title'], equals('Mithai & Sweets'));
      expect(map['description'], equals('Authentic Indian Sweets'));
      expect(map['subtitle'], equals('Authentic Indian Sweets'));
      expect(map['productCount'], equals(12));
      expect(map['itemCount'], equals(12));
      expect(map['isActive'], isTrue);
      expect(map['sortOrder'], equals(3));
    });

    test('DairyCategory model copyWith preserves and updates new fields', () {
      final now = DateTime.now();
      const cat = DairyCategory(
        id: 'cat_1',
        name: 'Milk',
        description: 'Fresh milk',
        productCount: 5,
        icon: Icons.local_drink,
        color: AppColors.primary,
        emoji: '🥛',
        isActive: true,
        sortOrder: 1,
      );

      final updated = cat.copyWith(
        name: 'Organic Milk',
        isActive: false,
        sortOrder: 2,
        updatedAt: now,
      );

      expect(updated.id, equals('cat_1'));
      expect(updated.name, equals('Organic Milk'));
      expect(updated.isActive, isFalse);
      expect(updated.sortOrder, equals(2));
      expect(updated.updatedAt, equals(now));
      expect(updated.productCount, equals(5));
    });
  });

  group('Task 2 — Admin Category Management & Validation Logic', () {
    test('Duplicate category-name detection (case-insensitive and trimmed)', () {
      final existingCategories = [
        const DairyCategory(
          id: 'cat_milk',
          name: 'Milk',
          description: 'Fresh Milk',
          productCount: 5,
          icon: Icons.local_drink,
          color: AppColors.primary,
          emoji: '🥛',
          isActive: true,
          sortOrder: 0,
        ),
        const DairyCategory(
          id: 'cat_paneer',
          name: 'Paneer',
          description: 'Fresh Paneer',
          productCount: 2,
          icon: Icons.lunch_dining,
          color: AppColors.primary,
          emoji: '🧀',
          isActive: true,
          sortOrder: 1,
        ),
      ];

      bool isDuplicate(String name, [String? excludeId]) {
        final trimmed = name.trim().toLowerCase();
        if (trimmed.isEmpty) return false;
        return existingCategories.any((c) =>
            (excludeId != null ? c.id != excludeId : true) &&
            c.name.trim().toLowerCase() == trimmed);
      }

      // Exact match
      expect(isDuplicate('Milk'), isTrue);
      // Case-insensitive match
      expect(isDuplicate('milk'), isTrue);
      expect(isDuplicate('MILK'), isTrue);
      // Trimmed match
      expect(isDuplicate('   Milk   '), isTrue);
      expect(isDuplicate('  paneer  '), isTrue);
      // Updating same category ignores itself
      expect(isDuplicate('Milk', 'cat_milk'), isFalse);
      // Updating to another existing category detects duplicate
      expect(isDuplicate('Paneer', 'cat_milk'), isTrue);
      // New distinct name
      expect(isDuplicate('Lassi'), isFalse);
    });

    test('Deletion guard blocks deletion if products are linked to category', () {
      final products = [
        const DairyProduct(
          id: 'prod_1',
          name: 'Pure Cow Milk 1L',
          subtitle: 'Pure',
          category: 'Milk',
          unit: '1L',
          price: 60.0,
        ),
        const DairyProduct(
          id: 'prod_2',
          name: 'Fresh Malai Paneer 500g',
          subtitle: 'Fresh',
          category: 'Paneer',
          unit: '500g',
          price: 200.0,
        ),
      ];

      bool hasLinkedProducts(String categoryName, String categoryId) {
        final catName = categoryName.trim().toLowerCase();
        return products.any((p) {
          return p.category.trim().toLowerCase() == catName ||
              p.category.trim().toLowerCase() == categoryId;
        });
      }

      // Category with products linked
      expect(hasLinkedProducts('Milk', 'cat_milk'), isTrue);
      expect(hasLinkedProducts('Paneer', 'cat_paneer'), isTrue);

      // Category with 0 products linked
      expect(hasLinkedProducts('Water', 'cat_water'), isFalse);
      expect(hasLinkedProducts('Uple', 'cat_uple'), isFalse);
    });

    test('Toggle active status updates isActive state', () {
      const cat = DairyCategory(
        id: 'cat_test_toggle',
        name: 'Test Toggle',
        description: 'Test',
        productCount: 0,
        icon: Icons.category,
        color: AppColors.primary,
        emoji: '🥛',
        isActive: true,
      );

      final toggled = cat.copyWith(isActive: !cat.isActive);
      expect(toggled.isActive, isFalse);

      final toggledBack = toggled.copyWith(isActive: !toggled.isActive);
      expect(toggledBack.isActive, isTrue);
    });
  });

  group('Task 2 — Customer Category Filtering & Sorting', () {
    test('Active categories are sorted by sortOrder and inactive categories are excluded', () {
      final categories = [
        const Category(
          id: 'cat_3',
          title: 'Paneer',
          subtitle: 'Fresh',
          imageUrl: '',
          iconData: null,
          backgroundColor: Colors.white,
          borderColor: Colors.green,
          titleColor: Colors.black,
          itemCount: 2,
          isActive: true,
          sortOrder: 3,
        ),
        const Category(
          id: 'cat_hidden',
          title: 'Hidden Item',
          subtitle: 'Hidden',
          imageUrl: '',
          iconData: null,
          backgroundColor: Colors.white,
          borderColor: Colors.green,
          titleColor: Colors.black,
          itemCount: 0,
          isActive: false,
          sortOrder: 1,
        ),
        const Category(
          id: 'cat_1',
          title: 'Milk',
          subtitle: 'Pure',
          imageUrl: '',
          iconData: null,
          backgroundColor: Colors.white,
          borderColor: Colors.green,
          titleColor: Colors.black,
          itemCount: 5,
          isActive: true,
          sortOrder: 1,
        ),
      ];

      final activeSorted = categories.where((c) => c.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      expect(activeSorted.length, equals(2));
      expect(activeSorted.first.id, equals('cat_1'));
      expect(activeSorted.last.id, equals('cat_3'));
      expect(activeSorted.any((c) => c.id == 'cat_hidden'), isFalse);
    });

    test('Dynamic Shop category options list prepends "All" option to live active categories', () {
      final firestoreCategories = [
        const Category(
          id: 'cat_milk',
          title: 'Milk',
          subtitle: '100% Pure',
          imageUrl: 'assets/images/doodh.png',
          iconData: null,
          backgroundColor: Colors.white,
          borderColor: Colors.green,
          titleColor: Colors.black,
          itemCount: 5,
          isActive: true,
          sortOrder: 0,
        ),
        const Category(
          id: 'cat_sweets',
          title: 'Sweets',
          subtitle: 'Delicious Sweets',
          imageUrl: 'assets/images/mithai.png',
          iconData: null,
          backgroundColor: Colors.white,
          borderColor: Colors.green,
          titleColor: Colors.black,
          itemCount: 2,
          isActive: true,
          sortOrder: 1,
        ),
      ];

      final categoryOptions = <Map<String, String>>[
        {
          'id': 'cat_all',
          'title': 'All',
          'image': 'assets/images/all.png',
          'description': 'Browse our entire range.',
        },
        ...firestoreCategories.map((c) => {
              'id': c.id,
              'title': c.title,
              'image': c.resolvedImageUrl,
              'description': c.subtitle,
            }),
      ];

      expect(categoryOptions.length, equals(3));
      expect(categoryOptions[0]['id'], equals('cat_all'));
      expect(categoryOptions[1]['id'], equals('cat_milk'));
      expect(categoryOptions[2]['id'], equals('cat_sweets'));
    });
  });
}
