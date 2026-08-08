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
      builder: (sheetCtx) => _PickFromWishlistSheet(store: store),
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

class _PickFromWishlistSheet extends StatefulWidget {
  const _PickFromWishlistSheet({required this.store});

  final AppStore store;

  @override
  State<_PickFromWishlistSheet> createState() =>
      _PickFromWishlistSheetState();
}

class _PickFromWishlistSheetState extends State<_PickFromWishlistSheet> {
  late final Set<int> _originalIds =
      widget.store.basket.map((b) => b.product.id).toSet();
  late final Set<int> _checkedIds = {..._originalIds};

  void _onToggle(Product product, bool? checked) {
    setState(() {
      if (checked ?? false) {
        _checkedIds.add(product.id);
      } else {
        _checkedIds.remove(product.id);
        if (_originalIds.contains(product.id)) {
          widget.store.removeFromBasket(product.id);
        }
      }
    });
  }

  Future<void> _confirm() async {
    final newlyChecked = _checkedIds.difference(_originalIds);
    for (final id in newlyChecked) {
      final product = widget.store.products.firstWhere((p) => p.id == id);
      await widget.store.addToBasket(product);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.store.products;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
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
                    child: Text('위시리스트에서 담기',
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
                child: products.isEmpty
                    ? Center(
                        child: Text('위시리스트에 담긴 상품이 없어요',
                            style: DiaryTheme.body(14,
                                color: DiaryColors.inkMuted)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: products.length,
                        itemBuilder: (context, i) {
                          final product = products[i];
                          final checked = _checkedIds.contains(product.id);
                          return WhiteProductCard(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: checked,
                                  onChanged: (v) => _onToggle(product, v),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    product.image,
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
                                      Text(product.platform,
                                          style: DiaryTheme.body(11,
                                              color: DiaryColors.inkMuted)),
                                      Text(product.name,
                                          style: DiaryTheme.body(14,
                                              weight: FontWeight.w700)),
                                      Text(formatWon(product.price),
                                          style: DiaryTheme.body(13,
                                              weight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              DiaryButton(
                label: '담기 완료 (${_checkedIds.length})',
                filled: true,
                color: DiaryColors.folderPeach,
                icon: Icons.check,
                onPressed: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
