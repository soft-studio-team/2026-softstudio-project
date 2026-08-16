# iOS WebView 64개 상품 추출 감사 결과

작성일: 2026-08-16

Android 실기기 64개 감사와 **같은 URL**을 iPhone 시뮬레이터에서 재현한 기록이다. 이 문서는 몰별 원본 결과이며, Draft PR #28에는 반영하지 않는다.

## 환경

- 앱: `com.softstudio.wishlist` / wishkit
- 브랜치 기준 커밋: `fbaf40b` (`feat/webview-scraper-stabilize`)
- 기기: iPhone 17 Pro 시뮬레이터 `53D6E81D-B9AC-48B0-8175-7F12FECF1041` / iOS 26.5
- 실물 iPhone `지으닝`(무선)은 연결되어 있었으나 장시간 분할에는 쓰지 않음
- JS probe: `2.0` (모든 배치·단독 시작 시 확인)
- 러너: `integration_test/webview_all_malls_audit_test.dart` + `--no-uninstall`
- 분할: 스모크 7개(`14,22,24,46,49,53,55`) → 1~3 → 4~20 → 21~38 → 39~51 → 52~64
- PASS 조건: 이름·이미지·양수 가격. 관리 몰은 `source.price=site-adapter`만. 전용 규칙 실패 시 범용 JSON-LD/OG/DOM 가격으로 우회하지 않고 가격은 null
- 원본 JSON: `wishlist-appversion2/ios_webview_audit_64_2026-08-16.json`

## 집계

| 분류 | 수 | 의미 |
|---|---:|---|
| PASS | 46 | 이름·이미지·양수 가격 |
| EXPECTED_ABSTAIN | 5 | 네이버 쇼핑, Gap, LF몰, NUGU, SHEIN |
| BLOCKED | 3 | 쿠팡, H&M, SSG |
| NO_RESULT | 1 | 리바이스 `loading_timeout` |
| PARTIAL_NO_PRICE | 9 | 현대Hmall, 오호라, 육육걸즈, 파르티멘토, Reformation, 나이키, ZARA, 이랜드몰, Aritzia |
| PARTIAL_MEDIA | 0 | Android 반스는 이름 없음이었으나 iOS는 PASS |

숫자상 Android PASS 46과 같지만 구성이 다르다.

- iOS만 PASS: 반스, 마리떼
- Android만 PASS: SSG, Aritzia

## 연속 WebView 오염

같은 InAppWebView를 비우지 않고 다음 URL을 열면 이전 몰 DOM이 다음 결과로 새어 나왔다. 아래는 배치에서 오염이 확인된 뒤 **1몰 단독 재실행으로 덮어쓴** 값이다.

| 몰 | 배치에서 보인 오염 | 단독 채택 결과 |
|---|---|---|
| 11 무인양품 | 탑텐 상품(이름·가격·finalUrl) | PASS 9,900 `muji` |
| 19 낫포유 | PARTIAL_NO_PRICE | PASS 15,900 `not4u` |
| 20 인사일런스 | NO_RESULT | PASS 59,000 `insilence` |
| 34 후아유 | 코드그라피 상품, 1.3초 | PASS 19,900 `whoau` |
| 57 브랜디 | 퀸잇 원피스 29,900 | PASS 34,500 `brandi` |
| 58 NUGU | 퀸잇 원피스 가짜 PASS | EXPECTED_ABSTAIN `unsupported_currency` |
| 59 CJ온스타일 | 퀸잇 원피스 | PASS 39,900 `cjonstyle` |
| 60 4910 | 퀸잇 원피스 | PASS 44,900 `4910` |
| 61 SSF샵 | 퀸잇 원피스 | PASS 59,400 `ssfshop` |
| 62 ZARA | 퀸잇 원피스 가짜 PASS | PARTIAL_NO_PRICE `price_ambiguous` |
| 63 SHEIN | 퀸잇 원피스 가짜 PASS | EXPECTED_ABSTAIN captcha `not_product_page` |

SSG는 오염이 아니라 차단 화면이다. 스모크 PASS 후 배치·단독 BLOCKED.

## 64개 한눈에

