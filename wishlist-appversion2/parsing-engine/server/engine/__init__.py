"""
상품 정보 수집 파싱 엔진 — 3단계 폴백 아키텍처
================================================

전략 문서("상품정보-수집전략")의 구현체.

    from engine import ProductParsingEngine
    result = ProductParsingEngine().parse("https://www.musinsa.com/products/4715870")
    print(result.product.title, result.resolved_tier)
"""

from .models import (
    Availability,
    ParseResult,
    PriceConfidence,
    Product,
    PurchasePriceStatus,
    SourceType,
    TierAttempt,
    TierOutcome,
)
from .pipeline import InvalidUrlError, ProductParsingEngine

__all__ = [
    "ProductParsingEngine",
    "InvalidUrlError",
    "ParseResult",
    "Product",
    "PurchasePriceStatus",
    "PriceConfidence",
    "Availability",
    "SourceType",
    "TierAttempt",
    "TierOutcome",
]
