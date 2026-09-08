import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../services/parsing_bridge.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

/// Shown when another app shares a product URL into this app.
class ShareIntakeScreen extends StatefulWidget {
  const ShareIntakeScreen({super.key, this.sharedUrl});

  final String? sharedUrl;

  @override
  State<ShareIntakeScreen> createState() => _ShareIntakeScreenState();
}

class _ShareIntakeScreenState extends State<ShareIntakeScreen> {
  // 서버/엔진이 내려주는 필드 키(title/price/image_url 등)를 사용자가 보는
  // 화면에 그대로 노출하지 않기 위한 한글 라벨 변환. 모르는 키는 원문 그대로
  // 보여줘서(하위 호환) 조용히 정보가 사라지지는 않게 한다.
  static String _missingFieldLabel(String field) {
    switch (field) {
      case 'title':
        return '상품명';
      case 'price':
        return '가격';
      case 'image_url':
        return '이미지';
      default:
        return field;
    }
  }

  final bridge = ParsingBridge();
  final urlCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  bool loading = false;
  String? error;
  ParsedProductInfo? parsed;
  String? selectedListId;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    selectedListId = store.tabs
        .firstWhere((t) => t.id != 'all', orElse: () => store.tabs.first)
        .id;
    final initial = widget.sharedUrl ?? store.pendingShareUrl;
    if (initial != null) {
      urlCtrl.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _parse());
    }
  }

  @override
  void dispose() {
    urlCtrl.dispose();
    titleCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final input = urlCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final info = input.contains('http') && !input.trim().contains(' ')
          ? await bridge.parseProductUrl(input)
          : await bridge.scrapShareInput(input);
      titleCtrl.text = info.name;
      priceCtrl.text = info.price > 0 ? '${info.price}' : '';
      setState(() => parsed = info);
    } catch (e) {
      setState(() => error = '상품 정보를 읽지 못했어요');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (parsed == null || selectedListId == null) return;
    final name = titleCtrl.text.trim().isEmpty ? parsed!.name : titleCtrl.text.trim();
    final price = int.tryParse(priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        parsed!.price;

    final info = ParsedProductInfo(
      name: name,
      price: price,
      platform: parsed!.platform,
      image: parsed!.image,
      productUrl: parsed!.productUrl.isEmpty
          ? urlCtrl.text.trim()
          : parsed!.productUrl,
      originalPrice: parsed!.originalPrice,
      discount: parsed!.discount,
      missingFields: parsed!.missingFields,
      resolvedTier: parsed!.resolvedTier,
      engineUsed: parsed!.engineUsed,
      onDeviceExtracted: parsed!.onDeviceExtracted,
    );

    final store = context.read<AppStore>();
    final product = await store.addParsedProduct(
      info,
      listId: selectedListId!,
    );
    store.setPendingShareUrl(null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} 을(를) 저장했어요')),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final lists = store.tabs.where((t) => t.id != 'all').toList();

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      appBar: AppBar(
        title: Text('공유 담기', style: DiaryTheme.display(28)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DiaryGridPaper(
            child: ListView(
              children: [
                Text(
                  '다른 앱에서 공유한 링크를\n위시리스트 카드로 정리해요',
                  style: DiaryTheme.body(14, color: DiaryColors.inkMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: '상품 URL 또는 공유 텍스트',
                    filled: true,
                    fillColor: DiaryColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: loading ? null : _parse,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DiaryButton(
                  label: loading ? '파싱 중...' : '정보 가져오기',
                  filled: true,
                  color: DiaryColors.folderBlue,
                  onPressed: loading ? () {} : _parse,
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: DiaryTheme.body(12, color: DiaryColors.pin)),
                ],
                if (parsed != null) ...[
                  const SizedBox(height: 16),
                  WhiteProductCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (parsed!.image.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: parsed!.image,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              // 스크롤 중 프레임 드랍의 흔한 원인 — 지정 안 하면 원본 해상도 그대로
                              // 디코딩한 뒤 화면에서만 축소해서 그리므로, 실제 표시 크기 기준으로
                              // 디코딩 자체를 줄인다(72px 표시 기준 고해상도 화면 대비 3배).
                              memCacheWidth: 216,
                              memCacheHeight: 216,
                              placeholder: (_, __) => Container(
                                width: 72,
                                height: 72,
                                color: DiaryColors.grid,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 72,
                                height: 72,
                                color: DiaryColors.grid,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(parsed!.platform,
                                  style: DiaryTheme.body(12,
                                      color: DiaryColors.inkMuted)),
                              // 티어/추출 방식은 내부 구현 정보라 사용자에게 그대로
                              // 보여줄 필요가 없다. 자동으로 아예 못 찾은 경우
                              // (엔진 미사용 · 이전엔 'Tier 3 · 오프라인 추정'으로
                              // 노출되던 경우)에만 알기 쉬운 말로 안내한다.
                              if (!parsed!.engineUsed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '자동으로 정보를 찾지 못했어요 · 아래에서 직접 입력해주세요',
                                    style: DiaryTheme.body(11,
                                        color: DiaryColors.pin),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '상품명',
                      filled: true,
                      fillColor: DiaryColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '기본 판매가 (쿠폰·옵션 제외, 원)',
                      filled: true,
                      fillColor: DiaryColors.white,
                    ),
                  ),
                  if (parsed!.originalPrice != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '정가 ${formatWon(parsed!.originalPrice!)} · '
                      '판매가 ${formatWon(parsed!.price)}',
                      style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '쿠폰은 제외한 기본 판매가예요. 옵션을 선택하면 가격이 달라질 수 있어요.',
                    style: DiaryTheme.body(11, color: DiaryColors.inkMuted),
                  ),
                  if (parsed!.missingFields.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '보완 필요: '
                      '${parsed!.missingFields.map(_missingFieldLabel).join(', ')}',
                      style:
                          DiaryTheme.body(12, color: DiaryColors.pin),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text('어느 리스트로 보낼까요?',
                      style: DiaryTheme.body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tab in lists)
                        ChoiceChip(
                          label: Text(tab.name),
                          selected: selectedListId == tab.id,
                          selectedColor: store.tabColor(tab),
                          onSelected: (_) =>
                              setState(() => selectedListId = tab.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DiaryButton(
                    label: '이 리스트에 저장',
                    filled: true,
                    color: DiaryColors.folderMint,
                    onPressed: _save,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
