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
}
