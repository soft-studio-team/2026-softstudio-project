# Claude Code 세션 인수인계 — 2026-09-19 (Cowork 중간 검수용)

이 문서는 2026-09-19에 Claude Code CLI로 진행한 두 건의 독립 작업(AI 추출 엔진 서버 포팅,
Firebase Crashlytics 연동)의 맥락과 남은 과제를 정리한 것. Cowork에서 방향 확인/결정이
필요한 항목만 따로 표시해뒀다(**[Cowork 결정 필요]**).

브랜치는 둘 다 `main`에서 새로 딴 것이고, main 자체는 안 건드림.

---

## 1. `feat/ai-extraction-server` — AI 완전 의존 상품 추출 엔진 서버 포팅

**배경**: `engine-ai-prototype/`(이 저장소 밖, 로컬 프로토타입 폴더)에서 골든셋 36개 상품
기준으로 "몰별 규칙 없이 AI가 상품 페이지를 읽어 추출"하는 방식을 검증 완료(완전 일치
21/36=58%, 그라운딩 31/36=86%). 이 작업은 그 검증된 파이프라인(Playwright 렌더링 →
Gemini 텍스트 추출 → 애매하면 스크린샷 폴백)을 실제 HTTP 서버로 감싸는 것.

**상태**: 커밋 2건, **origin에 push 완료**, PR은 아직 안 엶.
- `cf972f6`, `d789116`, `19499e0` (서버 코드 + 부하테스트 + 최종 보고서)
- 파일 위치: `wishlist-appversion2/parsing-engine/`
- 최종 보고서: `wishlist-appversion2/parsing-engine/REPORT_2026-09-19.md` (pytest 결과,
  Fargate/Lambda 소견, 가격 미스매치 12건 원인 분석 — Cowork에서 이 파일을 먼저 읽는 걸 권장)

**핵심 발견**:
1. **⚠️ [Cowork 결정 필요] 저장소 문서 충돌**: `ENGINE_DEVELOPMENT_HANDOFF.md`(마지막
   커밋 8/21)가 "Python 서버 폴백 채택 안 함, WebView 우선"이라고 못 박아뒀는데,
   engine-ai-prototype의 9/18 결정("AI 완전 의존")이 이걸 뒤집는 것처럼 보인다. **이 방향
   전환이 팀 차원에서 실제로 확정된 건지 Cowork에서 정리해줘야 함** — 확정이면
   `ENGINE_DEVELOPMENT_HANDOFF.md`의 예전 서술을 어떻게 정리할지, 아니면 아직 논의 중이면
   이 작업 자체를 계속 진행해도 되는 건지.
2. 골든셋 회귀 없음 확인(완전 일치 23/36, 기준선보다 높음).
3. 응답시간/메모리 실측 완료 — 순차 1건 peak_rss 1.4~1.9GB, 동시 요청 1건당 +400~650MB.
   **ECS/Fargate 쪽으로 기울어진 잠정 소견** (Lambda는 이 프로파일과 안 맞음).
4. 가격 미스매치 12건 전부 원인 규명 — 새로 생긴 버그 없음, 유일한 새 발견은 "에이블리가
   이미지 CDN을 이전한 것으로 보여서 가격뿐 아니라 이미지도 골든셋이 stale할 수 있다"는 것.
5. 렌더링(Playwright)에는 동시 실행 제한이 없다는 설계 허점 발견(코드 미수정, 기록만).

**남은 결정 [Cowork]**:
- 위 1번 문서 충돌 정리
- Gemini 유료 Tier 1의 정확한 RPM/TPM (Google이 콘솔에서만 보여줌 — 사용자 본인 계정 확인 필요, AI가 대신 못 함)
- AWS 배포 최종 형태(ECS/Fargate vs Lambda) — 이번 소견은 로컬 개발 머신 기준이라 실제
  타깃 인스턴스에서 재확인 필요
- DB/캐시 백엔드 선정 (AWS DB 이관 트랙과 조율)
- 앱↔서버 통합 방식 (API 응답 스키마 문서화까지만 완료, 실제 연동은 별도)
- PR을 지금 열지 여부

---

## 2. `feat/crashlytics-integration` — Firebase Crashlytics 연동

**배경**: 베타 배포 전 필수 — 지금 앱은 크래시가 나도 알 방법이 없음.

**상태**: 커밋 1건(`302bea3`), **로컬에만 있고 push 안 함** — 사용자 확인 대기 중.
- 변경 파일: `pubspec.yaml`/`pubspec.lock`/`lib/main.dart`/
  `android/settings.gradle.kts`/`android/app/build.gradle.kts`/`analysis_options.yaml` (6개)

