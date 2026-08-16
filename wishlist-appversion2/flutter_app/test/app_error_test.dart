import 'package:figmadesign/models/models.dart';
import 'package:figmadesign/services/app_error.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps short Korean store messages', () {
    expect(
      userFacingMessage(Exception('이메일과 비밀번호를 입력해 주세요.')),
      '이메일과 비밀번호를 입력해 주세요.',
    );
  });

  test('hides raw exception text', () {
    expect(
      userFacingMessage(StateError('Bad state: Null check operator')),
      '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.',
    );
  });

  test('maps auth and firestore failures to user copy', () {
    expect(
      userFacingMessage(
        FirebaseAuthException(code: 'invalid-credential'),
      ),
      '이메일 또는 비밀번호가 맞지 않아요.',
    );
    expect(
      userFacingMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      '권한이 없어 이 작업을 할 수 없어요.',
    );
  });

  test('placeholder parse is not treated as a real product', () {
    final info = ParsedProductInfo(
      name: '공유된 상품',
      price: 0,
      platform: '쇼핑몰',
      image: '',
      productUrl: 'https://example.com/item',
      missingFields: const ['title', 'price', 'image_url'],
      resolvedTier: 3,
      engineUsed: false,
    );
    expect(info.isPlaceholder, isTrue);
  });
}
