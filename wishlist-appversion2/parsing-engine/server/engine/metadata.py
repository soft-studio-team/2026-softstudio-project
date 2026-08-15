"""
표준 메타데이터 파서: JSON-LD(Product) + Open Graph
=====================================================

문서 4절의 두 표준을 파싱합니다. 둘 다 사이트 운영자가 **외부 서비스에
읽히기를 의도하고 직접 넣어둔** 기계 판독용 데이터입니다.

  - JSON-LD / schema.org Product (4.2) — 구글 리치 결과(SEO)용.
    가격(offers.price)이 포함된 경우가 많아 **우선** 파싱한다.
  - Open Graph (4.1) — 링크 공유 미리보기용. 제목·이미지는 거의 항상 있다.

화면용 DOM(CSS 셀렉터)은 읽지 않습니다. 그래서 사이트가 화면을 개편해도
이 파서는 깨지지 않으며, 사이트별 셀렉터 유지보수가 존재하지 않습니다.
범용 파서 하나로 모든 사이트를 커버합니다. (문서 5.3 안정성 근거)
"""

from __future__ import annotations

import html as html_module
import json
import re
from dataclasses import dataclass, field
from urllib.parse import urljoin

from bs4 import BeautifulSoup


@dataclass
class ExtractedMetadata:
    """HTML 한 페이지에서 뽑아낸 표준 메타데이터 필드 모음."""

    title: str | None = None
    image_url: str | None = None
    price: int | None = None              # 판매가/할인가
    original_price: int | None = None     # 정가 (할인 전)
    price_source: str | None = None       # 채택한 구매 가격 후보 필드
    regular_price_source: str | None = None
    currency: str | None = None
    brand: str | None = None
    seller: str | None = None           # 판매자/입점 스토어 (JSON-LD offers.seller)
    category: str | None = None
    description: str | None = None
    og_type: str | None = None          # "product" 여부로 상품 페이지 판정에 활용
    site_name: str | None = None        # og:site_name — 미등록 사이트의 표시 이름
    canonical_url: str | None = None    # og:url
    sources: list[str] = field(default_factory=list)  # ["json-ld", "open-graph", ...]

    def has_product_core(self) -> bool:
        """Tier 2 성공 판정: 제목·이미지·가격이 모두 있어야 한다.

        가격이 빠진 채로는 '상품 카드 완성'이 아니므로 Tier 3으로 내려가
        제목·이미지는 미리 채우고 가격만 사용자 입력을 받는다.
        """
        return bool(self.title) and bool(self.image_url) and self.price is not None

    def has_anything(self) -> bool:
        """Tier 3 판정: 제목 하나라도 있으면 미리보기 저장이 가능하다."""
        return bool(self.title) or bool(self.image_url) or bool(self.description)


# ---------------------------------------------------------------------------
# 가격 정규화
# ---------------------------------------------------------------------------

_PRICE_RE = re.compile(r"[-+]?\d[\d,]*(?:\.\d+)?")


def normalize_price(value) -> int | None:
    """schema.org price 값을 원 단위 정수로 정규화한다.

    실제 사이트들의 표기가 제각각이라 모두 수용한다:
    89000, "89000", "89,000", "89000.0", "₩89,000", "89000원"
    """
    if value is None:
        return None
    if isinstance(value, bool):  # bool은 int의 하위 타입이므로 먼저 걸러낸다
        return None
    if isinstance(value, (int, float)):
        return int(value) if value > 0 else None
    if isinstance(value, str):
        m = _PRICE_RE.search(value.replace(" ", ""))
        if not m:
            return None
        try:
            number = float(m.group(0).replace(",", ""))
        except ValueError:
            return None
        return int(number) if number > 0 else None
    return None


# ---------------------------------------------------------------------------
# JSON-LD (schema.org Product) — 우선 파싱
# ---------------------------------------------------------------------------

def _iter_jsonld_nodes(document):
    """JSON-LD 문서에서 모든 노드를 평탄화해 순회한다.

    사이트마다 최상위가 dict, list, 또는 {"@graph": [...]} 로 제각각이라
    세 경우를 모두 펼친다.
    """
    stack = [document]
    while stack:
        node = stack.pop()
        if isinstance(node, list):
            stack.extend(node)
        elif isinstance(node, dict):
            yield node
            graph = node.get("@graph")
            if isinstance(graph, list):
                stack.extend(graph)


def _node_is_type(node: dict, type_name: str) -> bool:
    declared = node.get("@type")
    if isinstance(declared, list):
        return any(str(t).lower() == type_name.lower() for t in declared)
    return str(declared).lower() == type_name.lower()


def _first_str(value) -> str | None:
    """schema.org 필드는 문자열/리스트/객체가 모두 올 수 있어 방어적으로 편다."""
    if isinstance(value, str):
        return value.strip() or None
    if isinstance(value, list):
        for item in value:
            found = _first_str(item)
            if found:
                return found
        return None
    if isinstance(value, dict):
        # {"@type": "Brand", "name": "나이키"} / {"url": "..."} 형태
        return _first_str(value.get("name")) or _first_str(value.get("url"))
    return None


