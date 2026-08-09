import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/models.dart';
import '../services/account_repository.dart';
import '../theme/diary_theme.dart';

class AppStore extends ChangeNotifier {
  static const _basketKey = 'basket_items';
  static const _sharedKey = 'shared_baskets';

  AppStore({AccountRepository? repository})
      : _repo = repository ?? AccountRepository();

  final AccountRepository _repo;

  bool ready = false;
  bool firebaseReady = false;
  String? firebaseError;
  bool isLoggedIn = false;
  bool awaitingEmailVerification = false;
  String? pendingVerificationEmail;
  String? _pendingName;
  String? _pendingHandle;

  List<WishlistTab> tabs = [];
  List<Product> products = [];
  List<BasketItem> basket = [];
  List<Friend> friends = [];
  List<FriendWishlist> friendWishlists = [];
  final Map<String, SharedBasket> sharedBaskets = {};

  String selectedTabId = 'all';
  String? pendingShareUrl;

  AppUser currentUser = AppUser(
    name: '게스트',
    handle: '@guest',
    avatarUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=guest',
  );

  Future<void> init() async {
    firebaseReady = isFirebaseConfigured;
    if (!firebaseReady) {
      firebaseError =
          'Firebase 키가 아직 설정되지 않았어요. FIREBASE_SETUP.md 를 따라 앱을 등록해 주세요.';
      ready = true;
      notifyListeners();
      return;
    }

    try {
      // Initialized in main.dart — just sync auth state.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _hydrateSession(user);
      }
    } catch (e) {
      firebaseError = e.toString();
    }