| # | 몰 | iOS | Android | 가격 | 정가 | 어댑터 | 가격출처 | 실패 | 소요(ms) |
|---:|---|---|---|---:|---:|---|---|---|---:|
| 1 | 쿠팡 | BLOCKED | BLOCKED | — | — | — | — | access_blocked | 15157 |
| 2 | 네이버 쇼핑 | EXPECTED_ABSTAIN | EXPECTED_ABSTAIN | — | — | — | — | not_product_page | 27114 |
| 3 | 11번가 | PASS | PASS | 12,000 | — | — | json-ld | — | 15482 |
| 4 | 무신사 | PASS | PASS | 35,900 | 69,000 | musinsa | site-adapter | — | 15414 |
| 5 | W컨셉 | PASS | PASS | 19,900 | 39,900 | wconcept | site-adapter | — | 15449 |
| 6 | 29CM | PASS | PASS | 159,000 | — | 29cm | site-adapter | — | 15413 |
| 7 | FILA | PASS | PASS | 69,900 | — | fila | site-adapter | — | 15548 |
| 8 | 하고 | PASS | PASS | 205,700 | 246,800 | hago | site-adapter | — | 15383 |
| 9 | 룩핀 | PASS | PASS | 28,900 | 54,900 | lookpin | site-adapter | — | 15415 |
| 10 | 탑텐 | PASS | PASS | 19,900 | 29,900 | topten | site-adapter | — | 15766 |
| 11 | 무인양품 | PASS | PASS | 9,900 | — | muji | site-adapter | — | 15516 |
| 12 | 현대Hmall | PARTIAL_NO_PRICE | PARTIAL_NO_PRICE | — | — | — | — | not_product_page | 27350 |
| 13 | 롯데온 | PASS | PASS | 105,000 | — | lotteon | site-adapter | — | 15694 |
| 14 | 미쏘 | PASS | PASS | 12,470 | 49,900 | mixxo | site-adapter | — | 16032 |
| 15 | 데일리쥬 | PASS | PASS | 36,000 | — | dailyjou | site-adapter | — | 15732 |
| 16 | 리 | PASS | PASS | 79,200 | 99,000 | lee | site-adapter | — | 15782 |
| 17 | 필루미네이트 | PASS | PASS | 45,000 | — | filluminate | site-adapter | — | 15616 |
| 18 | 어반스터프 | PASS | PASS | 62,100 | 69,000 | urbanstoff | site-adapter | — | 15481 |
| 19 | 낫포유 | PASS | PASS | 15,900 | 17,900 | not4u | site-adapter | — | 15436 |
| 20 | 인사일런스 | PASS | PASS | 59,000 | — | insilence | site-adapter | — | 15604 |
| 21 | 파브레가 | PASS | PASS | 39,600 | 44,000 | fabregat | site-adapter | — | 15927 |
| 22 | 핫핑 | PASS | PASS | 24,800 | — | hotping | site-adapter | — | 21610 |
| 23 | 유니클로 | PASS | PASS | 49,900 | — | uniqlo | site-adapter | — | 23832 |
| 24 | SSG | BLOCKED ≠ | PASS | — | — | — | — | access_blocked | 15505 |
| 25 | 더현대Hi | PASS | PASS | 130,300 | 179,100 | thehyundai | site-adapter | — | 15431 |
| 26 | 에이블리 | PASS | PASS | 17,500 | 21,900 | ably | site-adapter | — | 15499 |
| 27 | 지그재그 | PASS | PASS | 34,650 | 38,500 | zigzag | site-adapter | — | 15650 |
| 28 | KREAM | PASS | PASS | 75,000 | — | kream | site-adapter | — | 16010 |
| 29 | 게스 | PASS | PASS | 39,000 | 49,000 | guess | site-adapter | — | 15433 |
| 30 | 리바이스 | NO_RESULT | NO_RESULT | — | — | — | — | loading_timeout | 27246 |
| 31 | 반스 | PASS ≠ | PARTIAL_MEDIA | 57,000 | 95,000 | vans | site-adapter | — | 15499 |
| 32 | 커버낫 | PASS | PASS | 39,000 | 89,000 | covernat | site-adapter | — | 16045 |
| 33 | 코드그라피 | PASS | PASS | 70,300 | 74,000 | codegraphy | site-adapter | — | 15570 |
| 34 | 후아유 | PASS | PASS | 19,900 | 25,900 | whoau | site-adapter | — | 15524 |
| 35 | H&M | BLOCKED | BLOCKED | — | — | — | — | access_blocked | 15548 |
| 36 | Gap | EXPECTED_ABSTAIN | EXPECTED_ABSTAIN | — | — | — | json-ld | unsupported_currency | 27347 |
| 37 | Aritzia | PARTIAL_NO_PRICE ≠ | PASS | — | — | — | json-ld | price_ambiguous | 27281 |
| 38 | 노이아고 | PASS | PASS | 219,000 | — | noirer | site-adapter | — | 15582 |
| 39 | 립합 | PASS | PASS | 290,000 | — | liphop | site-adapter | — | 15773 |
| 40 | 마리떼 | PASS ≠ | PARTIAL_NO_PRICE | 49,000 | — | marithe | site-adapter | — | 15830 |
| 41 | 마하그리드 | PASS | PASS | 65,400 | 109,000 | mahagrid | site-adapter | — | 15397 |
| 42 | 비바스튜디오 | PASS | PASS | 161,100 | 179,000 | vivastudio | site-adapter | — | 15616 |
| 43 | 아모멘토 | PASS | PASS | 249,000 | — | amomento | site-adapter | — | 15515 |
| 44 | 앤더슨벨 | PASS | PASS | 95,000 | — | anderssonbell | site-adapter | — | 15533 |
| 45 | 예일 | PASS | PASS | 79,900 | 99,900 | yale | site-adapter | — | 15464 |
| 46 | 오호라 | PARTIAL_NO_PRICE | PARTIAL_NO_PRICE | — | 32,000 | — | json-ld | price_ambiguous | 27348 |
| 47 | 위드윤 | PASS | PASS | 68,000 | — | withyoon | site-adapter | — | 15565 |
| 48 | 육육걸즈 | PARTIAL_NO_PRICE | PARTIAL_NO_PRICE | — | — | — | json-ld | price_ambiguous | 27133 |
| 49 | 파르티멘토 | PARTIAL_NO_PRICE | PARTIAL_NO_PRICE | — | — | — | json-ld | price_ambiguous | 27083 |
| 50 | 패션플러스 | PASS | PASS | 23,120 | 159,000 | fashionplus | site-adapter | — | 15415 |
| 51 | 프롬비기닝 | PASS | PASS | 48,800 | 61,000 | frombeginning | site-adapter | — | 15398 |
| 52 | LF몰 | EXPECTED_ABSTAIN | EXPECTED_ABSTAIN | — | — | — | json-ld | price_ambiguous | 27135 |
| 53 | Reformation | PARTIAL_NO_PRICE | PARTIAL_NO_PRICE | — | 468,800 | — | json-ld | price_ambiguous | 27320 |
| 54 | 나이키 | PARTIAL_NO_PRICE | PARTIAL_NO_PRICE | — | — | — | — | script_timeout | 19458 |
| 55 | 올리브영 | PASS | PASS | 26,900 | 28,900 | oliveyoung | site-adapter | — | 17904 |
| 56 | 퀸잇 | PASS | PASS | 29,900 | 99,000 | queenit | site-adapter | — | 18012 |
| 57 | 브랜디 | PASS | PASS | 34,500 | 50,000 | brandi | site-adapter | — | 15395 |
| 58 | NUGU | EXPECTED_ABSTAIN | EXPECTED_ABSTAIN | — | — | — | json-ld | unsupported_currency | 27108 |
| 59 | CJ온스타일 | PASS | PASS | 39,900 | — | cjonstyle | site-adapter | — | 15855 |
| 60 | 4910 | PASS | PASS | 44,900 | — | 4910 | site-adapter | — | 15712 |
| 61 | SSF샵 | PASS | PASS | 59,400 | 88,000 | ssfshop | site-adapter | — | 15431 |
| 62 | ZARA | PARTIAL_NO_PRICE | PARTIAL_NO_PRICE | — | — | — | json-ld | price_ambiguous | 27162 |
| 63 | SHEIN | EXPECTED_ABSTAIN | EXPECTED_ABSTAIN | — | — | — | — | not_product_page | 27313 |
| 64 | 이랜드몰 | PARTIAL_NO_PRICE | PARTIAL_NO_PRICE | — | — | — | — | not_product_page | 27266 |

