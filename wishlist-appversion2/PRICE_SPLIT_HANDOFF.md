# PRICE 몰 2인 분담 핸드오프

베이스 브랜치: `feat/webview-scraper-stabilize`  
Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28

## 기기 제약 (중요)
Galaxy Tab S7(`R54RB01SMVB`) **실기기 Tab 검증은 기기 소유자 1명만** 한다.  
팀원(패치 담당)은 **PC만** 사용한다. Tab 돌리지 말 것.

역할 분리:
| 역할 | 하는 일 | 안 하는 일 |
|------|---------|------------|
| 패치 담당 (팀원) | 프로브·엔진/카탈로그 패치·단위테스트·브랜치 push·PR 코멘트 | Tab/`run_tab_s7_compare.py` |
| 기기 소유자 | 패치 브랜치 pull → Tab 재검증 → MATCH면 머지/코멘트 | (가능하면 패치도 병행) |

## 이미 끝난 것 (건드리지 말 것)
정가 MATCH 3: 리, 필루미네이트, 어반스터프, 파브레가, 비바스튜디오, 프롬비기닝, 미쏘, 립합, 마하그리드, W컨셉, 나이키, CJ온스타일, 4910, 더현대Hi, 앤더슨벨 등.

## 정책
- **정가 우선** (`product:price:amount` / `product_price`). 회원가로 카탈로그를 낮추지 말 것.
- 관리 도메인은 전용 규칙 실패 시 범용 가격 우회 금지.
- `tools/_*.py`, bulk `audit-logs/` 는 커밋하지 말 것.
- 에이블리·SSG는 **보류** (로드/차단).

## 분담 (패치 범위)

### A — Cafe24 / 브랜드몰
브랜치: `fix/price-a-cafe24`  
몰: **코드그라피, 커버낫, 데일리쥬, 낫포유, 인사일런스, 핫핑(NAME)**  
파일: `product_extract_js.dart` (해당 host만), `live_field_compare_catalog.dart`

### B — SPA / 대형몰
브랜치: `fix/price-b-spa`  
몰: **올리브영, 롯데온, 지그재그, KREAM, Aritzia, 11번가(IMAGE), 이랜드몰(IMAGE)**  
파일: `product_extract_js.dart` (해당 host만), `live_field_compare_catalog.dart`

## 패치 담당 루프 (PC만)
1. 카탈로그 URL을 PC에서 프로브 (`product:price` vs `sale_price` 등)
2. 엔진/카탈로그 패치. `product_extract_js.dart`는 **자기 몰 hostIs 블록만**
3. `flutter test test/product_extract_js_sync_test.dart` (및 관련 unit test)
4. push → PR #28에 코멘트: **「Tab 검증 요청: [몰 목록] / 브랜치 / 예상 eng 가격」**
5. 기기 소유자 결과 보고 후, 실패면 패치 수정 반복

완료 판정은 **기기 소유자의 Tab MATCH 3**다. 패치 담당이 “끝”이라고 단정하지 말 것.

## 기기 소유자 루프 (Tab만 / 또는 패치+Tab)
1. `fix/price-a-cafe24` 또는 `fix/price-b-spa` pull
2. `tools/run_tab_s7_compare.py` 의 `MALLS`에 요청 몰만 넣고 실행  
   cwd: `wishlist-appversion2`, device `R54RB01SMVB`, `--no-uninstall`
3. MATCH 3 → 피처 브랜치로 머지·CHANGELOG·PR 코멘트  
   실패 → 패치 담당에게 eng/live/`failureReason` 회신

hang 시: `adb kill-server` → `start-server` → `am force-stop com.softstudio.wishlist`

---

## Cursor용 프롬프트

### A 담당 프롬프트 (팀원 · PC만 · 복붙)

