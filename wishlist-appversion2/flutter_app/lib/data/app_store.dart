import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../theme/diary_theme.dart';

class AppStore extends ChangeNotifier {
  static const _tabsKey = 'wishlist_tabs';
  static const _productsKey = 'wishlist_products';
  static const _authKey = 'auth_logged_in';
  static const _basketKey = 'basket_items';
  static const _userKey = 'current_user';
  static const _friendsKey = 'friends_follow';
  static const _sharedKey = 'shared_baskets';

  bool ready = false;
  bool isLoggedIn = false;

  List<WishlistTab> tabs = [];
  List<Product> products = [];
  List<BasketItem> basket = [];
  List<Friend> friends = [];
  List<FriendWishlist> friendWishlists = [];
  final Map<String, SharedBasket> sharedBaskets = {};

  String selectedTabId = 'all';
  String? pendingShareUrl;

  AppUser currentUser = AppUser(
    name: '김지은',
    handle: '@kimjieun',
    avatarUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop',
    followers: 127,
    following: 89,
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool(_authKey) ?? false;

    final tabsRaw = prefs.getString(_tabsKey);
    if (tabsRaw != null) {
      tabs = (jsonDecode(tabsRaw) as List)
          .map((e) => WishlistTab.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      tabs = List.from(_initialTabs);
    }

    final productsRaw = prefs.getString(_productsKey);
    if (productsRaw != null) {
      products = (jsonDecode(productsRaw) as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      products = List.from(_initialProducts);
    }

    final basketRaw = prefs.getString(_basketKey);
    if (basketRaw != null) {
      final ids = (jsonDecode(basketRaw) as List).cast<int>();
      basket = ids
          .map((id) {
            final p = products.where((e) => e.id == id).firstOrNull;
            return p == null ? null : BasketItem(product: p);
          })
          .whereType<BasketItem>()
          .toList();
    }

    final userRaw = prefs.getString(_userKey);
    if (userRaw != null) {
      final map = jsonDecode(userRaw) as Map<String, dynamic>;
      currentUser = AppUser(
        name: map['name'] as String? ?? currentUser.name,
        handle: map['handle'] as String? ?? currentUser.handle,
        avatarUrl: map['avatarUrl'] as String? ?? currentUser.avatarUrl,
        followers: map['followers'] as int? ?? currentUser.followers,
        following: map['following'] as int? ?? currentUser.following,
      );
    }

    friends = List.from(_initialFriends);
    final followRaw = prefs.getString(_friendsKey);
    if (followRaw != null) {
      final followMap = (jsonDecode(followRaw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v == true));
      friends = friends
          .map((f) => followMap.containsKey(f.id)
              ? f.copyWith(isFollowing: followMap[f.id]!)
              : f)
          .toList();
    }
    _syncFollowingCount();
    friendWishlists = _buildFriendWishlists(products);
    friends = friends
        .map((f) {
          final lists =
              friendWishlists.where((w) => w.friendId == f.id).toList();
          final items = lists.fold<int>(0, (sum, w) => sum + w.items.length);
          return f.copyWith(
            wishlistCount: lists.length,
            itemCount: items,
          );
        })
        .toList();

    final sharedRaw = prefs.getString(_sharedKey);
    if (sharedRaw != null) {
      final list = jsonDecode(sharedRaw) as List;
      for (final e in list) {
        final map = e as Map<String, dynamic>;
        final id = map['id'] as String;
        sharedBaskets[id] = SharedBasket(
          id: id,
          title: map['title'] as String? ?? '공유 바구니',
          ownerName: map['ownerName'] as String? ?? currentUser.name,
          items: (map['items'] as List? ?? [])
              .map((p) => Product.fromJson(p as Map<String, dynamic>))
              .toList(),
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
        );
      }
    }

    ready = true;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    // Local prototype auth — no backend yet.
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception('이메일과 비밀번호를 입력해 주세요.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, true);
    isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, false);
    isLoggedIn = false;
    notifyListeners();
  }

  List<Product> get displayedProducts {
    if (selectedTabId == 'all') return products;
    return products.where((p) => p.listId == selectedTabId).toList();
  }

  WishlistTab get selectedTab =>
      tabs.firstWhere((t) => t.id == selectedTabId, orElse: () => tabs.first);

  /// Custom lists only (excludes the fixed "전체" tab).
  List<WishlistTab> get customTabs =>
      tabs.where((t) => t.id != 'all').toList();

  Color tabColor(WishlistTab tab) {
    // Seeded lists map onto the neutral file palette.
    const map = {
      'all': DiaryColors.fileCream,
      'summer': DiaryColors.fileSand,
      'daily': DiaryColors.fileStone,
      'accessories': DiaryColors.fileMauve,
      'beauty': DiaryColors.fileClay,
      'shoes': DiaryColors.fileWarmGray,
    };
    if (tab.colorHex != null && tab.colorHex!.isNotEmpty) {
      final hex = tab.colorHex!.replaceFirst('#', '');
      try {
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    if (map.containsKey(tab.id)) return map[tab.id]!;
    return DiaryColors.fileCream;
  }

  /// Pick a file color that isn't already used when possible.
  Color nextFileColor() {
    final used = <int>{
      for (final t in tabs.where((t) => t.id != 'all'))
        tabColor(t).toARGB32(),
    };
    final unused =
        DiaryColors.fileColors.where((c) => !used.contains(c.toARGB32()));
    final pool =
        unused.isNotEmpty ? unused.toList() : DiaryColors.fileColors.toList();
    return pool[Random().nextInt(pool.length)];
  }

  /// Reorder custom tabs. Indices are among tabs excluding 'all'.
  /// Matches [ReorderableListView.onReorder] (adjusts newIndex when moving down).
  Future<void> reorderTabs(int oldIndex, int newIndex) async {
    final allTab = tabs.firstWhere((t) => t.id == 'all');
    final rest = tabs.where((t) => t.id != 'all').toList();
    if (oldIndex < 0 || oldIndex >= rest.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= rest.length) return;
    final item = rest.removeAt(oldIndex);
    rest.insert(target, item);
    tabs = [allTab, ...rest];
    await _persist();
    notifyListeners();
  }

  int countFor(WishlistTab tab) {
    if (tab.id == 'all') return products.length;
    return products.where((p) => p.listId == tab.id).length;
  }

  void selectTab(String id) {
    selectedTabId = id;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tabsKey,
      jsonEncode(tabs.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _productsKey,
      jsonEncode(products.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _basketKey,
      jsonEncode(basket.map((e) => e.product.id).toList()),
    );
  }

  Future<void> addTab(String name, {bool isPublic = false}) async {
    final color = nextFileColor();
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    final tab = WishlistTab(
      id: 'list-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      isPublic: isPublic,
      colorHex: hex,
    );
    tabs = [...tabs, tab];
    selectedTabId = tab.id;
    await _persist();
    notifyListeners();
  }

  Future<void> renameTab(String id, String name) async {
    tabs = tabs.map((t) => t.id == id ? t.copyWith(name: name) : t).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> deleteTab(String id) async {
    if (id == 'all') return;
    tabs = tabs.where((t) => t.id != id).toList();
    if (selectedTabId == id) selectedTabId = 'all';
    await _persist();
    notifyListeners();
  }

  Future<void> toggleTabPublic(String id) async {
    tabs = tabs
        .map((t) => t.id == id ? t.copyWith(isPublic: !t.isPublic) : t)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> removeProduct(int id) async {
    products = products.where((p) => p.id != id).toList();
    basket = basket.where((b) => b.product.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> moveProduct(int id, String listId) async {
    products = products
        .map((p) => p.id == id ? p.copyWith(listId: listId) : p)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> updateMemo(int id, String memo) async {
    products =
        products.map((p) => p.id == id ? p.copyWith(memo: memo) : p).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> addToBasket(Product product) async {
    if (basket.any((b) => b.product.id == product.id)) return;
    basket = [...basket, BasketItem(product: product)];
    await _persist();
    notifyListeners();
  }

  Future<void> toggleBasketSelected(int id) async {
    basket = basket
        .map((b) => b.product.id == id
            ? b.copyWith(isSelected: !b.isSelected)
            : b)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> removeFromBasket(int id) async {
    basket = basket.where((b) => b.product.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<Product> addParsedProduct(
    ParsedProductInfo info, {
    required String listId,
  }) async {
    final id = (products.map((e) => e.id).fold<int>(0, max)) + 1;
    final product = Product(
      id: id,
      listId: listId == 'all' ? 'summer' : listId,
      name: info.name,
      price: info.price,
      image: info.image.isEmpty
          ? 'https://images.unsplash.com/photo-1524275406383-49f669cf763a?w=400&h=400&fit=crop'
          : info.image,
      platform: info.platform,
      originalPrice: info.originalPrice,
      discount: info.discount,
      productUrl: info.productUrl,
    );
    products = [...products, product];
    await _persist();
    notifyListeners();
    return product;
  }

  void setPendingShareUrl(String? url) {
    pendingShareUrl = url;
    notifyListeners();
  }

  Product? productById(int id) {
    return products.where((p) => p.id == id).firstOrNull;
  }

  Friend? friendById(String id) =>
      friends.where((f) => f.id == id).firstOrNull;

  List<FriendWishlist> wishlistsForFriend(String friendId) =>
      friendWishlists.where((w) => w.friendId == friendId).toList();

  FriendWishlist? friendWishlistById(String id) =>
      friendWishlists.where((w) => w.id == id).firstOrNull;

  SharedBasket? sharedBasketById(String id) => sharedBaskets[id];

  /// Instagram-style follow toggle. Updates button label + following count.
  Future<void> toggleFollow(String friendId) async {
    final idx = friends.indexWhere((f) => f.id == friendId);
    if (idx < 0) return;
    final wasFollowing = friends[idx].isFollowing;
    friends = [
      for (var i = 0; i < friends.length; i++)
        if (i == idx)
          friends[i].copyWith(isFollowing: !wasFollowing)
        else
          friends[i],
    ];
    _syncFollowingCount();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _friendsKey,
      jsonEncode({for (final f in friends) f.id: f.isFollowing}),
    );
    notifyListeners();
  }

  void _syncFollowingCount() {
    currentUser = currentUser.copyWith(
      following: friends.where((f) => f.isFollowing).length,
    );
  }

  Future<void> updateProfile({
    String? name,
    String? handle,
    String? avatarUrl,
  }) async {
    var nextHandle = handle?.trim() ?? currentUser.handle;
    if (nextHandle.isNotEmpty && !nextHandle.startsWith('@')) {
      nextHandle = '@$nextHandle';
    }
    currentUser = currentUser.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : null,
      handle: nextHandle.isNotEmpty ? nextHandle : null,
      avatarUrl: avatarUrl?.trim().isNotEmpty == true ? avatarUrl!.trim() : null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userKey,
      jsonEncode({
        'name': currentUser.name,
        'handle': currentUser.handle,
        'avatarUrl': currentUser.avatarUrl,
        'followers': currentUser.followers,
        'following': currentUser.following,
      }),
    );
    notifyListeners();
  }

  /// Creates a shareable basket snapshot from selected basket items.
  Future<SharedBasket> createSharedBasketFromSelection() async {
    final selected = basket.where((b) => b.isSelected).map((b) => b.product).toList();
    if (selected.isEmpty) {
      throw Exception('공유할 상품을 선택해 주세요.');
    }
    final id = 'sb-${DateTime.now().millisecondsSinceEpoch}';
    final shared = SharedBasket(
      id: id,
      title: '살까말까 공유',
      ownerName: currentUser.name,
      items: selected,
      createdAt: DateTime.now(),
    );
    sharedBaskets[id] = shared;
    await _persistShared();
    notifyListeners();
    return shared;
  }

  String shareUrlFor(SharedBasket basket) =>
      'https://wishlist.app/shared/${basket.id}';

  Future<void> _persistShared() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sharedKey,
      jsonEncode(sharedBaskets.values
          .map((s) => {
                'id': s.id,
                'title': s.title,
                'ownerName': s.ownerName,
                'createdAt': s.createdAt.toIso8601String(),
                'items': s.items.map((p) => p.toJson()).toList(),
              })
          .toList()),
    );
  }

  Product? findCatalogProduct(int id) {
    final own = productById(id);
    if (own != null) return own;
    for (final w in friendWishlists) {
      final hit = w.items.where((p) => p.id == id).firstOrNull;
      if (hit != null) return hit;
    }
    for (final s in sharedBaskets.values) {
      final hit = s.items.where((p) => p.id == id).firstOrNull;
      if (hit != null) return hit;
    }
    return null;
  }
}

final _initialFriends = [
  Friend(
    id: '1',
    name: '김민지',
    username: '@minji_style',
    avatar:
        'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop',
    isFollowing: true,
    wishlistCount: 2,
    itemCount: 5,
  ),
  Friend(
    id: '2',
    name: '이서연',
    username: '@seoyeon',
    avatar:
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&h=200&fit=crop',
    isFollowing: false,
    wishlistCount: 1,
    itemCount: 3,
  ),
  Friend(
    id: '3',
    name: '박준호',
    username: '@junho_daily',
    avatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop',
    isFollowing: true,
    wishlistCount: 1,
    itemCount: 2,
  ),
];

List<FriendWishlist> _buildFriendWishlists(List<Product> seedProducts) {
  Product pick(int i) {
    if (seedProducts.isEmpty) {
      return Product(
        id: 9000 + i,
        listId: 'friend',
        name: '친구 추천 아이템',
        price: 39000,
        image:
            'https://images.unsplash.com/photo-1524275406383-49f669cf763a?w=400&h=400&fit=crop',
        platform: '무신사',
      );
    }
    final src = seedProducts[i % seedProducts.length];
    return Product(
      id: 9000 + i,
      listId: 'friend',
      name: src.name,
      price: src.price,
      image: src.image,
      platform: src.platform,
      originalPrice: src.originalPrice,
      discount: src.discount,
      productUrl: src.productUrl,
    );
  }

  return [
    FriendWishlist(
      id: 'fw-1a',
      friendId: '1',
      friendName: '김민지',
      listName: '봄 데일리룩',
      isPublic: true,
      items: [pick(0), pick(1), pick(3)],
    ),
    FriendWishlist(
      id: 'fw-1b',
      friendId: '1',
      friendName: '김민지',
      listName: '주말 코디',
      isPublic: true,
      items: [pick(4), pick(2)],
    ),
    FriendWishlist(
      id: 'fw-2a',
      friendId: '2',
      friendName: '이서연',
      listName: '미니멀 옷장',
      isPublic: true,
      items: [pick(1), pick(5), pick(6)],
    ),
    FriendWishlist(
      id: 'fw-3a',
      friendId: '3',
      friendName: '박준호',
      listName: '데일리 슈즈',
      isPublic: true,
      items: [pick(7), pick(3)],
    ),
  ];
}

final _initialTabs = [
  WishlistTab(id: 'all', name: '전체', isPublic: true),
  WishlistTab(id: 'summer', name: '여름 여행 옷', isPublic: true),
  WishlistTab(id: 'daily', name: '일상 윗옷', isPublic: true),
  WishlistTab(id: 'accessories', name: '악세서리', isPublic: false),
  WishlistTab(id: 'beauty', name: '뷰티', isPublic: true),
  WishlistTab(id: 'shoes', name: '신발', isPublic: false),
];

final _initialProducts = [
  Product(
    id: 1,
    listId: 'summer',
    name: '린넨 블렌드 셔츠',
    price: 45000,
    originalPrice: 58000,
    image:
        'https://images.unsplash.com/photo-1624222244232-5f1ae13bbd53?w=400&h=400&fit=crop&auto=format',
    platform: '무신사',
    discount: 22,
    productUrl: 'https://www.musinsa.com',
  ),
  Product(
    id: 2,
    listId: 'daily',
    name: '베이직 화이트 티셔츠',
    price: 29000,
    image:
        'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=400&h=400&fit=crop&auto=format',
    platform: '지그재그',
  ),
  Product(
    id: 3,
    listId: 'accessories',
    name: '실버 체인 브레이슬릿',
    price: 38000,
    originalPrice: 48000,
    image:
        'https://images.unsplash.com/photo-1621341103818-01dada8c6ef8?w=400&h=400&fit=crop&auto=format',
    platform: '29CM',
    discount: 21,
  ),
  Product(
    id: 4,
    listId: 'summer',
    name: '베이지 롱 코트',
    price: 128000,
    image:
        'https://images.unsplash.com/photo-1544022613-e87ca75a784a?w=400&h=400&fit=crop&auto=format',
    platform: '무신사',
  ),
  Product(
    id: 5,
    listId: 'daily',
    name: '화이트 와이드 팬츠',
    price: 52000,
    originalPrice: 69000,
    image:
        'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400&h=400&fit=crop&auto=format',
    platform: '쿠팡',
    discount: 25,
  ),
  Product(
    id: 6,
    listId: 'accessories',
    name: '골드 링 세트',
    price: 24000,
    image:
        'https://images.unsplash.com/photo-1623251738730-c43469a8aefc?w=400&h=400&fit=crop&auto=format',
    platform: '지그재그',
  ),
  Product(
    id: 7,
    listId: 'beauty',
    name: '파스텔 니트 가디건',
    price: 42000,
    image:
        'https://images.unsplash.com/photo-1524275406383-49f669cf763a?w=400&h=400&fit=crop&auto=format',
    platform: '29CM',
  ),
  Product(
    id: 8,
    listId: 'shoes',
    name: '미니멀 안경',
    price: 68000,
    originalPrice: 85000,
    image:
        'https://images.unsplash.com/photo-1574258495973-f010dfbb5371?w=400&h=400&fit=crop&auto=format',
    platform: '무신사',
    discount: 20,
  ),
];
