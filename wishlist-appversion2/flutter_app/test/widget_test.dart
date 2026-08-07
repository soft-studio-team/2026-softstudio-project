import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:figmadesign/data/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppStore seeds tabs', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.init();
    expect(store.tabs.isNotEmpty, true);
    expect(store.products.isNotEmpty, true);
  });

  test('toggleFollow flips Instagram-style following state', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.init();
    final friend = store.friends.first;
    final before = friend.isFollowing;
    await store.toggleFollow(friend.id);
    expect(store.friendById(friend.id)!.isFollowing, !before);
    await store.toggleFollow(friend.id);
    expect(store.friendById(friend.id)!.isFollowing, before);
  });

  test('createSharedBasketFromSelection builds shareable list', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.init();
    await store.addToBasket(store.products.first);
    final shared = await store.createSharedBasketFromSelection();
    expect(shared.items, isNotEmpty);
    expect(store.sharedBasketById(shared.id), isNotNull);
    expect(store.shareUrlFor(shared), contains('/shared/${shared.id}'));
  });
}
