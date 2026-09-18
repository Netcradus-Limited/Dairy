/// Sawariya Dairy Asset Paths & Resolution Logic
abstract class AppAssets {
  static const String imagePath = 'assets/images';
  static const String logoPath = '$imagePath/logo';
  static const String productPath = '$imagePath/products';
  static const String categoryPath = '$imagePath/categories';
  static const String bannerPath = '$imagePath/banners';
  static const String iconPath = '$imagePath/icons';

  static const String landingHeroMilk = '$imagePath/newland1.png';
  static const String landingHeroProducts = '$imagePath/newland2.png';
  static const String landingHeroScooter = '$imagePath/newland3.png';
  static const String landingBgMeadow = '$imagePath/landing_bg_meadow.jpg';
  static const String landingBg = '$imagePath/landing.jpg';
  static const String loginHeroCow = '$imagePath/login_hero_cow.jpg';
  static const String dairyMascot = '$imagePath/dairy_mascot.jpg';
  static const String sawariyaLogo = '$imagePath/newlogo.png';
  static const String milkBottle = '$productPath/sawariya_milk_bottle.jpg';
  static const String lassiBottle = '$productPath/sawariya_lassi_bottle.jpg';

  // PNG product images for hero / banner / cards use
  static const String milkPng = '$imagePath/nnd.png';
  static const String lassiPng = '$imagePath/nnl.png';
  static const String gheePng = '$imagePath/nng.png';
  static const String paneerPng = '$imagePath/nnp.png';
  static const String makhanPng = '$imagePath/nnm.png';
  static const String uplePng = '$imagePath/uple.png';
  static const String waterPng = '$imagePath/water.png';

  // PNG category images (Home / Shop category cards)
  static const String milkCategory = '$imagePath/doodh.png';
  static const String gheeCategory = '$imagePath/newgh.png';
  static const String lassiCategory = '$imagePath/las.png';
  static const String makhanCategory = '$imagePath/mak.png';
  static const String paneerCategory = '$imagePath/pan.png';
  static const String upleCategory = '$imagePath/u3.png';
  static const String waterCategory = '$imagePath/w3.png';

  // Placeholder URLs for remote network fallback images
  static const String milkPlaceholder =
      'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80';
  static const String curdPlaceholder =
      'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=600&q=80';
  static const String paneerPlaceholder =
      'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80';
  static const String gheePlaceholder =
      'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=600&q=80';
  static const String heroBannerPlaceholder =
      'https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80';
  static const String a2BannerPlaceholder =
      'https://images.unsplash.com/photo-1500595046743-cd271d694d30?auto=format&fit=crop&w=1200&q=80';

  // ─── Image resolution helpers ──────────────────────────────────────────────

  /// Default local asset for each category (category card thumbnails).
  static const Map<String, String> _categoryDefaultByKey = {
    'cat_milk': milkCategory,
    'cat_ghee': gheeCategory,
    'cat_lassi': lassiCategory,
    'cat_makhan': makhanCategory,
    'cat_paneer': paneerCategory,
    'cat_uple': upleCategory,
    'cat_water': waterCategory,
  };

  /// Default local asset for the products that belong to each category.
  static const Map<String, String> _productDefaultByKey = {
    'cat_milk': milkPng,
    'cat_ghee': gheePng,
    'cat_lassi': lassiPng,
    'cat_makhan': makhanPng,
    'cat_paneer': paneerPng,
    'cat_uple': uplePng,
    'cat_water': waterPng,
  };

  /// Every known-valid local asset path in the project bundle.
  static const Set<String> _validAssetPaths = {
    '$imagePath/all.png',
    milkCategory,
    gheeCategory,
    lassiCategory,
    makhanCategory,
    paneerCategory,
    upleCategory,
    waterCategory,
    milkPng,
    gheePng,
    lassiPng,
    makhanPng,
    paneerPng,
    uplePng,
    waterPng,
    sawariyaLogo,
    milkBottle,
    lassiBottle,
    landingHeroMilk,
    landingHeroProducts,
    landingHeroScooter,
    landingBgMeadow,
    landingBg,
    loginHeroCow,
    dairyMascot,
    '$imagePath/nicon.png',
    '$imagePath/1.png',
    '$imagePath/2.png',
    '$imagePath/3.png',
    '$imagePath/deliver.png',
    '$imagePath/delivery.jpg',
    '$imagePath/freshness.jpg',
    '$imagePath/home.png',
    '$imagePath/hygien.jpg',
    '$imagePath/nature quality.jpg',
    '$imagePath/poster.jpg',
    '$imagePath/purity.jpg',
    '$imagePath/quality.jpg',
    '$imagePath/trust.jpg',
    '$imagePath/why.jpeg',
    '$imagePath/shopbanner1.png',
    '$imagePath/shopbanner2.png',
    '$imagePath/shopbanner3.png',
    '$imagePath/banner4.png',
    '$imagePath/banner5.png',
    '$imagePath/bghome.png',
  };

  /// Returns true if [url] is a remote network URL (http, https, gs).
  static bool isNetworkImage(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gs://');
  }

