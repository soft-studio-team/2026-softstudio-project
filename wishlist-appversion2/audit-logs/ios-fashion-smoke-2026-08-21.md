# iOS 패션 Top 10 live field compare smoke

- 날짜: 2026-08-21
- 브랜치: `main` @ `2588cbe` (PR #28 머지 후)
- 앱: `wishlist-appversion2/flutter_app`
- 러너: `integration_test/live_field_compare_test.dart` (`--no-uninstall`)
- 카탈로그: `integration_test/live_field_compare_catalog.dart`
- 단위 테스트: `product_extract_js_sync` · `webview_scraper_result` · `parsing_bridge` · `live_field_compare` **35 passed**
- 엔진 코드: **수정 없음**

## 기기

| 대상 | 결과 |
|------|------|
| iPhone 실기기 `지으닝` (wireless) `00008140-001202993CEB001C` iOS 26.6 | `flutter test` 실패: wireless tether에서 앱을 시작하지 못함. `flutter test`에는 `--publish-port` 없음 |
| USB iPhone | 미연결 |
| **사용** iPhone 17 시뮬레이터 `F1FAFF04-97E5-4838-BDC0-09A977AC46B2` iOS 26.5 | 10몰 완주 |

`POPULAR_MALL_RESEARCH.md`는 main에 없음. 몰 이름은 카탈로그 `LiveCompareMall` / `MALL_SUPPORT.md` 지원 표. **SSF샵** 이름 확인.

## 몰별 판정

PASS = 3 SKU 모두 `verdict=MATCH` 이고 이름·양수 가격·이미지 있음.  
안드 Tab MATCH 3는 `MALL_SUPPORT.md` / CHANGELOG(PR #28). 같은 몰이 안드 MATCH·iOS 실패면 **OS 차이**.

| # | 몰 | iOS | 1 | 2 | 3 | 안드 Tab | 비고 |
|---|-----|-----|---|---|---|----------|------|
| 1 | 에이블리 | **FAIL 2/3** | PRICE | MATCH | MATCH | MATCH 3 | **OS 차이**. #1 `enginePrice=null` `failureReason=price_ambiguous`. finalUrl은 `mobile.a-bly.com` 유지 |
| 2 | 무신사 | **FAIL 2/3** | MATCH | PRICE | MATCH | MATCH 3 | **OS 차이**. #2 got **80100** / live **84550** (양수) |
| 3 | 지그재그 | **FAIL 2/3** | MATCH | MATCH | PRICE | MATCH 3 | **OS 차이**. #3 got **194150** / live **185580** (양수). 카탈로그 특가 표기 |
| 4 | 퀸잇 | **FAIL 1/3** | PRICE | MATCH | PRICE | MATCH 3 | **OS 차이**. #1 got **29900**/32900, #3 got **33387**/35900 |
| 5 | KREAM | **PASS 3/3** | MATCH | MATCH | MATCH | MATCH 3 | |
| 6 | 29CM | **FAIL 2/3** | MATCH | PRICE | MATCH | MATCH 3 | **OS 차이**. #2 got **180400** / live **117260** (양수) |
| 7 | 4910 | **PASS 3/3** | MATCH | MATCH | MATCH | MATCH 3 | finalUrl `4910.kr/desktop/goods/...` |
| 8 | W컨셉 | **PASS 3/3** | MATCH | MATCH | MATCH | MATCH 3 | |
| 9 | SSF샵 | **PASS 3/3** | MATCH | MATCH | MATCH | MATCH 3 | 카탈로그 이름 `SSF샵` |
| 10 | 올리브영 | **PASS 3/3** | MATCH | MATCH | MATCH | MATCH 3 | |

요약: **SKU 24/30 MATCH**, 몰 전체 PASS **5/10** (KREAM, 4910, W컨셉, SSF샵, 올리브영). BLOCKED / timeout / NO_RESULT 없음. 실패 6건은 모두 PRICE.

`live_field_compare_test`는 `source.price`를 찍지 않아 site-adapter 여부는 이 러너로 확인하지 못함.

## 실패 SKU (got)

### 에이블리 #1 — PRICE / `price_ambiguous`

- URL: `https://mobile.a-bly.com/goods/75432976`
- elapsed: 68243ms
- name MATCH, image MATCH
- got price: **null**
- live price: **26500**
- failureReason: `price_ambiguous`
- finalUrl: `https://mobile.a-bly.com/goods/75432976` (m↔mobile same-site 이슈는 이번 SKU에서 안 보임)
- 재현 후 원인 정리 전에는 엔진 수정하지 않음

### 무신사 #2 — PRICE

- URL: `https://www.musinsa.com/products/6797005`
- got: **80100** / live: **84550**
- 이름·이미지 MATCH, failureReason null
- 양수 가격이 카탈로그와만 다르면 정답 드리프트 가능성도 있음

### 지그재그 #3 — PRICE

- URL: `https://zigzag.kr/catalog/products/161980550`
- got: **194150** / live: **185580**
- 이름·이미지 MATCH. live 이름에 `뷰티페스타 특가` 표기

### 퀸잇 #1 · #3 — PRICE

- #1 `421b849e…` got **29900** / live **32900**
- #3 `b52c66c7…` got **33387** / live **35900**
- 이름·이미지 MATCH

### 29CM #2 — PRICE

- URL: `https://www.29cm.co.kr/products/3423314`
- got: **180400** / live: **117260**
- 이름·이미지 MATCH

## 복구

시뮬레이터에 일반 debug 앱을 다시 설치 (`flutter run --debug`, uninstall 없음, `--release` 없음).
