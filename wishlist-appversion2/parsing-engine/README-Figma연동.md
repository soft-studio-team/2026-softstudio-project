# 파싱 엔진 — Figma·외부 앱 연동용

Figma로 만든 앱 UI에서 **이 zip의 서버만** 붙이면 됩니다.  
Flutter 테스트 앱(`app/`)과 웹 시뮬레이터(`static/simulator.html`)는 **포함하지 않았습니다.**

## zip 안 구조

```text
parsing-engine/
├── README-Figma연동.md      ← 지금 읽고 있는 파일
├── server/
│   ├── api_server_engine.py   ★ Figma 연동 시 이 파일로 서버 실행
│   ├── engine/                ★ 파싱 엔진 본체 (Tier 1→2→3)
│   ├── wishlist_store.py        간단 JSON 저장 (데모용, 나중에 DB로 교체 가능)
│   ├── requirements.txt
│   └── tests/
└── docs/
    └── parsing-engine-design.html
```

### 전체 테스트 zip과의 차이

| | `wishlist-app-test.zip` | `parsing-engine.zip` (이 파일) |
|---|------------------------|-------------------------------|
| `server/engine/` | ✅ | ✅ |
| API 서버 | `api_server.py` (+ 웹 시뮬레이터) | `api_server_engine.py` (API만) |
| `app/` Flutter | ✅ | ❌ |
| `static/simulator.html` | ✅ | ❌ |

> **맞아요** — 전체 zip에서 시뮬레이션용 코드(`app/`, 웹 시뮬레이터)만 빼면 이 패키지와 같습니다.

## 서버 실행

```bash
cd server
pip3 install -r requirements.txt
python3 -m uvicorn api_server_engine:app --reload
```

- API 문서: http://127.0.0.1:8000/docs
- 헬스체크: http://127.0.0.1:8000/health

## Figma 앱에서 호출할 API

### 1. 파싱만 (저장 안 함) — 화면 미리보기·검증용

```http
POST /parse
Content-Type: application/json

{"url": "https://www.29cm.co.kr/products/1577769"}
```

응답 예시 (핵심 필드):

```json
{
  "product": {
    "title": "퀸 비키니 브라_화이트",
    "image_url": "https://...",
    "price": 109000,
    "original_price": 129000,
    "discount_rate": 16,
    "brand": "아그넬",
    "seller": null,
    "platform_label": "29CM",
    "original_url": "https://www.29cm.co.kr/products/1577769",
    "source_type": "METADATA"
  },
  "resolved_tier": 2,
  "missing_fields": []
}
```

| 필드 | 의미 |
|------|------|
| `platform_label` | 쇼핑몰 이름 |
| `original_url` | 상품 URL (항상 저장) |
| `title` | 상품명 |
| `price` | 판매가/할인가 |
| `original_price` | 정가 (없으면 null) |
| `discount_rate` | 할인율 % (정가 > 판매가일 때만) |
| `image_url` | 상품 이미지 |

- `resolved_tier`: 1=공식 API, 2=메타데이터(제목+이미지+판매가), 3=미리보기+사용자 입력
- `missing_fields` 가 비어 있지 않으면 → UI에서 해당 필드만 입력받으면 됨 (`price` 등)

### 2. 파싱 + 저장 — 위시리스트 담기

```http
POST /api/scrap
Content-Type: application/json

{"input": "트임 슬릿 롱 원피스 https://m.a-bly.com/goods/10062919"}
```

공유 텍스트 전체를 넣어도 서버가 URL과 상품명 힌트를 분리합니다.

응답:

```json
{
  "product": { "...": "..." },
  "isNew": true
}
```

### 3. 목록 / 수정 / 삭제

| 메서드 | 경로 | 용도 |
|--------|------|------|
| GET | `/api/products` | 저장된 목록 |
| PATCH | `/api/products/{id}` | 빠진 필드 보완 (`{"price": 12900}`) |
| DELETE | `/api/products/{id}` | 삭제 |

`{id}` 는 `original_url` 과 동일합니다.

## Figma / 프론트 연동 체크리스트

1. **베이스 URL** — 개발: `http://127.0.0.1:8000` (실기기는 맥 IP + `--host 0.0.0.0`)
2. **CORS** — Figma Make / 웹뷰에서 다른 origin이면 FastAPI에 CORS 미들웨어 추가 필요 (배포 시)
3. **흐름** — URL 입력 → `POST /parse` → `missing_fields` 확인 → Tier 3이면 가격 입력 UI → `PATCH`
4. **에이블리 등 차단 사이트** — Tier 3으로 저장되며, 공유 텍스트에 상품명이 있으면 `title` 은 미리 채워짐. (기기 WebView 폴백은 추후 앱 레이어에서 추가 예정)

## Python에서 직접 쓰기 (서버 없이)

```python
from engine import ProductParsingEngine

result = ProductParsingEngine().parse("https://www.29cm.co.kr/products/1577769")
print(result.product.title, result.resolved_tier, result.missing_fields)
```

## 테스트

```bash
cd server
python3 -m pytest tests/ -q
```

## Tier 1 API 키 (선택)

| 플랫폼 | 환경변수 |
|--------|----------|
| 네이버 | `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` |
| 쿠팡 | `COUPANG_ACCESS_KEY`, `COUPANG_SECRET_KEY` |
| 11번가 | `ELEVENST_API_KEY` |

미설정 시 Tier 2/3으로 자동 폴백합니다.
