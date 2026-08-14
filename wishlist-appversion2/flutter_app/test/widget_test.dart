import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:figmadesign/data/app_store.dart';
import 'package:figmadesign/models/models.dart';
import 'package:figmadesign/services/kakao_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppStore init without Firebase stays logged out', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.init();
    expect(store.ready, true);
    expect(store.isLoggedIn, false);
    expect(store.firebaseReady, false);
  });

  test('createSharedBasketFromSelection builds shareable list', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
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

  test('publishReview keeps a local blog-style review', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
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

  test('Kakao share copy includes owner, items, and URL', () {
    final basket = SharedBasket(
      id: 'sb-1',
      title: '살까말까 공유',
      ownerName: '지은',
      items: [
        Product(
          id: 1,
          listId: 'all',
          name: '니트',
          price: 32000,
          image: 'https://example.com/knit.png',
          platform: '테스트몰',
        ),
        Product(
          id: 2,
          listId: 'all',
          name: '슬랙스',
          price: 48000,
          image: 'https://example.com/slacks.png',
          platform: '테스트몰',
        ),
      ],
      createdAt: DateTime(2026, 8, 14),
    );

    expect(KakaoSharePayload.title(basket), '지은 님의 살까말까');
    expect(KakaoSharePayload.description(basket), '니트, 슬랙스');
    expect(
      KakaoSharePayload.text(
        basket: basket,
        url: 'https://wishlist.app/shared/sb-1',
      ),
      contains('https://wishlist.app/shared/sb-1'),
    );
  });
}
