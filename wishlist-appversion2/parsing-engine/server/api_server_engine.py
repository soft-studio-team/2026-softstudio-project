"""
파싱 엔진 API 서버 (Figma·외부 앱 연동용)
==========================================

웹 시뮬레이터·Flutter 앱 없이 **파싱 API만** 제공하는 진입점입니다.
Figma로 만든 프론트엔드나 다른 클라이언트가 HTTP로 호출할 때 사용하세요.

    cd server
    pip install -r requirements.txt
    uvicorn api_server_engine:app --reload

주요 엔드포인트:
    POST /parse        {"url": "..."}              파싱만 (저장 안 함)
    POST /api/scrap    {"input": "공유 텍스트"}     파싱 + 위시리스트 저장
    GET  /api/products                               저장 목록
    PATCH /api/products/{id}                         사용자 보완 입력
    DELETE /api/products/{id}

API 문서: http://127.0.0.1:8000/docs
"""

from __future__ import annotations

import re
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from engine import InvalidUrlError, ParseResult, ProductParsingEngine
from wishlist_store import WishlistStore

app = FastAPI(
    title="위시리스트 상품 파싱 API (엔진 전용)",
    description="3단계 폴백(공식 API → 표준 메타데이터 → 미리보기+사용자 보완) 파싱 엔진",
    version="2.0.0",
)

engine = ProductParsingEngine()
store = WishlistStore()

_URL_RE = re.compile(r"https?://[^\s\"'<>]+")


def split_share_input(text: str) -> tuple[str | None, str | None]:
    match = _URL_RE.search(text or "")
    if match is None:
        return None, None
    remainder = (text[: match.start()] + " " + text[match.end() :]).strip()
    remainder = _URL_RE.sub("", remainder).strip(" -|:·,\n\t")
    hint = remainder if len(remainder) >= 3 else None
    return match.group(0), hint


class ParseRequest(BaseModel):
    url: str


class ScrapRequest(BaseModel):
    input: str


class UpdateFields(BaseModel):
    title: str | None = None
    # Canonical v2 names. price/original_price are accepted for v1 clients.
    purchase_price: int | None = None
    regular_price: int | None = None
    purchase_price_status: Literal[
        "unknown", "provisional", "confirmed", "option_dependent"
    ] | None = None
    availability: Literal["unknown", "available", "unavailable"] | None = None
    option_dependent: bool | None = None
    option_price_min: int | None = None
    option_price_max: int | None = None
    price: int | None = None
    original_price: int | None = None
    image_url: str | None = None
    brand: str | None = None
    seller: str | None = None
    category: str | None = None


def _to_app_item(result: ParseResult) -> dict:
    product = result.product.to_dict()
    product["id"] = product["original_url"]
    product["resolved_tier"] = result.resolved_tier
    product["missing_fields"] = result.missing_fields
    return product


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/parse")
def parse(request: ParseRequest) -> dict:
    try:
        result = engine.parse(request.url)
    except InvalidUrlError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e
    return result.to_dict()


@app.post("/api/scrap")
def scrap(request: ScrapRequest) -> dict:
    url, hint = split_share_input(request.input)
    if url is None:
        raise HTTPException(status_code=400, detail="공유한 내용에서 링크를 찾지 못했어요.")
    try:
        result = engine.parse(url, title_hint=hint)
    except InvalidUrlError as e:
        raise HTTPException(status_code=400, detail=f"링크 형식이 올바르지 않아요: {e}") from e

    item = _to_app_item(result)
    is_new = store.upsert(item)
    return {"product": item, "isNew": is_new}


@app.get("/api/products")
def products() -> list[dict]:
    return store.list_items()


@app.patch("/api/products/{item_id:path}")
def update_product(item_id: str, fields: UpdateFields) -> dict:
    from engine.models import discount_rate_from

    updates = {k: v for k, v in fields.model_dump().items() if v is not None}
    if "purchase_price" in updates:
        updates["price"] = updates.pop("purchase_price")
    if "regular_price" in updates:
        updates["original_price"] = updates.pop("regular_price")
    if "price" in updates and "purchase_price_status" not in updates:
        # PATCH의 가격은 사용자가 직접 확인·입력한 값으로 취급한다.
        updates["purchase_price_status"] = "confirmed"
    if not updates:
        raise HTTPException(status_code=400, detail="갱신할 필드가 없어요.")
    item = store.update_fields(item_id, updates)
    if item is None:
        raise HTTPException(status_code=404, detail="해당 상품을 찾지 못했어요.")
    if "price" in updates or "original_price" in updates:
        rate = discount_rate_from(item.get("price"), item.get("original_price"))
        item = store.update_fields(item_id, {"discount_rate": rate}) or item
        item["discount_rate"] = rate
    pricing = dict(item.get("pricing") or {})
    pricing.update({
        "regular_price": item.get("original_price"),
        "purchase_price": item.get("price"),
        "purchase_price_status": item.get(
            "purchase_price_status", "unknown"
        ),
        "currency": item.get("currency", "KRW"),
        "option_dependent": item.get("option_dependent"),
        "option_price_min": item.get("option_price_min"),
        "option_price_max": item.get("option_price_max"),
        "excluded_conditions": [
            "coupon", "membership", "card", "points", "shipping",
        ],
    })
    if "price" in updates:
        pricing["confidence"] = "high"
        pricing["evidence"] = [{
            "price_role": "purchase_price",
            "source": "manual",
            "adapter": None,
            "field": "user_input",
        }]
        item["price_confidence"] = "high"
    item["pricing"] = pricing
    store.update_fields(item_id, {
        "pricing": pricing,
        "price_confidence": item.get("price_confidence", "unknown"),
    })
    item["missing_fields"] = [
        f for f in item.get("missing_fields", []) if f not in updates
    ]
    store.update_fields(item_id, {"missing_fields": item["missing_fields"]})
    return item


@app.delete("/api/products/{item_id:path}")
def delete_product(item_id: str) -> dict:
    deleted = store.delete(item_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="해당 상품을 찾지 못했어요.")
    return {"deleted": True}
