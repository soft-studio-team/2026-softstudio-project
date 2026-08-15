"""
데이터 모델
===========

전략 문서 5.1절의 데이터 모델을 그대로 코드로 옮긴 파일입니다.

핵심 원칙: 상품이 어느 경로(Tier 1/2/3)로 수집됐든 **동일한 구조로 정규화**하여
저장하고, 어떤 경로로 수집됐는지(source_type)를 반드시 함께 기록합니다.

source_type 을 기록하는 이유 (문서 5.1):
  1. 가격 추적 가능 여부(price_trackable) 등 기능 분기의 기준이 된다.
  2. 파싱 실패율을 플랫폼별로 모니터링해 어느 사이트의 구조가 바뀌었는지
     감지할 수 있다. (→ TierAttempt 추적 기록이 그 재료)
"""

from __future__ import annotations

import enum
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone


class SourceType(str, enum.Enum):
    """상품 정보가 어느 경로로 수집됐는지."""

    API = "API"            # Tier 1: 공식 오픈 API 응답
    METADATA = "METADATA"  # Tier 2: JSON-LD / Open Graph 표준 메타데이터
    MANUAL = "MANUAL"      # Tier 3: 미리보기 수준 + 사용자 보완 필요


class TierOutcome(str, enum.Enum):
    """각 티어 시도의 결과. 플랫폼별 실패율 모니터링의 단위 데이터."""

    SUCCESS = "success"    # 이 티어에서 상품 정보를 확보함
    SKIPPED = "skipped"    # 시도 조건이 안 되어 건너뜀 (예: API 미지원 플랫폼)
    FAILED = "failed"      # 시도했으나 실패 → 다음 티어로 폴백


class PurchasePriceStatus(str, enum.Enum):
    """`purchase_price`의 의미가 확인된 정도."""

    UNKNOWN = "unknown"
    PROVISIONAL = "provisional"
    CONFIRMED = "confirmed"
    OPTION_DEPENDENT = "option_dependent"


class PriceConfidence(str, enum.Enum):
    """숫자 추출이 아니라 가격의 의미 판정에 대한 신뢰도."""

    UNKNOWN = "unknown"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    VERIFIED = "verified"


class Availability(str, enum.Enum):
    """상품의 현재 구매 가능 상태. 가격과 독립적으로 관리한다."""

    UNKNOWN = "unknown"
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"


# 정규화된 상품 필드 중 "핵심"으로 간주하는 것.
# 이 중 빠진 필드는 missing_fields 로 내려보내 앱이 사용자 입력을 받게 한다.
CORE_FIELDS = ("title", "image_url", "price")


