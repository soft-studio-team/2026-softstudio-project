import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

/// Firestore layout:
///   users/{uid}                         profile + counts
///   users/{uid}/tabs/{tabId}
///   users/{uid}/products/{productId}
///   users/{uid}/following/{otherUid}
///   users/{uid}/followers/{otherUid}
class AccountRepository {
  AccountRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _authOverride = auth,
        _dbOverride = db;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  User? get firebaseUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _tabs(String uid) =>
      _userDoc(uid).collection('tabs');

  CollectionReference<Map<String, dynamic>> _products(String uid) =>
      _userDoc(uid).collection('products');

  CollectionReference<Map<String, dynamic>> _following(String uid) =>
      _userDoc(uid).collection('following');

  CollectionReference<Map<String, dynamic>> _followers(String uid) =>
      _userDoc(uid).collection('followers');

  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
    required String handle,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final normalized = _normalizeHandle(handle);
    final profile = AppUser(
      uid: uid,
      email: email.trim(),
      name: name.trim().isEmpty ? email.split('@').first : name.trim(),
      handle: normalized,
      avatarUrl: _defaultAvatar(normalized),
    );
    await _userDoc(uid).set({
      ...profile.toJson(),
      'handleLower': normalized.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _seedDefaultTabs(uid);
    return cred;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() => _auth.signOut();

  Future<AppUser?> loadProfile(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return AppUser.fromJson(snap.data()!..['uid'] = uid);
  }

  Future<void> ensureProfile(User user) async {
    final existing = await _userDoc(user.uid).get();
    if (existing.exists) return;
    final email = user.email ?? '';
    final base = email.contains('@') ? email.split('@').first : 'user';
    final handle = _normalizeHandle(base);
    final profile = AppUser(
      uid: user.uid,
      email: email,
      name: base,
      handle: handle,
      avatarUrl: _defaultAvatar(handle),
    );
    await _userDoc(user.uid).set({
      ...profile.toJson(),
      'handleLower': handle.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _seedDefaultTabs(user.uid);
  }

  Future<void> updateProfile(String uid, AppUser user) async {
    await _userDoc(uid).set({
      ...user.toJson(),
      'handleLower': user.handle.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<WishlistTab>> loadTabs(String uid) async {
    final snap = await _tabs(uid).get();
    if (snap.docs.isEmpty) {
      await _seedDefaultTabs(uid);
      final again = await _tabs(uid).get();
      return again.docs.map((d) => WishlistTab.fromJson(d.data())).toList();
    }
    final tabs = snap.docs.map((d) => WishlistTab.fromJson(d.data())).toList();
    tabs.sort((a, b) {
      if (a.id == 'all') return -1;
      if (b.id == 'all') return 1;
      return a.name.compareTo(b.name);
    });
    return tabs;
  }

  Future<void> saveTabs(String uid, List<WishlistTab> tabs) async {
    final batch = _db.batch();
    for (final tab in tabs) {
      batch.set(_tabs(uid).doc(tab.id), tab.toJson());
    }
    await batch.commit();
  }

  Future<void> deleteTabDoc(String uid, String tabId) async {
    await _tabs(uid).doc(tabId).delete();
  }

  Future<List<Product>> loadProducts(String uid) async {
    final snap = await _products(uid).get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = data['id'] ?? int.tryParse(d.id) ?? d.id.hashCode;
      return Product.fromJson(data);
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> upsertProduct(String uid, Product product) async {
    await _products(uid).doc('${product.id}').set(product.toJson());
  }

  Future<void> deleteProduct(String uid, int productId) async {
    await _products(uid).doc('$productId').delete();
  }

  Future<List<String>> followingIds(String uid) async {
    final snap = await _following(uid).get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<List<Friend>> loadDirectory({
    required String myUid,
    required Set<String> following,
  }) async {
    final snap = await _db.collection('users').limit(80).get();
    final out = <Friend>[];
    for (final doc in snap.docs) {
      if (doc.id == myUid) continue;
      final user = AppUser.fromJson(doc.data()..['uid'] = doc.id);
      final counts = await _wishlistCounts(doc.id);
      out.add(Friend(
        id: doc.id,
        name: user.name,
        username: user.handle,
        avatar: user.avatarUrl,
        isFollowing: following.contains(doc.id),
        wishlistCount: counts.$1,
        itemCount: counts.$2,
      ));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<(int, int)> _wishlistCounts(String uid) async {
    final tabs = await _tabs(uid).get();
    final products = await _products(uid).get();
    final publicLists =
        tabs.docs.where((d) => (d.data()['isPublic'] as bool? ?? true) && d.id != 'all').length;
    return (publicLists, products.docs.length);
  }

  Future<void> setFollowing({
    required String myUid,
    required String targetUid,
    required bool follow,
  }) async {
    if (myUid == targetUid) return;
    final batch = _db.batch();
    final followingRef = _following(myUid).doc(targetUid);
    final followerRef = _followers(targetUid).doc(myUid);
    final meRef = _userDoc(myUid);
    final themRef = _userDoc(targetUid);

    if (follow) {
      batch.set(followingRef, {
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(followerRef, {
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(meRef, {'following': FieldValue.increment(1)});
      batch.update(themRef, {'followers': FieldValue.increment(1)});
    } else {
      batch.delete(followingRef);
      batch.delete(followerRef);
      batch.update(meRef, {'following': FieldValue.increment(-1)});
      batch.update(themRef, {'followers': FieldValue.increment(-1)});
    }
    await batch.commit();
  }

  Future<List<FriendWishlist>> loadFriendWishlists(
    List<Friend> followingFriends,
  ) async {
    final result = <FriendWishlist>[];
    for (final friend in followingFriends.where((f) => f.isFollowing)) {
      final tabsSnap = await _tabs(friend.id).get();
      final productsSnap = await _products(friend.id).get();
      final products = productsSnap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = data['id'] ?? int.tryParse(d.id) ?? d.id.hashCode;
        return Product.fromJson(data);
      }).toList();

      for (final tabDoc in tabsSnap.docs) {
        final tab = WishlistTab.fromJson(tabDoc.data());
        if (tab.id == 'all' || !tab.isPublic) continue;
        final items = products.where((p) => p.listId == tab.id).toList();
        result.add(FriendWishlist(
          id: '${friend.id}_${tab.id}',
          friendId: friend.id,
          friendName: friend.name,
          listName: tab.name,
          isPublic: true,
          items: items,
        ));
      }
    }
    return result;
  }

  Future<void> _seedDefaultTabs(String uid) async {
    final defaults = [
      WishlistTab(id: 'all', name: '전체', isPublic: true),
      WishlistTab(id: 'summer', name: '여름 여행 옷', isPublic: true),
      WishlistTab(id: 'daily', name: '일상 윗옷', isPublic: true),
      WishlistTab(id: 'accessories', name: '악세서리', isPublic: false),
      WishlistTab(id: 'beauty', name: '뷰티', isPublic: true),
      WishlistTab(id: 'shoes', name: '신발', isPublic: false),
    ];
    final batch = _db.batch();
    for (final tab in defaults) {
      batch.set(_tabs(uid).doc(tab.id), tab.toJson());
    }
    await batch.commit();
  }

  String _normalizeHandle(String raw) {
    var h = raw.trim();
    if (h.isEmpty) h = 'user';
    if (!h.startsWith('@')) h = '@$h';
    return h.replaceAll(RegExp(r'\s+'), '');
  }

  String _defaultAvatar(String handle) {
    final seed = Uri.encodeComponent(handle.replaceFirst('@', ''));
    return 'https://api.dicebear.com/7.x/thumbs/png?seed=$seed';
  }
}
