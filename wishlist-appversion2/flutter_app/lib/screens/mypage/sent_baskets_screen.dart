import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../services/app_error.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class SentBasketsScreen extends StatelessWidget {
  const SentBasketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final baskets = store.sentBaskets;

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
          '내가 보낸 살까말까',
          style: DiaryTheme.ui(18, weight: FontWeight.w700),
        ),
      ),
      body: baskets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '아직 보낸 살까말까가 없어요.\n살까말까 탭에서 친구에게 보내거나 링크를 만들면 여기에 쌓여요',
                  textAlign: TextAlign.center,
                  style: DiaryTheme.body(14, color: DiaryColors.inkMuted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: baskets.length,
              itemBuilder: (context, i) {
                final b = baskets[i];
                return WhiteProductCard(
                  onTap: () => context.push('/shared/${b.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: DiaryTheme.body(15, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(b),
                        style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final p in b.items.take(8))
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    p.image,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 56,
                                      height: 56,
                                      color: DiaryColors.paper,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => showSentBasketShareSheet(
                            context,
                            store,
                            b,
                          ),
                          child: const Text('다시 보내기'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _subtitle(SharedBasket b) {
    final when = '${b.createdAt.month}/${b.createdAt.day}';
    if (b.recipientNames.isNotEmpty) {
      final names = b.recipientNames.take(2).join(', ');
      final extra = b.recipientNames.length > 2
          ? ' 외 ${b.recipientNames.length - 2}명'
          : '';
      return '$when  ·  $names$extra  ·  상품 ${b.items.length}개';
    }
    return '$when  ·  링크 공유  ·  상품 ${b.items.length}개';
  }
}

Future<void> showSentBasketShareSheet(
  BuildContext context,
  AppStore store,
  SharedBasket basket,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: DiaryColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('다시 보내기', style: DiaryTheme.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: Text('앱 친구에게 보내기', style: DiaryTheme.body(14)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _resendToFriends(context, store, basket);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text('링크 복사', style: DiaryTheme.body(14)),
                onTap: () async {
                  final url = store.shareUrlFor(basket);
                  await Clipboard.setData(ClipboardData(text: url));
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('링크 복사됨 · $url')),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _resendToFriends(
  BuildContext context,
  AppStore store,
  SharedBasket basket,
) async {
  final following = store.friends.where((f) => f.isFollowing).toList();
  if (following.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('팔로잉한 친구가 없어요. 먼저 친구를 추가해 주세요.')),
    );
    return;
  }

  final selected = <String>{};
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiaryColors.paper,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '다시 보낼 친구',
                      style: DiaryTheme.body(16, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: following.length,
                        itemBuilder: (context, i) {
                          final f = following[i];
                          final checked = selected.contains(f.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  selected.add(f.id);
                                } else {
                                  selected.remove(f.id);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              backgroundImage: NetworkImage(f.avatar),
                            ),
                            title: Text(f.name),
                            subtitle: Text(f.username),
                          );
                        },
                      ),
                    ),
                    FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(sheetCtx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: DiaryColors.ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('보내기 (${selected.length})'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (confirmed != true || selected.isEmpty || !context.mounted) return;
  try {
    await store.resendBasketToFriends(
      items: basket.items,
      friendIds: selected.toList(),
      existingId: basket.id,
    );
    if (!context.mounted) return;
    final warning = store.takeLastWarning();
    showAppMessage(
      context,
      warning ?? '${selected.length}명의 친구에게 다시 보냈어요',
    );
  } catch (e) {
    if (!context.mounted) return;
    showAppError(context, e);
  }
}
