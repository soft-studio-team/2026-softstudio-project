import 'package:flutter/foundation.dart';

/// 앱 전역 설정.
///
/// 파싱 엔진 서버 주소는 실행 대상에 따라 달라진다:
///  - Android 에뮬레이터는 호스트 PC를 127.0.0.1 이 아니라 10.0.2.2 로 본다.
///  - iOS 시뮬레이터/데스크톱/웹은 127.0.0.1 그대로.
///  - 실기기·다른 서버로 붙일 때는 빌드시 덮어쓴다:
///      flutter run --dart-define=ENGINE_BASE_URL=http://192.168.0.10:8000
class AppConfig {
  static const String _override =
      String.fromEnvironment('ENGINE_BASE_URL', defaultValue: '');

  static String get engineBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Kakao Developers 네이티브 앱 키.
  /// https://developers.kakao.com 에서 앱을 만든 뒤
  /// iOS 번들 ID / Android 패키지명 `com.softstudio.wishlist` 를 등록하고 키를 넣는다.
  ///
  ///     flutter run --dart-define=KAKAO_NATIVE_APP_KEY=여기에키
  ///
  /// 키가 있으면 카톡이 바로 열린다. 없으면 시스템 공유 시트에서 카톡을 고르면 된다.
  static const String kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '',
  );

  static bool get hasKakaoNativeAppKey => kakaoNativeAppKey.isNotEmpty;
}