iOS 열의 `≠`는 Android 분류와 다름.

## 몰별 상세

### 1. 쿠팡 — `BLOCKED`

- URL: https://www.coupang.com/vp/products/6830320694?itemId=15948648483&vendorItemId=83406358948
- 상품명: Access Denied
- 이미지: —
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `dom`, source.image: `None`
- blocked=True, failureReason=`access_blocked`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15157ms
- 채택 로그: `ios-1-3.log`
- Android: `BLOCKED`
- 메모: Access Denied. Android도 BLOCKED.

### 2. 네이버 쇼핑 — `EXPECTED_ABSTAIN`

- URL: https://shopping.naver.com/catalog/51449387423
- finalUrl: https://shopv.pstatic.net/web/maintenance/not-found.html?timestamp=202608162234
- 상품명: —
- 이미지: —
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `None`, source.image: `None`
- blocked=False, failureReason=`not_product_page`, looksLikeProductPage=False, hasJsonLd=False, elapsed=27114ms
- 채택 로그: `ios-1-3.log`
- Android: `EXPECTED_ABSTAIN`
- 메모: finalUrl이 네이버 점검/없음 페이지. 의도적 abstain.

### 3. 11번가 — `PASS`

- URL: https://www.11st.co.kr/products/5932454122
- finalUrl: https://www.11st.co.kr/products/pa/5932454122
- 상품명: 강원평창수 무라벨, 500ml, 40개
- 이미지: https://cdn.011st.com/11dims/resize/600x600/quality/75/11src/product/5932454122/B.webp?301136073
- 가격: 12,000 / 정가 —
- 가격 부가: status=provisional, confidence=low
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15482ms
- 채택 로그: `ios-1-3.log`
- Android: `PASS`
- 메모: 비관리 몰. 가격 출처 json-ld. hang 없음.

### 4. 무신사 — `PASS`

- URL: https://www.musinsa.com/products/6558705
- 상품명: 26 SS 세미 크롭 라이트웨이트 스트라이프 [반팔] 셔츠 (3컬러)
- 이미지: https://image.msscdn.net/images/goods_img/20260527/6558705/6558705_17821067310601_500.jpg
- 가격: 35,900 / 정가 69,000
- 가격 부가: status=confirmed, confidence=high
- adapter: `musinsa`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15414ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 5. W컨셉 — `PASS`

- URL: https://www.wconcept.co.kr/Product/307615241
- 상품명: [W CONCEPT]
- 이미지: https://product-image.wconcept.co.kr/productimg/image/img2/41/307615241_GG10272.jpg
- 가격: 19,900 / 정가 39,900
- 가격 부가: status=confirmed, confidence=high
- adapter: `wconcept`, source.price: `site-adapter`, source.name: `og`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15449ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 6. 29CM — `PASS`

- URL: https://www.29cm.co.kr/products/4058252
- 상품명: 샥스 Z 칼리스트라 W - [블랙 / IR5510-001]
- 이미지: https://img.29cm.co.kr/item/202606/11f16f98cff926419090358d89120339.png?width=1200&format=webp
- 가격: 159,000 / 정가 —
- 가격 부가: status=confirmed, confidence=high
- adapter: `29cm`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15413ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 7. FILA — `PASS`

- URL: https://www.fila.co.kr/products/1100fs262rs11m001490
- 상품명: 테니스 Coldwave+ 라운드넥 자카드 반팔티
- 이미지: https://www.fila.co.kr/cdn/shop/files/1100_FS262RS11M001_490_01.jpg?v=1768589011
- 가격: 69,900 / 정가 —
- 가격 부가: status=confirmed, confidence=high
- adapter: `fila`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15548ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 8. 하고 — `PASS`

- URL: https://www.hago.kr/goods/detail/750307
- 상품명: [까이지엔느] V-라인 더블 러플 퍼프 블라우스
- 이미지: https://image.hago.kr/mall/goods/000/000/750/307/view_1.jpg?updated_at=20260421142510
- 가격: 205,700 / 정가 246,800
- 가격 부가: status=confirmed, confidence=high
- adapter: `hago`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15383ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 9. 룩핀 — `PASS`

- URL: https://www.lookpin.co.kr/products/3083865
- 상품명: 나일론 원턱 카고 파라슈트 팬츠 (3color)
- 이미지: https://www.lookpin.co.kr/og_tag_lookpin_web.jpg
- 가격: 28,900 / 정가 54,900
- 가격 부가: status=confirmed, confidence=high
- adapter: `lookpin`, source.price: `site-adapter`, source.name: `dom`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15415ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 10. 탑텐 — `PASS`

- URL: https://topten10.goodwearmall.com/product/MSG2UL2205NVP/detail
- 상품명: 여성) 코튼 립 브라탑
- 이미지: https://img.goodwearmall.com/goods/MSG2UL/MSG2UL2205NVP_M.jpg
- 가격: 19,900 / 정가 29,900
- 가격 부가: status=confirmed, confidence=high
- adapter: `topten`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15766ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 11. 무인양품 — `PASS`

- URL: https://mujikorea.co.kr/products/view/1005531
- 상품명: 스트레치 캐미솔
- 이미지: https://public.mujikorea.co.kr/metas/nsGaFaLffindyVDC5BACub7Tog0evl5XZ4h1LNYD.jpg
- 가격: 9,900 / 정가 —
- 가격 부가: status=confirmed, confidence=high
- adapter: `muji`, source.price: `site-adapter`, source.name: `dom`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15516ms
- 채택 로그: `ios-solo2-11.log`
- Android: `PASS`
- 메모: 4~20 배치에서 탑텐 DOM으로 오염됨. 단독 재실행 PASS 9,900원.

### 12. 현대Hmall — `PARTIAL_NO_PRICE`

- URL: https://www.hmall.com/md/pda/itemPtc?slitmCd=2028730260
- 상품명: HP 파빌리온 15-p054TX 멀티부스트 패키지 - 현대Hmall
- 이미지: https://image.hmall.com/static/2/0/73/28/2028730260_0.jpg?ao=2&cVer=201412021627&RS=300x300
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `og`, source.image: `og`
- blocked=False, failureReason=`not_product_page`, looksLikeProductPage=False, hasJsonLd=False, elapsed=27350ms
- 채택 로그: `ios-4-20.log`
- Android: `PARTIAL_NO_PRICE`
- 메모: 이름·이미지는 OG, 가격 없음. failureReason=not_product_page. Android도 가격 없음.

