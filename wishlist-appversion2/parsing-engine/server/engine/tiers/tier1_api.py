"""
Tier 1 — 공식 오픈 API 연동 (문서 5.2)
========================================

대상: 쿠팡(파트너스 API), 네이버(쇼핑 검색 API), 11번가(OpenAPI).
오픈마켓형 플랫폼은 외부 유입 트래픽이 곧 수익이므로 API를 공식 제공한다(문서 3.1).

주의할 설계 포인트 — 이들 API는 대부분 **검색 API**다. "URL을 넣으면 상품이
나오는" 구조가 아니므로 다음 흐름을 구현한다:

  1. URL에서 플랫폼 식별            → urltools.analyze_url (파이프라인이 수행)
  2. URL에서 상품 식별자 추출        → urltools.analyze_url (파이프라인이 수행)
  3. 식별자 직접 조회가 안 되면, 페이지 제목에서 얻은 상품명으로 API 검색 후
     결과를 매칭 (식별자 일치 → 이름 유사도 순)             → match_candidates
  4. 응답에서 상품명·이미지·가격을 정규화 저장               → 각 어댑터

제약사항(문서 5.2)을 그대로 구현에 반영:
  - API 키는 환경변수로 주입하며, 미설정 시 어댑터는 "skipped"로 표시되고
    파이프라인은 Tier 2로 폴백한다. (승인 절차가 있는 쿠팡 파트너스 등)
  - 호출량 제한이 있으므로 파이프라인 수준에서 결과를 캐싱한다.
  - 매칭 실패 시 해당 URL은 Tier 2로 폴백한다.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Callable, Protocol

from ..models import Product, SourceType, discount_rate_from
from ..urltools import UrlInfo

API_TIMEOUT = 8.0


class LookupContext(Protocol):
    """어댑터가 파이프라인에서 받는 조회 컨텍스트.

    - url_info: 현재까지 해석된 URL 정보. title_hint() 호출로 페이지를
      가져온 뒤에는 단축링크가 풀린 최종 URL 기준으로 갱신되어 있을 수 있다.
    - title_hint(): 페이지 제목(상품명 힌트). **필요할 때만** 호출해야 한다 —
      호출 시점에 페이지 GET 1회가 발생하며, 그 결과는 Tier 2와 공유된다
      (URL당 GET 1회 원칙).
    """

    @property
    def url_info(self) -> UrlInfo: ...

    def title_hint(self) -> str | None: ...

# 테스트에서 실제 네트워크 없이 어댑터를 검증할 수 있도록 전송 계층을 주입 가능하게 한다.
# (url, headers) -> (status_code, body_bytes)
Transport = Callable[[str, dict], tuple[int, bytes]]


def _default_transport(url: str, headers: dict) -> tuple[int, bytes]:
    request = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=API_TIMEOUT) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


class AdapterError(Exception):
    """API 호출/매칭 실패. 파이프라인은 이를 받아 Tier 2로 폴백한다."""


@dataclass
class ApiCandidate:
    """API 검색 결과 한 건을 매칭용으로 정규화한 것."""

    product_id: str | None
    title: str
    image_url: str | None
    price: int | None
    original_price: int | None = None  # 정가 (네이버 hprice 등)
    brand: str | None = None
    seller: str | None = None      # 판매자/입점 스토어 (네이버 mallName 등)
    category: str | None = None


# ---------------------------------------------------------------------------
# 매칭: 식별자 일치 → 이름 유사도 순 (문서 5.2 흐름 3)
# ---------------------------------------------------------------------------

_TAG_RE = re.compile(r"<[^>]+>")

# 이름 유사도 매칭의 최소 신뢰 기준. 이보다 낮으면 "다른 상품"으로 보고
# 잘못된 데이터를 저장하느니 Tier 2로 폴백하는 것을 택한다.
MIN_TITLE_SIMILARITY = 0.55


def strip_html_tags(text: str) -> str:
    """네이버 쇼핑 검색 응답의 title 은 <b>키워드</b> 마크업을 포함한다."""
    return _TAG_RE.sub("", text)


def clean_title_for_search(title: str) -> str:
    """페이지 제목을 검색 키워드로 다듬는다.

    og:title 은 보통 "상품명 - 사이즈 & 후기 | 무신사" 처럼 사이트 이름과
    상투구가 붙어 있으므로, 구분자 뒤 꼬리를 잘라 상품명만 남긴다.
    """
    cleaned = strip_html_tags(title)
    for separator in (" | ", " - ", " – ", " :: "):
        if separator in cleaned:
            cleaned = cleaned.split(separator)[0]
    return cleaned.strip()


def title_similarity(a: str, b: str) -> float:
    normalize = lambda s: re.sub(r"\s+", " ", strip_html_tags(s)).strip().lower()
    return SequenceMatcher(None, normalize(a), normalize(b)).ratio()


def match_candidates(
    candidates: list[ApiCandidate],
    product_id: str | None,
    keyword: str | None,
) -> ApiCandidate | None:
    """검색 결과에서 우리가 찾는 상품을 고른다. 확신이 없으면 None(→ 폴백)."""
    if not candidates:
        return None
    # 1순위: 상품 식별자 일치 — 가장 확실한 매칭
    if product_id:
        for candidate in candidates:
            if candidate.product_id and str(candidate.product_id) == str(product_id):
                return candidate
    # 2순위: 이름 유사도 — 기준 미달이면 채택하지 않는다
    if keyword:
        best = max(candidates, key=lambda c: title_similarity(c.title, keyword))
        if title_similarity(best.title, keyword) >= MIN_TITLE_SIMILARITY:
            return best
    return None


def _candidate_to_product(
    candidate: ApiCandidate, url: str, platform: str, platform_label: str
) -> Product:
    original = candidate.original_price
    if original is not None and candidate.price is not None and original <= candidate.price:
        original = None
    return Product(
        original_url=url,
        title=strip_html_tags(candidate.title),
        image_url=candidate.image_url,
        price=candidate.price,
        original_price=original,
        discount_rate=discount_rate_from(candidate.price, original),
        brand=candidate.brand,
        seller=candidate.seller,
        category=candidate.category,
        source_platform=platform,
        platform_label=platform_label,
        source_type=SourceType.API,
        price_trackable=True,  # 공식 API 재조회로 가격 갱신 가능 (문서 6절)
    )


# ---------------------------------------------------------------------------
# 어댑터 공통 인터페이스
# ---------------------------------------------------------------------------

class OpenApiAdapter:
    """플랫폼 하나의 공식 API 연동. 파이프라인은 platform 코드로 어댑터를 찾는다."""

    platform: str = ""
    platform_label: str = ""  # 화면 표시용 이름

    def __init__(self, transport: Transport | None = None):
        self._transport = transport or _default_transport

    def is_configured(self) -> bool:
        """API 자격 증명이 준비됐는지. False면 파이프라인이 skipped 처리한다."""
        raise NotImplementedError

    def lookup(self, ctx: LookupContext) -> Product:
        """상품을 조회·매칭해 정규화된 Product 를 반환한다.

        실패 시 AdapterError 를 던지고, 파이프라인이 Tier 2로 폴백한다.
        """
        raise NotImplementedError


# ---------------------------------------------------------------------------
# 네이버 쇼핑 검색 API (developers.naver.com)
# ---------------------------------------------------------------------------

class NaverShoppingAdapter(OpenApiAdapter):
    """GET https://openapi.naver.com/v1/search/shop.json?query=...

    검색 전용 API이므로 반드시 매칭 단계를 거친다.
    응답 항목의 productId 가 URL의 식별자(스마트스토어 products/{id}, nvMid)와
    일치하면 그 항목을, 아니면 이름 유사도로 매칭한다.
    """

    platform = "naver"
    platform_label = "네이버 쇼핑"
    ENDPOINT = "https://openapi.naver.com/v1/search/shop.json"

    def __init__(self, transport: Transport | None = None,
                 client_id: str | None = None, client_secret: str | None = None):
        super().__init__(transport)
        self._client_id = client_id or os.environ.get("NAVER_CLIENT_ID")
        self._client_secret = client_secret or os.environ.get("NAVER_CLIENT_SECRET")

    def is_configured(self) -> bool:
        return bool(self._client_id and self._client_secret)

    def lookup(self, ctx: LookupContext) -> Product:
        keyword = ctx.title_hint()  # 필요한 시점에 1회 fetch (Tier 2와 공유)
        if not keyword:
            # 검색 API라 키워드 없이는 조회 자체가 불가능하다
            raise AdapterError("no search keyword available (page title missing)")
        query = urllib.parse.urlencode({"query": clean_title_for_search(keyword), "display": 20})
        status, body = self._transport(
            f"{self.ENDPOINT}?{query}",
            {
                "X-Naver-Client-Id": self._client_id,
                "X-Naver-Client-Secret": self._client_secret,
            },
        )
        if status != 200:
            raise AdapterError(f"naver shopping API returned HTTP {status}")
        try:
            items = json.loads(body).get("items", [])
        except (json.JSONDecodeError, ValueError) as e:
            raise AdapterError(f"naver shopping API returned invalid JSON: {e}") from e

        candidates = []
        for item in items:
            sale = int(item["lprice"]) if str(item.get("lprice") or "").isdigit() else None
            listed = int(item["hprice"]) if str(item.get("hprice") or "").isdigit() else None
            candidates.append(ApiCandidate(
                product_id=str(item.get("productId") or "") or None,
                title=item.get("title") or "",
                image_url=item.get("image") or None,
                price=sale,
                original_price=listed,
                brand=item.get("brand") or item.get("maker") or None,
                seller=item.get("mallName") or None,  # 입점 판매자/스토어 이름
                category=" > ".join(
                    c for c in (item.get(f"category{i}") for i in range(1, 5)) if c
                ) or None,
            ))
        # title_hint() 이후에는 단축링크(naver.me)가 풀려 식별자가 생겼을 수 있다
        matched = match_candidates(candidates, ctx.url_info.product_id,
                                   clean_title_for_search(keyword))
        if matched is None:
            raise AdapterError("no confident match in naver shopping results")
        return _candidate_to_product(matched, ctx.url_info.url,
                                     self.platform, self.platform_label)


# ---------------------------------------------------------------------------
# 쿠팡 파트너스 API (제휴 마케팅용 — 가입·승인 필요, 문서 5.2 제약사항)
# ---------------------------------------------------------------------------

class CoupangPartnersAdapter(OpenApiAdapter):
    """GET /v2/providers/affiliate_open_api/apis/openapi/v1/products/search

    HMAC-SHA256 서명 인증을 사용한다. 검색 API이므로 매칭 단계를 거친다.
    """

    platform = "coupang"
    platform_label = "쿠팡"
    HOST = "https://api-gateway.coupang.com"
    SEARCH_PATH = "/v2/providers/affiliate_open_api/apis/openapi/v1/products/search"

    def __init__(self, transport: Transport | None = None,
                 access_key: str | None = None, secret_key: str | None = None):
        super().__init__(transport)
        self._access_key = access_key or os.environ.get("COUPANG_ACCESS_KEY")
        self._secret_key = secret_key or os.environ.get("COUPANG_SECRET_KEY")

    def is_configured(self) -> bool:
        return bool(self._access_key and self._secret_key)

    def _authorization(self, method: str, path: str, query: str) -> str:
        """쿠팡 파트너스 공식 문서의 CEA HMAC 서명 규격."""
        signed_date = time.strftime("%y%m%dT%H%M%SZ", time.gmtime())
        message = signed_date + method + path + query
        signature = hmac.new(
            self._secret_key.encode(), message.encode(), hashlib.sha256
        ).hexdigest()
        return (
            f"CEA algorithm=HmacSHA256, access-key={self._access_key}, "
            f"signed-date={signed_date}, signature={signature}"
        )

    def lookup(self, ctx: LookupContext) -> Product:
        keyword = ctx.title_hint()
        if not keyword:
            raise AdapterError("no search keyword available (page title missing)")
        query = urllib.parse.urlencode(
            {"keyword": clean_title_for_search(keyword), "limit": 20}
        )
        status, body = self._transport(
            f"{self.HOST}{self.SEARCH_PATH}?{query}",
            {"Authorization": self._authorization("GET", self.SEARCH_PATH, query)},
        )
        if status != 200:
            raise AdapterError(f"coupang partners API returned HTTP {status}")
        try:
            product_data = (json.loads(body).get("data") or {}).get("productData", [])
        except (json.JSONDecodeError, ValueError) as e:
            raise AdapterError(f"coupang partners API returned invalid JSON: {e}") from e

        candidates = [
            ApiCandidate(
                product_id=str(item.get("productId") or "") or None,
                title=item.get("productName") or "",
                image_url=item.get("productImage") or None,
                price=item.get("productPrice")
                if isinstance(item.get("productPrice"), int) else None,
                category=item.get("categoryName") or None,
            )
            for item in product_data
        ]
        # title_hint() 이후에는 단축링크(link.coupang.com)가 풀려 식별자가 생겼을 수 있다
        matched = match_candidates(candidates, ctx.url_info.product_id,
                                   clean_title_for_search(keyword))
        if matched is None:
            raise AdapterError("no confident match in coupang partners results")
        return _candidate_to_product(matched, ctx.url_info.url,
                                     self.platform, self.platform_label)


# ---------------------------------------------------------------------------
# 11번가 OpenAPI
# ---------------------------------------------------------------------------

class ElevenStAdapter(OpenApiAdapter):
    """11번가 OpenAPI (XML 응답).

    다른 두 API와 달리 상품 코드로 **직접 조회**(ProductInfo)가 가능하므로,
    URL에서 식별자를 얻었으면 검색·매칭 없이 바로 조회한다.
    식별자가 없으면 ProductSearch 로 검색 후 매칭한다.
    """

    platform = "11st"
    platform_label = "11번가"
    ENDPOINT = "https://openapi.11st.co.kr/openapi/OpenApiService.tmall"

    def __init__(self, transport: Transport | None = None, api_key: str | None = None):
        super().__init__(transport)
        self._api_key = api_key or os.environ.get("ELEVENST_API_KEY")

    def is_configured(self) -> bool:
        return bool(self._api_key)

    def _call(self, params: dict) -> ET.Element:
        query = urllib.parse.urlencode({"key": self._api_key, **params})
        status, body = self._transport(f"{self.ENDPOINT}?{query}", {})
        if status != 200:
            raise AdapterError(f"11st OpenAPI returned HTTP {status}")
        try:
            return ET.fromstring(body.decode("utf-8", errors="replace"))
        except ET.ParseError as e:
            raise AdapterError(f"11st OpenAPI returned invalid XML: {e}") from e

    @staticmethod
    def _text(element: ET.Element, *tags: str) -> str | None:
        for tag in tags:
            node = element.find(f".//{tag}")
            if node is not None and node.text and node.text.strip():
                return node.text.strip()
        return None

    def _parse_products(self, root: ET.Element) -> list[ApiCandidate]:
        candidates = []
        for product in root.iter("Product"):
            price_text = self._text(product, "SalePrice", "ProductPrice", "Price")
            candidates.append(ApiCandidate(
                product_id=self._text(product, "ProductCode"),
                title=self._text(product, "ProductName") or "",
                image_url=self._text(
                    product, "ProductImage300", "ProductImage200", "ProductImage"
                ),
                price=int(price_text) if price_text and price_text.isdigit() else None,
                seller=self._text(product, "SellerNick", "Seller"),  # 입점 판매자
            ))
        return candidates

    def lookup(self, ctx: LookupContext) -> Product:
        # 1) 식별자 직접 조회 (가장 확실 — 페이지 fetch 자체가 필요 없다)
        if ctx.url_info.product_id:
            root = self._call(
                {"apiCode": "ProductInfo", "productCode": ctx.url_info.product_id}
            )
            candidates = self._parse_products(root)
            if candidates and candidates[0].title:
                return _candidate_to_product(
                    candidates[0], ctx.url_info.url,
                    self.platform, self.platform_label,
                )
        # 2) 키워드 검색 후 매칭
        keyword = ctx.title_hint()
        if not keyword:
            raise AdapterError("no product id and no search keyword")
        root = self._call(
            {"apiCode": "ProductSearch", "keyword": clean_title_for_search(keyword)}
        )
        matched = match_candidates(
            self._parse_products(root), ctx.url_info.product_id,
            clean_title_for_search(keyword),
        )
        if matched is None:
            raise AdapterError("no confident match in 11st search results")
        return _candidate_to_product(matched, ctx.url_info.url,
                                     self.platform, self.platform_label)


def default_adapters(transport: Transport | None = None) -> dict[str, OpenApiAdapter]:
    """플랫폼 코드 → 어댑터 매핑. 파이프라인이 사용한다."""
    adapters = (
        NaverShoppingAdapter(transport),
        CoupangPartnersAdapter(transport),
        ElevenStAdapter(transport),
    )
    return {adapter.platform: adapter for adapter in adapters}
