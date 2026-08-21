import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:figmadesign/data/app_store.dart';
import 'package:figmadesign/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppStore init without Firebase stays logged out', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(firebaseConfigured: false);
    await store.init();
    expect(store.ready, true);
    expect(store.isLoggedIn, false);
    expect(store.firebaseReady, false);
  });

  test('createSharedBasketFromSelection builds shareable list', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(firebaseConfigured: false);
    await store.init();
    store.products = [
      Product(
        id: 1,
        listId: 'summer',
        name: '테스트 상품',
        price: 1000,
        image: 'https://example.com/a.png',
        platform: '테스트',
      ),
    ];
    await store.addToBasket(store.products.first);
    final shared = await store.createSharedBasketFromSelection(
      memo: '살까 말까 고민 중',
    );
    expect(shared.items, isNotEmpty);
    expect(shared.memo, '살까 말까 고민 중');
    expect(shared.threadId, shared.id);
    expect(store.sharedBasketById(shared.id), isNotNull);
  });

  test('reorderTabs uses adjusted onReorderItem destination index', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(firebaseConfigured: false);
    await store.init();
    store.tabs = [
      WishlistTab(id: 'all', name: '전체', isPublic: true),
      WishlistTab(id: 'a', name: 'A', isPublic: false),
      WishlistTab(id: 'b', name: 'B', isPublic: false),
      WishlistTab(id: 'c', name: 'C', isPublic: false),
    ];

    await store.reorderTabs(0, 2);

    expect(store.tabs.map((tab) => tab.id), ['all', 'b', 'c', 'a']);
  });

  test('publishReview keeps a local blog-style review', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(firebaseConfigured: false);
    await store.init();
    store.currentUser = AppUser(
      uid: 'user-1',
      name: '나',
      handle: '@me',
      avatarUrl: 'https://example.com/me.png',
    );
    store.products = [
      Product(
        id: 7,
        listId: 'all',
        name: '테스트 니트',
        price: 32000,
        image: 'https://example.com/knit.png',
        platform: '테스트몰',
      ),
    ];

    final review = await store.publishReview(
      product: store.products.first,
      title: '보풀은 나지만 따뜻해요',
      body: '일주일 입어본 솔직 후기입니다.',
      mood: 5,
    );

    expect(review.title, '보풀은 나지만 따뜻해요');
    expect(store.myReviews, hasLength(1));
    expect(store.myReviewForProduct(7)?.body, contains('솔직 후기'));
    expect(store.reviewFeed.first.id, review.id);
    expect(review.mood, 5);
    expect(review.imageUrls, isEmpty);
  });

  test('Product json round-trips list privacy', () {
    final product = Product(
      id: 3,
      listId: 'summer',
      name: '선글라스',
      price: 20000,
      image: 'https://example.com/s.png',
      platform: '테스트',
      isPublic: true,
    );
    final decoded = Product.fromJson(product.toJson());
    expect(decoded.isPublic, true);
    expect(
      Product.fromJson({
        'id': 1,
        'listId': 'secret',
        'name': '비공개 상품',
        'price': 1,
      }).isPublic,
      false,
    );
  });

  test('AppNotification parses follow basket review and list types', () {
    AppNotification n(String type) => AppNotification.fromJson({
      'id': 'n-$type',
      'type': type,
      'fromUid': 'u1',
      'fromName': '지은',
      'fromHandle': '@jieun',
      'fromAvatar': 'https://example.com/a.png',
      'message': '알림',
      'relatedId': 'x',
      'read': false,
      'createdAt': '2026-08-15T12:00:00.000',
    });

    expect(n('follow').type, AppNotificationType.follow);
    expect(n('basket').type, AppNotificationType.basket);
    expect(n('review').type, AppNotificationType.review);
    expect(n('list').type, AppNotificationType.list);
    expect(n('comment').type, AppNotificationType.comment);
  });

  test('SharedBasket json keeps share memo and thread id', () {
    final basket = SharedBasket(
      id: 'sb-1',
      title: '지은의 살까말까',
      ownerName: '지은',
      createdAt: DateTime(2026, 8, 17),
      items: const [],
      recipientUids: const ['u2'],
      memo: '지금 사면 충동인가 싶어요',
      threadId: 'sb-1',
    );
    final decoded = SharedBasket.fromJson(basket.toJson());
    expect(decoded.memo, '지금 사면 충동인가 싶어요');
    expect(decoded.threadId, 'sb-1');
    expect(decoded.commentThreadId, 'sb-1');
  });

  test('groupBasketComments nests one level of replies', () {
    final root = BasketComment(
      id: 'c1',
      threadId: 't1',
      authorUid: 'u2',
      authorName: '민수',
      authorHandle: '@min',
      authorAvatar: 'https://example.com/a.png',
      text: '그냥 사',
      createdAt: DateTime(2026, 8, 17, 12),
    );
    final reply = BasketComment(
      id: 'c2',
      threadId: 't1',
      parentId: 'c1',
      authorUid: 'u1',
      authorName: '지은',
      authorHandle: '@jieun',
      authorAvatar: 'https://example.com/b.png',
      text: '진짜?',
      createdAt: DateTime(2026, 8, 17, 13),
    );
    final nested = BasketComment(
      id: 'c3',
      threadId: 't1',
      parentId: 'c2',
      authorUid: 'u2',
      authorName: '민수',
      authorHandle: '@min',
      authorAvatar: 'https://example.com/a.png',
      text: '응',
      createdAt: DateTime(2026, 8, 17, 14),
    );
    expect(flattenCommentParentId('c2', [root, reply]), 'c1');
    expect(flattenCommentParentId('c1', [root, reply]), 'c1');
    expect(flattenCommentParentId('', [root]), '');

    final grouped = groupBasketComments([root, reply, nested]);
    expect(grouped, hasLength(1));
    expect(grouped.first.root.id, 'c1');
    expect(grouped.first.replies.map((c) => c.id), ['c2']);
  });

  test('salkamalka feed does not show another account sent basket as mine', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(firebaseConfigured: false);
    await store.init();
    store.currentUser = AppUser(
      uid: 'account-b',
      name: '지은B',
      handle: '@b',
      avatarUrl: 'https://example.com/b.png',
    );
    store.sharedBaskets['sb-from-a'] = SharedBasket(
      id: 'sb-from-a',
      title: '지은A의 살까말까',
      ownerName: '지은A',
      fromUid: 'account-a',
      createdAt: DateTime(2026, 8, 17),
      items: const [],
      recipientUids: const ['account-b'],
      recipientNames: const ['지은B'],
      channels: const [SharedChannel.friends],
    );
    store.receivedBaskets = [
      SharedBasket(
        id: 'recv-1',
        title: '지은A의 살까말까',
        ownerName: '지은A',
        fromUid: 'account-a',
        createdAt: DateTime(2026, 8, 17),
        items: const [],
        channels: const [SharedChannel.friends],
        threadId: 'sb-from-a',
      ),
    ];

    final feed = store.salkamalkaFeed;
    expect(feed, hasLength(1));
    expect(feed.first.isMine, isFalse);
    expect(feed.first.basket.fromUid, 'account-a');
  });
}