def _price_type_is_list(price_type) -> bool:
    """schema.org priceType 이 정가(ListPrice 등)인지 본다."""
    if price_type is None:
        return False
    values = price_type if isinstance(price_type, list) else [price_type]
    markers = ("listprice", "strikethroughprice", "regularprice", "msrp")
    for value in values:
        text = str(value).lower().replace(" ", "").replace("_", "")
        if any(marker in text for marker in markers):
            return True
    return False


def _price_type_is_conditional(price_type) -> bool:
    """쿠폰·회원 등 사용자 조건이 필요한 가격 유형인지 본다."""
    if price_type is None:
        return False
    values = price_type if isinstance(price_type, list) else [price_type]
    markers = (
        "coupon", "member", "membership", "loyalty", "subscription",
        "voucher", "promo", "promotional",
    )
    for value in values:
        text = str(value).lower().replace(" ", "").replace("_", "")
        if any(marker in text for marker in markers):
            return True
    return False


def _offer_is_conditional(offer: dict) -> bool:
    """로그인·등급·쿠폰 소유 여부에 따라 달라지는 Offer를 제외한다."""
    if _price_type_is_conditional(offer.get("priceType")):
        return True
    return any(offer.get(key) not in (None, "", [], {}) for key in (
        "validForMemberTier", "membershipPointsEarned",
    ))


def _extract_from_price_specification(spec) -> tuple[int | None, int | None, str | None]:
    """priceSpecification 에서 (판매가, 정가, 통화)를 뽑는다."""
    if isinstance(spec, list):
        sale = original = currency = None
        for item in spec:
            s, o, c = _extract_from_price_specification(item)
            if s is not None and sale is None:
                sale = s
            if o is not None and original is None:
                original = o
            currency = currency or c
        return sale, original, currency
    if not isinstance(spec, dict):
        return None, None, None
    amount = normalize_price(spec.get("price") or spec.get("priceAmount"))
    currency = _first_str(spec.get("priceCurrency"))
    if _price_type_is_conditional(spec.get("priceType")) or _offer_is_conditional(spec):
        return None, None, currency
    if _price_type_is_list(spec.get("priceType")):
        return None, amount, currency
    return amount, None, currency


def _extract_offer(offers) -> tuple[int | None, int | None, str | None]:
    """offers 에서 (판매가, 정가, 통화)를 뽑는다.

    Offer / AggregateOffer / 리스트 / priceSpecification 을 지원한다.
    정가 후보: listPrice, originalPrice, priceSpecification(ListPrice).
    AggregateOffer 의 highPrice 는 옵션별 최고가일 수 있어 정가로 쓰지 않는다.
    """
    if isinstance(offers, list):
        for offer in offers:
            price, original, currency = _extract_offer(offer)
            if price is not None or original is not None:
                return price, original, currency
        return None, None, None
    if not isinstance(offers, dict):
        return None, None, None

    if _offer_is_conditional(offers):
        return None, None, _first_str(offers.get("priceCurrency"))

    price = normalize_price(
        offers.get("price")
        or offers.get("lowPrice")          # AggregateOffer — 최저 판매가
    )
    original = normalize_price(
        offers.get("listPrice")
        or offers.get("originalPrice")
        or offers.get("priceBeforeDiscount")
    )
    currency = _first_str(offers.get("priceCurrency"))

    if isinstance(offers.get("priceSpecification"), (dict, list)):
        spec_sale, spec_original, spec_currency = _extract_from_price_specification(
            offers["priceSpecification"]
        )
        if price is None:
            price = spec_sale
        if original is None:
            original = spec_original
        currency = currency or spec_currency

    # 정가가 판매가보다 작거나 같으면 할인 정보가 아님
    if original is not None and price is not None and original <= price:
        original = None
    return price, original, currency


def _extract_seller(offers) -> str | None:
    """offers 에서 판매자 이름을 뽑는다.

    {"seller": {"@type": "Organization", "name": "행복한스토어"}} 형태가 표준이며,
    오픈마켓/스마트스토어형 사이트들이 입점 판매자를 여기에 넣는다.
    """
    if isinstance(offers, list):
        for offer in offers:
            seller = _extract_seller(offer)
            if seller:
                return seller
        return None
    if not isinstance(offers, dict):
        return None
    return _first_str(offers.get("seller"))


