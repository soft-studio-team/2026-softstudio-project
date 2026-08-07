"""3단계 폴백 파이프라인 통합 테스트. — 문서 5절

핵심 검증 대상:
  1. Tier 1 → 2 → 3 폴백 순서와 각 단계의 시도 기록(attempts)
  2. "저장은 항상 성공한다" — 어떤 실패 상황에서도 ParseResult 가 나온다
  3. "URL당 페이지 GET은 최대 1회" — Tier 1 이 fetch 한 결과를 Tier 2 가 재사용
  4. source_type / price_trackable / missing_fields 파생 규칙
"""

import json

import pytest

from conftest import FakeFetcher
from engine.cache import TTLCache
from engine.fetch import FetchBlocked, FetchFailed
from engine.models import SourceType, TierOutcome
from engine.pipeline import InvalidUrlError, ProductParsingEngine
from engine.tiers.tier1_api import NaverShoppingAdapter


MUSINSA_HTML = """
<html><head>
<meta property="og:type" content="product"/>
<meta property="og:title" content="제이에스티나(JESTINA) GINO SM 크로스 BK - 사이즈 &amp; 후기 | 무신사"/>
<meta property="og:image" content="https://image.msscdn.net/goods/1.jpg"/>
<meta property="og:description" content="제품분류: 가방 > 메신저/크로스 백"/>
</head></html>
"""

JSONLD_HTML = """
<html><head>
<script type="application/ld+json">
{"@type": "Product", "name": "코듀로이 자켓", "image": "https://cdn.example.com/j.jpg",
 "brand": "어떤브랜드",
 "offers": {"@type": "Offer", "price": "139000", "priceCurrency": "KRW"}}
</script>
</head></html>
"""


def make_engine(fetcher, adapters=None):
    return ProductParsingEngine(fetcher=fetcher, adapters=adapters or {}, cache=TTLCache())


# ---------------------------------------------------------------------------
# Tier 2 성공 경로
# ---------------------------------------------------------------------------

def test_og_without_price_falls_to_tier3_with_title_and_image():
    """제목·이미지만 있고 가격이 없으면 Tier 2 실패 → Tier 3.
    얻은 제목·이미지는 미리 채우고 가격만 사용자 입력."""
    engine = make_engine(FakeFetcher(html=MUSINSA_HTML))
    result = engine.parse("https://www.musinsa.com/products/4715870")

    assert result.resolved_tier == 3
    assert result.product.source_type == SourceType.MANUAL
    assert result.product.source_platform == "musinsa"
    assert result.product.platform_label == "무신사"
    assert result.product.title.startswith("제이에스티나")
    assert result.product.image_url.startswith("https://image.msscdn.net/")
    assert result.product.price is None
    assert result.missing_fields == ["price"]

    tier1 = result.attempts[0]
    tier2 = next(a for a in result.attempts if a.tier == 2)
    assert (tier1.tier, tier1.outcome) == (1, TierOutcome.SKIPPED)
    assert tier2.outcome == TierOutcome.FAILED
    assert "price" in tier2.reason


def test_tier2_jsonld_with_price_has_no_missing_fields():
    engine = make_engine(FakeFetcher(html=JSONLD_HTML))
    result = engine.parse("https://shop.example.com/products/1")
    assert result.resolved_tier == 2
    assert result.product.price == 139000
    assert result.product.brand == "어떤브랜드"
    assert result.missing_fields == []


DISCOUNT_HTML = """
<html><head>
<script type="application/ld+json">
{"@type": "Product", "name": "린넨 셔츠",
 "image": "https://cdn.example.com/s.jpg",
 "offers": {"@type": "Offer", "price": "39000", "listPrice": "59000",
            "priceCurrency": "KRW"}}
</script>
</head></html>
"""


