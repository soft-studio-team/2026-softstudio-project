"""
Tier 3 — 미리보기 수준 저장 + 사용자 보완 (문서 5.4)
======================================================

대상: 메타데이터조차 불완전한 사이트, 또는 상위 티어가 모두 실패한 경우.

이 티어는 **절대 실패하지 않습니다**. 카카오톡 미리보기 카드 수준의 최소
정보(제목, 대표 이미지, 원본 링크)를 저장하고, 얻은 정보는 전부 미리
채워둔 뒤 빠진 항목(주로 가격)만 사용자가 입력·수정하게 합니다.

UX 원칙: "전부 수동 입력"이 아니라 "빠진 것만 확인".
어떤 사이트가 와도 저장 자체는 항상 성공하므로, 파싱 엔진의 실패가
앱의 실패로 이어지지 않습니다.
"""

from __future__ import annotations

from ..metadata import ExtractedMetadata
from ..models import (
    PriceConfidence,
    Product,
    PurchasePriceStatus,
    SourceType,
    discount_rate_from,
)


def build_preview_product(
    meta: ExtractedMetadata | None, original_url: str,
    platform: str, platform_label: str,
) -> Product:
    """얻은 것은 전부 채우고, 최소한 원본 링크만으로도 Product 를 만든다."""
    price = meta.price if meta else None
    original_price = meta.original_price if meta else None
    return Product(
        original_url=original_url,
        title=meta.title if meta else None,
        image_url=meta.image_url if meta else None,
        price=price,
        original_price=original_price,
        discount_rate=discount_rate_from(price, original_price),
        currency=(meta.currency if meta and meta.currency else "KRW"),
        brand=meta.brand if meta else None,
        seller=meta.seller if meta else None,
        category=meta.category if meta else None,
        description=meta.description if meta else None,
        source_platform=platform,
        platform_label=platform_label,
        source_type=SourceType.MANUAL,
        price_trackable=False,  # 문서 6: Tier 3 가격 추적 미지원
        purchase_price_status=(
            PurchasePriceStatus.PROVISIONAL
            if price is not None else PurchasePriceStatus.UNKNOWN
        ),
        price_confidence=(
            PriceConfidence.LOW if price is not None else PriceConfidence.UNKNOWN
        ),
        price_evidence=([{
            "price_role": "purchase_price",
            "source": "metadata",
            "adapter": None,
            "field": meta.price_source,
        }] if meta and price is not None else []),
    )
