import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final tab = store.selectedTab;
    final products = store.displayedProducts;
    final border = store.tabColor(tab);

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Wish List',
              style: DiaryTheme.display(34, weight: FontWeight.w700),
            ),
            CustomPaint(
              size: const Size(88, 10),
              painter: _SquigglePainter(
                DiaryColors.inkSoft.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: _TabsRow(
                store: store,
                onDoubleTapTab: (t) => _openListEditSheet(context, store, t),
                onAdd: () => _showAddListDialog(context, store),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '더블탭: 편집 · 꾹 눌러 드래그: 순서 변경',
                  style: DiaryTheme.ui(11, color: DiaryColors.inkMuted),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    border: Border.all(color: border, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: DiaryGridPaper(
                      padding: EdgeInsets.zero,
                      borderRadius: 0,
                      child: Column(
                        children: [
                          if (tab.id != 'all')
                            _PrivacyBanner(
                              isPublic: tab.isPublic,
                              onToggle: () => store.toggleTabPublic(tab.id),
                            ),
                          Expanded(
                            child: products.isEmpty
                                ? Center(
                                    child: Text(
                                      '아직 담긴 아이템이 없어요',
                                      style: DiaryTheme.ui(
                                        14,
                                        color: DiaryColors.inkMuted,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      20,
                                    ),
                                    itemCount: products.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final p = products[i];
                                      return WishlistProductCard(
                                        product: p,
                                        onOpen: () =>
                                            context.push('/product/${p.id}'),
                                        onDelete: () =>
                                            store.removeProduct(p.id),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openListEditSheet(
    BuildContext context,
    AppStore store,
    WishlistTab tab,
  ) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DiaryColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final latest = store.tabs.firstWhere(
          (t) => t.id == tab.id,
          orElse: () => tab,
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DiaryColors.grid.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${latest.name} 편집',
                  style: DiaryTheme.ui(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  secondary: Icon(
                    latest.isPublic ? Icons.public : Icons.lock_outline,
                    color: DiaryColors.ink,
                  ),
                  title: Text(
                    '비공개 리스트',
                    style: DiaryTheme.ui(15, weight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    latest.isPublic
                        ? '지금 공개 중 · 켜면 나만 볼 수 있어요'
                        : '나만 볼 수 있어요',
                    style: DiaryTheme.ui(12, color: DiaryColors.inkMuted),
                  ),
                  value: !latest.isPublic,
                  activeThumbColor: DiaryColors.fileTaupe,
                  onChanged: (_) {
                    store.toggleTabPublic(latest.id);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(
                    '이름 변경',
                    style: DiaryTheme.ui(15, weight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameDialog(context, store, latest);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                  ),
                  title: Text(
                    '삭제',
                    style: DiaryTheme.ui(
                      15,
                      weight: FontWeight.w600,
                      color: Colors.red.shade400,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    store.deleteTab(latest.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    AppStore store,
    WishlistTab tab,
  ) async {
    final controller = TextEditingController(text: tab.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DiaryColors.paper,
        title: Text(
          '이름 변경',
          style: DiaryTheme.ui(17, weight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          style: DiaryTheme.ui(15),
          decoration: InputDecoration(
            hintText: '리스트 이름',
            hintStyle: DiaryTheme.ui(14, color: DiaryColors.inkMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: DiaryTheme.ui(14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
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
    if (name != null && name.isNotEmpty) {
      await store.renameTab(tab.id, name);
    }
  }

  Future<void> _showAddListDialog(BuildContext context, AppStore store) async {
    final controller = TextEditingController();
    var isPublic = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: DiaryColors.paper,
          title: Text(
            '새 리스트',
            style: DiaryTheme.ui(17, weight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: DiaryTheme.ui(15),
                decoration: InputDecoration(
                  hintText: '예: 여름 여행 옷',
                  hintStyle: DiaryTheme.ui(14, color: DiaryColors.inkMuted),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('공개 리스트', style: DiaryTheme.ui(14)),
                value: isPublic,
                onChanged: (v) => setLocal(() => isPublic = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: DiaryTheme.ui(14)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                '추가',
                style: DiaryTheme.ui(
                  14,
                  weight: FontWeight.w700,
                  color: DiaryColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await store.addTab(controller.text.trim(), isPublic: isPublic);
    }
  }
}

/// Fixed "전체" + long-press drag reorder for custom lists.
/// Double-tap opens the edit sheet (rename / delete / privacy).
class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.store,
    required this.onDoubleTapTab,
    required this.onAdd,
  });

  final AppStore store;
  final void Function(WishlistTab tab) onDoubleTapTab;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final custom = store.customTabs;
    final allTab = store.tabs.first;
    return Row(
      children: [
        const SizedBox(width: 12),
        _FolderTab(
          tab: allTab,
          selected: store.selectedTabId == 'all',
          count: store.countFor(allTab),
          color: store.tabColor(allTab),
          onTap: () => store.selectTab('all'),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 3,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: child,
              );
            },
            onReorder: store.reorderTabs,
            itemCount: custom.length,
            itemBuilder: (context, index) {
              final tab = custom[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(tab.id),
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FolderTab(
                    tab: tab,
                    selected: store.selectedTabId == tab.id,
                    count: store.countFor(tab),
                    color: store.tabColor(tab),
                    onTap: () => store.selectTab(tab.id),
                    onDoubleTap: () => onDoubleTapTab(tab),
                  ),
                ),
              );
            },
          ),
        ),
        _AddListTab(onTap: onAdd),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _FolderTab extends StatelessWidget {
  const _FolderTab({
    required this.tab,
    required this.selected,
    required this.count,
    required this.color,
    required this.onTap,
    this.onDoubleTap,
  });

  final WishlistTab tab;
  final bool selected;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color : color.withValues(alpha: 0.72);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(
              color: color.withValues(alpha: 0.9),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab.id != 'all') ...[
                Icon(
                  tab.isPublic ? Icons.public : Icons.lock_outline,
                  size: 13,
                  color: DiaryColors.ink.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                tab.name,
                style: DiaryTheme.ui(
                  13,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: DiaryTheme.ui(12, color: DiaryColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddListTab extends StatelessWidget {
  const _AddListTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        onTap: onTap,
        child: Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: DiaryColors.fileCream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: DiaryColors.fileStone),
          ),
          child: Icon(
            Icons.add,
            size: 20,
            color: DiaryColors.ink.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.isPublic, required this.onToggle});

  final bool isPublic;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DiaryColors.grid.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(
              isPublic ? Icons.public : Icons.lock_outline,
              size: 16,
              color: DiaryColors.inkMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPublic ? '공개 리스트' : '비공개 리스트',
                    style: DiaryTheme.ui(13, weight: FontWeight.w700),
                  ),
                  Text(
                    isPublic ? '친구들이 이 리스트를 볼 수 있어요' : '나만 볼 수 있어요',
                    style: DiaryTheme.ui(11, color: DiaryColors.inkMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onToggle,
              child: Text(
                isPublic ? '비공개로 변경' : '공개로 변경',
                style: DiaryTheme.ui(
                  12,
                  weight: FontWeight.w700,
                  color: const Color(0xFF5B7C99),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared product row used by own wishlist, friend lists, and shared baskets.
class WishlistProductCard extends StatelessWidget {
  const WishlistProductCard({
    super.key,
    required this.product,
    required this.onOpen,
    this.onDelete,
  });

  final Product product;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  product.image,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.platform,
                      style: DiaryTheme.product(
                        11,
                        color: DiaryColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DiaryTheme.product(14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (product.originalPrice != null) ...[
                          Text(
                            formatWon(product.originalPrice!),
                            style: DiaryTheme.product(
                              11,
                              color: DiaryColors.inkMuted,
                            ).copyWith(decoration: TextDecoration.lineThrough),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          formatWon(product.price),
                          style: DiaryTheme.product(
                            13,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: DiaryColors.inkSoft.withValues(alpha: 0.7),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(0, size.height * 0.55);
    for (double x = 0; x <= size.width; x += 8) {
      path.quadraticBezierTo(
        x + 4,
        x % 16 == 0 ? 2 : size.height - 2,
        x + 8,
        size.height * 0.55,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