def test_tier2_captures_original_price_and_discount_rate():
    engine = make_engine(FakeFetcher(html=DISCOUNT_HTML))
    result = engine.parse("https://shop.example.com/products/2")
    assert result.resolved_tier == 2
    assert result.product.price == 39000
    assert result.product.original_price == 59000
    assert result.product.discount_rate == 34  # round(20000/59000*100)


# ---------------------------------------------------------------------------
# Tier 3 폴백 경로: 어떤 실패에도 저장은 성공한다
# ---------------------------------------------------------------------------

def test_robots_blocked_falls_to_tier3_without_bypass():
    engine = make_engine(FakeFetcher(error=FetchBlocked("robots.txt disallows")))
    result = engine.parse("https://blocked.example.com/item/1")

    assert result.resolved_tier == 3
    assert result.product.source_type == SourceType.MANUAL
    assert result.product.original_url == "https://blocked.example.com/item/1"
    assert set(result.missing_fields) == {"title", "image_url", "price"}

    tier2 = next(a for a in result.attempts if a.tier == 2)
    assert tier2.outcome == TierOutcome.SKIPPED
    assert "robots.txt" in tier2.reason


def test_network_failure_falls_to_tier3():
    engine = make_engine(FakeFetcher(error=FetchFailed("HTTP 403", status=403)))
    result = engine.parse("https://strict.example.com/item/1")
    assert result.resolved_tier == 3
    assert result.product.original_url == "https://strict.example.com/item/1"


def test_unknown_platform_label_falls_back_to_og_site_name():
    """레지스트리에 없는 사이트는 og:site_name 을 쇼핑몰 이름으로 쓴다."""
    html = """
    <meta property="og:title" content="수제 캔들"/>
    <meta property="og:image" content="https://cdn.example.com/candle.jpg"/>
    <meta property="product:price:amount" content="22000"/>
    <meta property="og:site_name" content="어느공방"/>
    """
    engine = make_engine(FakeFetcher(html=html))
    result = engine.parse("https://some-atelier.example.com/goods/7")
    assert result.resolved_tier == 2
    assert result.product.source_platform == "unknown"
    assert result.product.platform_label == "어느공방"


def test_unknown_platform_label_last_resort_is_domain():
    """og:site_name 조차 없으면 도메인이라도 보여준다."""
    engine = make_engine(FakeFetcher(error=FetchFailed("HTTP 500", status=500)))
    result = engine.parse("https://tiny-shop.example.com/goods/9")
    assert result.product.platform_label == "tiny-shop.example.com"


def test_tier3_prefills_title_from_share_text_when_site_blocks():
    """에이블리 시나리오: 사이트가 접근을 전면 차단(Cloudflare 등)해도,
    공유 텍스트의 상품명으로 제목은 미리 채워져야 한다. 남는 건 이미지·가격뿐."""
    engine = make_engine(FakeFetcher(error=FetchBlocked("robots.txt disallows")))
    result = engine.parse(
        "https://m.a-bly.com/goods/10062919",
        title_hint="트임 슬릿 롱 원피스 - 에이블리",
    )

    assert result.resolved_tier == 3
    assert result.product.title == "트임 슬릿 롱 원피스"  # 사이트 꼬리표 제거됨
    assert result.product.platform_label == "에이블리"
    assert set(result.missing_fields) == {"image_url", "price"}


def test_metadata_missing_falls_to_tier3_with_preview():
    """제목만 있는 페이지: Tier 2 기준(제목+이미지+가격) 미달 → Tier 3 미리보기.
    단, 얻은 제목은 미리 채워져야 한다 ("전부 수동 입력"이 아니라 "빠진 것만 확인")."""
    engine = make_engine(FakeFetcher(html="<head><title>어느 편집샵 상품</title></head>"))
    result = engine.parse("https://tiny-shop.example.com/goods/9")

    assert result.resolved_tier == 3
    assert result.product.title == "어느 편집샵 상품"     # 얻은 건 미리 채운다
    assert "title" not in result.missing_fields
    assert set(result.missing_fields) == {"image_url", "price"}