  /// Normalizes any given image path or remote URL according to application rules:
  /// 1. Null / empty string returns empty string.
  /// 2. Remote URLs (http://, https://, gs://) are returned unchanged.
  /// 3. Redundant `assets/assets/` prefixes are collapsed to single `assets/`.
  /// 4. Paths already starting with `assets/` are kept as-is (never prepends another assets/).
  /// 5. Paths starting with `images/` are prepended with `assets/` -> `assets/images/...`.
  /// 6. Relative subpaths (e.g. `banners/x.png`) are prepended with `assets/` -> `assets/banners/x.png`.
  /// 7. Plain filenames (e.g. `milk.png`) are prepended with `assets/images/` -> `assets/images/milk.png`.
  static String normalizeAssetPath(String? rawPath) {
    if (rawPath == null) return '';
    var path = rawPath.trim();
    if (path.isEmpty) return '';

    // Remote network or cloud storage URL
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('gs://')) {
      return path;
    }

    // Collapse any repeated assets/ prefixes
    while (path.startsWith('assets/assets/')) {
      path = path.substring(7); // removes the first 'assets/'
    }

    if (path.startsWith('assets/')) {
      return path;
    }

    if (path.startsWith('images/')) {
      return 'assets/$path';
    }

    if (path.contains('/')) {
      return 'assets/$path';
    }

    return 'assets/images/$path';
  }

  static String? _fallbackDefault(
      Map<String, String> defaults, String? categoryKey) {
    if (categoryKey == null) return null;
    final key = categoryKey.toLowerCase();
    for (final entry in defaults.entries) {
      if (entry.key == categoryKey || entry.key == key) {
        return entry.value;
      }
    }
    for (final entry in defaults.entries) {
      final defaultKey = entry.key.replaceFirst('cat_', '').toLowerCase();
      if (key == defaultKey ||
          key.contains(defaultKey) ||
          defaultKey.contains(key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Resolves which image source to use for a category thumbnail.
  /// A valid network URL (http/https/gs) is ALWAYS returned unchanged.
  /// A valid local asset path is returned unchanged.
  /// Obsolete paths or keyword matches resolve to the correct category asset.
  static String? categoryImage({
    String? imageUrl,
    String? categoryKey,
    String? name,
  }) {
    final normalized = normalizeAssetPath(imageUrl);
    if (isNetworkImage(normalized)) return normalized;

    final search =
        '${categoryKey ?? ''} ${name ?? ''} $normalized'.toLowerCase();
    if (search.contains('paneer') || search.contains('pan')) {
      return paneerCategory;
    }
    if (search.contains('ghee') || search.contains('gh')) {
      return gheeCategory;
    }
    if (search.contains('lassi') || search.contains('las')) {
      return lassiCategory;
    }
    if (search.contains('makhan') ||
        search.contains('butter') ||
        search.contains('mak')) {
      return makhanCategory;
    }
    if (search.contains('uple') ||
        search.contains('dung') ||
        search.contains('u3')) {
      return upleCategory;
    }
    if (search.contains('water') || search.contains('w3')) {
      return waterCategory;
    }
    if (search.contains('milk') ||
        search.contains('doodh') ||
        search.contains('dood')) {
      return milkCategory;
    }
    if (search.contains('all')) {
      return '$imagePath/all.png';
    }

    if (_validAssetPaths.contains(normalized)) {
      return normalized;
    }

    return _fallbackDefault(_categoryDefaultByKey, categoryKey ?? name) ??
        milkCategory;
  }

  /// Resolves which image source to use for a product thumbnail.
  /// A valid network URL (http/https/gs) is ALWAYS returned unchanged.
  /// Identifies the product from title, categoryKey, productId, or imageUrl to avoid
  /// displaying stale generic milk images from previous order records or 404s for obsolete asset names.
  static String? productImage({
    String? imageUrl,
    String? categoryKey,
    String? productId,
    String? productTitle,
    String? title,
  }) {
    final normalized = normalizeAssetPath(imageUrl);

    // 1. Direct valid network URL (http/https/gs from Firestore / Firebase Storage)
    if (isNetworkImage(normalized)) {
      return normalized;
    }

    final effectiveTitle = (productTitle ?? title)?.trim();
    final effectiveProductId = productId?.trim();
    final effectiveCategoryKey = categoryKey?.trim();

    // 2. Identify the product from title, category, ID, or raw asset filename
    final search =
        '${effectiveTitle ?? ''} ${effectiveCategoryKey ?? ''} ${effectiveProductId ?? ''} $normalized'
            .toLowerCase();

    if (search.contains('paneer') || search.contains('pan')) {
      return paneerPng;
    }
    if (search.contains('ghee') || search.contains('gh')) {
      return gheePng;
    }
    if (search.contains('lassi') || search.contains('las')) {
      return lassiPng;
    }
    if (search.contains('makhan') ||
        search.contains('butter') ||
        search.contains('mak')) {
      return makhanPng;
    }
    if (search.contains('uple') ||
        search.contains('dung') ||
        search.contains('u3')) {
      return uplePng;
    }
    if (search.contains('water') || search.contains('w3')) {
      return waterPng;
    }
    if (search.contains('milk') ||
        search.contains('doodh') ||
        search.contains('nnd')) {
      return milkPng;
    }

    // 3. Fallbacks by mapped keys
    final fromId = _fallbackDefault(_productDefaultByKey, effectiveProductId);
    if (fromId != null) {
      return fromId;
    }
    final fromCategory =
        _fallbackDefault(_productDefaultByKey, effectiveCategoryKey);
    if (fromCategory != null) {
      return fromCategory;
    }
    final fromTitle = _fallbackDefault(_productDefaultByKey, effectiveTitle);
    if (fromTitle != null) {
      return fromTitle;
    }

    // 4. If normalized imageUrl is an explicit valid bundled asset and no conflicting keyword was found
    if (_validAssetPaths.contains(normalized)) {
      return normalized;
    }

    return milkPng;
  }
}
