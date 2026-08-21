# WebView 가격 추출 — 몰 지원 현황

기준: 2026-08-21 · Tab S7(`R54RB01SMVB`) live compare · 브랜치 `feat/webview-scraper-stabilize`  
정책: **정가/조건 없는 판매가** 우선. 쿠폰·회원·첫구매가로 맞추지 않음.

## 지원 (Tab MATCH 인증 · 50몰)

`live_field_compare_catalog.dart` 대조 카탈로그. 상품당 이름·가격·이미지 일치.

| # | 몰 | 비고 |
|---|-----|------|
| 1 | 11번가 | |
| 2 | 무신사 | |
| 3 | W컨셉 | |
| 4 | 29CM | |
| 5 | FILA | |
| 6 | 하고 | |
| 7 | 룩핀 | |
| 8 | 탑텐 | |
| 9 | 무인양품 | |
| 10 | 현대Hmall | |
| 11 | 롯데온 | |
| 12 | 미쏘 | |
| 13 | 데일리쥬 | |
| 14 | 리 | 정가(metaList) |
| 15 | 필루미네이트 | 정가 |
| 16 | 어반스터프 | 정가 |
| 17 | 낫포유 | 카탈로그 2상품 · MATCH 2/2 |
| 18 | 인사일런스 | |
| 19 | 파브레가 | 정가 |
| 20 | 핫핑 | |
| 21 | 유니클로 | |
| 22 | SSG | **deal** 경로. `itemView`는 `access_blocked` 가능 |
| 23 | 더현대Hi | |
| 24 | 에이블리 | `mobile.a-bly.com` |
| 25 | 지그재그 | 쿠폰/최저가도전 제외 |
| 26 | KREAM | 브랜드배송 SKU |
| 27 | 게스 | |
| 28 | 반스 | |
| 29 | 커버낫 | |
| 30 | 코드그라피 | |
| 31 | 후아유 | |
| 32 | Aritzia | Global-e KRW |
| 33 | 노이아고 | |
| 34 | 립합 | 정가 |
| 35 | 마하그리드 | 정가 |
| 36 | 비바스튜디오 | 정가 |
| 37 | 아모멘토 | |
| 38 | 앤더슨벨 | |
| 39 | 예일 | |
| 40 | 위드윤 | |
| 41 | 패션플러스 | |
| 42 | 프롬비기닝 | 정가 |
| 43 | 나이키 | |
| 44 | 올리브영 | RSC/API 폴링 |
| 45 | 퀸잇 | |
| 46 | 브랜디 | |
| 47 | CJ온스타일 | |
| 48 | 4910 | |
| 49 | SSF샵 | |
| 50 | 이랜드몰 | |

## 미지원 / 의도적 기권

앱이 **양수 가격을 확정하지 않는** 것이 정상인 몰.

| 몰 | 이유 |
|----|------|
| Gap | 미지원 통화 · `expectedAbstain` |
| LF몰 | guard-only · `expectedAbstain` |
| NUGU | 미지원 통화(¥) · `expectedAbstain` |
| SHEIN | 세션/통화 조건 · `expectedAbstain` |
| 네이버 쇼핑 | 카탈로그형 · `expectedAbstain` |
| 쿠팡 | 접근 차단(`access_blocked` / Access Denied) |

## 엔진 규칙 있음 · Tab live-compare 미인증

64몰 감사 목록에는 있으나, 50몰 대조 카탈로그·MATCH 3 인증 밖. **지원으로 광고하지 않음.**

| 몰 | 상태 |
|----|------|
| 리바이스 | 로드/timeout 불안정. 대기 시간 늘리지 않음 |
| H&M | 자주 차단 |
| 마리떼 | 부분 추출 이력 |
| 오호라 | 전용 규칙 실패 시 가격 비움 |
| 육육걸즈 | 전용 규칙 실패 시 가격 비움 |
| 파르티멘토 | 전용 규칙 실패 시 가격 비움 |
| Reformation | 전용 규칙 실패 시 가격 비움 |
| ZARA | provisional 금지 · confirmed만 |

## 운영 메모

- SSG: 일반 `itemView`가 막히면 **활성 deal** URL 사용. 만료 deal(`행사 기간이 아닙니다`)은 null.
- 에이블리: `m.a-bly.com` ↔ `mobile.a-bly.com` same-site.
- 검증: `python tools/run_tab_s7_compare.py` (`MALLS`, `--no-uninstall`, 기기 `R54RB01SMVB`).
- 관련 PR: [#28](https://github.com/soft-studio-team/2026-softstudio-project/pull/28)
