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
    this.isPublic = false,
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
  final bool isPublic;

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
    bool? isPublic,
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
      isPublic: isPublic ?? this.isPublic,
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
    'isPublic': isPublic,
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
    isPublic: json['isPublic'] as bool? ?? false,
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
    avatarUrl:
        json['avatarUrl'] as String? ??
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

/// Snapshot of a basket shared via URL or sent to a friend in-app.
class SharedBasket {
  SharedBasket({
    required this.id,
    required this.title,
    required this.ownerName,
    required this.items,
    required this.createdAt,
    this.fromUid = '',
    this.fromHandle = '',
    this.fromAvatar = '',
    this.recipientUids = const [],
    this.recipientNames = const [],
  });

  final String id;
  final String title;
  final String ownerName;
  final List<Product> items;
  final DateTime createdAt;
  final String fromUid;
  final String fromHandle;
  final String fromAvatar;
  final List<String> recipientUids;
  final List<String> recipientNames;

  SharedBasket copyWith({
    List<String>? recipientUids,
    List<String>? recipientNames,
  }) {
    return SharedBasket(
      id: id,
      title: title,
      ownerName: ownerName,
      items: items,
      createdAt: createdAt,
      fromUid: fromUid,
      fromHandle: fromHandle,
      fromAvatar: fromAvatar,
      recipientUids: recipientUids ?? this.recipientUids,
      recipientNames: recipientNames ?? this.recipientNames,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'ownerName': ownerName,
    'fromUid': fromUid,
    'fromHandle': fromHandle,
    'fromAvatar': fromAvatar,
    'createdAt': createdAt.toIso8601String(),
    'items': items.map((p) => p.toJson()).toList(),
    'recipientUids': recipientUids,
    'recipientNames': recipientNames,
  };

  factory SharedBasket.fromJson(Map<String, dynamic> json) => SharedBasket(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '살까말까 공유',
    ownerName: json['ownerName'] as String? ?? '',
    fromUid: json['fromUid'] as String? ?? '',
    fromHandle: json['fromHandle'] as String? ?? '',
    fromAvatar: json['fromAvatar'] as String? ?? '',
    items: (json['items'] as List? ?? [])
        .map((p) => Product.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    recipientUids: (json['recipientUids'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    recipientNames: (json['recipientNames'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

enum AppNotificationType { follow, basket, review, list }

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    required this.fromHandle,
    required this.fromAvatar,
    required this.message,
    required this.createdAt,
    this.relatedId,
    this.read = false,
  });

  final String id;
  final AppNotificationType type;
  final String fromUid;
  final String fromName;
  final String fromHandle;
  final String fromAvatar;
  final String message;
  final String? relatedId;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    fromUid: fromUid,
    fromName: fromName,
    fromHandle: fromHandle,
    fromAvatar: fromAvatar,
    message: message,
    relatedId: relatedId,
    createdAt: createdAt,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'fromUid': fromUid,
    'fromName': fromName,
    'fromHandle': fromHandle,
    'fromAvatar': fromAvatar,
    'message': message,
    'relatedId': relatedId,
    'read': read,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final typeRaw = json['type'] as String? ?? 'follow';
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: switch (typeRaw) {
        'basket' => AppNotificationType.basket,
        'review' => AppNotificationType.review,
        'list' => AppNotificationType.list,
        _ => AppNotificationType.follow,
      },
      fromUid: json['fromUid'] as String? ?? '',
      fromName: json['fromName'] as String? ?? '',
      fromHandle: json['fromHandle'] as String? ?? '',
      fromAvatar: json['fromAvatar'] as String? ?? '',
      message: json['message'] as String? ?? '',
      relatedId: json['relatedId'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: _notificationTime(json),
    );
  }
}

DateTime _notificationTime(Map<String, dynamic> json) {
  final raw = json['createdAt'] ?? json['createdAtServer'];
  if (raw is DateTime) return raw;
  if (raw is String) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
  try {
    final dynamic value = raw;
    if (value != null) {
      final dated = value.toDate();
      if (dated is DateTime) return dated;
    }
  } catch (_) {}
  return DateTime.now();
}

/// Friend who sent one or more 살까말까 baskets (for the friends tab).
class FriendSalkamalka {
  FriendSalkamalka({
    required this.friendId,
    required this.friendName,
    required this.friendHandle,
    required this.friendAvatar,
    required this.baskets,
  });

  final String friendId;
  final String friendName;
  final String friendHandle;
  final String friendAvatar;
  final List<SharedBasket> baskets;

  List<Product> get allProducts {
    final seen = <int>{};
    final out = <Product>[];
    for (final b in baskets) {
      for (final p in b.items) {
        if (seen.add(p.id)) out.add(p);
      }
    }
    return out;
  }

  int get itemCount => allProducts.length;
}

class SalkamalkaFeedEntry {
  SalkamalkaFeedEntry({required this.basket, required this.isMine});

  final SharedBasket basket;
  final bool isMine;
}

/// Blog-style product review shared with followers.
class ProductReview {
  ProductReview({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorHandle,
    required this.authorAvatar,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPlatform,
    required this.productPrice,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.productUrl,
    this.mood = 3,
    this.imageUrls = const [],
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String authorHandle;
  final String authorAvatar;
  final int productId;
  final String productName;
  final String productImage;
  final String productPlatform;
  final int productPrice;
  final String? productUrl;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int mood;
  final List<String> imageUrls;

  ProductReview copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
    String? authorName,
    String? authorHandle,
    String? authorAvatar,
    int? mood,
    List<String>? imageUrls,
  }) {
    return ProductReview(
      id: id,
      authorUid: authorUid,
      authorName: authorName ?? this.authorName,
      authorHandle: authorHandle ?? this.authorHandle,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      productId: productId,
      productName: productName,
      productImage: productImage,
      productPlatform: productPlatform,
      productPrice: productPrice,
      productUrl: productUrl,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mood: mood ?? this.mood,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorUid': authorUid,
    'authorName': authorName,
    'authorHandle': authorHandle,
    'authorAvatar': authorAvatar,
    'productId': productId,
    'productName': productName,
    'productImage': productImage,
    'productPlatform': productPlatform,
    'productPrice': productPrice,
    'productUrl': productUrl,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'mood': mood,
    'imageUrls': imageUrls,
  };

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
    id: json['id'] as String? ?? '',
    authorUid: json['authorUid'] as String? ?? '',
    authorName: json['authorName'] as String? ?? '',
    authorHandle: json['authorHandle'] as String? ?? '',
    authorAvatar: json['authorAvatar'] as String? ?? '',
    productId: (json['productId'] as num?)?.toInt() ?? 0,
    productName: json['productName'] as String? ?? '',
    productImage: json['productImage'] as String? ?? '',
    productPlatform: json['productPlatform'] as String? ?? '',
    productPrice: (json['productPrice'] as num?)?.toInt() ?? 0,
    productUrl: json['productUrl'] as String?,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    mood: (json['mood'] as num?)?.toInt() ?? 3,
    imageUrls: (json['imageUrls'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

class BasketItem {
  BasketItem({required this.product, this.isSelected = true});

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
    this.purchasePriceStatus = 'unknown',
    this.priceConfidence = 'unknown',
    this.availability = 'unknown',
    this.optionDependent,
    this.optionPriceMin,
    this.optionPriceMax,
    this.priceEvidence = const [],
    this.extractFailureReason,
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
  final String purchasePriceStatus;
  final String priceConfidence;
  final String availability;
  final bool? optionDependent;
  final int? optionPriceMin;
  final int? optionPriceMax;
  final List<Map<String, dynamic>> priceEvidence;
  final String? extractFailureReason;

  bool get needsManualPrice => price <= 0;

  /// Canonical v2 aliases. 기존 UI의 price/originalPrice는 하위 호환용이다.
  int? get purchasePrice => price > 0 ? price : null;
  int? get regularPrice => originalPrice;

  /// 단말 WebView(Tier 2.5)로 정보를 보완했는지. UI 배지 표시용.
  final bool onDeviceExtracted;

  /// 서버가 못 채운 칸을 단말 WebView 추출 결과로 메운다.
  /// [replacePrice]일 때는 화면에서 검증한 정가·판매가 쌍으로 교체한다.
  ParsedProductInfo mergeOnDevice({
    String? name,
    int? price,
    int? originalPrice,
    String? image,
    String? platform,
    bool replacePrice = false,
    String? purchasePriceStatus,
    String? priceConfidence,
    String? availability,
    bool? optionDependent,
    int? optionPriceMin,
    int? optionPriceMax,
    List<Map<String, dynamic>>? priceEvidence,
  }) {
    final hasDevicePrice = price != null && price > 0;
    final filledPrice = hasDevicePrice && (replacePrice || this.price <= 0)
        ? price
        : this.price;
    final candidateOriginal = hasDevicePrice && replacePrice
        ? originalPrice
        : (this.originalPrice ?? originalPrice);
    final filledOriginal =
        candidateOriginal != null && candidateOriginal > filledPrice
        ? candidateOriginal
        : null;
    final filledDiscount = filledOriginal != null && filledPrice > 0
        ? ((filledOriginal - filledPrice) / filledOriginal * 100).round()
        : null;
    final filledName =
        (this.name.isEmpty || this.name == '공유된 상품') &&
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
      originalPrice: filledOriginal,
      discount: filledDiscount,
      missingFields: remaining,
      resolvedTier: resolvedTier,
      engineUsed: engineUsed,
      onDeviceExtracted: true,
      purchasePriceStatus: hasDevicePrice
          ? (purchasePriceStatus ?? 'provisional')
          : this.purchasePriceStatus,
      priceConfidence: hasDevicePrice
          ? (priceConfidence ?? 'low')
          : this.priceConfidence,
      availability: availability ?? this.availability,
      optionDependent: optionDependent ?? this.optionDependent,
      optionPriceMin: optionPriceMin ?? this.optionPriceMin,
      optionPriceMax: optionPriceMax ?? this.optionPriceMax,
      priceEvidence: hasDevicePrice
          ? (priceEvidence ??
                const [
                  {
                    'price_role': 'purchase_price',
                    'source': 'rendered-webview',
                    'adapter': null,
                    'field': null,
                  },
                ])
          : this.priceEvidence,
      extractFailureReason: extractFailureReason,
    );
  }

  /// Engine POST /parse response: { product, resolved_tier, missing_fields, ... }
  factory ParsedProductInfo.fromEngineResponse(Map<String, dynamic> json) {
    final product = (json['product'] as Map<String, dynamic>?) ?? json;
    return ParsedProductInfo.fromEngineProduct(
      product,
      resolvedTier: json['resolved_tier'] as int?,
      missingFields:
          (json['missing_fields'] as List?)
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
    final pricing = (product['pricing'] as Map?)?.cast<String, dynamic>();
    final purchasePrice = pricing != null
        ? (pricing['purchase_price'] as num?)?.toInt()
        : (product['price'] as num?)?.toInt();
    final regularPrice = pricing != null
        ? (pricing['regular_price'] as num?)?.toInt()
        : (product['original_price'] as num?)?.toInt() ??
              (product['originalPrice'] as num?)?.toInt();
    final evidence =
        (pricing?['evidence'] as List?)
            ?.whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList() ??
        const <Map<String, dynamic>>[];
    return ParsedProductInfo(
      name: (product['title'] as String?)?.trim().isNotEmpty == true
          ? product['title'] as String
          : (product['name'] as String? ?? '공유된 상품'),
      price: purchasePrice ?? 0,
      platform: (product['platform_label'] as String?)?.isNotEmpty == true
          ? product['platform_label'] as String
          : (product['source_platform'] as String? ??
                product['platform'] as String? ??
                '쇼핑몰'),
      image:
          product['image_url'] as String? ?? product['image'] as String? ?? '',
      productUrl:
          product['original_url'] as String? ??
          product['productUrl'] as String? ??
          product['url'] as String? ??
          '',
      originalPrice: regularPrice,
      discount:
          (product['discount_rate'] as num?)?.toInt() ??
          (product['discount'] as num?)?.toInt(),
      missingFields: missingFields.isNotEmpty
          ? missingFields
          : ((product['missing_fields'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const []),
      resolvedTier: resolvedTier ?? product['resolved_tier'] as int?,
      engineUsed: true,
      purchasePriceStatus:
          pricing?['purchase_price_status'] as String? ??
          product['purchase_price_status'] as String? ??
          (purchasePrice == null ? 'unknown' : 'provisional'),
      priceConfidence:
          pricing?['confidence'] as String? ??
          product['price_confidence'] as String? ??
          'unknown',
      availability: product['availability'] as String? ?? 'unknown',
      optionDependent: pricing?['option_dependent'] as bool?,
      optionPriceMin: (pricing?['option_price_min'] as num?)?.toInt(),
      optionPriceMax: (pricing?['option_price_max'] as num?)?.toInt(),
      priceEvidence: evidence,
    );
  }

  factory ParsedProductInfo.fromJson(Map<String, dynamic> json) {
    // Backward-compatible flat shape.
    if (json.containsKey('product')) {
      return ParsedProductInfo.fromEngineResponse(json);
    }
    if (json.containsKey('pricing') || json.containsKey('original_price')) {
      return ParsedProductInfo.fromEngineProduct(json);
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