```
너는 wishlist WebView 추출 엔진 패치 담당 A다. Tab S7 실기기는 없다. PC 작업만 한다.

베이스: feat/webview-scraper-stabilize
브랜치: fix/price-a-cafe24 (없으면 생성)
Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28
문서: wishlist-appversion2/PRICE_SPLIT_HANDOFF.md

담당 몰: 코드그라피, 커버낫, 데일리쥬, 낫포유, 인사일런스, 핫핑(NAME)

정책:
- 정가(product:price / product_price) 우선. 회원가로 카탈로그를 낮추지 말 것.
- run_tab_s7_compare.py / flutter test integration_test(실기기) / adb 는 실행하지 말 것.
- 다른 담당 몰(올리브영·롯데온·지그재그·KREAM·Aritzia·11번가·이랜드)·에이블리·SSG는 건드리지 말 것.
- product_extract_js.dart는 내 몰 hostIs 블록만 수정.

작업:
1) 카탈로그 URL PC 프로브 → eng vs live 원인 정리
2) product_extract_js.dart / live_field_compare_catalog.dart 패치
3) flutter test test/product_extract_js_sync_test.dart 통과
4) push 후 PR #28에 「Tab 검증 요청」 코멘트 (몰, 브랜치, 예상 정가, 변경 요약)
5) 기기 소유자가 Tab 실패를 알려주면 패치만 수정해 다시 요청

참고: cafe24MetaList, verifiedCafe(covernat/code-graphy), not4u/insilence/hotping/dailyjou
응답은 한국어.
```

### B 담당 프롬프트 (팀원 · PC만 · 복붙)

```
너는 wishlist WebView 추출 엔진 패치 담당 B다. Tab S7 실기기는 없다. PC 작업만 한다.

베이스: feat/webview-scraper-stabilize
브랜치: fix/price-b-spa (없으면 생성)
Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28
문서: wishlist-appversion2/PRICE_SPLIT_HANDOFF.md

담당 몰: 올리브영, 롯데온, 지그재그, KREAM, Aritzia, 11번가(IMAGE), 이랜드몰(IMAGE)

정책:
- 정가/조건 없는 판매가 우선. 쿠폰·회원·첫구매가로 맞추지 말 것.
- run_tab_s7_compare.py / flutter test integration_test(실기기) / adb 는 실행하지 말 것.
- 다른 담당 몰(코드그라피·커버낫·데일리쥬·낫포유·인사일런스·핫핑)·에이블리·SSG는 건드리지 말 것.
- product_extract_js.dart는 내 몰 hostIs 블록만 수정.

작업:
1) 카탈로그 URL PC 프로브 → eng vs live / price_ambiguous 원인 정리
2) product_extract_js.dart / live_field_compare_catalog.dart 패치 (필요 시 SKU 교체)
3) flutter test test/product_extract_js_sync_test.dart 통과
4) push 후 PR #28에 「Tab 검증 요청」 코멘트 (몰, 브랜치, 예상 가격, 변경 요약)
5) 기기 소유자가 Tab 실패를 알려주면 패치만 수정해 다시 요청

참고: oliveyoung/lotteon/zigzag/kream/aritzia/elandmall
응답은 한국어.
```

### 기기 소유자 프롬프트 (Tab 검증 · 복붙)

```
너는 wishlist Tab S7 검증 담당이다. 팀원이 push한 PRICE 패치 브랜치를 실기기로 확인한다.

베이스: feat/webview-scraper-stabilize
Draft PR: https://github.com/soft-studio-team/2026-softstudio-project/pull/28
기기: R54RB01SMVB, --no-uninstall
문서: wishlist-appversion2/PRICE_SPLIT_HANDOFF.md

할 일:
1) PR #28의 최신 「Tab 검증 요청」 코멘트를 보고 브랜치(fix/price-a-cafe24 또는 fix/price-b-spa)를 checkout
2) tools/run_tab_s7_compare.py MALLS에 요청 몰만 넣고 python tools/run_tab_s7_compare.py 실행 (cwd: wishlist-appversion2)
3) MATCH 3면 피처 브랜치로 머지·CHANGELOG·PR 코멘트
4) 실패면 eng/live/failureReason/로그 경로를 PR에 남기고 패치 담당에게 수정 요청
5) 에이블리/SSG는 보류. hang 시 adb kill/start + force-stop

응답은 한국어.
```
