import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
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
    );
  }

  Future<void> _openPickFromWishlistSheet(
      BuildContext context, AppStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) =>
          _CategoryPickerSheet(store: store, outerContext: context),
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

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.store, required this.outerContext});

  final AppStore store;
  final BuildContext outerContext;

  Future<void> _addCategory(
      BuildContext sheetContext, String label, List<Product> products) async {
    final existingIds = store.basket.map((b) => b.product.id).toSet();
    final newProducts =
        products.where((p) => !existingIds.contains(p.id)).toList();
    for (final product in newProducts) {
      await store.addToBasket(product);
    }
    if (!sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    if (!outerContext.mounted) return;
    final message = newProducts.isEmpty
        ? '이미 모두 담겨 있어요'
        : '$label ${newProducts.length}개를 담았어요';
    ScaffoldMessenger.of(outerContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custom = store.customTabs;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (sheetCtx, scrollController) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('카테고리에서 담기',
                        style: DiaryTheme.body(16, weight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: custom.isEmpty
                    ? Center(
                        child: Text('카테고리가 없어요',
                            style: DiaryTheme.body(14,
                                color: DiaryColors.inkMuted)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: custom.length + 1,
                        itemBuilder: (context, i) {
                          final isAll = i == 0;
                          final label = isAll ? '전체' : custom[i - 1].name;
                          final color = isAll
                              ? store.tabColor(store.tabs.first)
                              : store.tabColor(custom[i - 1]);
                          final products = isAll
                              ? store.products
                              : store.products
                                  .where((p) => p.listId == custom[i - 1].id)
                                  .toList();
                          final count = products.length;
                          final disabled = count == 0;
                          return Opacity(
                            opacity: disabled ? 0.45 : 1,
                            child: WhiteProductCard(
                              indexColor: color,
                              onTap: disabled
                                  ? null
                                  : () => _addCategory(context, label, products),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(label,
                                        style: DiaryTheme.body(14,
                                            weight: FontWeight.w700)),
                                  ),
                                  Text('$count개',
                                      style: DiaryTheme.body(13,
                                          color: DiaryColors.inkMuted)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