**한 일**:
- `firebase_crashlytics: 5.2.7`로 고정 추가(⚠️ 최신 5.4.0이 아님 — 아래 이유 참고)
- `main.dart`: `FlutterError.onError` + `PlatformDispatcher.instance.onError` 둘 다 등록,
  기존 `isFirebaseConfigured` 게이트 안에서 `Firebase.initializeApp()` 이후에만 등록되게 함
- Android Gradle에 Crashlytics 플러그인 선언(`settings.gradle.kts` version 3.0.8,
  `app/build.gradle.kts`에 적용)

**버전 스큐 이슈(직접 겪고 해결함)**: firebase_crashlytics 5.4.0(최신)은
`firebase_core ^4.14.0`을 요구해서 넣으면 `firebase_core`가 자동으로 4.15.0까지 올라가고,
그러면 기존에 고정돼 있던 `firebase_auth 6.5.7`이 네이티브 레벨에서 안 맞아 컴파일 에러가
난다. `firebase_auth`를 6.7.0으로 올리면 이번엔 그 네이티브 aar이 Kotlin 2.3.0 메타데이터를
요구하는데 이 프로젝트 Kotlin 플러그인은 2.1.0으로 고정돼 있어서 또 실패한다. **5.2.7은
기존 `firebase_core ^4.13.0`과 정확히 맞아서 이 연쇄를 전부 피할 수 있었다** —
`firebase_core`/`firebase_auth` 버전을 전혀 안 건드리고 crashlytics만 추가함(pubspec.lock
diff 16줄).

**검증(전부 실제 실행)**: `flutter pub get` 성공 / `flutter analyze` 1건(기존 이슈,
이번 변경과 무관) / `flutter test` 82개 전부 통과 / `flutter build apk --release` 성공
(60.3MB).

**환경 참고(이 머신에 처음 세팅한 것들, 다음 세션에서 참고)**:
- 이 머신에 Flutter SDK가 전혀 없었음 → `~/development/flutter`에 새로 클론,
  이 프로젝트가 CHANGELOG에 고정해둔 버전(**Flutter 3.44.3 / Dart 3.12.2**)으로 맞춤(최신
  안정 버전 3.47.4는 이 프로젝트의 Gradle 8.12와 최소 버전 요구사항이 안 맞아서 실패했었음)
- Android cmdline-tools 새로 설치 + 라이선스 동의 완료(`~/Android/Sdk`는 이미 있었음 — Android
  Studio로 세팅된 상태였음)
- `flutter config --jdk-dir`을 JBR 21(`~/.jdks/jbr-21.0.11`)로 지정함 — Android Studio 기본
  JDK(25)는 이 프로젝트 Gradle 8.12와 안 맞았음
- `android/local.properties`는 새로 만들었고 gitignore 대상이라 커밋 안 됨(각자 로컬에서
  다시 만들어야 함 — `sdk.dir`/`flutter.sdk` 두 줄)

**남은 것 [사용자 본인만 가능]**:
- Push 여부 결정 (아직 확인 안 됨)
- 실기기에서 강제 크래시 1회 → Firebase 콘솔 Crashlytics 대시보드에 리포트 뜨는지 확인
  (테스트 버튼 코드는 별도로 전달함 — 확인 후 release 빌드에서 제거 권장)

**⚠️ [Cowork 결정 필요] 사용자가 세션 중 제기한 질문**: "어차피 Firebase 버리고 AWS로
이관할 건데 그래도 지금 확인해보는 게 좋나?" — 이번 세션에서는 "크래시 리포팅은 백엔드 DB
이관과 별개의 클라이언트 사이드 문제이고, 베타 기간 크래시 가시성은 나중에 복구할 수 없으니
지금 하는 게 맞다"는 의견을 냈고 그대로 진행했다. **다만 Firebase Auth/Firestore/Storage/
Messaging까지 포함한 전체 이관 계획이 얼마나 구체화됐는지에 따라 우선순위가 달라질 수 있어서,
Cowork에서 그 계획 자체를 한 번 정리해주는 게 좋을 듯하다.**

---

## 두 작업 공통으로 Cowork에서 정리해줬으면 하는 것

1. `ENGINE_DEVELOPMENT_HANDOFF.md`의 8/21 결정과 9/18 결정 간 충돌 — 공식 확정 여부
2. Firebase 전체(Auth/Firestore/Storage/Messaging/Crashlytics) → AWS 이관 계획의 범위와
   시점 — 이게 정리되면 Crashlytics push 여부, 그리고 parsing-engine의 DB/캐시 백엔드
   선정 둘 다에 영향을 줌
3. 두 브랜치 다 PR을 열지, 언제 열지
