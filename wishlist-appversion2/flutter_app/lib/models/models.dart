class WishlistTab {
  WishlistTab({
    required this.id,
    required this.name,
    required this.isPublic,
    this.colorHex,
  });

  final String id;
  final String name;
  final bool isPublic;
  final String? colorHex;

  WishlistTab copyWith({
    String? id,
    String? name,
    bool? isPublic,
    String? colorHex,
  }) {
    return WishlistTab(
      id: id ?? this.id,
      name: name ?? this.name,
      isPublic: isPublic ?? this.isPublic,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isPublic': isPublic,
        'color': colorHex,
      };

  factory WishlistTab.fromJson(Map<String, dynamic> json) => WishlistTab(
        id: json['id'] as String,
        name: json['name'] as String,
        isPublic: json['isPublic'] as bool? ?? true,
        colorHex: json['color'] as String?,
      );
}

class Product {
  Product({
    required this.id,
    required this.listId,
    required this.name,
    required this.price,
    required this.image,
    required this.platform,
    this.originalPrice,
    this.discount,
    this.productUrl,
    this.memo,
  });

  final int id;
  final String listId;
  final String name;
  final int price;
  final String image;
  final String platform;
  final int? originalPrice;
  final int? discount;
  final String? productUrl;
  final String? memo;

  Product copyWith({
    int? id,
    String? listId,
    String? name,
    int? price,
    String? image,
    String? platform,
    int? originalPrice,
    int? discount,
    String? productUrl,
    String? memo,
  }) {
    return Product(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      price: price ?? this.price,
      image: image ?? this.image,
      platform: platform ?? this.platform,
      originalPrice: originalPrice ?? this.originalPrice,
      discount: discount ?? this.discount,
      productUrl: productUrl ?? this.productUrl,
      memo: memo ?? this.memo,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'name': name,
        'price': price,
        'image': image,
        'platform': platform,
        'originalPrice': originalPrice,
        'discount': discount,
        'productUrl': productUrl,
        'memo': memo,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: (json['id'] as num).toInt(),
        listId: json['listId'] as String,
        name: json['name'] as String,
        price: (json['price'] as num?)?.toInt() ?? 0,
        image: json['image'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
        originalPrice: (json['originalPrice'] as num?)?.toInt(),
        discount: (json['discount'] as num?)?.toInt(),
        productUrl: json['productUrl'] as String?,
        memo: json['memo'] as String?,
      );
}

class AppUser {
  AppUser({
    required this.name,
    required this.handle,
    required this.avatarUrl,
    this.uid = '',
    this.email = '',
    this.followers = 0,
    this.following = 0,
  });

  final String uid;
  final String email;
  final String name;
  final String handle;
  final String avatarUrl;
  final int followers;
  final int following;

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? handle,
    String? avatarUrl,
    int? followers,
    int? following,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      followers: followers ?? this.followers,
      following: following ?? this.following,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'name': name,
        'handle': handle,
        'avatarUrl': avatarUrl,
        'followers': followers,
        'following': following,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String? ?? '',
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '사용자',
        handle: json['handle'] as String? ?? '@user',
        avatarUrl: json['avatarUrl'] as String? ??
            'https://api.dicebear.com/7.x/thumbs/png?seed=user',
        followers: (json['followers'] as num?)?.toInt() ?? 0,
        following: (json['following'] as num?)?.toInt() ?? 0,
      );
}

class Friend {
  Friend({
    required this.id,
    required this.name,
    required this.username,
    required this.avatar,
    required this.isFollowing,
    required this.wishlistCount,
    required this.itemCount,
  });

  final String id;
  final String name;
  final String username;
  final String avatar;
  final bool isFollowing;
  final int wishlistCount;
  final int itemCount;

  Friend copyWith({
    String? id,
    String? name,
    String? username,
    String? avatar,
    bool? isFollowing,
    int? wishlistCount,
    int? itemCount,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      isFollowing: isFollowing ?? this.isFollowing,
      wishlistCount: wishlistCount ?? this.wishlistCount,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}

class FriendWishlist {
  FriendWishlist({
    required this.id,
    required this.friendId,
    required this.friendName,
    required this.listName,
    required this.isPublic,
    required this.items,
  });

  final String id;
  final String friendId;
  final String friendName;
  final String listName;
  final bool isPublic;
  final List<Product> items;
}

/// Snapshot of a basket shared via URL (prototype, local).
class SharedBasket {
  SharedBasket({
    required this.id,
    required this.title,
    required this.ownerName,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String ownerName;
  final List<Product> items;
  final DateTime createdAt;
}

class BasketItem {
  BasketItem({
    required this.product,
    this.isSelected = true,
  });

  final Product product;
  final bool isSelected;

  BasketItem copyWith({Product? product, bool? isSelected}) {
    return BasketItem(
      product: product ?? this.product,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Normalized product info returned by the parsing bridge (engine untouched).
class ParsedProductInfo {
  ParsedProductInfo({
    required this.name,
    required this.price,
    required this.platform,
    required this.image,
    required this.productUrl,
    this.originalPrice,
    this.discount,
    this.missingFields = const [],
    this.resolvedTier,
    this.engineUsed = true,
    this.onDeviceExtracted = false,
  });

  final String name;
  final int price;
  final String platform;
  final String image;
  final String productUrl;
  final int? originalPrice;
  final int? discount;
  final List<String> missingFields;
  final int? resolvedTier;
  final bool engineUsed;

  /// 단말 WebView(Tier 2.5)로 정보를 보완했는지. UI 배지 표시용.
  final bool onDeviceExtracted;

  /// 서버가 못 채운 칸을 단말 WebView 추출 결과로 메운다.
  /// 이미 값이 있는 칸은 서버 값을 존중하고, 비어 있던 칸만 채운다.
  ParsedProductInfo mergeOnDevice({
    String? name,
    int? price,
    String? image,
    String? platform,
  }) {
    final filledPrice =
        (this.price <= 0 && price != null && price > 0) ? price : this.price;
    final filledName = (this.name.isEmpty || this.name == '공유된 상품') &&
            name != null &&
            name.isNotEmpty
        ? name
        : this.name;
    final filledImage = this.image.isEmpty && image != null && image.isNotEmpty
        ? image
        : this.image;
    final filledPlatform =
        (this.platform.isEmpty || this.platform == '쇼핑몰') &&
                platform != null &&
                platform.isNotEmpty
            ? platform
            : this.platform;

    final remaining = missingFields.where((f) {
      if (f == 'price') return filledPrice <= 0;
      if (f == 'title') return filledName.isEmpty;
      if (f == 'image_url') return filledImage.isEmpty;
      return true;
    }).toList();

    return ParsedProductInfo(
      name: filledName,
      price: filledPrice,
      platform: filledPlatform,
      image: filledImage,
      productUrl: productUrl,
      originalPrice: originalPrice,
      discount: discount,
      missingFields: remaining,
      resolvedTier: resolvedTier,
      engineUsed: engineUsed,
      onDeviceExtracted: true,
    );
  }

  /// Engine POST /parse response: { product, resolved_tier, missing_fields, ... }
  factory ParsedProductInfo.fromEngineResponse(Map<String, dynamic> json) {
    final product = (json['product'] as Map<String, dynamic>?) ?? json;
    return ParsedProductInfo.fromEngineProduct(
      product,
      resolvedTier: json['resolved_tier'] as int?,
      missingFields: (json['missing_fields'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Engine product dict (also used by /api/scrap → product).
  factory ParsedProductInfo.fromEngineProduct(
    Map<String, dynamic> product, {
    int? resolvedTier,
    List<String> missingFields = const [],
  }) {
    return ParsedProductInfo(
      name: (product['title'] as String?)?.trim().isNotEmpty == true
          ? product['title'] as String
          : (product['name'] as String? ?? '공유된 상품'),
      price: (product['price'] as num?)?.toInt() ?? 0,
      platform: (product['platform_label'] as String?)?.isNotEmpty == true
          ? product['platform_label'] as String
          : (product['source_platform'] as String? ??
              product['platform'] as String? ??
              '쇼핑몰'),
      image: product['image_url'] as String? ??
          product['image'] as String? ??
          '',
      productUrl: product['original_url'] as String? ??
          product['productUrl'] as String? ??
          product['url'] as String? ??
          '',
      originalPrice: (product['original_price'] as num?)?.toInt() ??
          (product['originalPrice'] as num?)?.toInt(),
      discount: (product['discount_rate'] as num?)?.toInt() ??
          (product['discount'] as num?)?.toInt(),
      missingFields: missingFields.isNotEmpty
          ? missingFields
          : ((product['missing_fields'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const []),
      resolvedTier: resolvedTier ?? product['resolved_tier'] as int?,
      engineUsed: true,
    );
  }

  factory ParsedProductInfo.fromJson(Map<String, dynamic> json) {
    // Backward-compatible flat shape.
    if (json.containsKey('product')) {
      return ParsedProductInfo.fromEngineResponse(json);
    }
    return ParsedProductInfo(
      name: json['name'] as String? ?? '상품',
      price: (json['price'] as num?)?.toInt() ?? 0,
      platform: json['platform'] as String? ?? 'unknown',
      image: json['image'] as String? ?? '',
      productUrl: json['productUrl'] as String? ?? json['url'] as String? ?? '',
      originalPrice: (json['originalPrice'] as num?)?.toInt(),
      discount: (json['discount'] as num?)?.toInt(),
    );
  }
}
