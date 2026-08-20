# PRICE 몰 2인 분담 핸드오프

베이스 브랜치: `feat/webview-scraper-stabilize`  
Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28  
기기: Galaxy Tab S7 `R54RB01SMVB` (한 번에 1명만 Tab 검증)

## 이미 끝난 것 (건드리지 말 것)
정가 정책으로 Tab MATCH 3 확인됨:  
리, 필루미네이트, 어반스터프, 파브레가, 비바스튜디오, 프롬비기닝, 미쏘, 립합, 마하그리드, W컨셉, 나이키, CJ온스타일, 4910, 더현대Hi, 앤더슨벨 등.

## 정책
- **정가 우선** (`product:price:amount` / `product_price`). 회원가·멤버할인가로 카탈로그를 맞추지 말 것.
- 관리 도메인은 전용 규칙 실패 시 범용 가격 우회 금지.
- Tab: `--no-uninstall`, 몰 단위 1개씩, ADB reset + cooldown.
- 커밋은 통과(MATCH 3) 후. `tools/_*.py`, bulk `audit-logs/` 는 커밋하지 말 것.
- 에이블리·SSG는 **보류** (로드/차단).

## 분담

### A — Cafe24 / 브랜드몰
브랜치 예: `fix/price-a-cafe24`  
몰: **코드그라피, 커버낫, 데일리쥬, 낫포유, 인사일런스, 핫핑(NAME)**

핵심 파일:
- `flutter_app/lib/services/product_extract_js.dart` (`verifiedCafe`, `cafe24Offer`, `cafe24MetaList`, `not4u`, `insilence`, `hotping`)
- `flutter_app/integration_test/live_field_compare_catalog.dart`
- `tools/run_tab_s7_compare.py` 의 `MALLS`

### B — SPA / 대형몰
브랜치 예: `fix/price-b-spa`  
몰: **올리브영, 롯데온, 지그재그, KREAM, Aritzia, 11번가(IMAGE), 이랜드몰(IMAGE)**

핵심 파일:
- `flutter_app/lib/services/product_extract_js.dart` (`oliveyoung`, `lotteon`, `zigzag`, `kream`, `aritzia`, `elandmall` 등)
- `flutter_app/integration_test/live_field_compare_catalog.dart`
- `tools/run_tab_s7_compare.py` 의 `MALLS`

## 한 몰 작업 루프
1. 최신 `audit-logs/compare-*.txt` 또는 Tab 결과에서 `enginePrice` vs `livePrice` / `failureReason` 확인
2. PC로 meta `product:price` vs `sale_price` (또는 몰 전용 JSON) 프로브
3. 엔진을 정가로 맞추거나, 카탈로그가 낡았으면 live 갱신 / SKU 교체
4. `MALLS = ["몰이름"]` 후 `python tools/run_tab_s7_compare.py` (cwd: `wishlist-appversion2`)
5. MATCH 3이면 커밋 → push → PR #28 코멘트

## Cursor용 프롬프트

### A 담당 프롬프트 (복붙)

```
너는 wishlist WebView 추출 엔진 패치 담당 A다.

베이스: feat/webview-scraper-stabilize
내 브랜치: fix/price-a-cafe24 (없으면 생성)
Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28

목표: 아래 몰을 Tab S7에서 이름·가격·사진 MATCH 3로 만들기.
- 코드그라피, 커버낫, 데일리쥬, 낫포유, 인사일런스, 핫핑(NAME)

정책:
- 정가(product:price / product_price) 우선. 회원가로 카탈로그를 낮추지 말 것.
- 에이블리/SSG/다른 사람 몰(올리브영·롯데온·지그재그·KREAM·Aritzia·11번가·이랜드)은 건드리지 말 것.
- product_extract_js.dart는 내 몰 hostIs 블록만 수정.

작업 루프:
1) 카탈로그 URL 프로브 → eng vs live 원인 파악
2) product_extract_js.dart / live_field_compare_catalog.dart 패치
3) tools/run_tab_s7_compare.py MALLS를 해당 몰만 넣고 Tab 검증
   - device R54RB01SMVB, --no-uninstall, cwd wishlist-appversion2
4) MATCH 3면 커밋·푸시·PR #28 코멘트 (CHANGELOG 짧게)

참고: cafe24MetaList, verifiedCafe(covernat/code-graphy), not4u/insilence/hotping/dailyjou 규칙.
문서: wishlist-appversion2/PRICE_SPLIT_HANDOFF.md
응답은 한국어.
```

### B 담당 프롬프트 (복붙)

```
너는 wishlist WebView 추출 엔진 패치 담당 B다.

베이스: feat/webview-scraper-stabilize
내 브랜치: fix/price-b-spa (없으면 생성)
Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28

목표: 아래 몰을 Tab S7에서 이름·가격·사진 MATCH 3로 만들기.
- 올리브영, 롯데온, 지그재그, KREAM, Aritzia
- 이미지 위주: 11번가, 이랜드몰

정책:
- 정가/조건 없는 판매가 우선. 쿠폰·회원·첫구매가로 맞추지 말 것.
- 에이블리/SSG/다른 사람 몰(코드그라피·커버낫·데일리쥬·낫포유·인사일런스·핫핑)은 건드리지 말 것.
- product_extract_js.dart는 내 몰 hostIs 블록만 수정.

작업 루프:
1) 카탈로그 URL 프로브 → eng vs live / price_ambiguous 원인 파악
2) product_extract_js.dart / live_field_compare_catalog.dart 패치 (필요 시 SKU 교체)
3) tools/run_tab_s7_compare.py MALLS를 해당 몰만 넣고 Tab 검증
   - device R54RB01SMVB, --no-uninstall, cwd wishlist-appversion2
4) MATCH 3면 커밋·푸시·PR #28 코멘트 (CHANGELOG 짧게)

참고: oliveyoung/lotteon/zigzag/kream/aritzia/elandmall 규칙, Tab은 A와 시간 겹치지 않게.
문서: wishlist-appversion2/PRICE_SPLIT_HANDOFF.md
응답은 한국어.
```

## Tab 사용 약속
- 슬랙/채팅에 `Tab 사용 중 / 해제` 한 줄만 남기기
- hang 시: `adb kill-server` → `start-server` → `am force-stop com.softstudio.wishlist`