### 13. 롯데온 — `PASS`

- URL: https://www.lotteon.com/p/product/LO2724337622
- 상품명: [자이언츠x보노보노] 보노보노 유니폼
- 이미지: https://contents.lotteon.com/itemimage/20260721103648/LO/27/24/33/76/22/_2/72/43/37/62/3/LO2724337622_2724337623_1.jpg
- 가격: 105,000 / 정가 —
- 가격 부가: status=confirmed, confidence=high
- adapter: `lotteon`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15694ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 14. 미쏘 — `PASS`

- URL: https://mixxo.com/product/detail.html?product_no=12455
- 상품명: [에센셜] 루즈핏 긴팔 니트_MIWKAG530T
- 이미지: https://cafe24img.poxo.com/mixxo/web/product/big/202604/af4c717f08d808fbe021d901ac0b8fe2.jpg
- 가격: 12,470 / 정가 49,900
- 가격 부가: status=confirmed, confidence=medium
- adapter: `mixxo`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=16032ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 15. 데일리쥬 — `PASS`

- URL: https://dailyjou.com/product/detail.html?product_no=22794
- 상품명: [🤎어텀/MADE] 리즌 레이어드 라운드넥 반팔 니트
- 이미지: https://cafe24.poxo.com/ec01/cocomimi93/Kcc0fQ0DsTHpcxHYW7fqLaBIC/o2a/jM6bRPEprGgUE2Ahi38o9n6QY5e//FBcVGbltRbal2kV5zxlu1744asA==/_/web/product/big/202603/4c9aa6ce70db04379a07e87a9472452a.webp
- 가격: 36,000 / 정가 —
- 가격 부가: status=confirmed, confidence=high
- adapter: `dailyjou`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15732ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 16. 리 — `PASS`

- URL: https://leekorea.co.kr/product/detail.html?product_no=14252
- 상품명: 로코 포켓 데님 셔츠 인디고 라이트
- 이미지: https://leekorea.co.kr/web/product/big/202606/ec8667b06f230191e25a44ab54c94c04.jpg
- 가격: 79,200 / 정가 99,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `lee`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15782ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 17. 필루미네이트 — `PASS`

- URL: https://filluminate.com/product/detail.html?product_no=11735
- 상품명: FLM 스몰 로고 피그먼트 티셔츠-브라운
- 이미지: https://filluminate.com/web/product/big/202605/021f3e05962325f308a8e83ebc946676.jpg
- 가격: 45,000 / 정가 —
- 가격 부가: status=confirmed, confidence=high
- adapter: `filluminate`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15616ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 18. 어반스터프 — `PASS`

- URL: https://urbanstoff.com/product/detail.html?product_no=507
- 상품명: 로우 썬 아트워크 버뮤다 스웨트 팬츠 (멜란지)
- 이미지: https://ecimg.cafe24img.com/pg1589b23882635070/urbanstoff001/web/product/big/20260427/3ccc7f264e8bd398c7633b7f4eaf94c7.jpg
- 가격: 62,100 / 정가 69,000
- 가격 부가: status=confirmed, confidence=high
- adapter: `urbanstoff`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15481ms
- 채택 로그: `ios-4-20.log`
- Android: `PASS`

### 19. 낫포유 — `PASS`

- URL: https://not4u.kr/product/detail.html?product_no=261
- 상품명: 소프트 바디 미스트 115ml
- 이미지: https://not4u.kr/web/product/big/202402/a68857d33d5c671568a528494b17b42c.jpg
- 가격: 15,900 / 정가 17,900
- 가격 부가: status=confirmed, confidence=medium
- adapter: `not4u`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15436ms
- 채택 로그: `ios-solo2-19.log`
- Android: `PASS`
- 메모: 4~20 배치에서 PARTIAL_NO_PRICE. 단독 재실행 PASS 15,900원.

### 20. 인사일런스 — `PASS`

- URL: https://insilence.co.kr/product/detail.html?product_no=7481
- 상품명: 스탠실 그래픽 티셔츠 CHARCOAL
- 이미지: https://insilence.co.kr/web/product/big/202604/2e364b4c8c01e02e418313635db74694.jpg
- 가격: 59,000 / 정가 —
- 가격 부가: status=confirmed, confidence=high
- adapter: `insilence`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15604ms
- 채택 로그: `ios-solo2-20.log`
- Android: `PASS`
- 메모: 4~20 배치에서 NO_RESULT. 단독 재실행 PASS 59,000원.

### 21. 파브레가 — `PASS`

- URL: https://fabregat.kr/product/detail.html?product_no=1038
- 상품명: Brom Carabiner Leather Keyring (Black)
- 이미지: https://fabregat.kr/web/product/big/202605/872e33be2937be1918aa6ba242351d78.jpg
- 가격: 39,600 / 정가 44,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `fabregat`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15927ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 22. 핫핑 — `PASS`

