import 'package:flutter/foundation.dart';

/// 앱 전역 설정.
///
/// 상품 추출은 단말 WebView만 사용한다. `ENGINE_BASE_URL`은 더 이상
/// 공유 담기 경로에서 호출하지 않는다.
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
}
