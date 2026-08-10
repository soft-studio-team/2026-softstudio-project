# 변경 이력 (CHANGELOG)

이 문서는 최초 공유본 대비 **무엇을 왜 바꿨는지**를 기록합니다.
각 항목은 두 가지 설명을 함께 답니다:

- 🟢 **쉬운 설명** — 코드를 안 봐도 이해되는 설명 (팀 공유·발표용)
- 🔧 **기술 설명** — 파일·구체적 변경 (구현 확인용)

> 앞으로 코드가 바뀔 때마다 이 문서 맨 위에 같은 형식으로 계속 추가합니다.

---

## 2026-08-10 — WebView Tier 2.5 를 최신 main(인증·Firebase·리브랜딩) 위로 재통합

🟢 **쉬운 설명**
그동안 팀이 로그인·이메일 인증(Firebase)·앱 리브랜딩(wishkit)·seed 제거를 크게
진행해서, 옛 스냅샷 기준으로 만든 WebView Tier 2.5 기능을 **최신 main 위에 다시
얹었습니다.** 기능 동작은 그대로이고, 팀의 Firebase 설정·리브랜딩과 충돌 없이
공존하도록 병합했습니다. 앱은 `flutter analyze` 통과 상태입니다.

🔧 **기술 설명**
- 최신 `origin/main`(21커밋 진행분: Firebase Auth/Firestore, `com.softstudio.wishlist`
  리브랜딩, seed 제거)에서 새 브랜치 `feat/webview-tier-2.5` 를 만들어 재적용.
- 기능 파일은 main 이 안 건드려 깨끗이 적용: `parsing_bridge.dart`,
  `share_intake_screen.dart`, 신규 `config.dart`·`product_extract_js.dart`·
  `webview_scraper.dart`.
- `models.dart` 의 `ParsedProductInfo` 에 `onDeviceExtracted`·`mergeOnDevice` 추가
  (main 은 `Product.fromJson`·`AppUser` 만 바꿔 충돌 없음).
- 빌드 병합: main 의 google-services 플러그인·리브랜딩을 유지한 채 AGP 8.10.1,
  Java/Kotlin 17, cleartext 허용, `flutter_inappwebview` 추가,
  `receive_sharing_intent` 1.8.1 고정을 그 위에 얹음.
- 이전 `fix/build-config` 브랜치는 이 브랜치로 대체됨(빌드 변경은 WebView 의존성과
  분리하면 의미가 없어, 기능과 한 브랜치로 합침).

---

## 2026-08-07 — README에 개발 환경/버전 정보 추가

🟢 **쉬운 설명**
팀원이 환경을 맞출 때 참고하도록, 이 프로젝트가 쓰는 Flutter·Dart·Python·안드로이드
빌드 툴의 버전을 README에 표로 정리했습니다. 초기본에서 바뀐 항목은 ★로 표시했습니다.

🔧 **기술 설명**
- `README.md`에 "개발 환경 / 버전 정보" 섹션 추가: Flutter 3.44.3 / Dart 3.12.2,
  주요 pub 패키지 resolved 버전, Python 3.14.6 + 엔진 requirements, Android
  툴체인(Gradle 8.12 / AGP 8.10.1 / Kotlin 2.1.0 / compileSdk 36 / minSdk 24 /
  JVM target 17). CHANGELOG 링크도 함께 명시.

---

## 2026-08-07 — 엔진 빠른 테스트 스크립트 추가

🟢 **쉬운 설명**
엔진이 잘 도는지 확인하려고 매번 무거운 에뮬레이터를 켤 필요 없이, **서버에 URL만
던져 결과를 표로 보는 스크립트**를 추가했습니다. 어떤 몰이 몇 번 티어로 처리되는지
(자동으로 가격이 나오는지, 사용자 입력이 필요한지)를 몇 초 만에 확인할 수 있습니다.

