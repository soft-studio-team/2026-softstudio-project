# Tab S7 실페이지 대조 — 이어서 하는 사람용

2026-08-18 저녁 기준. Draft PR #28. **머지하지 말 것.**

새 Cursor 대화에는 아래 「시작 프롬프트」를 그대로 붙여 넣으면 된다. 이 파일의 나머지와 `ENGINE_DEVELOPMENT_HANDOFF.md` §0.13을 먼저 읽는다.

---

## 시작 프롬프트

```
wishkit Tab S7 실페이지 대조를 이어서 해. 엔진 코드를 고치지 말고, 아직 안 끝난 몰만 1몰씩 비교한다.

## 저장소
- GitHub: soft-studio-team/2026-softstudio-project
- 브랜치: feat/webview-scraper-stabilize
- 최신을 pull 한다. 이 파일: wishlist-appversion2/TAB_S7_LIVE_COMPARE_CONTINUATION.md
- 인수인계: wishlist-appversion2/ENGINE_DEVELOPMENT_HANDOFF.md 섹션 0.13
- Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28
- 앱 경로: wishlist-appversion2/flutter_app
- 패키지: com.softstudio.wishlist
- 한국어로 답하고, 끝나면 커밋·푸시·PR #28 코멘트. 절대 머지하지 말 것.

## 기기
- Galaxy Tab S7 SM-T870 / 시리얼 R54RB01SMVB / Android 13
- ADB: C:\Users\tingo\AppData\Local\Android\sdk\platform-tools\adb.exe
- SuperDisplay 켜지 말 것. 앱 uninstall 금지. flutter test는 반드시 --no-uninstall

## 지금 할 일
1. 코드그라피 2·3번 재시도 (1번은 PRICE 완료)
2. 남은 14몰을 1몰씩 대조: 후아유, Aritzia, 마하그리드, 비바스튜디오, 아모멘토, 앤더슨벨, 예일, 위드윤, 패션플러스, 프롬비기닝, 나이키, CJ온스타일, 4910, SSF샵
3. 전부 끝나면 flutter build apk --debug 후 adb install -r 로 검사 APK를 기기에 남긴다 (uninstall 금지)
4. ENGINE_DEVELOPMENT_HANDOFF.md §0.13, CHANGELOG, 이 파일을 갱신하고 커밋·푸시·PR 코멘트

## 금지
- git reset --hard, git checkout --, git clean
- 로그인·결제·사용자 데이터 삭제·장바구니 삭제
- 앱 uninstall. flutter test 기본값은 종료 시 앱을 지운다
- 리바이스 대기 시간 늘리기
- 관리 몰 가격이 애매할 때 JSON-LD/OG/DOM 범용 가격 우회. 가격은 null
- 대형 배치(3몰 이상) 한 번에 돌리기. 설치 직후 hang이 잦다
- 엔진 개선(W컨셉 og:title, Cafe24 가격 등)은 대조가 끝난 다음
```

---

## 이게 무슨 작업인가

자동 채움 50몰에 대해 **실제 상품 페이지 정답**(카탈로그)과 **탭 WebView 엔진 추출값**을 비교한다. App Store/Firebase에 저장하지 않는다.

- 카탈로그: `flutter_app/integration_test/live_field_compare_catalog.dart`
- 러너: `flutter_app/integration_test/live_field_compare_test.dart`
- 비교 규칙: `flutter_app/lib/services/live_field_compare.dart`
- 정답 JSON 원본: `audit-logs/live-answers-2026-08-18.json` (카탈로그 생성용. 엔진 JS로 채우지 않음)

분류 이름은 **맞은 필드가 아니라 틀린 필드**다.

| 라벨 | 의미 |
|---|---|
| `MATCH` | 이름·가격·사진 모두 정답과 같음 |
| `PRICE` | 이름·사진은 맞고 가격만 다름 (자주 `enginePrice: null` + `price_ambiguous`) |
| `NAME` | 이름만 다름 |
| `IMAGE` | 사진만 다름 |
| `PRICE_IMAGE` / `NAME_PRICE` / `NAME_PRICE_IMAGE` | 해당 필드들이 틀림 |
| `NO_RESULT` | 엔진이 결과를 못 냄 |
| `ENGINE_ONLY` | 카탈로그 live가 없음 |

---

## 환경·명령

작업 디렉터리:

```
cd C:\Users\tingo\Dev\2026-softstudio-project\wishlist-appversion2\flutter_app
```

한 몰만 돌리기 (권장):

```
adb = C:\Users\tingo\AppData\Local\Android\sdk\platform-tools\adb.exe
& $adb -s R54RB01SMVB shell settings put global stay_on_while_plugged_in 7
& $adb -s R54RB01SMVB shell input keyevent 82
& $adb -s R54RB01SMVB shell am force-stop com.softstudio.wishlist
flutter test integration_test/live_field_compare_test.dart -d R54RB01SMVB --no-uninstall --dart-define=LIVE_COMPARE_MALLS=후아유
```

성공 로그는 `LIVE_COMPARE_RESULT` JSON 한 줄이다. 상품 3개가 나오고 `All tests passed`면 그 몰은 끝.

배치 사이·hang 뒤:

```
& $adb kill-server
Start-Sleep 2
& $adb start-server
& $adb wait-for-device
& $adb devices -l
```

`error: closed` / `device not found` / `Android null (API null)` 이면 위 리셋 후 1몰만 다시.

Gradle `Could not copy ... app-debug.apk` 또는 `kernel_blob.bin` 잠금이면 `java`/`dart` 프로세스를 끄고 `flutter build apk --debug`를 한 뒤 테스트를 재개한다. 대형 배치 스크립트(`tools/run_remaining_compare.py`)는 stdout 파이프 버퍼로 hang 나서 쓰지 말 것.

