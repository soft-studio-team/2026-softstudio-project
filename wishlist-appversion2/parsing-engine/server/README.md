# 상품 정보 수집 파싱 엔진 — 3단계 폴백 아키텍처

외부 쇼핑 앱에서 공유받은 상품 URL로부터 상품명·이미지·가격 등을 자동 추출해
일관된 구조로 정규화하는 파싱 엔진입니다. "상품정보-수집전략" 문서의 구현체입니다.

> 이전 버전의 웹뷰(헤드리스 브라우저/Playwright) 렌더링 방식은 **의도적으로
> 기각·제거**했습니다. 자동화 브라우징은 이커머스 이용약관의 "자동화 수단에 의한
> 접근 금지" 조항과 충돌할 소지가 크고, 화면 개편마다 깨지며, 발표에서 방어하기
> 어렵기 때문입니다. 새 엔진의 모든 단계는 **데이터 제공자가 의도한 경로**만
> 사용합니다.

## 아키텍처

```
공유받은 URL
│
├─ [Tier 1] 공식 오픈 API 연동        (쿠팡·네이버·11번가 등 오픈마켓형)
│    └─ URL에서 플랫폼 식별 → 상품 식별자 추출 → API 조회 → 매칭
│    └─ 성공 시: 상품명·이미지·가격 확보 (신뢰도 최고, 가격 추적 가능)
│
├─ [Tier 2] 표준 메타데이터 파싱       (무신사·29CM·W컨셉 등 편집샵형)
│    └─ HTTP GET 1회 → JSON-LD(Product) 우선 → 없으면 Open Graph
│    └─ 성공 조건: 제목 + 이미지 + 가격 (하나라도 없으면 Tier 3)
│
└─ [Tier 3] 미리보기 수준 + 사용자 보완 (그 외 모든 사이트 — 절대 실패하지 않음)
     └─ 얻은 것은 전부 미리 채우고, 빠진 항목(주로 가격)만 사용자가 입력
```

상위 단계가 실패하면 자동으로 다음 단계로 내려가며(graceful degradation),
어떤 단계로 수집됐는지(`source_type`)와 각 단계의 시도 기록(`attempts`)을
결과에 함께 남깁니다. → 플랫폼별 실패율 모니터링으로 사이트 구조 변화를 감지.

## 준수 원칙 (약관·윤리 방어선)

코드 구조 자체가 다음을 강제합니다 (`engine/fetch.py`):

- **robots.txt 확인·존중** — 차단되면 우회하지 않고 Tier 3으로 폴백
- **정직한 User-Agent** — `WishlistBot/1.0 (+저장소 URL; ...)` 로 신원 명시
- **저장 시점 1회 요청** — 사용자가 명시적으로 저장한 URL에 대해 GET 1회.
  Tier 1이 페이지 제목이 필요해 가져온 결과는 Tier 2/3이 그대로 재사용
- **결과 캐싱** — 동일 URL 중복 요청 방지 + API rate limit 대응
- **JS 렌더링·로그인·봇 차단 우회 없음** — 의존성에 브라우저 자체가 없음

## 디렉터리 구조

```
server/
├── api_server.py            # FastAPI 서버 (POST /parse)
├── engine/
│   ├── pipeline.py          # 3단계 폴백 오케스트레이터 (엔진 본체)
│   ├── models.py            # Product / ParseResult / TierAttempt 정규화 모델
│   ├── urltools.py          # 플랫폼 식별 + 상품 식별자 추출 (레지스트리)
│   ├── fetch.py             # HTTP GET 1회 + robots.txt 존중 + 정직한 UA
│   ├── metadata.py          # JSON-LD(Product) 우선 → Open Graph 보완 파서
│   ├── cache.py             # TTL 캐시
│   └── tiers/
│       ├── tier1_api.py     # 네이버·쿠팡·11번가 API 어댑터 + 매칭 로직
│       ├── tier2_metadata.py
│       └── tier3_preview.py
└── tests/                   # 오프라인(네트워크 불필요) 테스트 54개
```

## 실행