🔧 **기술 설명**
- `parsing-engine/server/scripts/try_engine.py` 신규. 서버 `POST /parse` 를 여러 URL로
  호출해 `resolved_tier`·가격·`missing_fields`·제목을 표로 출력. 인자로 URL을 주면
  그 URL들을, 없으면 기본 샘플(29CM·SSG·무신사·무인양품·올리브영)을 테스트.
  Windows 콘솔 한글 깨짐 방지로 stdout을 UTF-8로 재설정. 서버 엔진(Tier 1/2/3)만
  검증하며 앱 Tier 2.5(단말 WebView)는 포함하지 않음.
- 사용: `python scripts/try_engine.py [url ...]` (서버가 8000 포트에 떠 있어야 함)

---

## 2026-08-07 — 온디바이스 WebView Tier 2.5 병합 + Android 빌드 정상화

두 갈래의 작업입니다. **A**가 이번의 본 목적(엔진 전략 병합)이고,
**B**는 그걸 실제 안드로이드에서 돌리기 위해 필요했던 기존 환경 문제 수정입니다.

### A. 단말 WebView 보완 계층 추가 (Tier 2.5)

🟢 **쉬운 설명**
기존 파싱 엔진(서버)은 약관 준수를 위해 "공식 API → 표준 메타데이터"만 씁니다.
그래서 쿠팡·네이버·무신사·올리브영·자라·무인양품처럼 서버가 가격을 못 얻는 몰이 많고,
그런 상품은 사용자가 가격을 직접 입력해야 했습니다.

이번에 **앱(사용자 폰) 쪽에 안 보이는 브라우저(WebView)를 한 겹 추가**했습니다.
서버가 가격을 못 채운 상품만, 앱이 그 상품 페이지를 몰래 한 번 열어 가격·이름·사진을
자동으로 뽑아 채웁니다. 사용자 본인 폰·본인 세션으로 자기가 저장하려는 상품 1건을 여는
것이라, 서버가 대량으로 긁는 것과 달리 차단·약관 리스크가 훨씬 낮습니다.

- 서버가 이미 가격을 줬으면 → WebView는 **안 돕니다** (낭비 없음)
- WebView가 실패해도 → 원래 서버 결과로 그대로 저장 (**저장은 절대 안 깨짐**)
- WebView가 없는 환경(웹·윈도우)에서는 → 자동으로 건너뜀 (기존 동작 유지)
- **팀 Python 엔진은 한 줄도 안 바꿨습니다.**

수집 우선순위: `Tier1 공식 API → Tier2 서버 메타데이터 → [신규] Tier2.5 단말 WebView → Tier3 사용자 입력`

🔧 **기술 설명**

| 파일 | 상태 | 변경 |
|---|---|---|
| `flutter_app/lib/services/product_extract_js.dart` | 신규 | WebView 안에서 `evaluateJavascript`로 실행되는 추출 스크립트. JSON-LD(`Product` + **`ProductGroup`/`hasVariant`** — 서버 파서가 놓치는 자라·유니클로·나이키 커버), Open Graph, 범용 DOM(h1·"12,345원"/"₩12,345") 순으로 추출. 자라 원화 ÷100 버그 보정 포함. 결과는 JSON 문자열로 반환. |
| `flutter_app/lib/services/webview_scraper.dart` | 신규 | `HeadlessInAppWebView`로 페이지를 백그라운드 로드 → 가격이 보일 때까지 1초 간격 폴링(최대 12초) → 차단/빈 페이지면 몰 홈을 1회 거친 뒤 재시도(쿠팡 대응). `TargetPlatform.android/iOS`에서만 동작(`isSupported`). |
| `flutter_app/lib/services/parsing_bridge.dart` | 수정 | `_fillOnDevice()` 추가. 서버 응답의 `price<=0` 또는 `missing_fields`에 price가 있을 때만 `WebViewScraper.extract()` 호출 후 병합. `baseUrl` 기본값을 `AppConfig.engineBaseUrl`로 교체(B 참조). |
| `flutter_app/lib/models/models.dart` | 수정 | `ParsedProductInfo`에 `onDeviceExtracted` 필드와 `mergeOnDevice()` 추가. 서버가 채운 값은 유지하고 비어 있는 칸(가격·이름·사진)만 단말 추출값으로 채운 뒤 `missing_fields` 재계산. |
| `flutter_app/lib/screens/share/share_intake_screen.dart` | 수정 | 결과 카드 배지에 `onDeviceExtracted`면 "Tier 2.5 · 단말에서 추출" 표시. `_save()`에서 플래그 보존. |