    await _loadLocalExtras();
    ready = true;
    notifyListeners();
  }

  Future<void> _hydrateSession(User user) async {
    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser ?? user;
    if (!fresh.emailVerified) {
      awaitingEmailVerification = true;
      pendingVerificationEmail = fresh.email;
      isLoggedIn = false;
      return;
    }

    awaitingEmailVerification = false;
    pendingVerificationEmail = null;
    await _repo.ensureProfile(
      fresh,
      name: _pendingName,
      handle: _pendingHandle,
    );
    _pendingName = null;
    _pendingHandle = null;
    final profile = await _repo.loadProfile(fresh.uid);
    if (profile != null) {
      currentUser = profile;
    }
    tabs = await _repo.loadTabs(fresh.uid);
    products = await _repo.loadProducts(fresh.uid);
    final following = (await _repo.followingIds(fresh.uid)).toSet();
    friends = await _repo.loadDirectory(myUid: fresh.uid, following: following);
    friendWishlists = await _repo.loadFriendWishlists(friends);
    _syncFriendCounts();
    currentUser = currentUser.copyWith(
      following: following.length,
    );
    isLoggedIn = true;
    selectedTabId = 'all';
  }

  Future<void> _clearSessionLocal() async {
    isLoggedIn = false;
    awaitingEmailVerification = false;
    pendingVerificationEmail = null;
    _pendingName = null;
    _pendingHandle = null;
    tabs = [];
    products = [];
    basket = [];
    friends = [];
    friendWishlists = [];
    currentUser = AppUser(
      name: '게스트',
      handle: '@guest',
      avatarUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=guest',
    );
    selectedTabId = 'all';
  }

  Future<void> register({
    required String email,
    required String password,
    String name = '',
    String handle = '',
  }) async {
    _ensureFirebase();
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception('이메일과 비밀번호를 입력해 주세요.');
    }
    if (password.trim().length < 6) {
      throw Exception('비밀번호는 6자 이상이어야 해요.');
    }
    _pendingName = name.trim().isEmpty ? null : name.trim();
    _pendingHandle = handle.trim().isEmpty ? null : handle.trim();
    await _repo.registerPending(email: email, password: password);
    awaitingEmailVerification = true;
    pendingVerificationEmail = email.trim();
    isLoggedIn = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    _ensureFirebase();
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception('이메일과 비밀번호를 입력해 주세요.');
    }
    final cred = await _repo.login(email: email, password: password);
    final user = cred.user!;
    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser ?? user;
    if (!fresh.emailVerified) {
      awaitingEmailVerification = true;
      pendingVerificationEmail = fresh.email ?? email.trim();
      isLoggedIn = false;
      notifyListeners();
      return;
    }
    await _hydrateSession(fresh);
    await _restoreBasketForUser();
    notifyListeners();
  }

  Future<void> resendVerificationEmail() async {
    _ensureFirebase();
    await _repo.sendVerificationEmail();
  }

  /// Returns true when the email is verified and the app account is ready.
  Future<bool> confirmEmailVerified() async {
    _ensureFirebase();
    final user = await _repo.reloadUser();
    if (user == null) {
      throw Exception('로그인 세션이 없어요. 다시 로그인해 주세요.');
    }
    if (!user.emailVerified) return false;
    await _hydrateSession(user);
    await _restoreBasketForUser();
    notifyListeners();
    return true;
  }

  Future<void> cancelEmailVerification() async {
    if (firebaseReady) {
      await _repo.logout();
    }
    await _clearSessionLocal();
    notifyListeners();
  }

  Future<void> logout() async {
    if (firebaseReady) {
      await _repo.logout();
    }
    await _clearSessionLocal();
    notifyListeners();
  }

  void _ensureFirebase() {
    if (!firebaseReady) {
      throw Exception(
        'Firebase가 연결되지 않았어요. 콘솔에서 앱 등록 후 firebase_options.dart 를 채워 주세요.',
      );
    }
  }

  String? get uid =>
      currentUser.uid.isNotEmpty ? currentUser.uid : _repo.firebaseUser?.uid;

  List<Product> get displayedProducts {
    if (selectedTabId == 'all') return products;
    return products.where((p) => p.listId == selectedTabId).toList();
  }

  WishlistTab get selectedTab =>
      tabs.firstWhere((t) => t.id == selectedTabId, orElse: () => tabs.first);

  List<WishlistTab> get customTabs =>
      tabs.where((t) => t.id != 'all').toList();

  Color tabColor(WishlistTab tab) {
    const map = {
      'all': DiaryColors.fileCream,
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
    await _persistTabs();
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

  Future<void> _persistTabs() async {
    final id = uid;
    if (id == null) return;
    await _repo.saveTabs(id, tabs);
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
    await _persistTabs();
    notifyListeners();
  }

  Future<void> renameTab(String id, String name) async {
    tabs = tabs.map((t) => t.id == id ? t.copyWith(name: name) : t).toList();
    await _persistTabs();
    notifyListeners();
  }

  Future<void> deleteTab(String id) async {
    if (id == 'all') return;
    tabs = tabs.where((t) => t.id != id).toList();
    if (selectedTabId == id) selectedTabId = 'all';
    final userId = uid;
    if (userId != null) {
      await _repo.deleteTabDoc(userId, id);
      await _persistTabs();
    }
    notifyListeners();
  }

  Future<void> toggleTabPublic(String id) async {
    tabs = tabs
        .map((t) => t.id == id ? t.copyWith(isPublic: !t.isPublic) : t)
        .toList();
    await _persistTabs();
    notifyListeners();
  }

  Future<void> removeProduct(int id) async {
    products = products.where((p) => p.id != id).toList();
    basket = basket.where((b) => b.product.id != id).toList();
    final userId = uid;
    if (userId != null) {
      await _repo.deleteProduct(userId, id);
    }
    await _persistBasket();
    notifyListeners();
  }

  Future<void> moveProduct(int id, String listId) async {
    products = products
        .map((p) => p.id == id ? p.copyWith(listId: listId) : p)
        .toList();
    final userId = uid;
    final product = productById(id);
    if (userId != null && product != null) {
      await _repo.upsertProduct(userId, product);
    }
    notifyListeners();
  }

  Future<void> updateMemo(int id, String memo) async {
    products =
        products.map((p) => p.id == id ? p.copyWith(memo: memo) : p).toList();
    final userId = uid;
    final product = productById(id);
    if (userId != null && product != null) {
      await _repo.upsertProduct(userId, product);
    }
    notifyListeners();
  }

  Future<void> addToBasket(Product product) async {
    if (basket.any((b) => b.product.id == product.id)) return;
    basket = [...basket, BasketItem(product: product)];
    await _persistBasket();
    notifyListeners();
  }

  Future<void> toggleBasketSelected(int id) async {
    basket = basket
        .map((b) => b.product.id == id
            ? b.copyWith(isSelected: !b.isSelected)
            : b)
        .toList();
    await _persistBasket();
    notifyListeners();
  }

  Future<void> removeFromBasket(int id) async {
    basket = basket.where((b) => b.product.id != id).toList();
    await _persistBasket();
    notifyListeners();
  }

  Future<Product> addParsedProduct(
    ParsedProductInfo info, {
    required String listId,
  }) async {
    final id = (products.map((e) => e.id).fold<int>(0, max)) + 1;
    final product = Product(
      id: id == 0 ? DateTime.now().millisecondsSinceEpoch : id,
      listId: listId,
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
    final userId = uid;
    if (userId != null) {
      await _repo.upsertProduct(userId, product);
    }
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

  Future<void> refreshFriends() async {
    final userId = uid;
    if (userId == null) return;
    final following = (await _repo.followingIds(userId)).toSet();
    friends = await _repo.loadDirectory(myUid: userId, following: following);
    friendWishlists = await _repo.loadFriendWishlists(friends);
    _syncFriendCounts();
    final profile = await _repo.loadProfile(userId);
    if (profile != null) currentUser = profile;
    notifyListeners();
  }

  Future<void> toggleFollow(String friendId) async {
    final userId = uid;
    if (userId == null) return;
    final idx = friends.indexWhere((f) => f.id == friendId);
    if (idx < 0) return;
    final wasFollowing = friends[idx].isFollowing;
    final next = !wasFollowing;
    await _repo.setFollowing(
      myUid: userId,
      targetUid: friendId,
      follow: next,
    );
    friends = [
      for (var i = 0; i < friends.length; i++)
        if (i == idx)
          friends[i].copyWith(isFollowing: next)
        else
          friends[i],
    ];
    currentUser = currentUser.copyWith(
      following: friends.where((f) => f.isFollowing).length,
    );
    friendWishlists = await _repo.loadFriendWishlists(friends);
    _syncFriendCounts();
    notifyListeners();
  }

  void _syncFriendCounts() {
    friends = friends.map((f) {
      final lists = friendWishlists.where((w) => w.friendId == f.id).toList();
      final items = lists.fold<int>(0, (sum, w) => sum + w.items.length);
      return f.copyWith(wishlistCount: lists.length, itemCount: items);
    }).toList();
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
    final userId = uid;
    if (userId != null) {
      await _repo.updateProfile(userId, currentUser);
    }
    notifyListeners();
  }

  Future<SharedBasket> createSharedBasketFromSelection() async {
    final selected =
        basket.where((b) => b.isSelected).map((b) => b.product).toList();
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

  Future<void> _persistBasket() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_basketKey}_${uid ?? 'guest'}';
    await prefs.setString(
      key,
      jsonEncode(basket.map((e) => e.product.id).toList()),
    );
  }

  Future<void> _restoreBasketForUser() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_basketKey}_${uid ?? 'guest'}';
    final basketRaw = prefs.getString(key);
    if (basketRaw == null) {
      basket = [];
      return;
    }
    final ids = (jsonDecode(basketRaw) as List).cast<int>();
    basket = ids
        .map((id) {
          final p = products.where((e) => e.id == id).firstOrNull;
          return p == null ? null : BasketItem(product: p);
        })
        .whereType<BasketItem>()
        .toList();
  }

  Future<void> _loadLocalExtras() async {
    final prefs = await SharedPreferences.getInstance();
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
