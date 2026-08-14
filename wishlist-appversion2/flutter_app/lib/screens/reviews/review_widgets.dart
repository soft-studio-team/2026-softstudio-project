import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class ReviewPostCard extends StatelessWidget {
  const ReviewPostCard({
    super.key,
    required this.review,
    this.showAuthor = true,
  });

  final ProductReview review;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    return WhiteProductCard(
      onTap: () => context.push('/reviews/${review.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAuthor) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(review.authorAvatar),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorName,
                        style: DiaryTheme.body(13, weight: FontWeight.w700),
                      ),
                      Text(
                        '${review.authorHandle}  ·  ${relativeTime(review.createdAt)}',
                        style: DiaryTheme.body(
                          11,
                          color: DiaryColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (review.productImage.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  review.productImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: DiaryColors.paper,
                    child: const Icon(Icons.image_outlined),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            review.productPlatform,
            style: DiaryTheme.product(11, color: DiaryColors.inkMuted),
          ),
          Text(
            review.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DiaryTheme.product(12, color: DiaryColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Text(
            review.title,
            style: DiaryTheme.body(16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            review.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: DiaryTheme.product(13, color: DiaryColors.ink),
          ),
          if (!showAuthor) ...[
            const SizedBox(height: 8),
            Text(
              relativeTime(review.createdAt),
              style: DiaryTheme.body(11, color: DiaryColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

String relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${t.year}.${t.month}.${t.day}';
}
