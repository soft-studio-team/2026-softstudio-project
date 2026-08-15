import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/diary_theme.dart';

/// Preferences for which in-app notification types to show.
/// Inbox itself lives on the Friends page bell icon.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      appBar: AppBar(
        backgroundColor: DiaryColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '알림 설정',
          style: DiaryTheme.ui(18, weight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            '받고 싶은 알림을 골라요',
            style: DiaryTheme.body(13, color: DiaryColors.inkMuted),
          ),
          const SizedBox(height: 12),
          _PrefCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '새 팔로우',
                style: DiaryTheme.body(15, weight: FontWeight.w700),
              ),
              subtitle: Text(
                '누군가 나를 팔로우하면 알림함에 표시해요',
                style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
              ),
              value: store.notifyOnFollow,
              activeThumbColor: DiaryColors.accent,
              onChanged: (v) => store.setNotifyOnFollow(v),
            ),
          ),
          const SizedBox(height: 10),
          _PrefCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '살까말까 장바구니',
                style: DiaryTheme.body(15, weight: FontWeight.w700),
              ),
              subtitle: Text(
                '친구가 살까말까를 보내면 알림함에 표시해요',
                style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
              ),
              value: store.notifyOnBasket,
              activeThumbColor: DiaryColors.accent,
              onChanged: (v) => store.setNotifyOnBasket(v),
            ),
          ),
          const SizedBox(height: 10),
          _PrefCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '친구 리뷰',
                style: DiaryTheme.body(15, weight: FontWeight.w700),
              ),
              subtitle: Text(
                '친구가 상품 리뷰를 올리면 알림함에 표시해요',
                style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
              ),
              value: store.notifyOnReview,
              activeThumbColor: DiaryColors.accent,
              onChanged: (v) => store.setNotifyOnReview(v),
            ),
          ),
          const SizedBox(height: 10),
          _PrefCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '리스트 공개',
                style: DiaryTheme.body(15, weight: FontWeight.w700),
              ),
              subtitle: Text(
                '친구가 위시리스트를 공개하면 알림함에 표시해요',
                style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
              ),
              value: store.notifyOnList,
              activeThumbColor: DiaryColors.accent,
              onChanged: (v) => store.setNotifyOnList(v),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none),
            label: const Text('알림함 열기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DiaryColors.ink,
              side: BorderSide(color: DiaryColors.ink.withValues(alpha: 0.25)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '알림함은 내 친구 페이지 오른쪽 위 종 아이콘에서도 볼 수 있어요',
            style: DiaryTheme.body(11, color: DiaryColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _PrefCard extends StatelessWidget {
  const _PrefCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: DiaryColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiaryColors.ink.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
