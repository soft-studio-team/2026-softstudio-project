import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';
import 'basket_picker_sheet.dart';

class SalkamalkaScreen extends StatelessWidget {
  const SalkamalkaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final selected = store.basket.where((b) => b.isSelected).length;

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('살까말까', style: DiaryTheme.display(34)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: DiaryGridPaper(
                  border: Border.all(color: DiaryColors.fileCream, width: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('📌 선택된 아이템 총 $selected개',
                          style: DiaryTheme.body(13, weight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: store.basket.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: OneLineText(
                                    '고민중인 상품을 담아 친구와 공유해보세요',
                                    textAlign: TextAlign.center,
                                    style: DiaryTheme.body(
                                      14,
                                      color: DiaryColors.inkMuted,
                                    ),
                                  ),
                                ),
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
                                              borderRadius:
                                                  BorderRadius.circular(10),
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
                                                      style: DiaryTheme.body(
                                                          11,
                                                          color: DiaryColors
                                                              .inkMuted)),
                                                  Text(
                                                    item.product.name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: DiaryTheme.body(
                                                      14,
                                                      weight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                      formatWon(
                                                          item.product.price),
                                                      style: DiaryTheme.body(
                                                          13,
                                                          weight: FontWeight
                                                              .w600)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => store
                                                  .removeFromBasket(
                                                      item.product.id),
                                              icon: const Icon(Icons.close,
                                                  size: 18),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        left: 8,
                                        top: 2,
                                        child: Icon(Icons.push_pin,
                                            size: 18,
                                            color: pinColors[
                                                i % pinColors.length]),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: DiaryButton(
                              label: '상품 추가하기',
                              icon: Icons.add,
                              onPressed: () =>
                                  _openPickFromWishlistSheet(context, store),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DiaryButton(
                              label: selected == 0
                                  ? '공유하기'
                                  : '공유하기 ($selected)',
                              filled: true,
                              color: DiaryColors.folderPeach,
                              icon: Icons.ios_share,
                              onPressed: selected == 0
                                  ? null
                                  : () => _openShareSheet(context, store),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPickFromWishlistSheet(
      BuildContext context, AppStore store) async {
    final picked = await showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => BasketPickerSheet(store: store),
    );
    if (picked == null || picked.isEmpty) return;
    await store.addManyToBasket(picked);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${picked.length}개를 담았어요')),
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
                  await _openFriendPicker(context, store);
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

  Future<void> _openFriendPicker(BuildContext context, AppStore store) async {
    final following = store.friends.where((f) => f.isFollowing).toList();
    if (following.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팔로잉한 친구가 없어요. 먼저 친구를 추가해 주세요.')),
      );
      return;
    }

    final selected = <String>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
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
                        '보낼 친구 선택',
                        style: DiaryTheme.body(16, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '팔로잉 중인 친구에게 살까말까를 보내요',
                        style: DiaryTheme.body(
                          12,
                          color: DiaryColors.inkMuted,
                        ),
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

    if (confirmed != true || selected.isEmpty) return;
    try {
      await store.sendBasketToFriends(selected.toList());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length}명의 친구에게 살까말까를 보냈어요'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}