검사 후 앱을 지우지 않는다. 전부 끝나면:

```
flutter build apk --debug
& $adb -s R54RB01SMVB install -r build\app\outputs\flutter-apk\app-debug.apk
```

---

## 2026-08-18 저녁 재실행 현황 (이 세션이 기준)

카탈로그는 50몰, 정답 3개씩(낫포유만 2개, hang URL 290 제외). 탑텐·무인양품 live 가격은 브라우저 재확인 후 수정됨(커밋 `8383ded`).

이번 재실행은 전체 50몰을 한 번에 돌리다가 미쏘에서 hang이 나서, **1~2몰씩** 다시 돌린 결과다. 예전 터미널 `733*.txt`는 **다른 상품 URL**일 수 있으니 이번 진행의 근거로 쓰지 말 것. 근거는 `711*.txt`·`712*.txt`의 `LIVE_COMPARE_RESULT`.

### 3/3 완료 (낫포유는 2/2)

| 몰 | 분류 |
|---|---|
| 11번가 | MATCH, IMAGE, PRICE_IMAGE |
| 무신사 | MATCH 3 |
| W컨셉 | NAME_PRICE, NAME, NAME (엔진 이름 `[W CONCEPT]`) |
| 29CM | MATCH 3 |
| FILA | MATCH 3 |
| 하고 | IMAGE 3 (`og` 플레이스홀더 가능성) |
| 룩핀 | IMAGE 3 (엔진 이미지 `og_tag_lookpin_web.jpg`) |
| 탑텐 | MATCH 3 |
| 무인양품 | MATCH 3 |
| 현대Hmall | MATCH 3 |
| 롯데온 | PRICE 3 |
| 미쏘 | MATCH, PRICE, PRICE |
| 데일리쥬 | MATCH, MATCH, PRICE |
| 리 | PRICE 3 (~90% 회원가) |
| 필루미네이트 | PRICE 3 (~90%) |
| 어반스터프 | PRICE 3 (~90%) |
| 낫포유 | PRICE 2 (`price_ambiguous`) |
| 인사일런스 | PRICE 3 |
| 파브레가 | PRICE 3 (~90%) |
| 핫핑 | NAME 3 (HTML `<b>`/`<br>`) |
| 유니클로 | MATCH 3 |
| SSG | PRICE_IMAGE 3 |
| 더현대Hi | PRICE 3 (live 가격 이상 여부 재확인 가치 있음) |
| 에이블리 | NAME_PRICE_IMAGE 3 (`loading_timeout`) |
| 지그재그 | PRICE, PRICE, MATCH |
| KREAM | PRICE 3 |
| 게스 | MATCH 3 |
| 반스 | MATCH 3 |
| 커버낫 | PRICE, MATCH, MATCH |
| 노이아고 | PRICE 3 (엔진 가격 null, `price_ambiguous`) |
| 립합 | PRICE 3 (`price_ambiguous`) |
| 올리브영 | PRICE, PRICE, MATCH |
| 퀸잇 | MATCH 3 |
| 브랜디 | MATCH 3 |
| 이랜드몰 | MATCH, IMAGE, MATCH |

### 부분

- **코드그라피**: 1번만 PRICE (`price_ambiguous`, Cafe24). 2번 `product_no=8260`에서 hang. **여기서부터 재개.**

### 아직 없음 (14몰)

후아유, Aritzia, 마하그리드, 비바스튜디오, 아모멘토, 앤더슨벨, 예일, 위드윤, 패션플러스, 프롬비기닝, 나이키, CJ온스타일, 4910, SSF샵

카탈로그 URL은 `live_field_compare_catalog.dart`에 있다. 예: 후아유 `whoau.com/product/detail.html?product_no=4457` 등.

---

## 알려진 함정

1. **3몰 이상 연속**이면 APK 설치 직후 로그가 멈추는 일이 많다. 1몰씩.
2. **유니클로·반스**는 대형 배치에서 hang, 단독이면 MATCH 3.
3. **립합 3번**도 hang이 났으나 단독 재시도로 PRICE 3 완료.
4. ADB는 Gradle 빌드(~40–200초) 동안 USB가 끊길 수 있다. 빌드 후 `device not found`면 kill-server 후 같은 명령을 다시.
5. 코드그라피 재시도 직후 `compressDebugAssets` / `kernel_blob.bin` 잠금이 났다. java/dart를 끄고 `flutter build apk --debug`까지는 성공해 둔 상태(2026-08-18 20:59).
6. PowerShell에 한글 몰 이름을 넣은 `.ps1`은 인코딩이 깨진다. `LIVE_COMPARE_MALLS=` 인자는 Cursor/터미널에서 직접 넘긴다.
7. 리바이스 대기는 늘리지 않는다. 관리 몰 가격 폴백 없다.

---

## 대조가 끝난 뒤 (아직 하지 말 것, 우선순위만)

엔진 쪽 후보. 대조 숫자를 다 모은 다음에 손댄다.

- W컨셉 og:title → `[W CONCEPT]`
- 올리브영·노이아고·SSG·코드그라피·립합 Cafe24 `price_ambiguous`
- 에이블리 `loading_timeout`
- 핫핑 이름 HTML 태그
- 룩핀·하고 대표 이미지 og 플레이스홀더
- 더현대Hi·4910·패션플러스 live 정답 품질

---

## 커밋에 넣지 말 것

- `flutter_app/.dart_tool/`, `build/`
- `tools/_*.py` 일회성 채움/프로브 스크립트
- `tools/run_remaining_compare.py` / `.ps1` (동작 불안정)
- 로그인 쿠키, `.env`
