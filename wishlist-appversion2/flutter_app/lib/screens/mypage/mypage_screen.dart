import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    final folders = store.tabs.where((t) => t.id != 'all').toList();

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      body: SafeArea(
        child: SpiralNotebook(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            children: [
              Row(
                children: [
                  Text('마이페이지', style: DiaryTheme.display(32)),
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      await store.logout();
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Price-tag style profile with edit affordance
              Stack(
                children: [
                  CustomPaint(
                    painter: _TagPainter(color: const Color(0xFFE8B4A8)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 18, 14, 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: NetworkImage(user.avatarUrl),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: DiaryTheme.body(
                                    16,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  user.handle,
                                  style: DiaryTheme.body(
                                    12,
                                    color: DiaryColors.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${user.followers} 팔로워  |  ${user.following} 팔로잉  |  ${store.products.length} 아이템',
                                  style: DiaryTheme.body(11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: DiaryColors.ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openEditProfile(context, store),
                      child: Text(
                        '정보 수정하기',
                        style: DiaryTheme.body(11, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('내 wishlist', style: DiaryTheme.display(26)),
              const SizedBox(height: 10),
              if (folders.isEmpty) ...[
                Text(
                  '아직 폴더가 없어요. + 를 눌러 첫 폴더를 만들어보세요',
                  textAlign: TextAlign.center,
                  style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
                ),
                const SizedBox(height: 10),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 16.0;
                  final chipWidth = (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: spacing,
                    runSpacing: 10,
                    children: [
                      for (final tab in folders)
                        _FolderChip(
                          label: tab.name,
                          color: store.tabColor(tab),
                          width: chipWidth,
                          onTap: () {
                            store.selectTab(tab.id);
                            // Switch to wishlist tab in bottom nav.
                            StatefulNavigationShell.maybeOf(context)
                                ?.goBranch(0);
                            context.go('/');
                          },
                        ),
                      _FolderChip(
                        label: '+',
                        color: DiaryColors.folderLilac,
                        width: chipWidth,
                        onTap: () async {
                          final ctrl = TextEditingController();
                          final name = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('폴더 추가'),
                              content: TextField(controller: ctrl),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('취소')),
                                TextButton(
                                    onPressed: () => Navigator.pop(
                                        context, ctrl.text.trim()),
                                    child: const Text('추가')),
                              ],
                            ),
                          );
                          if (name != null && name.isNotEmpty) {
                            await store.addTab(name);
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              DiaryButton(
                label: '알림 설정',
                icon: Icons.notifications_none,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('알림 설정은 준비 중이에요')),
                  );
                },
              ),
              const SizedBox(height: 8),
              DiaryButton(
                label: '앱 정보',
                icon: Icons.info_outline,
                onPressed: () {
                  showAboutDialog(
                    context: context,
                    applicationName: '통합 위시리스트',
                    applicationVersion: '0.1.0',
                    applicationLegalese: 'MZ diary scrapbook wishlist',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context, AppStore store) async {
    final nameCtrl = TextEditingController(text: store.currentUser.name);
    final handleCtrl = TextEditingController(text: store.currentUser.handle);
    final avatarCtrl =
        TextEditingController(text: store.currentUser.avatarUrl);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DiaryColors.paper,
        title: Text(
          '정보 수정하기',
          style: DiaryTheme.ui(17, weight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: NetworkImage(store.currentUser.avatarUrl),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              TextField(
                controller: handleCtrl,
                decoration: const InputDecoration(labelText: '핸들 (@username)'),
              ),
              TextField(
                controller: avatarCtrl,
                decoration: const InputDecoration(labelText: '프로필 사진 URL'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '저장',
              style: DiaryTheme.ui(
                14,
                weight: FontWeight.w700,
                color: DiaryColors.accent,
              ),
            ),
          ),
        ],
      ),
    );

    if (saved == true) {
      await store.updateProfile(
        name: nameCtrl.text,
        handle: handleCtrl.text,
        avatarUrl: avatarCtrl.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필을 저장했어요')),
        );
      }
    }
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({
    required this.label,
    required this.color,
    required this.width,
    required this.onTap,
  });

  final String label;
  final Color color;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DiaryColors.ink.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: DiaryTheme.body(13, weight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TagPainter extends CustomPainter {
  _TagPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(18, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(18, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
    canvas.drawCircle(
        Offset(18, size.height / 2), 5, Paint()..color = DiaryColors.paper);
    canvas.drawCircle(
      Offset(18, size.height / 2),
      5,
      Paint()
        ..color = DiaryColors.ink.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
