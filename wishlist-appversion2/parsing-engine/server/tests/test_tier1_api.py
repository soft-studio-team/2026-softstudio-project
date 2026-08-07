"""Tier 1 어댑터(공식 API 연동 + 매칭) 테스트. — 문서 5.2

실제 API 를 호출하지 않고 가짜 transport 로 응답을 흉내낸다.
"""

import json

import pytest

from engine.tiers.tier1_api import (
    AdapterError,
    ApiCandidate,
    ElevenStAdapter,
    NaverShoppingAdapter,
    clean_title_for_search,
    match_candidates,
    strip_html_tags,
)
from engine.urltools import analyze_url


class FakeContext:
    """LookupContext 프로토콜의 테스트 구현."""

    def __init__(self, url: str, title: str | None):
        self.url_info = analyze_url(url)
        self._title = title
        self.title_hint_calls = 0

    def title_hint(self):
        self.title_hint_calls += 1
        return self._title


# ---------------------------------------------------------------------------
# 검색 키워드 다듬기 / 매칭 규칙
# ---------------------------------------------------------------------------

def test_clean_title_strips_site_suffix():
    # 문서 4.4 실측 og:title 그대로
    raw = "제이에스티나(JESTINA) GINO SM 크로스 BK (JHNCHE5BS913BK980) - 사이즈 & 후기 | 무신사"
    assert clean_title_for_search(raw) == "제이에스티나(JESTINA) GINO SM 크로스 BK (JHNCHE5BS913BK980)"


def test_strip_html_tags():
    assert strip_html_tags("나이키 <b>덩크</b> 로우") == "나이키 덩크 로우"


def test_match_prefers_product_id_over_similarity():
    candidates = [
        ApiCandidate(product_id="111", title="완전히 같은 이름의 상품", image_url=None, price=1000),
        ApiCandidate(product_id="222", title="다른 이름", image_url=None, price=2000),
    ]
    # 이름은 첫 번째가 더 비슷해도, 식별자가 일치하는 두 번째가 이긴다
    matched = match_candidates(candidates, product_id="222", keyword="완전히 같은 이름의 상품")
    assert matched.product_id == "222"


def test_match_falls_back_to_title_similarity():
    candidates = [
        ApiCandidate(product_id="1", title="아디다스 삼바 OG 화이트", image_url=None, price=1),
        ApiCandidate(product_id="2", title="나이키 덩크 로우 레트로", image_url=None, price=2),
    ]
    matched = match_candidates(candidates, product_id=None, keyword="나이키 덩크 로우")
    assert matched.product_id == "2"


def test_match_rejects_low_similarity():
    """확신 없는 매칭은 None — 틀린 데이터 저장보다 Tier 2 폴백이 낫다."""
    candidates = [
        ApiCandidate(product_id="1", title="전혀 관계 없는 주방용품 세트", image_url=None, price=1),
    ]
    assert match_candidates(candidates, product_id=None, keyword="나이키 덩크 로우") is None


def test_match_empty_results():
    assert match_candidates([], product_id="1", keyword="아무거나") is None


# ---------------------------------------------------------------------------
# 네이버 쇼핑 검색 API 어댑터
# ---------------------------------------------------------------------------

NAVER_RESPONSE = {
    "items": [
        {"title": "나이키 <b>덩크</b> 로우 레트로 흰검", "link": "https://search.shopping.naver.com/...",
         "image": "https://shopping-phinf.pstatic.net/dunk.jpg", "lprice": "119000",
         "brand": "나이키", "maker": "나이키", "productId": "51449387423",
         "mallName": "슈즈매니아스토어",
         "category1": "패션잡화", "category2": "신발", "category3": "운동화", "category4": ""},
        {"title": "전혀 다른 상품", "image": "", "lprice": "5000", "productId": "1",
         "brand": "", "maker": "", "category1": ""},
    ]
}


def make_naver_adapter(response: dict, status: int = 200):
    calls = []

    def transport(url, headers):
        calls.append((url, headers))
        return status, json.dumps(response).encode()

    adapter = NaverShoppingAdapter(
        transport=transport, client_id="test-id", client_secret="test-secret"
    )
    return adapter, calls


def test_naver_adapter_matches_by_product_id():
    adapter, calls = make_naver_adapter(NAVER_RESPONSE)
    ctx = FakeContext(
        "https://shopping.naver.com/catalog/51449387423",
        "나이키 덩크 로우 레트로 : 네이버 쇼핑",
    )
    product = adapter.lookup(ctx)
    assert product.title == "나이키 덩크 로우 레트로 흰검"   # <b> 태그 제거됨
    assert product.price == 119000
    assert product.brand == "나이키"
    assert product.seller == "슈즈매니아스토어"              # 입점 판매자 (mallName)
    assert product.platform_label == "네이버 쇼핑"
    assert product.category == "패션잡화 > 신발 > 운동화"
    assert product.source_type.value == "API"
    assert product.price_trackable is True                    # 문서 6: Tier 1 은 추적 O
    assert product.original_url == "https://shopping.naver.com/catalog/51449387423"
    # 인증 헤더가 정직하게 실려 나갔는지
    assert calls[0][1]["X-Naver-Client-Id"] == "test-id"


def test_naver_adapter_requires_keyword():
    adapter, _ = make_naver_adapter(NAVER_RESPONSE)
    ctx = FakeContext("https://shopping.naver.com/catalog/51449387423", None)
    with pytest.raises(AdapterError, match="keyword"):
        adapter.lookup(ctx)


def test_naver_adapter_http_error_becomes_adapter_error():
    adapter, _ = make_naver_adapter({}, status=429)  # rate limit 상황
    ctx = FakeContext("https://shopping.naver.com/catalog/51449387423", "나이키 덩크")
    with pytest.raises(AdapterError, match="429"):
        adapter.lookup(ctx)


def test_naver_adapter_unconfigured():
    adapter = NaverShoppingAdapter(transport=lambda u, h: (200, b"{}"),
                                   client_id=None, client_secret=None)
    assert adapter.is_configured() is False


# ---------------------------------------------------------------------------
# 11번가 어댑터: 상품코드 직접 조회 (검색·매칭 불필요, 페이지 fetch 도 불필요)
# ---------------------------------------------------------------------------

ELEVENST_PRODUCT_INFO_XML = """<?xml version="1.0" encoding="utf-8"?>
<ProductInfoResponse>
  <Product>
    <ProductCode>1234567890</ProductCode>
    <ProductName>삼성전자 갤럭시 버즈3</ProductName>
    <ProductImage300>https://cdn.011st.com/buds3.jpg</ProductImage300>
    <SalePrice>189000</SalePrice>
  </Product>
</ProductInfoResponse>
"""


def test_11st_adapter_direct_lookup_skips_page_fetch():
    def transport(url, headers):
        assert "apiCode=ProductInfo" in url and "productCode=1234567890" in url
        return 200, ELEVENST_PRODUCT_INFO_XML.encode()

    adapter = ElevenStAdapter(transport=transport, api_key="test-key")
    ctx = FakeContext("https://www.11st.co.kr/products/1234567890", "안 쓰일 제목")
    product = adapter.lookup(ctx)
    assert product.title == "삼성전자 갤럭시 버즈3"
    assert product.price == 189000
    assert product.image_url == "https://cdn.011st.com/buds3.jpg"
    assert ctx.title_hint_calls == 0   # 식별자 직접 조회라 페이지 fetch 가 없어야 한다
