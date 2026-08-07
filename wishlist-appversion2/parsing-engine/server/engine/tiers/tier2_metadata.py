"""
Tier 2 — 표준 메타데이터 파싱 (문서 5.3)
==========================================

대상: 공식 API가 없는 플랫폼 (무신사, 29CM, W컨셉, 에이블리, 나이키 등).

동작은 파이프라인이 확보한 페이지 스냅샷(HTTP GET 1회의 결과)에서
JSON-LD → Open Graph 순으로 추출된 메타데이터(metadata.extract_metadata)를
정규화된 Product 로 변환하는 것뿐입니다. 요청·robots.txt·캐싱은 fetch 계층,
파싱은 metadata 계층이 맡고 있으므로 이 모듈은 "성공 판정과 정규화"만 합니다.

성공 판정: 상품명 + 이미지 + 가격이 모두 있어야 Tier 2.
가격이 없으면 Tier 3으로 내려가, 얻은 제목·이미지는 미리 채우고
가격만 사용자가 입력한다 ("빠진 것만 확인" UX).
"""

from __future__ import annotations

from ..metadata import ExtractedMetadata
from ..models import Product, SourceType, discount_rate_from


def build_metadata_product(
    meta: ExtractedMetadata, original_url: str,
    platform: str, platform_label: str,
) -> Product | None:
    """추출된 메타데이터가 핵심 필드(제목·이미지·가격)를 모두 갖추면 Product 로 정규화한다.

    하나라도 없으면 None 을 반환하고 Tier 3으로 폴백한다.
    """
    if not meta.has_product_core():
        return None
    product = Product(
        original_url=original_url,
        title=meta.title,
        image_url=meta.image_url,
        price=meta.price,
        original_price=meta.original_price,
        discount_rate=discount_rate_from(meta.price, meta.original_price),
        currency=meta.currency or "KRW",
        brand=meta.brand,
        seller=meta.seller,
        category=meta.category,
        description=meta.description,
        source_platform=platform,
        platform_label=platform_label,
        source_type=SourceType.METADATA,
        # 가격 변동 추적은 공식 API 재조회가 가능한 Tier 1부터 지원한다(문서 6).
        # Tier 2는 "주기적 재파싱으로 제한적 지원 검토" 단계이므로 아직 False.
        price_trackable=False,
    )
    return product