# ---------------------------------------------------------------------------
# Tier 1 경로와 폴백
# ---------------------------------------------------------------------------

NAVER_SEARCH_RESPONSE = json.dumps({
    "items": [{
        "title": "나이키 <b>덩크</b> 로우 레트로", "image": "https://pstatic.net/dunk.jpg",
        "lprice": "119000", "productId": "8123456789", "brand": "나이키",
        "category1": "패션잡화", "category2": "신발",
    }]
}).encode()

SMARTSTORE_HTML = """
<head><meta property="og:title" content="나이키 덩크 로우 레트로 : 스토어명"/>
<meta property="og:image" content="https://pstatic.net/page-image.jpg"/>
<meta property="product:price:amount" content="119000"/></head>
"""

SMARTSTORE_HTML_NO_PRICE = """
<head><meta property="og:title" content="나이키 덩크 로우 레트로 : 스토어명"/>
<meta property="og:image" content="https://pstatic.net/page-image.jpg"/></head>
"""


def test_tier1_success_via_api_search_and_id_match():
    fetcher = FakeFetcher(html=SMARTSTORE_HTML)
    adapter = NaverShoppingAdapter(
        transport=lambda url, headers: (200, NAVER_SEARCH_RESPONSE),
        client_id="id", client_secret="secret",
    )
    engine = make_engine(fetcher, adapters={"naver": adapter})
    result = engine.parse("https://smartstore.naver.com/somestore/products/8123456789")

    assert result.resolved_tier == 1
    assert result.product.source_type == SourceType.API
    assert result.product.price == 119000
    assert result.product.price_trackable is True
    assert result.missing_fields == []
    # Tier 1 이 상품명 힌트를 위해 페이지를 1회 가져갔고, 그게 전부여야 한다
    assert fetcher.fetch_count == 1


def test_tier1_unconfigured_falls_to_tier2():
    """쿠팡 파트너스처럼 승인 전이라 키가 없으면: skipped 기록 후 Tier 2."""
    fetcher = FakeFetcher(html=JSONLD_HTML)
    adapter = NaverShoppingAdapter(transport=lambda u, h: (200, b"{}"),
                                   client_id=None, client_secret=None)
    engine = make_engine(fetcher, adapters={"naver": adapter})
    result = engine.parse("https://smartstore.naver.com/somestore/products/1")

    assert result.resolved_tier == 2
    tier1 = result.attempts[0]
    assert (tier1.tier, tier1.outcome) == (1, TierOutcome.SKIPPED)
    assert "credentials" in tier1.reason


def test_tier1_api_failure_falls_to_tier2_with_single_fetch():
    """API 가 죽어도(500) 이미 받아둔 페이지로 Tier 2 가 이어받는다. GET 은 1회."""
    fetcher = FakeFetcher(html=JSONLD_HTML)
    adapter = NaverShoppingAdapter(transport=lambda u, h: (500, b"oops"),
                                   client_id="id", client_secret="secret")
    engine = make_engine(fetcher, adapters={"naver": adapter})
    result = engine.parse("https://smartstore.naver.com/somestore/products/1")

    assert result.resolved_tier == 2
    assert result.product.title == "코듀로이 자켓"
    tier1 = result.attempts[0]
    assert (tier1.tier, tier1.outcome) == (1, TierOutcome.FAILED)
    assert fetcher.fetch_count == 1     # 핵심 불변식: URL당 GET 1회


