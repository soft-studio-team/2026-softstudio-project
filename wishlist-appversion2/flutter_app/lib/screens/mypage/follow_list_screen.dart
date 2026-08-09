import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

enum FollowListKind { followers, following }

/// Shows the current user's followers or following list, loaded from
/// Firestore via the users/{uid}/followers and users/{uid}/following
/// subcollections.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key, required this.kind});

  final FollowListKind kind;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late final Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _future = widget.kind == FollowListKind.followers
        ? store.loadFollowers()
        : store.loadFollowingUsers();
  }

  @override
  Widget build(BuildContext context) {
    final isFollowers = widget.kind == FollowListKind.followers;
    final title = isFollowers ? '팔로워' : '팔로잉';
    final emptyText = isFollowers ? '팔로워가 없습니다' : '팔로우하고 있는 사람이 없습니다';

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      appBar: AppBar(
        backgroundColor: DiaryColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(title, style: DiaryTheme.ui(16, weight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: FutureBuilder<List<AppUser>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data ?? [];
            if (users.isEmpty) {
              return Center(
                child: Text(
                  emptyText,
                  style: DiaryTheme.body(14, color: DiaryColors.inkMuted),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (context, i) {
                final u = users[i];
                return PersonRow(
                  name: u.name,
                  handle: u.handle,
                  avatarUrl: u.avatarUrl,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
