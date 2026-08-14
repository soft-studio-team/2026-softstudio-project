import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class ReviewComposeScreen extends StatefulWidget {
  const ReviewComposeScreen({
    super.key,
    this.productId,
    this.reviewId,
  });

  final int? productId;
  final String? reviewId;

  @override
  State<ReviewComposeScreen> createState() => _ReviewComposeScreenState();
}

class _ReviewComposeScreenState extends State<ReviewComposeScreen> {
  Product? selected;
  late final TextEditingController titleCtrl;
  late final TextEditingController bodyCtrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    ProductReview? existing;
    if (widget.reviewId != null) {
      existing = store.reviewById(widget.reviewId!);
    }
    existing ??= widget.productId != null
        ? store.myReviewForProduct(widget.productId!)
        : null;

    if (existing != null) {
      selected = store.findCatalogProduct(existing.productId) ??
          Product(
            id: existing.productId,
            listId: '',
            name: existing.productName,
            price: existing.productPrice,
            image: existing.productImage,
            platform: existing.productPlatform,
            productUrl: existing.productUrl,
          );
      titleCtrl = TextEditingController(text: existing.title);
      bodyCtrl = TextEditingController(text: existing.body);
    } else {
      selected = widget.productId != null
          ? store.findCatalogProduct(widget.productId!)
          : null;
      titleCtrl = TextEditingController();
      bodyCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final product = selected;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰할 상품을 골라 주세요')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final store = context.read<AppStore>();
      final existing = store.myReviewForProduct(product.id);
      final review = await store.publishReview(
        product: product,
        title: titleCtrl.text,
        body: bodyCtrl.text,
        existingId: existing?.id,
      );
      if (!mounted) return;
      context.pushReplacement('/reviews/${review.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final editing = selected != null &&
        store.myReviewForProduct(selected!.id) != null;

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
          editing ? '리뷰 수정' : '리뷰 쓰기',
          style: DiaryTheme.ui(18, weight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : _publish,
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    editing ? '수정' : '올리기',
                    style: DiaryTheme.ui(
                      15,
                      weight: FontWeight.w700,
                      color: DiaryColors.accent,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (selected == null)
            _ProductPicker(
              products: store.products,
              onPick: (p) => setState(() => selected = p),
            )
          else ...[
            WhiteProductCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      selected!.image,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: DiaryColors.paper,
                        child: const Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected!.platform,
                          style: DiaryTheme.product(
                            11,
                            color: DiaryColors.inkMuted,
                          ),
                        ),
                        Text(
                          selected!.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DiaryTheme.product(
                            14,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.productId == null && widget.reviewId == null)
                    TextButton(
                      onPressed: () => setState(() => selected = null),
                      child: const Text('바꾸기'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              style: DiaryTheme.body(22, weight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '제목을 적어보세요',
                hintStyle: DiaryTheme.body(22, color: DiaryColors.inkSoft),
                border: InputBorder.none,
              ),
            ),
            const Divider(height: 1),
            TextField(
              controller: bodyCtrl,
              minLines: 10,
              maxLines: null,
              style: DiaryTheme.product(15),
              decoration: InputDecoration(
                hintText: '이 상품에 대한 솔직한 이야기를 블로그처럼 남겨보세요.',
                hintStyle: DiaryTheme.product(15, color: DiaryColors.inkSoft),
                border: InputBorder.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.products,
    required this.onPick,
  });

  final List<Product> products;
  final ValueChanged<Product> onPick;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text(
              '위시리스트에 담긴 상품이 없어요',
              style: DiaryTheme.body(14, color: DiaryColors.inkMuted),
            ),
            const SizedBox(height: 8),
            Text(
              '상품을 담은 뒤 리뷰를 쓸 수 있어요',
              style: DiaryTheme.body(12, color: DiaryColors.inkSoft),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '리뷰할 상품을 고르세요',
          style: DiaryTheme.body(15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (final p in products)
          WhiteProductCard(
            onTap: () => onPick(p),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    p.image,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: DiaryColors.paper,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DiaryTheme.product(
                          13,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        p.platform,
                        style: DiaryTheme.product(
                          11,
                          color: DiaryColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}
