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
    final shared = await store.createSharedBasketFromSelection();
    expect(shared.items, isNotEmpty);
    expect(store.sharedBasketById(shared.id), isNotNull);
    expect(store.shareUrlFor(shared), contains('/shared/${shared.id}'));
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

  test('unknown product id is missing, not replaced with another item', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(firebaseConfigured: false);
    await store.init();
    store.products = [
      Product(
        id: 1,
        listId: 'all',
        name: '첫 상품',
        price: 1000,
        image: 'https://example.com/a.png',
        platform: '테스트',
      ),
    ];
    expect(store.findCatalogProduct(1)?.name, '첫 상품');
    expect(store.findCatalogProduct(999), isNull);
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
  });
}
