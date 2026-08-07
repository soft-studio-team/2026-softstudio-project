import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class SalkamalkaScreen extends StatelessWidget {
  const SalkamalkaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final selected = store.basket.where((b) => b.isSelected).length;

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: DiaryGridPaper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: DiaryColors.ink.withValues(alpha: 0.7),
                        width: 1.3),
                    color: DiaryColors.white.withValues(alpha: 0.7),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('살까말까', style: DiaryTheme.display(34)),
                      Text(
                        '고민중인 상품을 담아 친구와 공유해보세요',
                        style:
                            DiaryTheme.body(12, color: DiaryColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('📌 선택된 아이템 총 $selected개',
                    style: DiaryTheme.body(13, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                Expanded(
                  child: store.basket.isEmpty
                      ? Center(
                          child: Text('바구니에 담은 상품이 없어요',
                              style: DiaryTheme.body(14,
                                  color: DiaryColors.inkMuted)),
                        )
                      : ListView.builder(
                          itemCount: store.basket.length,
                          itemBuilder: (context, i) {
                            final item = store.basket[i];
                            final pinColors = [
                              DiaryColors.pin,
                              DiaryColors.folderYellow,
                              DiaryColors.accent,
                            ];
                            return Stack(
                              children: [
                                WhiteProductCard(
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: item.isSelected,
                                        onChanged: (_) => store
                                            .toggleBasketSelected(
                                                item.product.id),
                                      ),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          item.product.image,
                                          width: 58,
                                          height: 58,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item.product.platform,
                                                style: DiaryTheme.body(11,
                                                    color:
                                                        DiaryColors.inkMuted)),
                                            Text(item.product.name,
                                                style: DiaryTheme.body(14,
                                                    weight: FontWeight.w700)),
                                            Text(formatWon(item.product.price),
                                                style: DiaryTheme.body(13,
                                                    weight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => store
                                            .removeFromBasket(item.product.id),
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  top: 2,
                                  child: Icon(Icons.push_pin,
                                      size: 18,
                                      color: pinColors[i % pinColors.length]),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                DiaryButton(
                  label: selected == 0 ? '공유할 상품을 선택하세요' : '공유하기 ($selected)',
                  filled: true,
                  color: DiaryColors.folderPeach,
                  icon: Icons.ios_share,
                  onPressed: selected == 0
                      ? () {}
                      : () => _openShareSheet(context, store),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openShareSheet(BuildContext context, AppStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('공유 방식',
                  style: DiaryTheme.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('앱 친구에게 보내기'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final shared = await store.createSharedBasketFromSelection();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${shared.items.length}개 상품을 친구에게 공유했어요'),
                    ),
                  );
                  context.push('/shared/${shared.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('카카오톡'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('카카오 공유는 추후 연동 예정')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('링크 복사'),
                subtitle: const Text('링크를 열면 위시리스트처럼 보여요'),
                onTap: () async {
                  final shared = await store.createSharedBasketFromSelection();
                  final url = store.shareUrlFor(shared);
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!context.mounted) return;
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('링크 복사됨 · $url'),
                      action: SnackBarAction(
                        label: '미리보기',
                        onPressed: () => context.push('/shared/${shared.id}'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
