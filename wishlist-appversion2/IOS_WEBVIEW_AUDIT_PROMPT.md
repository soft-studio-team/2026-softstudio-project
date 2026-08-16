# iOS WebView 감사 — 다른 작업자용 시작 프롬프트

아래 블록을 새 Cursor 대화에 그대로 붙여 넣으면 됩니다.

---

```
wishkit iOS WebView 상품 추출 감사를 진행해. Android 실기기 64개 감사는 이미 끝났고, 같은 URL을 iPhone 또는 iOS 시뮬레이터에서 재현하는 것이 목적이다.

## 저장소
- GitHub: soft-studio-team/2026-softstudio-project
- 브랜치: feat/webview-scraper-stabilize
- 기준 커밋: 820a8c1 (docs: record the completed 64-mall phone WebView audit)
- Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28
- 앱 경로: wishlist-appversion2/flutter_app
- 패키지/표시 이름: com.softstudio.wishlist / wishkit
- 감사 러너: integration_test/webview_all_malls_audit_test.dart
- 인수인계: wishlist-appversion2/ENGINE_DEVELOPMENT_HANDOFF.md 섹션 0.3
- 한국어로 답하고, 끝나면 커밋·푸시·PR #28 갱신. 절대 머지하지 말 것.

## 금지
- git reset --hard, git checkout --, git clean 사용 금지
- 로그인, 결제, 사용자 데이터 삭제, 장바구니 삭제 금지
- 실기기 앱을 uninstall 하지 말 것. flutter test 기본값은 종료 시 앱을 지운다. 반드시 --no-uninstall
- 관리 쇼핑몰 전용 가격 규칙이 실패하면 JSON-LD/OG/DOM 범용 가격으로 우회하지 말 것. 가격은 null
- 고정 대기 시간만 늘리지 말 것
- SuperDisplay를 켜지 말 것 (Windows 환경 이야기. Mac에서는 해당 없음)

## 시작 절차
1. 이 브랜치를 checkout / pull 한다. origin/feat/webview-scraper-stabilize @ 820a8c1 이상.
2. 작업 루트를 저장소 루트로 옮긴다.
3. flutter devices 로 iPhone 실기기 또는 시뮬레이터 ID를 확인한다. iOS 기기가 없으면 중단하고 그 사실을 보고한다.
4. cd wishlist-appversion2/flutter_app
5. 단위 테스트만 먼저:
   flutter test test/product_extract_js_sync_test.dart test/webview_scraper_result_test.dart
6. 감사 전에 JS가 도는지 확인한다. WEBVIEW_JS_PROBE 가 2 가 아니면 몰 감사를 가격 통과로 보지 말 것.

## 감사 명령 (iOS 기기 ID를 DEVICE_ID로 바꿔)
반드시 --no-uninstall. 한 번에 64개를 돌리지 말고 Android와 같이 분할한다.

7개 스모크 (미쏘, 핫핑, SSG, 오호라, 파르티멘토, Reformation, 올리브영):
flutter test integration_test/webview_all_malls_audit_test.dart -d DEVICE_ID --no-uninstall --dart-define=WEBVIEW_AUDIT_ONLY=14,22,24,46,49,53,55

1~3 (쿠팡, 네이버, 11번가):
flutter test integration_test/webview_all_malls_audit_test.dart -d DEVICE_ID --no-uninstall --dart-define=WEBVIEW_AUDIT_START=0 --dart-define=WEBVIEW_AUDIT_END=3

그다음 4~20, 20~38, 38~51, 51~64 처럼 15개 안팎으로 나눈다.
노이아고(38, START=37 END=38)에서 Android는 긴 배치 중 러너가 끊긴 적이 있으므로 의심되면 단독 실행.

시작 로그 WEBVIEW_JS_PROBE 2 와 각 줄 WEBVIEW_AUDIT_RESULT JSON을 저장한다.

## 검사 후 일반 앱 복구
flutter test 는 검사 전용 엔트리를 설치한다. 끝나면 일반 앱을 덮어씌운다. uninstall 하지 말 것.
flutter build ios --debug
flutter install -d DEVICE_ID --no-uninstall
또는 Xcode에서 Runner를 일반 Debug로 설치. 사용자 데이터 삭제 금지.

## Android 실기기 기준 (비교용, iOS 통과로 베끼지 말 것)
기기: Galaxy SM-S938N / Android 16. JS probe=2.
PASS 46, EXPECTED_ABSTAIN 5, BLOCKED 2, PARTIAL_MEDIA 1, NO_RESULT 1, PARTIAL_NO_PRICE 9.

- BLOCKED: 쿠팡, H&M (Access Denied)
- EXPECTED_ABSTAIN: 네이버 쇼핑, Gap, LF몰, NUGU, SHEIN
- PARTIAL_MEDIA: 반스 (가격·이미지 있음, 이름 없음)
- NO_RESULT: 리바이스 (loading_timeout)
- PARTIAL_NO_PRICE: 현대Hmall, 마리떼, 오호라, 육육걸즈, 파르티멘토, Reformation, 나이키(not_product_page), ZARA, 이랜드몰(not_product_page)
- 11번가: hang 없이 PASS (json-ld, 비관리 몰)
- 노이아고: 단독 재실행 PASS 219000
- SSG·올리브영: Android에서는 전용 어댑터 PASS. iOS에서 차단 화면이면 BLOCKED로 적고 우회하지 말 것.

PASS로 보고하려면 이름·이미지·양수 가격이 있어야 한다. 관리 몰은 source.price 가 site-adapter 여야 한다. 전용 규칙 실패로 가격이 null이면 PARTIAL_NO_PRICE / price_ambiguous 가 맞다.

## 보고
CHANGELOG와 ENGINE_DEVELOPMENT_HANDOFF.md에 iOS 결과를 남긴다. Android와 다른 분류는 몰 이름·failureReason·finalUrl을 명시한다. 가격 미검증이면 통과로 쓰지 말 것.
커밋·푸시 후 PR #28을 draft로 갱신하고 머지하지 말 것.
```

---

## 한 줄 복붙용 브랜치

```bash
git fetch origin feat/webview-scraper-stabilize
git checkout feat/webview-scraper-stabilize
git pull --ff-only origin feat/webview-scraper-stabilize
```