def parse_jsonld_product(soup: BeautifulSoup, base_url: str) -> ExtractedMetadata | None:
    """<script type="application/ld+json"> 블록들에서 Product 노드를 찾는다."""
    for script in soup.find_all("script", attrs={"type": "application/ld+json"}):
        text = script.string or script.get_text()
        if not text or not text.strip():
            continue
        try:
            document = json.loads(html_module.unescape(text))
        except (json.JSONDecodeError, ValueError):
            continue  # 깨진 JSON-LD 블록은 무시하고 다음 블록으로
        for node in _iter_jsonld_nodes(document):
            if not _node_is_type(node, "Product"):
                continue
            price, original_price, currency = _extract_offer(node.get("offers"))
            image = _first_str(node.get("image"))
            meta = ExtractedMetadata(
                title=_first_str(node.get("name")),
                image_url=urljoin(base_url, image) if image else None,
                price=price,
                original_price=original_price,
                price_source=(
                    "json-ld:offers" if price is not None else None
                ),
                regular_price_source=(
                    "json-ld:offers:list-price"
                    if original_price is not None else None
                ),
                currency=currency,
                brand=_first_str(node.get("brand")),
                seller=_extract_seller(node.get("offers")),
                category=_first_str(node.get("category")),
                description=_first_str(node.get("description")),
                sources=["json-ld"],
            )
            if meta.title:  # 이름조차 없는 Product 노드는 신뢰하지 않는다
                return meta
    return None


# ---------------------------------------------------------------------------
# Open Graph — JSON-LD 로 못 채운 칸을 보완
# ---------------------------------------------------------------------------

_OG_PRICE_KEYS = ("product:price:amount", "og:price:amount")
_OG_CURRENCY_KEYS = ("product:price:currency", "og:price:currency")


def parse_open_graph(soup: BeautifulSoup, base_url: str) -> ExtractedMetadata | None:
    tags: dict[str, str] = {}
    for tag in soup.find_all("meta"):
        key = tag.get("property") or tag.get("name")
        content = tag.get("content")
        if key and content and key not in tags:
            tags[key.strip().lower()] = content.strip()

    def get(*keys: str) -> str | None:
        for key in keys:
            value = tags.get(key)
            if value:
                return value
        return None

    image = get("og:image", "og:image:url", "twitter:image")
    title = get("og:title", "twitter:title")
    if not title and soup.title and soup.title.get_text(strip=True):
        title = soup.title.get_text(strip=True)  # 최후 보루: <title>

    price = normalize_price(get(*_OG_PRICE_KEYS))
    # Facebook 상품 OG: product:price:amount=정가, product:sale_price:amount=할인가
    sale = normalize_price(get("product:sale_price:amount", "og:sale_price:amount"))
    listed = normalize_price(get(
        "product:original_price:amount", "og:original_price:amount",
        "product:price:normal_price",
    ))
    original_price = listed
    if sale is not None and price is not None and sale < price:
        # price 가 정가, sale 이 할인가인 관례
        original_price = price
        price = sale
    elif sale is not None and price is None:
        price = sale

    if original_price is not None and price is not None and original_price <= price:
        original_price = None

    meta = ExtractedMetadata(
        title=title,
        image_url=urljoin(base_url, image) if image else None,
        price=price,
        original_price=original_price,
        price_source=(
            "open-graph:product:sale_price:amount"
            if sale is not None and price == sale
            else "open-graph:product:price:amount"
            if price is not None else None
        ),
        regular_price_source=(
            "open-graph:regular-price" if original_price is not None else None
        ),
        currency=get(*_OG_CURRENCY_KEYS),
        description=get("og:description", "description", "twitter:description"),
        og_type=get("og:type"),
        site_name=get("og:site_name"),
        canonical_url=get("og:url"),
        sources=["open-graph"],
    )
    return meta if meta.has_anything() else None


# ---------------------------------------------------------------------------
# 통합: JSON-LD 우선 + OG 보완 (문서 5.3 동작 2~3단계)
# ---------------------------------------------------------------------------

def extract_metadata(html: str, base_url: str) -> ExtractedMetadata | None:
    """HTML에서 표준 메타데이터를 추출한다.

    JSON-LD(가격 포함 가능성 높음)를 우선 채택하고, JSON-LD가 없거나
    불완전하면 Open Graph 값으로 빈 칸만 보완한다.
    """
    soup = BeautifulSoup(html, "lxml")
    jsonld = parse_jsonld_product(soup, base_url)
    og = parse_open_graph(soup, base_url)

    if jsonld is None:
        return og
    if og is None:
        return jsonld

    # JSON-LD 를 기준으로, 비어 있는 필드만 OG 값으로 채운다.
    for field_name in ("title", "image_url", "price", "original_price",
                       "price_source", "regular_price_source", "currency",
                       "brand", "seller", "category", "description"):
        if getattr(jsonld, field_name) in (None, "") and getattr(og, field_name):
            setattr(jsonld, field_name, getattr(og, field_name))
    jsonld.og_type = og.og_type
    jsonld.site_name = og.site_name
    jsonld.canonical_url = og.canonical_url
    jsonld.sources = jsonld.sources + og.sources
    return jsonld