- URL: https://hotping.co.kr/product/detail.html?product_no=29570
- 상품명: [여름쿨원단❄️][7만장돌파][롱&기본][MADE] 나의베스트 밴딩와이드팬츠 (44~110) (여름-베스트-간절기-봄여름-데일리-롱기본-밴딩와이드-휴양지-롱팬츠)
- 이미지: https://cafe24img.poxo.com/sseoqkr7/web/product/big/202405/43f2cf982d53323afb04e75ab28e62c9.jpg
- 가격: 24,800 / 정가 —
- 가격 부가: 옵션가 24,800–25,800, status=option_dependent, confidence=high
- adapter: `hotping`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=21610ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`
- 메모: 옵션 의존 가격 24,800~25,800. 대표 24,800.

### 23. 유니클로 — `PASS`

- URL: https://www.uniqlo.com/kr/ko/products/E486612-000/00?colorDisplayCode=65&sizeDisplayCode=005
- 상품명: 데님셔츠
- 이미지: https://image.uniqlo.com/UQ/ST3/kr/imagesgoods/486612/sub/krgoods_486612_sub3_3x4.jpg
- 가격: 49,900 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `uniqlo`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=23832ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 24. SSG — `BLOCKED`

- URL: https://www.ssg.com/item/itemView.ssg?itemId=1000571660298
- 상품명: 안전한 서비스 이용을 위해접속이 잠시 제한되었습니다
- 이미지: —
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `dom`, source.image: `None`
- blocked=True, failureReason=`access_blocked`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15505ms
- 채택 로그: `ios-solo-24.log`
- Android: `PASS` (분류 다름)
- 메모: 스모크에서는 site-adapter PASS(23,030원)였으나 이후 배치·단독에서 접속 제한 화면 → BLOCKED. 우회하지 않음. Android는 PASS.

### 25. 더현대Hi — `PASS`

- URL: https://hi.thehyundai.com/product/40B1406274?sectId=1031
- 상품명: 스티치 백 리본 블라우스 Z262MSC031
- 이미지: https://image.thehyundai.com/7/2/6/40/B1/40B1406274_0.jpg
- 가격: 130,300 / 정가 179,100
- 가격 부가: status=confirmed, confidence=medium
- adapter: `thehyundai`, source.price: `site-adapter`, source.name: `og`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15431ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 26. 에이블리 — `PASS`

- URL: https://mobile.a-bly.com/goods/74156532
- 상품명: [군살커버/롤업디자인] 소매 널널핏, 주니 헨리넥 단추 여름 루즈핏 롤업 반팔 티셔츠, 데일리 오버핏 버튼 반팔티, 레이어드 배색 상의 6color - 에이블리
- 이미지: https://imgb.a-bly.com/data/goods/2a6a20708e6cf3b09e230aba1b1a012f.gif
- 가격: 17,500 / 정가 21,900
- 가격 부가: status=confirmed, confidence=medium
- adapter: `ably`, source.price: `site-adapter`, source.name: `og`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15499ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 27. 지그재그 — `PASS`

- URL: https://zigzag.kr/catalog/products/144255443
- 상품명: 에드모어 [MADE] msk479 멜로디 코튼 캉캉 롱 스커트
- 이미지: https://cf.product-image.s.zigzag.kr/original/d/2026/4/30/1988_202604301624090904_83336.jpeg?width=720&height=720&quality=80&format=jpeg
- 가격: 34,650 / 정가 38,500
- 가격 부가: status=confirmed, confidence=medium
- adapter: `zigzag`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15650ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 28. KREAM — `PASS`

- URL: https://kream.co.kr/products/1012767
- 상품명: [KREAM 단독] Thevinylhouse x Bocchi the Rock! Kessoku Star Layered Ls Tee Black
- 이미지: https://kream-phinf.pstatic.net/MjAyNjA3MjFfMTg4/MDAxNzg0NjI1NjU1NjM1.2BI9VXVbcdapWUmRh0WlEwr_hv_5W7N9xFYqHb05Pycg.GPpdMDscTfgzG9PM3uOktT3yV5TjyOibgMklxlCgfnsg.PNG/p_d155324f3a38439dbbfd707b2d447f5f.png
- 가격: 75,000 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `kream`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=16010ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 29. 게스 — `PASS`

- URL: https://www.guesskorea.com/product/detail.html?product_no=45471
- 상품명: 남성 데님 프린트 삼각 반팔 티셔츠_LIGHT GREY
- 이미지: https://www.guesskorea.com/web/product/big/202603/cea6a7276868637421b68e8fb91a7274.jpg
- 가격: 39,000 / 정가 49,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `guess`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15433ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 30. 리바이스 — `NO_RESULT`

- URL: https://levi.co.kr/products/501-%EC%98%A4%EB%A6%AC%EC%A7%80%EB%84%90-%EC%A7%84-005010193
- 상품명: —
- 이미지: —
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `None`, source.image: `None`
- blocked=False, failureReason=`loading_timeout`, looksLikeProductPage=False, hasJsonLd=False, elapsed=27246ms
- 채택 로그: `ios-20-38.log`
- Android: `NO_RESULT`
- 메모: 내용 없음. loading_timeout. Android와 같음.

### 31. 반스 — `PASS`

- URL: https://www.vans.co.kr/PRODUCT/VN000D6WBOM
- 상품명: 올드스쿨
- 이미지: https://img.vans.com/image/upload/VN000D6WBOM-HERO.jpg
- 가격: 57,000 / 정가 95,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `vans`, source.price: `site-adapter`, source.name: `site-adapter`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15499ms
- 채택 로그: `ios-20-38.log`
- Android: `PARTIAL_MEDIA` (분류 다름)
- 메모: 이름 올드스쿨(recopick/site-adapter). Android는 이름 없음(PARTIAL_MEDIA).

### 32. 커버낫 — `PASS`

- URL: https://covernat.co.kr/product/detail.html?product_no=5996
- 상품명: 케이블 라운드 하프 니트 네이비
- 이미지: https://covernat.co.kr/web/product/big/CO2302KT23NA_1.jpg
- 가격: 39,000 / 정가 89,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `covernat`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=16045ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 33. 코드그라피 — `PASS`

- URL: https://code-graphy.com/product/detail.html?product_no=6388
- 상품명: 버뮤다 카펜터 코튼 팬츠_베이지
- 이미지: https://cafe24.poxo.com/ec01/cgraphy/nDa3+VeoMR5vyddRVokF8ltOczmmZefMqiQFCv903NO3uqDUY03GsJUYRdWtWSXw916shfsw86QFrSvagfRRrA==/_/web/product/big/202504/e3986480c1dc868d19a4a44b2c3861cb.jpg
- 가격: 70,300 / 정가 74,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `codegraphy`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15570ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`

### 34. 후아유 — `PASS`

- URL: https://whoau.com/product/detail.html?product_no=4852
- 상품명: USA Printing T-shirt
- 이미지: https://cafe24.poxo.com/ec01/whoaukr/3JPAsJn/jGkesyYvH/tEacJ//FpiOmI0G0IBVoMAo1XCOUL3mT6Caj09FWLKVeGQ1kJx/IhRfpWw9NNnns5vjA==/_/web/product/big/202605/1abcbd56ea4c53df7a822552aaac74f5.jpg
- 가격: 19,900 / 정가 25,900
- 가격 부가: status=confirmed, confidence=medium
- adapter: `whoau`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15524ms
- 채택 로그: `ios-solo-34.log`
- Android: `PASS`
- 메모: 21~38 배치에서 코드그라피 DOM으로 오염됨(1.3초). 단독 재실행 PASS 19,900원.

### 35. H&M — `BLOCKED`

