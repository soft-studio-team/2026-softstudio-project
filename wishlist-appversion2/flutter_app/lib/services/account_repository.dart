import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

/// Firestore layout:
///   users/{uid}                         profile + counts
///   users/{uid}/tabs/{tabId}
///   users/{uid}/products/{productId}
///   users/{uid}/following/{otherUid}
///   users/{uid}/followers/{otherUid}
///   users/{uid}/notifications/{notifId}
///   users/{uid}/receivedBaskets/{basketId}
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

  CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _userDoc(uid).collection('notifications');

  CollectionReference<Map<String, dynamic>> _receivedBaskets(String uid) =>
      _userDoc(uid).collection('receivedBaskets');

  /// Creates Auth credentials and sends a verification email only.
  /// Firestore profile is created later via [ensureProfile] after verification.
  Future<UserCredential> registerPending({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.sendEmailVerification();
    return cred;
  }

  Future<void> sendVerificationEmail([User? user]) async {
    final target = user ?? _auth.currentUser;
    if (target == null) {
      throw Exception('인증 메일을 보낼 사용자가 없어요. 다시 로그인해 주세요.');
    }
    await target.sendEmailVerification();
  }

  Future<User?> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    return _auth.currentUser;
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

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('로그인된 계정이 없어요.');
    }
    final cred = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('로그인된 계정이 없어요.');
    }
    final cred = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);

    final uid = user.uid;
    final profile = await loadProfile(uid);
    await _deleteFirestoreUserTree(
      uid,
      handle: profile?.handle,
      unlinkSocial: true,
    );
    await user.delete();
  }

  /// Removes Firestore data for [uid]. Used by account deletion and by reclaim
  /// after Auth-only deletes in Firebase Console.
  Future<void> _deleteFirestoreUserTree(
    String uid, {
    String? handle,
    bool unlinkSocial = false,
  }) async {
    if (unlinkSocial) {
      final followingSnap = await _following(uid).get();
      for (final doc in followingSnap.docs) {
        await setFollowing(myUid: uid, targetUid: doc.id, follow: false);
      }

      final followersSnap = await _followers(uid).get();
      for (final doc in followersSnap.docs) {
        final followerUid = doc.id;
        final batch = _db.batch();
        batch.delete(_following(followerUid).doc(uid));
        batch.delete(_followers(uid).doc(followerUid));
        final followerProfile = await _userDoc(followerUid).get();
        if (followerProfile.exists) {
          batch.update(_userDoc(followerUid), {
            'following': FieldValue.increment(-1),
          });
        }
        await batch.commit();
      }
    }

    await _deleteCollectionDocs(_tabs(uid));
    await _deleteCollectionDocs(_products(uid));
    await _deleteCollectionDocs(_following(uid));
    await _deleteCollectionDocs(_followers(uid));
    await _deleteCollectionDocs(_notifications(uid));
    await _deleteCollectionDocs(_receivedBaskets(uid));

    if (handle != null && handle.isNotEmpty) {
      final key = _normalizeHandle(handle).toLowerCase();
      final handleSnap = await _handleDoc(key).get();
      if (handleSnap.exists && handleSnap.data()?['uid'] == uid) {
        await _handleDoc(key).delete();
      }
    }
    await _userDoc(uid).delete();
  }

  /// Clears leftover profiles/handles for the same email (Console Auth delete).
  Future<void> reclaimIdentityIfNeeded({
    required String newUid,
    required String email,
    required String handle,
  }) async {
    final emailKey = email.trim().toLowerCase();
    final handleKey = _normalizeHandle(handle).toLowerCase();

    final byHandle = await _db
        .collection('users')
        .where('handleLower', isEqualTo: handleKey)
        .limit(10)
        .get();
    for (final doc in byHandle.docs) {
      if (doc.id == newUid) continue;
      final ownerEmail =
          (doc.data()['email'] as String?)?.trim().toLowerCase() ?? '';
      if (ownerEmail != emailKey) {
        throw Exception('이미 사용 중인 아이디예요.');
      }
      await _deleteFirestoreUserTree(
        doc.id,
        handle: doc.data()['handle'] as String? ?? handle,
      );
    }

    // Same email, possibly different id — also leftover from Console deletes.
    for (final candidate in {email.trim(), emailKey}) {
      final byEmail = await _db
          .collection('users')
          .where('email', isEqualTo: candidate)
          .limit(10)
          .get();
      for (final doc in byEmail.docs) {
        if (doc.id == newUid) continue;
        await _deleteFirestoreUserTree(
          doc.id,
          handle: doc.data()['handle'] as String?,
        );
      }
    }

    final handleSnap = await _handleDoc(handleKey).get();
    if (handleSnap.exists) {
      final owner = handleSnap.data()?['uid'] as String?;
      if (owner != null && owner != newUid) {
        final ownerProfile = await _userDoc(owner).get();
        if (!ownerProfile.exists) {
          await _handleDoc(handleKey).delete();
        } else {
          final ownerEmail =
              (ownerProfile.data()?['email'] as String?)?.trim().toLowerCase();
          if (ownerEmail == emailKey) {
            await _deleteFirestoreUserTree(
              owner,
              handle: ownerProfile.data()?['handle'] as String? ?? handle,
            );
          }
        }
      }
    }
  }

  Future<void> _deleteCollectionDocs(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final snap = await col.limit(200).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (snap.docs.length >= 200) {
      await _deleteCollectionDocs(col);
    }
  }

  DocumentReference<Map<String, dynamic>> _handleDoc(String handleLower) =>
      _db.collection('handles').doc(handleLower);

  /// Looks up a profile by id/handle and returns a masked email for recovery UI.
  Future<String?> findMaskedEmailByHandle(String handle) async {
    final normalized = _normalizeHandle(handle).toLowerCase();
    final snap = await _db
        .collection('users')
        .where('handleLower', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final email = (snap.docs.first.data()['email'] as String?)?.trim() ?? '';
    if (email.isEmpty) return null;
    return _maskEmail(email);
  }

  Future<void> assertHandleAvailable(
    String handle, {
    String? exceptUid,
    String? email,
  }) async {
    final key = _normalizeHandle(handle).toLowerCase();
    final emailKey = email?.trim().toLowerCase();

    // Source of truth: a living profile that still uses this id.
    final taken = await _db
        .collection('users')
        .where('handleLower', isEqualTo: key)
        .limit(1)
        .get();
    if (taken.docs.isNotEmpty && taken.docs.first.id != exceptUid) {
      final ownerEmail = (taken.docs.first.data()['email'] as String?)
              ?.trim()
              .toLowerCase() ??
          '';
      // Same email can reclaim after Auth-only delete in Firebase Console.
      if (emailKey == null ||
          emailKey.isEmpty ||
          ownerEmail.isEmpty ||
          ownerEmail != emailKey) {
        throw Exception('이미 사용 중인 아이디예요.');
      }
    }

    final snap = await _handleDoc(key).get();
    if (!snap.exists) return;
    final owner = snap.data()?['uid'] as String?;
    if (owner == null || owner == exceptUid) return;

    final ownerProfile = await _userDoc(owner).get();
    if (!ownerProfile.exists) return;
    final ownerEmail =
        (ownerProfile.data()?['email'] as String?)?.trim().toLowerCase() ?? '';
    if (emailKey != null &&
        emailKey.isNotEmpty &&
        ownerEmail.isNotEmpty &&
        ownerEmail == emailKey) {
      return;
    }

    throw Exception('이미 사용 중인 아이디예요.');
  }

  Future<void> _claimHandleInTransaction({
    required Transaction tx,
    required String uid,
    required String handle,
    String? previousHandle,
    String? email,
  }) async {
    final normalized = _normalizeHandle(handle);
    final key = normalized.toLowerCase();
    final emailKey = email?.trim().toLowerCase();
    final ref = _handleDoc(key);
    final snap = await tx.get(ref);
    if (snap.exists) {
      final owner = snap.data()?['uid'] as String?;
      if (owner != null && owner != uid) {
        final ownerUser = await tx.get(_userDoc(owner));
        final ownerHandle =
            (ownerUser.data()?['handleLower'] as String?)?.toLowerCase();
        final ownerEmail =
            (ownerUser.data()?['email'] as String?)?.trim().toLowerCase() ?? '';
        final sameEmail = emailKey != null &&
            emailKey.isNotEmpty &&
            ownerEmail.isNotEmpty &&
            ownerEmail == emailKey;
        // Block only when another living profile still owns this id.
        if (ownerUser.exists && ownerHandle == key && !sameEmail) {
          throw Exception('이미 사용 중인 아이디예요.');
        }
        // Otherwise overwrite the stale/orphaned reservation.
      }
    }
    tx.set(ref, {
      'uid': uid,
      'handle': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (previousHandle == null || previousHandle.trim().isEmpty) return;
    final prevKey = _normalizeHandle(previousHandle).toLowerCase();
    if (prevKey == key) return;
    final prevRef = _handleDoc(prevKey);
    final prevSnap = await tx.get(prevRef);
    if (prevSnap.exists && prevSnap.data()?['uid'] == uid) {
      tx.delete(prevRef);
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return '***';
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty) return '***@$domain';
    if (local.length == 1) return '*@$domain';
    if (local.length == 2) return '${local[0]}*@$domain';
    return '${local[0]}***${local[local.length - 1]}@$domain';
  }

  Future<AppUser?> loadProfile(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return AppUser.fromJson(snap.data()!..['uid'] = uid);
  }

  /// Creates the app account in Firestore only for a verified user.
  Future<void> ensureProfile(
    User user, {
    String? name,
    String? handle,
  }) async {
    if (!user.emailVerified) {
      throw Exception('이메일 인증이 완료된 뒤에만 계정을 만들 수 있어요.');
    }
    final existing = await _userDoc(user.uid).get();
    if (existing.exists) {
      final data = existing.data();
      final currentHandle = data?['handle'] as String?;
      if (currentHandle != null && currentHandle.isNotEmpty) {
        final key = _normalizeHandle(currentHandle).toLowerCase();
        final owned = await _handleDoc(key).get();
        final owner = owned.data()?['uid'] as String?;
        if (!owned.exists || owner == user.uid) {
          await _db.runTransaction((tx) async {
            await _claimHandleInTransaction(
              tx: tx,
              uid: user.uid,
              handle: currentHandle,
            );
          });
        }
      }
      return;
    }
    final email = user.email ?? '';
    final base = email.contains('@') ? email.split('@').first : 'user';
    final resolvedName =
        (name != null && name.trim().isNotEmpty) ? name.trim() : base;
    if (handle == null || handle.trim().isEmpty) {
      throw Exception('아이디를 입력해 주세요.');
    }
    final resolvedHandle = _normalizeHandle(handle);
    await reclaimIdentityIfNeeded(
      newUid: user.uid,
      email: email,
      handle: resolvedHandle,
    );
    final profile = AppUser(
      uid: user.uid,
      email: email,
      name: resolvedName,
      handle: resolvedHandle,
      avatarUrl: _defaultAvatar(resolvedHandle),
    );
    await _db.runTransaction((tx) async {
      await _claimHandleInTransaction(
        tx: tx,
        uid: user.uid,
        handle: resolvedHandle,
        email: email,
      );
      tx.set(_userDoc(user.uid), {
        ...profile.toJson(),
        'handleLower': resolvedHandle.toLowerCase(),
        'emailLower': email.trim().toLowerCase(),
        'emailVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    await _seedDefaultTabs(user.uid);
  }

  Future<void> updateProfile(
    String uid,
    AppUser user, {
    String? previousHandle,
  }) async {
    await _db.runTransaction((tx) async {
      await _claimHandleInTransaction(
        tx: tx,
        uid: uid,
        handle: user.handle,
        previousHandle: previousHandle,
      );
      tx.set(
        _userDoc(uid),
        {
          ...user.toJson(),
          'handleLower': user.handle.toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
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

  Future<List<String>> followerIds(String uid) async {
    final snap = await _followers(uid).get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<List<AppUser>> loadUsers(List<String> uids) async {
    final out = <AppUser>[];
    for (final id in uids) {
      final doc = await _userDoc(id).get();
      if (doc.exists && doc.data() != null) {
        out.add(AppUser.fromJson(doc.data()!..['uid'] = id));
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
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
    AppUser? actor,
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

    // Best-effort inbox notification (does not block follow).
    if (follow && actor != null) {
      try {
        final notifRef = _notifications(targetUid).doc();
        await notifRef.set({
          'id': notifRef.id,
          'type': 'follow',
          'fromUid': myUid,
          'fromName': actor.name,
          'fromHandle': actor.handle,
          'fromAvatar': actor.avatarUrl,
          'message': '${actor.name} 님이 회원님을 팔로우하기 시작했어요',
          'relatedId': null,
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
          'createdAtServer': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
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

  Future<List<AppNotification>> loadNotifications(String uid) async {
    final snap = await _notifications(uid).limit(100).get();
    final list = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = data['id'] ?? d.id;
      return AppNotification.fromJson(data);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> markNotificationsRead(String uid, List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_notifications(uid).doc(id), {'read': true});
    }
    await batch.commit();
  }

  Future<List<SharedBasket>> loadReceivedBaskets(String uid) async {
    final snap = await _receivedBaskets(uid).limit(100).get();
    final list = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = data['id'] ?? d.id;
      return SharedBasket.fromJson(data);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> sendBasketToFriends({
    required AppUser from,
    required List<String> recipientUids,
    required List<Product> items,
  }) async {
    if (recipientUids.isEmpty || items.isEmpty) return;
    final now = DateTime.now();
    final batch = _db.batch();
    for (final recipientUid in recipientUids) {
      if (recipientUid == from.uid) continue;
      final basketRef = _receivedBaskets(recipientUid).doc();
      final basketId = basketRef.id;
      final basket = SharedBasket(
        id: basketId,
        title: '${from.name}의 살까말까',
        ownerName: from.name,
        fromUid: from.uid,
        fromHandle: from.handle,
        fromAvatar: from.avatarUrl,
        items: items,
        createdAt: now,
      );
      batch.set(basketRef, {
        ...basket.toJson(),
        'createdAtServer': FieldValue.serverTimestamp(),
      });
      final notifRef = _notifications(recipientUid).doc();
      batch.set(notifRef, {
        'id': notifRef.id,
        'type': 'basket',
        'fromUid': from.uid,
        'fromName': from.name,
        'fromHandle': from.handle,
        'fromAvatar': from.avatarUrl,
        'message': '${from.name} 님이 살까말까 장바구니를 보냈어요',
        'relatedId': basketId,
        'read': false,
        'createdAt': now.toIso8601String(),
        'createdAtServer': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// New accounts start with only the fixed '전체' tab — no demo categories.
  Future<void> _seedDefaultTabs(String uid) async {
    final allTab = WishlistTab(id: 'all', name: '전체', isPublic: true);
    await _tabs(uid).doc(allTab.id).set(allTab.toJson());
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