def test_tier1_succeeds_with_share_hint_even_when_page_fetch_blocked():
    """쿠팡 시나리오: 사이트가 서버 요청을 거절해도, 공유 텍스트의 상품명
    힌트만으로 Tier 1 API 검색·매칭이 가능해야 한다. 페이지 fetch는 0회."""
    fetcher = FakeFetcher(error=FetchFailed("HTTP 403", status=403))
    adapter = NaverShoppingAdapter(
        transport=lambda url, headers: (200, NAVER_SEARCH_RESPONSE),
        client_id="id", client_secret="secret",
    )
    engine = make_engine(fetcher, adapters={"naver": adapter})
    result = engine.parse(
        "https://smartstore.naver.com/somestore/products/8123456789",
        title_hint="나이키 덩크 로우 레트로 - 네이버 쇼핑",
    )

    assert result.resolved_tier == 1
    assert result.product.price == 119000
    assert fetcher.fetch_count == 0   # 힌트 덕분에 페이지 fetch 자체가 불필요


def test_tier1_no_confident_match_falls_to_tier2():
    """검색 결과가 전혀 다른 상품뿐이면 억지로 매칭하지 않고 폴백한다."""
    wrong_items = json.dumps({"items": [
        {"title": "주방용 실리콘 주걱", "image": "", "lprice": "3000", "productId": "1"},
    ]}).encode()
    fetcher = FakeFetcher(html=SMARTSTORE_HTML)
    adapter = NaverShoppingAdapter(transport=lambda u, h: (200, wrong_items),
                                   client_id="id", client_secret="secret")
    engine = make_engine(fetcher, adapters={"naver": adapter})
    result = engine.parse("https://smartstore.naver.com/somestore/products/8123456789")

    assert result.resolved_tier == 2   # 페이지 OG(제목·이미지·가격)로 폴백
    assert result.attempts[0].outcome == TierOutcome.FAILED
    assert "match" in result.attempts[0].reason


def test_tier1_no_match_and_no_price_falls_to_tier3():
    """API 매칭 실패 + 페이지에 가격도 없으면 Tier 3 (제목·이미지만 미리 채움)."""
    wrong_items = json.dumps({"items": [
        {"title": "주방용 실리콘 주걱", "image": "", "lprice": "3000", "productId": "1"},
    ]}).encode()
    fetcher = FakeFetcher(html=SMARTSTORE_HTML_NO_PRICE)
    adapter = NaverShoppingAdapter(transport=lambda u, h: (200, wrong_items),
                                   client_id="id", client_secret="secret")
    engine = make_engine(fetcher, adapters={"naver": adapter})
    result = engine.parse("https://smartstore.naver.com/somestore/products/8123456789")

    assert result.resolved_tier == 3
    assert result.product.title.startswith("나이키")
    assert result.missing_fields == ["price"]


# ---------------------------------------------------------------------------
# 입력 검증·캐시·단축링크
# ---------------------------------------------------------------------------

def test_invalid_url_is_the_only_failure_path():
    engine = make_engine(FakeFetcher())
    for bad in ("", "무신사에서 본 가방", "javascript:alert(1)"):
        with pytest.raises(InvalidUrlError):
            engine.parse(bad)


def test_cache_prevents_duplicate_requests():
    fetcher = FakeFetcher(html=MUSINSA_HTML)
    engine = make_engine(fetcher)
    url = "https://www.musinsa.com/products/4715870"

    first = engine.parse(url)
    second = engine.parse(url)

    assert first.from_cache is False
    assert second.from_cache is True
    assert second.product.title == first.product.title
    assert fetcher.fetch_count == 1    # 동일 URL 중복 요청 방지 (문서 5.3)


def test_short_link_redirect_reidentifies_platform():
    """단축링크가 리다이렉트로 풀리면 최종 URL 기준으로 플랫폼을 재식별한다."""
    fetcher = FakeFetcher(
        html=MUSINSA_HTML,
        final_url="https://www.musinsa.com/products/4715870",
    )
    engine = make_engine(fetcher)
    result = engine.parse("https://naver.me/abc123")   # naver 단축링크 → 무신사로 리다이렉트 가정

    assert result.product.source_platform == "musinsa"
    assert result.product.original_url == "https://naver.me/abc123"  # 원본 링크는 보존