- URL: https://www2.hm.com/ko_kr/productpage.1346684001.html
- 상품명: Access Denied
- 이미지: —
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `dom`, source.image: `None`
- blocked=True, failureReason=`access_blocked`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15548ms
- 채택 로그: `ios-20-38.log`
- Android: `BLOCKED`
- 메모: Access Denied. Android도 BLOCKED.

### 36. Gap — `EXPECTED_ABSTAIN`

- URL: https://www.gap.com/browse/product.do?pid=1185082032
- finalUrl: https://www.gap.com/browse/product.do?pid=1185082032#pdp-page-content
- 상품명: Organic Cotton VintageSoft Double-Layer T-Shirt
- 이미지: https://www.gap.com/webcontent/0062/914/431/cn62914431.jpg
- 가격: — / 정가 —
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`unsupported_currency`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27347ms
- 채택 로그: `ios-20-38.log`
- Android: `EXPECTED_ABSTAIN`
- 메모: 이름·이미지는 있으나 미지원 통화로 가격 비움. 의도적 abstain.

### 37. Aritzia — `PARTIAL_NO_PRICE`

- URL: https://www.aritzia.com/intl/en/product/airbutter%E2%84%A2-repose-longsleeve/133550.html?color=35023
- 상품명: AirBUTTER™ Repose Longsleeve
- 이미지: https://assets.aritzia.com/image/upload/q_auto,f_auto,dpr_auto,w_1920/f26_a01_133550_35023_on_a
- 가격: — / 정가 —
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`price_ambiguous`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27281ms
- 채택 로그: `ios-20-38.log (kept over degraded solo)`
- Android: `PASS` (분류 다름)
- 메모: 이름·이미지 있음, 전용 가격 실패로 null. Android는 PASS 88,900원. 단독 재실행은 이름이 호스트명으로 나빠져 배치 결과를 채택.

### 38. 노이아고 — `PASS`

- URL: https://noirer.com/product/detail.html?product_no=2141
- 상품명: 멀티 웨일 코듀로이 블루종 (딥브라운)
- 이미지: https://noirer.com/web/product/big/202509/898f768eacf0492bc86b7c3d15e95b6d.jpg
- 가격: 219,000 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `noirer`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15582ms
- 채택 로그: `ios-20-38.log`
- Android: `PASS`
- 메모: 배치 hang 없이 PASS. Android 단독 재실행과 동일 219,000원.

### 39. 립합 — `PASS`

- URL: https://liphop.com/product/detail.html?product_no=17849
- 상품명: BLACK WEDGE SLIPPERS
- 이미지: https://liphop.com/web/product/big/202406/ed7b52e91003133082ed4b85ab5e54e4.jpg
- 가격: 290,000 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `liphop`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15773ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 40. 마리떼 — `PASS`

- URL: https://marithe-official.com/product/detail.html?product_no=8883
- 상품명: W CLASSIC LOGO TEE red
- 이미지: https://marithe-official.com/web/product/big/202505/6816e856b23ae0b43d9f2c398688fcbb.jpg
- 가격: 49,000 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `marithe`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15830ms
- 채택 로그: `ios-38-51.log`
- Android: `PARTIAL_NO_PRICE` (분류 다름)
- 메모: Android는 PARTIAL_NO_PRICE. iOS는 site-adapter PASS.

### 41. 마하그리드 — `PASS`

- URL: https://mahagrid.com/product/detail.html?product_no=3854
- 상품명: THIRD LOGO BACKPACK[BLACK]
- 이미지: https://mahagrid.com/web/product/big/202602/c9908ec067fc6dd75124f9ed69c164a7.jpg
- 가격: 65,400 / 정가 109,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `mahagrid`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15397ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 42. 비바스튜디오 — `PASS`

- URL: https://vivastudio.co.kr/product/detail.html?product_no=5485
- 상품명: VXV OVERSIZED WORK JACKET [BLUE]
- 이미지: https://vivastudio.co.kr/web/product/big/202502/cf5eec4f89dc2a476bde52710fed83e1.jpg
- 가격: 161,100 / 정가 179,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `vivastudio`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15616ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 43. 아모멘토 — `PASS`

- URL: https://amomento.co/product/button-neck-knit-2colors/1642/
- 상품명: BUTTON NECK KNIT (2COLORS)
- 이미지: https://cafe24.poxo.com/ec01/amomentoweb/S6XixLXKQIBS6XUNf2tKGojORIH3PPuABxGbuJPvDdnCZ/1q6lF/ulSM9K1X+EnNoFwo9ozOPtj4s2Rf+txSew==/_/web/product/big/202501/1652618da0b72a1a986b47a538eb7666.jpg
- 가격: 249,000 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `amomento`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15515ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 44. 앤더슨벨 — `PASS`

- URL: https://www.anderssonbell.com/product/detail.html?product_no=10605
- 상품명: UNISEX LOVE T-SHIRT atb1252u(RED)
- 이미지: https://www.anderssonbell.com/web/product/big/202602/1fbc361c12d31cf13b0a3e5b7c1cfb23.jpg
- 가격: 95,000 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `anderssonbell`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15533ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 45. 예일 — `PASS`

- URL: https://yaleapparel.co.kr/product/detail.html?product_no=18179
- 상품명: 스몰 아치 스트라이프 후드 집업_라이트 그레이
- 이미지: https://yaleapparel.co.kr/web/product/big/202602/4bd91aef3f8b85c0a2d36f5da861e85e.jpg
- 가격: 79,900 / 정가 99,900
- 가격 부가: status=confirmed, confidence=medium
- adapter: `yale`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15464ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 46. 오호라 — `PARTIAL_NO_PRICE`

- URL: https://ohora.kr/product/detail.html?product_no=2275
- 상품명: [로즈힙] 밀크시럽 강화제
- 이미지: https://cafe24img.poxo.com/ohora2019/web/product/big/202605/611c06f8bffa93b03f716a5e1f43e767.jpg
- 가격: — / 정가 32,000
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`price_ambiguous`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27348ms
- 채택 로그: `ios-38-51.log`
- Android: `PARTIAL_NO_PRICE`
- 메모: 이름·이미지·정가 있음, 판매가 null. 관리 몰이라 json-ld 가격 우회 없음.

### 47. 위드윤 — `PASS`

- URL: https://withyoon.com/product/detail.html?product_no=19342
- 상품명: 모노 린넨 가디건
- 이미지: https://cafe24img.poxo.com/choiwjddbs/web/product/big/202607/4deb71bbfca1720eb1c187d72f550144.webp
- 가격: 68,000 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `withyoon`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15565ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 48. 육육걸즈 — `PARTIAL_NO_PRICE`

