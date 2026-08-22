import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/diary_theme.dart';
import '../mypage/sent_baskets_screen.dart';
import '../reviews/review_widgets.dart';
import '../wishlist/wishlist_screen.dart';

/// Shared 살까말까 post: products, sender memo, Instagram-style comments.
class SharedBasketDetailScreen extends StatefulWidget {
  const SharedBasketDetailScreen({super.key, required this.basketId});

  final String basketId;

  @override
  State<SharedBasketDetailScreen> createState() =>
      _SharedBasketDetailScreenState();
}

class _SharedBasketDetailScreenState extends State<SharedBasketDetailScreen> {
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  BasketComment? _replyingTo;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final basket = store.sharedBasketById(widget.basketId);
    if (basket == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('공유된 살까말까를 찾을 수 없어요')),
      );
    }

    final isMine = store.sharedBaskets.containsKey(basket.id) ||
        (store.uid != null && basket.fromUid == store.uid);
    final threadId = basket.commentThreadId;
    final canComment = threadId.isNotEmpty && store.isLoggedIn;

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
          basket.title,
          style: DiaryTheme.ui(16, weight: FontWeight.w700),
        ),
        actions: [
          if (isMine)
            IconButton(
              tooltip: '다시 보내기',
              onPressed: () => showSentBasketShareSheet(context, store, basket),
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<BasketComment>>(
              stream: canComment
                  ? store.watchBasketComments(threadId)
                  : Stream.value(const []),
              builder: (context, snap) {
                final comments = snap.data ?? const <BasketComment>[];
                final threads = groupBasketComments(comments);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(
                            basket.fromAvatar.isNotEmpty
                                ? basket.fromAvatar
                                : 'https://api.dicebear.com/7.x/thumbs/png?seed=${Uri.encodeComponent(basket.ownerName)}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                basket.ownerName,
                                style: DiaryTheme.body(
                                  14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                basket.fromHandle.isNotEmpty
                                    ? '${basket.fromHandle}  ·  ${relativeTime(basket.sharedAt)}'
                                    : relativeTime(basket.sharedAt),
                                style: DiaryTheme.body(
                                  12,
                                  color: DiaryColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (basket.memo.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        basket.memo.trim(),
                        style: DiaryTheme.body(15),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '고민 중인 상품 ${basket.items.length}개',
                      style: DiaryTheme.body(13, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (basket.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          '담긴 상품이 없어요',
                          style: DiaryTheme.body(
                            14,
                            color: DiaryColors.inkMuted,
                          ),
                        ),
                      )
                    else
                      for (final p in basket.items) ...[
                        WishlistProductCard(
                          product: p,
                          onOpen: () => context.push('/catalog-product/${p.id}'),
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 8),
                    Text(
                      '댓글 ${comments.length}',
                      style: DiaryTheme.body(13, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (!canComment)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '앱 친구에게 보낸 살까말까에서만 댓글을 달 수 있어요',
                          style: DiaryTheme.body(
                            13,
                            color: DiaryColors.inkMuted,
                          ),
                        ),
                      )
                    else if (snap.connectionState == ConnectionState.waiting &&
                        comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (threads.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '첫 댓글을 남겨 의견을 보태 주세요',
                          style: DiaryTheme.body(
                            13,
                            color: DiaryColors.inkMuted,
                          ),
                        ),
                      )
                    else
                      for (final thread in threads) ...[
                        _CommentTile(
                          comment: thread.root,
                          onReply: () => _startReply(thread.root),
                        ),
                        for (final reply in thread.replies)
                          _CommentTile(
                            comment: reply,
                            indented: true,
                            onReply: () => _startReply(thread.root),
                          ),
                      ],
                  ],
                );
              },
            ),
          ),
          if (canComment) _composer(store, basket),
        ],
      ),
    );
  }

  void _startReply(BasketComment comment) {
    setState(() => _replyingTo = comment);
    _commentFocus.requestFocus();
  }

  Widget _composer(AppStore store, SharedBasket basket) {
    return Material(
      color: DiaryColors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingTo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_replyingTo!.authorName}님에게 답글 달기',
                          style: DiaryTheme.body(
                            12,
                            color: DiaryColors.inkMuted,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _replyingTo = null),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      focusNode: _commentFocus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(store, basket),
                      decoration: InputDecoration(
                        hintText: _replyingTo == null
                            ? '댓글 달기...'
                            : '답글 달기...',
                        filled: true,
                        fillColor: DiaryColors.paper,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _submit(store, basket),
                    icon: const Icon(Icons.send),
                    color: DiaryColors.ink,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AppStore store, SharedBasket basket) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final parentId = _replyingTo?.id ?? '';
    try {
      await store.postBasketComment(
        basket: basket,
        text: text,
        parentId: parentId,
      );
      _commentCtrl.clear();
      setState(() => _replyingTo = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
    this.indented = false,
  });

  final BasketComment comment;
  final VoidCallback onReply;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indented ? 36 : 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: indented ? 14 : 16,
            backgroundImage: NetworkImage(comment.authorAvatar),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: comment.authorName,
                        style: DiaryTheme.body(13, weight: FontWeight.w700),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: comment.text,
                        style: DiaryTheme.body(13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      relativeTime(comment.createdAt),
                      style: DiaryTheme.body(
                        11,
                        color: DiaryColors.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        '답글 달기',
                        style: DiaryTheme.body(
                          11,
                          weight: FontWeight.w700,
                          color: DiaryColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
