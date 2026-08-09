import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int tab = 0; // 0 following, 1 wishlist
  final searchCtrl = TextEditingController();
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<AppStore>();
      if (!store.firebaseReady || !store.isLoggedIn) return;
      setState(() => refreshing = true);
      try {
        await store.refreshFriends();
      } finally {
        if (mounted) setState(() => refreshing = false);
      }
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = searchCtrl.text.trim().toLowerCase();
    final friends = store.friends
        .where((f) =>
            q.isEmpty ||
            f.name.toLowerCase().contains(q) ||
            f.username.toLowerCase().contains(q))
        .toList();
    final followingFriends =
        friends.where((f) => f.isFollowing).toList();
    final wishlistCards = store.friendWishlists
        .where((w) {
          final friend = store.friendById(w.friendId);
          return friend != null && friend.isFollowing;
        })
        .toList();

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('내 친구', style: DiaryTheme.display(34)),
                      const Spacer(),
                      if (refreshing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          tooltip: '친구 목록 새로고침',
                          onPressed: () async {
                            setState(() => refreshing = true);
                            try {
                              await store.refreshFriends();
                            } finally {
                              if (mounted) {
                                setState(() => refreshing = false);
                              }
                            }
                          },
                          icon: const Icon(Icons.refresh),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '이름·아이디로 친구 검색',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: DiaryColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TabChip(
                          label: '팔로잉',
                          color: DiaryColors.folderBlue,
                          active: tab == 0,
                          onTap: () => setState(() => tab = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TabChip(
                          label: '위시리스트',
                          color: DiaryColors.folderPink,
                          active: tab == 1,
                          onTap: () => setState(() => tab = 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SpiralNotebook(
                folderColor: DiaryColors.canvas,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: tab == 0
                      ? _FollowingList(
                          friends: friends,
                          onToggleFollow: (f) => store.toggleFollow(f.id),
                        )
                      : _FriendWishlistsPane(
                          wishlists: wishlistCards,
                          followingEmpty: followingFriends.isEmpty,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowingList extends StatelessWidget {
  const _FollowingList({
    required this.friends,
    required this.onToggleFollow,
  });

  final List<Friend> friends;
  final Future<void> Function(Friend friend) onToggleFollow;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Center(
        child: Text(
          '검색 결과가 없어요',
          style: DiaryTheme.body(14, color: DiaryColors.inkMuted),
        ),
      );
    }
    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, i) {
        final f = friends[i];
        return WhiteProductCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(f.avatar),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: DiaryTheme.body(14, weight: FontWeight.w700),
                    ),
                    Text(
                      f.username,
                      style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
                    ),
                    Text(
                      '위시리스트 ${f.wishlistCount}  ·  아이템 ${f.itemCount}',
                      style: DiaryTheme.body(11, color: DiaryColors.accent),
                    ),
                  ],
                ),
              ),
              _FollowButton(
                isFollowing: f.isFollowing,
                onPressed: () async {
                  final willFollow = !f.isFollowing;
                  await onToggleFollow(f);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        willFollow
                            ? '${f.name} 님을 팔로우했어요'
                            : '${f.name} 님 팔로우를 취소했어요',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Instagram-style: following = outlined "팔로잉", not following = filled "팔로우".
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.onPressed,
  });

  final bool isFollowing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isFollowing) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: DiaryColors.ink,
          side: BorderSide(color: DiaryColors.ink.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: const Text('팔로잉'),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: DiaryColors.ink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: const Text('팔로우'),
    );
  }
}

class _FriendWishlistsPane extends StatelessWidget {
  const _FriendWishlistsPane({
    required this.wishlists,
    required this.followingEmpty,
  });

  final List<FriendWishlist> wishlists;
  final bool followingEmpty;

  @override
  Widget build(BuildContext context) {
    if (followingEmpty) {
      return Center(
        child: Text(
          '팔로우한 친구가 없어요\n팔로잉 탭에서 친구를 팔로우해 보세요',
          textAlign: TextAlign.center,
          style: DiaryTheme.body(14, color: DiaryColors.inkMuted),
        ),
      );
    }
    if (wishlists.isEmpty) {
      return Center(
        child: Text(
          '공개된 친구 위시리스트가 없어요',
          style: DiaryTheme.body(14, color: DiaryColors.inkMuted),
        ),
      );
    }
    return ListView(
      children: [
        for (final w in wishlists)
          WhiteProductCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.listName,
                  style: DiaryTheme.body(15, weight: FontWeight.w700),
                ),
                Text(
                  w.friendName,
                  style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: w.items
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  context.push('/catalog-product/${p.id}'),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      p.image,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 72,
                                        height: 72,
                                        color: DiaryColors.paper,
                                        child: const Icon(Icons.image_outlined),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DiaryTheme.body(10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/friend-wishlist/${w.id}'),
                    child: const Text('위시리스트 전체보기'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            bottom: BorderSide(
              color: active ? DiaryColors.accent : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: DiaryTheme.body(
            13,
            weight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