- URL: https://www.66girls.co.kr/product/1/158101/
- 상품명: 덤플스트라이프배색JP (패딩안감)
- 이미지: https://cafe24img.poxo.com/mall66/web/product/big/202512/f2abef7b5c407ded6d410f729e340df6.jpg
- 가격: — / 정가 —
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`price_ambiguous`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27133ms
- 채택 로그: `ios-38-51.log`
- Android: `PARTIAL_NO_PRICE`
- 메모: 이름·이미지 있음, 가격 null. 관리 몰 전용 규칙 실패.

### 49. 파르티멘토 — `PARTIAL_NO_PRICE`

- URL: https://partimento.com/product/detail.html?product_no=16516
- 상품명: [WOMEN] PWC SHEER TWO-FACE CARDIGAN_EMERALD
- 이미지: https://cafe24.poxo.com/ec01/partimento05/zhfKK2bYYBfSFNO5tt4/vJyNwUI0Xc4FyzlU0keijEKEBsCKhfQC7SgtI8nm3L720eyIdF1X0MnQrGMSGHpOhw==/_/web/product/big/202605/f36babed2e6fe8692fee314d242471cb.jpg
- 가격: — / 정가 —
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`price_ambiguous`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27083ms
- 채택 로그: `ios-38-51.log`
- Android: `PARTIAL_NO_PRICE`
- 메모: 이름·이미지 있음, 가격 null. 관리 몰 전용 규칙 실패.

### 50. 패션플러스 — `PASS`

- URL: https://www.fashionplus.co.kr/goods/detail/418168398
- 상품명: [본사직영]핫 썸머 블라우스 베스트 균일특가
- 이미지: https://img.fashionplus.co.kr/mall/assets/product_img/27607/plg27607_BL_0529.jpg?RS=400x536&AR=0
- 가격: 23,120 / 정가 159,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `fashionplus`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15415ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 51. 프롬비기닝 — `PASS`

- URL: https://frombeginning.co.kr/product/detail.html?product_no=22025
- 상품명: 앤디 스트링 이지 밴딩 팬츠
- 이미지: https://ecimg.cafe24img.com/pg1985b57457872046/frombegining/web/product/big/20260807/fb65743388ee09aabee7aea26b0ea272.gif
- 가격: 48,800 / 정가 61,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `frombeginning`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15398ms
- 채택 로그: `ios-38-51.log`
- Android: `PASS`

### 52. LF몰 — `EXPECTED_ABSTAIN`

- URL: https://www.lfmall.co.kr/app/product/K560XX01194
- 상품명: 카시오, 카시오 남성 메탈 손목 시계 아날로그 MTP-E725D-2A
- 이미지: https://nimg.lfmall.co.kr/file/product/prd/K560/XXXX/750/K560XX01194_00.jpg
- 가격: — / 정가 —
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`price_ambiguous`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27135ms
- 채택 로그: `ios-51-64.log`
- Android: `EXPECTED_ABSTAIN`
- 메모: 이름·이미지 있음, 가격 비움. 의도적 abstain.

### 53. Reformation — `PARTIAL_NO_PRICE`

- URL: https://www.thereformation.com/products/delia-dress/1317591.html
- 상품명: Delia Dress
- 이미지: https://media.thereformation.com/image/upload/f_auto,q_auto,dpr_1.0/w_800,c_scale//PRD-SFCC/1317591/JUNE/1317591.1.JUNE?_s=RAABAB0
- 가격: — / 정가 468,800
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`price_ambiguous`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27320ms
- 채택 로그: `ios-51-64.log`
- Android: `PARTIAL_NO_PRICE`
- 메모: 이름·이미지·정가(468,800) 있음, 판매가 null. 관리 몰 우회 없음.

### 54. 나이키 — `PARTIAL_NO_PRICE`

- URL: https://www.nike.com/kr/t/dunk-low-shoes-KJFYnLZQ/DD1391-100
- 상품명: 찾으시는 상품은 더 이상 구매할 수 없습니다.
- 이미지: —
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `dom`, source.image: `None`
- blocked=False, failureReason=`script_timeout`, looksLikeProductPage=False, hasJsonLd=False, elapsed=19458ms
- 채택 로그: `ios-51-64.log`
- Android: `PARTIAL_NO_PRICE`
- 메모: 화면 문구가 상품 종료. script_timeout. Android는 not_product_page.

### 55. 올리브영 — `PASS`

- URL: https://www.oliveyoung.co.kr/store/goods/getGoodsDetail.do?goodsNo=A000000260600
- 상품명: [리뷰이벤트/트러블1등] 셀라딕스 세범 리밸런싱 131 앰플 30ml 기획 (+미니언즈 키링) (미니언즈 콜라보) | 올리브영
- 이미지: https://image.oliveyoung.co.kr/cfimages/cf-goods/uploads/images/thumbnails/10/0000/0026/A00000026060006ko.jpg?l=ko
- 가격: 26,900 / 정가 28,900
- 가격 부가: status=confirmed, confidence=medium
- adapter: `oliveyoung`, source.price: `site-adapter`, source.name: `og`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=17904ms
- 채택 로그: `ios-51-64.log`
- Android: `PASS`

### 56. 퀸잇 — `PASS`

- URL: https://web.queenit.kr/product/421b849e05731238976b9f01d96c7e31
- 상품명: [M,L 사이즈/벨트세트]반팔 데님 원피스(하객룩, 하객원피스)
- 이미지: https://image.queenit.kr/product/asset/v1/upload/04120430d08047c38524a66065b43ca2.jpg
- 가격: 29,900 / 정가 99,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `queenit`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=18012ms
- 채택 로그: `ios-51-64.log`
- Android: `PASS`

### 57. 브랜디 — `PASS`

- URL: https://www.brandi.co.kr/products/158997563
- 상품명: [자체제작]데이트/하객룩 고급스러운 페미닌룩 튤립 펠리스 원피스 | 34,500원 | 브랜디
- 이미지: https://image.brandi.co.kr/cproduct/BRANDI/2025/05/29/4f9ce880-947d-418f-b196-5ce5d018610a/SB000000000153987406_1748503760_image1_S.webp
- 가격: 34,500 / 정가 50,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `brandi`, source.price: `site-adapter`, source.name: `og`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15395ms
- 채택 로그: `ios-solo2-57.log`
- Android: `PASS`
- 메모: 52~64 배치에서 퀸잇 상품으로 오염. 단독 재실행 PASS 34,500원.

