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
                    onPressed: () => _openAccountSettings(context, store),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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

  Future<void> _openAccountSettings(BuildContext context, AppStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DiaryColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '계정 설정',
                  style: DiaryTheme.body(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text('프로필 수정하기', style: DiaryTheme.body(14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditProfile(context, store);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: Text('비밀번호 수정하기', style: DiaryTheme.body(14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openChangePassword(context, store);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: Text('로그아웃', style: DiaryTheme.body(14)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await store.logout();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_off_outlined, color: DiaryColors.pin),
                  title: Text(
                    '탈퇴하기',
                    style: DiaryTheme.body(14, color: DiaryColors.pin),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openDeleteAccount(context, store);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDeleteAccount(BuildContext context, AppStore store) async {
    final passwordCtrl = TextEditingController();
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: DiaryColors.paper,
              title: Text(
                '탈퇴하기',
                style: DiaryTheme.ui(17, weight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '탈퇴하면 계정과 위시리스트가 삭제되고 되돌릴 수 없어요.',
                      style: DiaryTheme.body(13, color: DiaryColors.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '비밀번호 확인',
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: DiaryTheme.body(12, color: DiaryColors.pin),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    if (passwordCtrl.text.isEmpty) {
                      setLocal(() => error = '비밀번호를 입력해 주세요.');
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(
                    '탈퇴',
                    style: DiaryTheme.ui(
                      14,
                      weight: FontWeight.w700,
                      color: DiaryColors.pin,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    try {
      await store.deleteAccount(password: passwordCtrl.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('탈퇴가 완료되었어요')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _openChangePassword(BuildContext context, AppStore store) async {
    final currentCtrl = TextEditingController();
    final nextCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: DiaryColors.paper,
              title: Text(
                '비밀번호 변경',
                style: DiaryTheme.ui(17, weight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '현재 비밀번호'),
                    ),
                    TextField(
                      controller: nextCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '새 비밀번호'),
                    ),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: DiaryTheme.body(12, color: DiaryColors.pin),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    if (nextCtrl.text != confirmCtrl.text) {
                      setLocal(() => error = '새 비밀번호가 서로 달라요.');
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(
                    '변경',
                    style: DiaryTheme.ui(
                      14,
                      weight: FontWeight.w700,
                      color: DiaryColors.accent,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    try {
      await store.changePassword(
        currentPassword: currentCtrl.text,
        newPassword: nextCtrl.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호를 변경했어요')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
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
          '프로필 수정하기',
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
                decoration: const InputDecoration(labelText: '아이디 (@없이 입력 가능)'),
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