의존성: `flutter_app/pubspec.yaml`에 `flutter_inappwebview: ^6.1.5` 추가.

### B. Android 빌드·실행 정상화 (기존 환경 문제)

🟢 **쉬운 설명**
안드로이드에서 앱을 처음 빌드하려니 여러 곳에서 막혔는데, **이번 기능 때문이 아니라
프로젝트의 안드로이드 설정이 최신 라이브러리와 안 맞아서** 생긴 문제였습니다(팀도 언젠가
겪었을 것). 순서대로 다 뚫었고, 덤으로 **원래 있던 버그(안드로이드에서 서버에 접속이
안 되던 문제)**까지 같이 고쳤습니다. 이제 `flutter run`으로 바로 실행됩니다.

🔧 **기술 설명**

| 파일 | 변경 | 이유 |
|---|---|---|
| `flutter_app/lib/config.dart` | 신규. 서버 주소를 플랫폼별로 결정: Android 에뮬레이터 → `http://10.0.2.2:8000`, 그 외 → `127.0.0.1:8000`, `--dart-define=ENGINE_BASE_URL=...`로 덮어쓰기 가능. | **기존 버그**: `parsing_bridge.dart`에 `127.0.0.1` 하드코딩 → 안드로이드에서 호스트 서버에 접속 불가였음. |
| `.../android/app/src/main/AndroidManifest.xml` | `<application>`에 `android:usesCleartextTraffic="true"` 추가. | Android 9+는 평문 HTTP를 기본 차단 → `http://10.0.2.2:8000` 서버 호출이 막혀서. |
| `flutter_app/pubspec.yaml` | `receive_sharing_intent`를 `^1.8.1` → **`1.8.1` 고정**. | 1.9.0이 아직 stable로 배포되지 않은 `compileSdk 37`을 요구해 빌드 불가. 1.8.1은 34 요구. |
| `.../android/settings.gradle.kts` | Android Gradle Plugin `8.7.3` → **`8.10.1`**. | 새로 들어온 `androidx.core:1.17.0`(WebView 의존성)이 AGP 8.9.1+ 요구. Gradle 8.12와 호환되는 최신 라인이 8.10. |
| `.../android/build.gradle.kts` (루트) | `subprojects`에 모든 플러그인 모듈의 Java·Kotlin JVM 타겟을 17로 통일하는 블록 추가(`plugins.withId("com.android.library")` + `KotlinCompile` `configureEach`). | AGP 8.10의 JVM-target 검증이, 구형 플러그인의 Java 1.8과 JBR 21의 Kotlin 타겟 불일치를 오류로 처리. |
| `.../android/app/build.gradle.kts` | `:app`의 Java·Kotlin 타겟 `11` → **`17`**. | 위와 같은 정합성(루트에서 `:app`은 이미 평가 완료라 못 바꿔 자체 파일에서 조정). |

### 검증

- `flutter analyze` — 신규/수정 코드 오류·경고 0 (기존 deprecation 2건만 잔존)
- `flutter build apk --debug` — **성공** (`build/app/outputs/flutter-apk/app-debug.apk`)
- ⚠️ Tier 2.5 기능은 **Android/iOS에서만** 동작 — 웹/윈도우 실행으로는 확인 불가.
  실행: 에뮬레이터(`Pixel_10`) → 엔진 서버 → `flutter run -d emulator-5554`