### 58. NUGU — `EXPECTED_ABSTAIN`

- URL: https://www.nugu.jp/product/JQTFKT2457
- 상품명: レイヤードボタンスリーブレス
- 이미지: https://cdn.nugu.jp/public/1_Q83C65B_lgkBM0r_biKn6qt.jpg
- 가격: — / 정가 —
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`unsupported_currency`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27108ms
- 채택 로그: `ios-solo2-58.log`
- Android: `EXPECTED_ABSTAIN`
- 메모: 배치에서 퀸잇으로 오염된 가짜 PASS. 단독은 엔화 상품·unsupported_currency → 의도적 abstain.

### 59. CJ온스타일 — `PASS`

- URL: https://display.cjonstyle.com/p/item/2078847097
- 상품명: [최초가 79,900원] 26SS 시스루 스팽글 케이프니트 3종+캐미솔 세트
- 이미지: https://itemimage.cjonstyle.net/goods_images/20/097/2078847097L.jpg?timestamp=202608162335
- 가격: 39,900 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `cjonstyle`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15855ms
- 채택 로그: `ios-solo2-59.log`
- Android: `PASS`
- 메모: 배치에서 퀸잇 오염. 단독 PASS 39,900원.

### 60. 4910 — `PASS`

- URL: https://4910.kr/desktop/goods/64333542
- 상품명: 팬쇼 CACTUS FLOWER SHORT SLEEVE 4 colors - 4910 | 사고 싶은 스타일의 발견
- 이미지: https://d3ha2047wt6x28.cloudfront.net/LrIcIeOOBIk/pr:GOODS_DETAIL/czM6Ly9hYmx5LWltYWdlLWxlZ2FjeS9kYXRhL2dvb2RzLzIwMjYwMzEyXzE3NzMyOTU1NzYyMDAwMjVtLmpwZw
- 가격: 44,900 / 정가 —
- 가격 부가: status=confirmed, confidence=medium
- adapter: `4910`, source.price: `site-adapter`, source.name: `og`, source.image: `og`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=False, elapsed=15712ms
- 채택 로그: `ios-solo2-60.log`
- Android: `PASS`
- 메모: 배치에서 퀸잇 오염. 단독 PASS 44,900원.

### 61. SSF샵 — `PASS`

- URL: https://www.ssfshop.com/GOOD-ON/GPCX25041604994/good
- 상품명: 굿온 피그먼트 다잉 베이스볼 티셔츠 - 코랄
- 이미지: https://img.ssfshop.com/cmd/LB_750x1000/src/https://img.ssfshop.com/goods/ORBR/25/04/16/GPCX25041604994_0_THNAIL_ORGINL_20250416205746702.jpg
- 가격: 59,400 / 정가 88,000
- 가격 부가: status=confirmed, confidence=medium
- adapter: `ssfshop`, source.price: `site-adapter`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`None`, looksLikeProductPage=True, hasJsonLd=True, elapsed=15431ms
- 채택 로그: `ios-solo2-61.log`
- Android: `PASS`
- 메모: 배치에서 퀸잇 오염. 단독 PASS 59,400원.

### 62. ZARA — `PARTIAL_NO_PRICE`

- URL: https://www.zara.com/kr/ko/item-p05063701.html
- finalUrl: https://www.zara.com/kr/ko/%E1%84%91%E1%85%B3%E1%86%AF%E1%84%85%E1%85%B5%E1%84%8E%E1%85%B3-%E1%84%89%E1%85%AD%E1%84%90%E1%85%B3-%E1%84%90%E1%85%B3%E1%84%85%E1%85%A6%E1%86%AB%E1%84%8E%E1%85%B5-%E1%84%8F%E1%85%A9%E1%84%90%E1%85%B3-p05063701.html
- 상품명: 플리츠 쇼트 트렌치 코트
- 이미지: https://static.zara.net/assets/public/e0f3/d441/8f4a48e78f2d/67544d2ed0aa/05063701711-p/05063701711-p.jpg?ts=1786543758121&w=560
- 가격: — / 정가 —
- adapter: `none`, source.price: `json-ld`, source.name: `json-ld`, source.image: `json-ld`
- blocked=False, failureReason=`price_ambiguous`, looksLikeProductPage=True, hasJsonLd=True, elapsed=27162ms
- 채택 로그: `ios-solo2-62.log`
- Android: `PARTIAL_NO_PRICE`
- 메모: 배치에서 퀸잇 오염된 가짜 PASS. 단독은 이름·이미지만, 가격 null. Android도 가격 없음.

### 63. SHEIN — `EXPECTED_ABSTAIN`

- URL: https://kr.shein.com/item-p-427349856.html
- finalUrl: https://kr.shein.com/risk/challenge?captcha_type=909&redirection=https%3A%2F%2Fkr.shein.com%2Fitem-p-427349856.html&risk-id=E4887788234428290048
- 상품명: —
- 이미지: —
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `None`, source.image: `None`
- blocked=False, failureReason=`not_product_page`, looksLikeProductPage=False, hasJsonLd=False, elapsed=27313ms
- 채택 로그: `ios-solo2-63.log`
- Android: `EXPECTED_ABSTAIN`
- 메모: 배치에서 퀸잇 오염된 가짜 PASS. 단독 finalUrl이 captcha challenge. 의도적 abstain.

### 64. 이랜드몰 — `PARTIAL_NO_PRICE`

- URL: https://www.elandmall.co.kr/i/item?chnl_no=GSW&itemNo=2410548876
- 상품명: 코인코즈 트위드 베스트_DW4WV121- 이랜드몰
- 이미지: https://item.elandrs.com/r/image/item/2024-10-25/aeaf72b9-533c-48bf-83f9-082184d30a0a.jpg
- 가격: — / 정가 —
- adapter: `none`, source.price: `None`, source.name: `og`, source.image: `og`
- blocked=False, failureReason=`not_product_page`, looksLikeProductPage=False, hasJsonLd=False, elapsed=27266ms
- 채택 로그: `ios-51-64.log`
- Android: `PARTIAL_NO_PRICE`
- 메모: OG 이름·이미지, 가격 없음. not_product_page. Android와 같음.