```bash
cd server
pip install -r requirements.txt
uvicorn api_server:app --reload
# http://127.0.0.1:8000/      → 웹 시뮬레이터 (폴백 체인 시각화)
# http://127.0.0.1:8000/docs  → API 문서에서 바로 테스트
```

```bash
# 테스트
python3 -m pytest tests/ -q
```

## Flutter 앱(iOS 시뮬레이터) 연결

`app/` 의 위시리스트 앱이 이 서버를 백엔드로 사용합니다.

```bash
# 1) 서버 켜기 (맥에서)
cd server && uvicorn api_server:app

# 2) 앱 실행 (iOS 시뮬레이터)
cd app && flutter run
```

- iOS 시뮬레이터는 맥과 주소를 공유하므로 기본값(`http://127.0.0.1:8000`)
  그대로 동작합니다. Android 에뮬레이터는 `app/lib/config.dart` 에서
  `http://10.0.2.2:8000` 으로 바꿔주세요.
- 앱용 API: `POST /api/scrap`(공유 텍스트 → 파싱+저장), `GET /api/products`,
  `PATCH /api/products/:id`(빠진 필드 사용자 보완), `DELETE /api/products/:id`.
  목록은 `server/data/wishlist.json` 에 보관됩니다.

## API

`POST /parse` `{"url": "https://www.29cm.co.kr/products/1577769"}`

```json
{
  "product": {
    "title": "퀸 비키니 브라_화이트",
    "image_url": "https://img.29cm.co.kr/next-product/...jpg",
    "price": 109000,
    "currency": "KRW",
    "brand": "아그넬",
    "category": "비키니",
    "original_url": "https://www.29cm.co.kr/products/1577769",
    "source_platform": "29cm",
    "source_type": "METADATA",
    "price_trackable": false,
    "fetched_at": "..."
  },
  "resolved_tier": 2,
  "missing_fields": [],
  "attempts": [
    {"tier": 1, "name": "open_api", "outcome": "skipped",
     "reason": "platform '29cm' does not provide an open API"},
    {"tier": 2, "name": "metadata", "outcome": "success",
     "reason": "extracted via json-ld, open-graph"}
  ]
}
```

- `missing_fields` 가 비어 있지 않으면 앱은 저장 화면에서 해당 필드만
  사용자에게 확인·입력받습니다 ("전부 수동 입력"이 아니라 "빠진 것만 확인").
- 유일한 실패 응답은 422 (URL이 http/https 형식이 아닌 경우) 뿐입니다.
  그 외에는 Tier 3 덕분에 항상 200으로 저장 가능한 결과가 나옵니다.

## Tier 1 API 자격 증명 (환경변수)

| 플랫폼 | 환경변수 | 비고 |
|---|---|---|
| 네이버 쇼핑 검색 | `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` | developers.naver.com 앱 등록 |
| 쿠팡 파트너스 | `COUPANG_ACCESS_KEY`, `COUPANG_SECRET_KEY` | 가입·승인 절차 필요 |
| 11번가 OpenAPI | `ELEVENST_API_KEY` | openapi.11st.co.kr |

미설정 시 해당 어댑터는 `skipped` 로 기록되고 Tier 2로 자연스럽게 폴백하므로,
키 없이도 엔진 전체는 정상 동작합니다.

## 실측 검증 기록 (2026-07-25, 이 저장소 환경에서 실행)

- **29CM** `products/1577769`, `products/3819652` → **Tier 2 성공.**
  JSON-LD에서 상품명·이미지·가격·브랜드·카테고리 전부 확보, `missing_fields: []`
- **무신사** `products/4715870` → **Tier 3 폴백.**
  무신사 robots.txt(2026-05-13 갱신)는 허용 목록 외 모든 봇(`User-agent: *`)에
  `Disallow: /` 를 적용. 준수 원칙에 따라 우회 없이 미리보기 저장으로 내려감.
  (전략 문서 4.4의 실측 당시와 달리 현재는 와일드카드 차단이 확인됨 —
  "특정 사이트가 제공을 중단하더라도 Tier 3으로 자동 전환되어 저장 기능은
  유지된다"는 설계가 실제로 동작한 사례)