@dataclass
class Product:
    """정규화된 상품 한 건. (문서 5.1 Product 모델)

    값을 확보하지 못한 칸은 None으로 남깁니다.
    Tier 3 덕분에 original_url 은 항상 존재하므로 저장 자체는 절대 실패하지 않습니다.
    """

    original_url: str                    # 원본 상품 페이지 (탭 시 이동)
    title: str | None = None             # 상품명
    image_url: str | None = None         # 대표 이미지
    price: int | None = None             # 판매가/할인가 (실제 결제에 가까운 가격, 원)
    original_price: int | None = None    # 정가 (할인 전 가격, 원). 없으면 None
    discount_rate: int | None = None     # 할인율 (%). 정가 > 판매가일 때만 계산
    currency: str = "KRW"                # 통화
    brand: str | None = None             # 브랜드 (가능하면)
    seller: str | None = None            # 판매자/입점 스토어 (가능하면 — JSON-LD
                                         # offers.seller, 네이버 mallName 등)
    category: str | None = None          # 카테고리 (가능하면)
    description: str | None = None       # 설명 (og:description 등, 보조 정보)
    source_platform: str = "unknown"     # musinsa, coupang, naver, ...
    platform_label: str = ""             # 화면 표시용 쇼핑몰 이름 ("무신사", "쿠팡",
                                         # 미등록 사이트는 og:site_name 또는 도메인)
    source_type: SourceType = SourceType.MANUAL   # API | METADATA | MANUAL
    price_trackable: bool = False        # 가격 추적 가능 여부 (source_type에서 파생)
    purchase_price_status: PurchasePriceStatus = PurchasePriceStatus.UNKNOWN
    price_confidence: PriceConfidence = PriceConfidence.UNKNOWN
    availability: Availability = Availability.UNKNOWN
    option_dependent: bool | None = None
    option_price_min: int | None = None
    option_price_max: int | None = None
    price_evidence: list[dict] = field(default_factory=list)
    fetched_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def missing_core_fields(self) -> list[str]:
        """사용자 보완(Tier 3 UX)이 필요한 핵심 필드 목록."""
        return [name for name in CORE_FIELDS if getattr(self, name) in (None, "")]

    def apply_discount_rate(self) -> None:
        """정가·판매가가 모두 있고 정가가 더 클 때만 할인율을 채운다."""
        if (
            self.original_price
            and self.price
            and self.original_price > self.price
        ):
            saved = self.original_price - self.price
            self.discount_rate = round(saved / self.original_price * 100)
        else:
            self.discount_rate = None

    def to_dict(self) -> dict:
        data = asdict(self)
        data["schema_version"] = 2
        data["source_type"] = self.source_type.value
        data["purchase_price_status"] = self.purchase_price_status.value
        data["price_confidence"] = self.price_confidence.value
        data["availability"] = self.availability.value
        data["pricing"] = {
            "regular_price": self.original_price,
            "purchase_price": self.price,
            "purchase_price_status": self.purchase_price_status.value,
            "currency": self.currency,
            "option_dependent": self.option_dependent,
            "option_price_min": self.option_price_min,
            "option_price_max": self.option_price_max,
            "excluded_conditions": [
                "coupon", "membership", "card", "points", "shipping",
            ],
            "confidence": self.price_confidence.value,
            "evidence": self.price_evidence,
        }
        # price/original_price는 v1 앱과 저장 데이터용 호환 필드다.
        # 신규 소비자는 pricing 객체를 기준으로 읽는다.
        return data


def discount_rate_from(price: int | None, original_price: int | None) -> int | None:
    """정가·판매가로 할인율(%)을 계산한다. 할인이 아니면 None."""
    if price and original_price and original_price > price:
        return round((original_price - price) / original_price * 100)
    return None


@dataclass
class TierAttempt:
    """폴백 체인에서 한 티어를 시도한 기록.

    "source_type 기반 실패율 모니터링으로 구조 변화 감지"(문서 7절)를 위해
    어떤 티어가 왜 실패/스킵됐는지를 결과에 그대로 남깁니다.
    """

    tier: int                  # 1 | 2 | 3
    name: str                  # 예: "naver_api", "metadata", "preview"
    outcome: TierOutcome
    reason: str | None = None  # 실패/스킵 사유 (사람이 읽을 수 있는 문장)

    def to_dict(self) -> dict:
        return {
            "tier": self.tier,
            "name": self.name,
            "outcome": self.outcome.value,
            "reason": self.reason,
        }


@dataclass
class ParseResult:
    """파싱 엔진의 최종 응답.

    Tier 3이 항상 성공하므로 product 는 반드시 존재합니다.
    파싱 엔진의 실패가 앱의 실패로 이어지지 않는다는 설계 원칙(문서 5.4)의 구현.
    """

    product: Product
    resolved_tier: int                       # 최종적으로 채택된 티어 (1|2|3)
    missing_fields: list[str] = field(default_factory=list)  # 사용자 입력이 필요한 필드
    attempts: list[TierAttempt] = field(default_factory=list)  # 폴백 추적 기록
    from_cache: bool = False                 # 캐시에서 반환됐는지

    def to_dict(self) -> dict:
        return {
            "product": self.product.to_dict(),
            "resolved_tier": self.resolved_tier,
            "missing_fields": self.missing_fields,
            "attempts": [a.to_dict() for a in self.attempts],
            "from_cache": self.from_cache,
        }
