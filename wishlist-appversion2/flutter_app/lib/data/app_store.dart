import 'dart:convert';
import 'dart:io';
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
  static const _pendingNameKey = 'pending_register_name';
  static const _pendingHandleKey = 'pending_register_handle';
  static const _notifyFollowKey = 'notify_follow';
  static const _notifyBasketKey = 'notify_basket';

  AppStore({AccountRepository? repository})
      : _repo = repository ?? AccountRepository();

  final AccountRepository _repo;

  bool ready = false;
  bool firebaseReady = false;
  String? firebaseError;
  bool isLoggedIn = false;
  bool awaitingEmailVerification = false;
  bool showSignupWelcome = false;
  String? pendingVerificationEmail;
  String? _pendingName;
  String? _pendingHandle;

  /// In-app notification preferences (MyPage → 알림 설정).
  bool notifyOnFollow = true;
  bool notifyOnBasket = true;

  List<WishlistTab> tabs = [];
  List<Product> products = [];
  List<BasketItem> basket = [];
  List<Friend> friends = [];
  List<FriendWishlist> friendWishlists = [];
  List<AppUser> followerUsers = [];
  List<AppNotification> notifications = [];
  List<SharedBasket> receivedBaskets = [];
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
      await _loadPendingProfileDraft();
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

  Future<void> _loadPendingProfileDraft() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingName = prefs.getString(_pendingNameKey);
    _pendingHandle = prefs.getString(_pendingHandleKey);
  }

  Future<void> _savePendingProfileDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pendingName != null) {
      await prefs.setString(_pendingNameKey, _pendingName!);
    } else {
      await prefs.remove(_pendingNameKey);
    }
    if (_pendingHandle != null) {
      await prefs.setString(_pendingHandleKey, _pendingHandle!);
    } else {
      await prefs.remove(_pendingHandleKey);
    }
  }

  Future<void> _clearPendingProfileDraft() async {
    _pendingName = null;
    _pendingHandle = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingNameKey);
    await prefs.remove(_pendingHandleKey);
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
    await _loadPendingProfileDraft();
    await _repo.ensureProfile(
      fresh,
      name: _pendingName,
      handle: _pendingHandle,
    );
    await _clearPendingProfileDraft();
    final profile = await _repo.loadProfile(fresh.uid);
    if (profile != null) {
      currentUser = profile;
    }
    tabs = await _repo.loadTabs(fresh.uid);
    products = await _repo.loadProducts(fresh.uid);
    final following = (await _repo.followingIds(fresh.uid)).toSet();
    friends = await _repo.loadDirectory(myUid: fresh.uid, following: following);
    friendWishlists = await _repo.loadFriendWishlists(friends);
    followerUsers = await _repo.loadUsers(await _repo.followerIds(fresh.uid));
    await _loadInboxSafely(fresh.uid);
    _syncFriendCounts();
    currentUser = currentUser.copyWith(
      following: following.length,
      followers: followerUsers.length,
    );
    isLoggedIn = true;
    selectedTabId = 'all';
    await _reloadNotificationPrefs();
  }

  Future<void> _reloadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final keySuffix = uid ?? 'guest';
    notifyOnFollow = prefs.getBool('${_notifyFollowKey}_$keySuffix') ?? true;
    notifyOnBasket = prefs.getBool('${_notifyBasketKey}_$keySuffix') ?? true;
  }

  /// Notifications / received baskets need updated Firestore rules.
  /// Never block login if those collections are still denied.
  Future<void> _loadInboxSafely(String userId) async {
    try {
      notifications = await _repo.loadNotifications(userId);
    } catch (_) {
      notifications = [];
    }
    try {
      receivedBaskets = await _repo.loadReceivedBaskets(userId);
    } catch (_) {
      receivedBaskets = [];
    }
  }

  Future<void> _clearSessionLocal() async {
    isLoggedIn = false;
    awaitingEmailVerification = false;
    showSignupWelcome = false;
    pendingVerificationEmail = null;
    tabs = [];
    products = [];
    basket = [];
    friends = [];
    friendWishlists = [];
    followerUsers = [];
    notifications = [];
    receivedBaskets = [];
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
    if (handle.trim().isEmpty) {
      throw Exception('아이디를 입력해 주세요.');
    }
    await _repo.assertHandleAvailable(handle, email: email);
    _pendingName = name.trim().isEmpty ? null : name.trim();
    _pendingHandle = handle.trim();
    await _savePendingProfileDraft();
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
    showSignupWelcome = true;
    notifyListeners();
    return true;
  }

  void dismissSignupWelcome() {
    if (!showSignupWelcome) return;
    showSignupWelcome = false;
    notifyListeners();
  }

  Future<void> cancelEmailVerification() async {
    if (firebaseReady) {
      await _repo.logout();
    }
    await _clearPendingProfileDraft();
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

  Future<void> deleteAccount({required String password}) async {
    _ensureFirebase();
    if (password.isEmpty) {
      throw Exception('비밀번호를 입력해 주세요.');
    }
    try {
      await _repo.deleteAccount(password: password);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('비밀번호가 맞지 않아요.');
        case 'requires-recent-login':
          throw Exception('보안을 위해 다시 로그인한 뒤 탈퇴해 주세요.');
        default:
          throw Exception(e.message ?? '탈퇴에 실패했어요 (${e.code})');
      }
    }
    await _clearPendingProfileDraft();
    await _clearSessionLocal();
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _ensureFirebase();
    if (email.trim().isEmpty) {
      throw Exception('가입한 이메일을 입력해 주세요.');
    }
    await _repo.sendPasswordResetEmail(email);
  }

  Future<String?> findMaskedEmailByHandle(String handle) async {
    _ensureFirebase();
    if (handle.trim().isEmpty) {
      throw Exception('아이디를 입력해 주세요.');
    }
    return _repo.findMaskedEmailByHandle(handle);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _ensureFirebase();
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      throw Exception('현재 비밀번호와 새 비밀번호를 입력해 주세요.');
    }
    if (newPassword.trim().length < 6) {
      throw Exception('새 비밀번호는 6자 이상이어야 해요.');
    }
    if (currentPassword == newPassword) {
      throw Exception('새 비밀번호는 현재 비밀번호와 달라야 해요.');
    }
    try {
      await _repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('현재 비밀번호가 맞지 않아요.');
        case 'weak-password':
          throw Exception('새 비밀번호가 너무 짧아요 (6자 이상).');
        case 'requires-recent-login':
          throw Exception('보안을 위해 다시 로그인한 뒤 변경해 주세요.');
        default:
          throw Exception(e.message ?? '비밀번호 변경에 실패했어요 (${e.code})');
      }
    }
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

  /// Optimistically moves [id] into [listId], persists to Firestore, and
  /// reverts the in-memory state (rethrowing) if the write fails — callers
  /// are expected to surface the error rather than let it fail silently.
  Future<void> moveProduct(int id, String listId) async {
    final previous = products;
    final product = productById(id);
    if (product == null || product.listId == listId) return;
    final updated = product.copyWith(listId: listId);
    products = [
      for (final p in products) p.id == id ? updated : p,
    ];
    notifyListeners();
    final userId = uid;
    if (userId == null) return;
    try {
      await _repo.upsertProduct(userId, updated);
    } catch (_) {
      products = previous;
      notifyListeners();
      rethrow;
    }
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

  SharedBasket? sharedBasketById(String id) {
    final local = sharedBaskets[id];
    if (local != null) return local;
    return receivedBaskets.where((b) => b.id == id).firstOrNull;
  }

  int get unreadNotificationCount =>
      visibleNotifications.where((n) => !n.read).length;

  /// Inbox rows filtered by MyPage notification preferences.
  List<AppNotification> get visibleNotifications => notifications.where((n) {
        if (n.type == AppNotificationType.follow) return notifyOnFollow;
        if (n.type == AppNotificationType.basket) return notifyOnBasket;
        return true;
      }).toList();

  List<FriendSalkamalka> get friendSalkamalkaGroups {
    final byFriend = <String, List<SharedBasket>>{};
    for (final b in receivedBaskets) {
      final key = b.fromUid.isNotEmpty ? b.fromUid : b.ownerName;
      byFriend.putIfAbsent(key, () => []).add(b);
    }
    final groups = byFriend.entries.map((e) {
      final baskets = List<SharedBasket>.from(e.value)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final first = baskets.first;
      return FriendSalkamalka(
        friendId: first.fromUid,
        friendName: first.ownerName,
        friendHandle: first.fromHandle,
        friendAvatar: first.fromAvatar.isNotEmpty
            ? first.fromAvatar
            : 'https://api.dicebear.com/7.x/thumbs/png?seed=${Uri.encodeComponent(first.ownerName)}',
        baskets: baskets,
      );
    }).toList();
    groups.sort((a, b) =>
        b.baskets.first.createdAt.compareTo(a.baskets.first.createdAt));
    return groups;
  }

  FriendSalkamalka? friendSalkamalkaByFriendId(String friendId) =>
      friendSalkamalkaGroups.where((g) => g.friendId == friendId).firstOrNull;

  Future<List<AppUser>> loadFollowers() async {
    final id = uid;
    if (id == null) return [];
    final ids = await _repo.followerIds(id);
    followerUsers = await _repo.loadUsers(ids);
    notifyListeners();
    return followerUsers;
  }

  Future<List<AppUser>> loadFollowingUsers() async {
    final id = uid;
    if (id == null) return [];
    final ids = await _repo.followingIds(id);
    return _repo.loadUsers(ids);
  }

  Future<void> refreshFriends() async {
    final userId = uid;
    if (userId == null) return;
    final following = (await _repo.followingIds(userId)).toSet();
    friends = await _repo.loadDirectory(myUid: userId, following: following);
    friendWishlists = await _repo.loadFriendWishlists(friends);
    followerUsers = await _repo.loadUsers(await _repo.followerIds(userId));
    await _loadInboxSafely(userId);
    _syncFriendCounts();
    final profile = await _repo.loadProfile(userId);
    if (profile != null) {
      currentUser = profile;
    } else {
      currentUser = currentUser.copyWith(
        following: following.length,
        followers: followerUsers.length,
      );
    }
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    final userId = uid;
    if (userId == null) return;
    try {
      notifications = await _repo.loadNotifications(userId);
    } catch (_) {
      notifications = [];
    }
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    final userId = uid;
    if (userId == null) return;
    final unread = notifications.where((n) => !n.read).map((n) => n.id).toList();
    if (unread.isEmpty) return;
    try {
      await _repo.markNotificationsRead(userId, unread);
      notifications = [
        for (final n in notifications) n.copyWith(read: true),
      ];
      notifyListeners();
    } catch (_) {}
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
      actor: next ? currentUser.copyWith(uid: userId) : null,
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

  Future<void> removeFollower(String followerUid) async {
    final userId = uid;
    if (userId == null) {
      throw Exception('로그인된 계정이 없어요.');
    }
    await _repo.removeFollower(myUid: userId, followerUid: followerUid);
    followerUsers = followerUsers.where((u) => u.uid != followerUid).toList();
    currentUser = currentUser.copyWith(followers: followerUsers.length);
    notifyListeners();
  }

  Future<void> setNotifyOnFollow(bool value) async {
    notifyOnFollow = value;
    await _persistNotificationPrefs();
    notifyListeners();
  }

  Future<void> setNotifyOnBasket(bool value) async {
    notifyOnBasket = value;
    await _persistNotificationPrefs();
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
    final previousHandle = currentUser.handle;
    var nextHandle = handle?.trim() ?? currentUser.handle;
    if (nextHandle.isEmpty) {
      throw Exception('아이디를 입력해 주세요.');
    }
    if (!nextHandle.startsWith('@')) {
      nextHandle = '@$nextHandle';
    }
    final userId = uid;
    if (userId == null) {
      throw Exception('로그인된 계정이 없어요.');
    }
    await _repo.assertHandleAvailable(nextHandle, exceptUid: userId);
    final nextUser = currentUser.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : null,
      handle: nextHandle,
      avatarUrl: avatarUrl?.trim().isNotEmpty == true ? avatarUrl!.trim() : null,
    );
    await _repo.updateProfile(
      userId,
      nextUser,
      previousHandle: previousHandle,
    );
    currentUser = nextUser;
    notifyListeners();
  }

  /// Uploads [file] to Storage and returns the public download URL.
  Future<String> uploadAvatarFile(File file) async {
    _ensureFirebase();
    final userId = uid;
    if (userId == null) {
      throw Exception('로그인된 계정이 없어요.');
    }
    return _repo.uploadAvatarFile(userId, file);
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
      fromUid: currentUser.uid,
      fromHandle: currentUser.handle,
      fromAvatar: currentUser.avatarUrl,
      items: selected,
      createdAt: DateTime.now(),
    );
    sharedBaskets[id] = shared;
    await _persistShared();
    notifyListeners();
    return shared;
  }

  Future<void> sendBasketToFriends(List<String> friendIds) async {
    final selected =
        basket.where((b) => b.isSelected).map((b) => b.product).toList();
    if (selected.isEmpty) {
      throw Exception('공유할 상품을 선택해 주세요.');
    }
    if (friendIds.isEmpty) {
      throw Exception('보낼 친구를 선택해 주세요.');
    }
    _ensureFirebase();
    final userId = uid;
    if (userId == null) {
      throw Exception('로그인된 계정이 없어요.');
    }
    await _repo.sendBasketToFriends(
      from: currentUser.copyWith(uid: userId),
      recipientUids: friendIds,
      items: selected,
    );
    await createSharedBasketFromSelection();
  }

  String shareUrlFor(SharedBasket basket) =>
      'https://wishlist.app/shared/${basket.id}';

  Future<void> _persistShared() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sharedKey,
      jsonEncode(sharedBaskets.values.map((s) => s.toJson()).toList()),
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
    notifyOnFollow = prefs.getBool('${_notifyFollowKey}_${uid ?? 'guest'}') ?? true;
    notifyOnBasket = prefs.getBool('${_notifyBasketKey}_${uid ?? 'guest'}') ?? true;
    final sharedRaw = prefs.getString(_sharedKey);
    if (sharedRaw != null) {
      final list = jsonDecode(sharedRaw) as List;
      for (final e in list) {
        final map = Map<String, dynamic>.from(e as Map);
        final basket = SharedBasket.fromJson(map);
        sharedBaskets[basket.id] = basket;
      }
    }
  }

  Future<void> _persistNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final keySuffix = uid ?? 'guest';
    await prefs.setBool('${_notifyFollowKey}_$keySuffix', notifyOnFollow);
    await prefs.setBool('${_notifyBasketKey}_$keySuffix', notifyOnBasket);
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
    for (final s in receivedBaskets) {
      final hit = s.items.where((p) => p.id == id).firstOrNull;
      if (hit != null) return hit;
    }
    return null;
  }
}
