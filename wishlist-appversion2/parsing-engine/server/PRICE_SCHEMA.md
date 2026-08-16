# 가격 JSON 스키마 v2

엔진의 목표 가격은 두 가지이며 서로 독립적이다.

- `regular_price`: 할인 전 기준 가격(정가). 알 수 없으면 `null`.
- `purchase_price`: 로그인, 쿠폰, 회원등급, 카드, 포인트 없이 상품 1개를 살 때의 상품 단가. 배송비와 옵션 추가금은 제외한다. 알 수 없으면 `null`.

한 가격을 모른다고 다른 가격으로 대신 채우지 않는다. 특히 정가만 확인된 상품은 `regular_price`만 숫자이고 `purchase_price`는 `null`이어야 한다.

```json
{
  "schema_version": 2,
  "pricing": {
    "regular_price": 32000,
    "purchase_price": 30400,
    "purchase_price_status": "confirmed",
    "currency": "KRW",
    "option_dependent": false,
    "option_price_min": null,
    "option_price_max": null,
    "excluded_conditions": [
      "coupon",
      "membership",
      "card",
      "points",
      "shipping"
    ],
    "confidence": "high",
    "evidence": [
      {
        "price_role": "purchase_price",
        "source": "metadata",
        "adapter": "musinsa",
        "field": "product:price:amount"
      }
    ]
  },
  "availability": "available"
}
```

## 상태값

`purchase_price_status`:

- `unknown`: 조건 없는 구매 가격을 얻지 못함. 화면의 주 가격으로 표시하지 않는다.
- `provisional`: 숫자는 얻었지만 쿠폰가인지 조건 없는 가격인지 아직 확정하지 못함.
- `confirmed`: 쇼핑몰별 명시 필드, 고정 조건의 옵션 선택 또는 장바구니로 의미를 확인함.
- `option_dependent`: 옵션별 가격이 달라 단일 가격으로 확정할 수 없음. 판단하지 못하면 `null`이며, 가능하면 `option_price_min/max`를 함께 제공한다.

`confidence`는 `unknown`, `low`, `medium`, `high`, `verified` 중 하나다. `availability`는 `unknown`, `available`, `unavailable` 중 하나이며 가격과 별도로 판정한다.

## 표시 규칙

- `confirmed`: `purchase_price`를 주 가격으로 표시한다.
- `provisional`: 임시 가격 또는 확인 필요로 표시한다. 확정 가격처럼 보이면 안 된다.
- `option_dependent`: 범위가 있으면 범위로 표시하고, 없으면 옵션 선택 필요로 표시한다.
- `unknown`: 구매 가격을 숨기고 정가만 있으면 정가만 표시한다.
- 쿠폰가·회원가·카드가·포인트 사용가는 이 객체에 넣지 않는다. 나중에 필요하면 별도의 `conditional_offers` 영역으로 추가한다.

## 하위 호환

기존 `price`는 `pricing.purchase_price`, `original_price`는 `pricing.regular_price`의 호환용 별칭이다. 새 코드는 반드시 `pricing`을 먼저 읽는다.
