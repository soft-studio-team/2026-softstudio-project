"""표준 메타데이터 파서(JSON-LD 우선 → OG 보완) 테스트. — 문서 4절, 5.3"""

from engine.metadata import extract_metadata, normalize_price


BASE = "https://shop.example.com/products/1"


# ---------------------------------------------------------------------------
# 가격 정규화: 실제 사이트들의 제각각인 표기를 모두 수용해야 한다
# ---------------------------------------------------------------------------

def test_normalize_price_variants():
    assert normalize_price(89000) == 89000
    assert normalize_price("89000") == 89000
    assert normalize_price("89,000") == 89000
    assert normalize_price("89000.0") == 89000
    assert normalize_price("₩89,000") == 89000
    assert normalize_price("89,000원") == 89000
    assert normalize_price(None) is None
    assert normalize_price("") is None
    assert normalize_price("품절") is None
    assert normalize_price(0) is None       # 0원은 가격 미확보로 본다
    assert normalize_price(True) is None    # bool 이 1로 둔갑하면 안 된다


# ---------------------------------------------------------------------------
# JSON-LD: 사이트마다 다른 구조 변형을 모두 처리해야 한다
# ---------------------------------------------------------------------------

def test_jsonld_simple_product():
    html = """
    <html><head><script type="application/ld+json">
    {"@context": "https://schema.org", "@type": "Product",
     "name": "GINO SM 크로스 BK",
     "image": "https://cdn.example.com/bag.jpg",
     "brand": {"@type": "Brand", "name": "제이에스티나"},
     "category": "가방 > 크로스백",
     "offers": {"@type": "Offer", "price": "128000", "priceCurrency": "KRW"}}
    </script></head><body></body></html>
    """
    meta = extract_metadata(html, BASE)
    assert meta.title == "GINO SM 크로스 BK"
    assert meta.image_url == "https://cdn.example.com/bag.jpg"
    assert meta.price == 128000
    assert meta.currency == "KRW"
    assert meta.brand == "제이에스티나"
    assert meta.category == "가방 > 크로스백"
    assert "json-ld" in meta.sources


def test_jsonld_inside_graph_with_type_list():
    """@graph 로 감싸고 @type 이 리스트인 변형 (실사이트에 흔함)."""
    html = """
    <script type="application/ld+json">
    {"@context": "https://schema.org",
     "@graph": [
        {"@type": "BreadcrumbList", "itemListElement": []},
        {"@type": ["Product", "IndividualProduct"],
         "name": "덩크 로우", "image": ["https://cdn.example.com/1.jpg"],
         "offers": [{"@type": "Offer", "price": 119000, "priceCurrency": "KRW"}]}
     ]}
    </script>
    """
    meta = extract_metadata(html, BASE)
    assert meta.title == "덩크 로우"
    assert meta.image_url == "https://cdn.example.com/1.jpg"
    assert meta.price == 119000


def test_jsonld_offer_seller_is_extracted():
    """오픈마켓형 사이트는 offers.seller 에 입점 판매자를 넣는다."""
    html = """
    <script type="application/ld+json">
    {"@type": "Product", "name": "캠핑 의자",
     "image": "https://cdn.example.com/chair.jpg",
     "offers": {"@type": "Offer", "price": "45000", "priceCurrency": "KRW",
                "seller": {"@type": "Organization", "name": "행복한아웃도어"}}}
    </script>
    """
    meta = extract_metadata(html, BASE)
    assert meta.seller == "행복한아웃도어"


def test_og_site_name_is_extracted():
    html = """
    <meta property="og:title" content="어떤 신발"/>
    <meta property="og:image" content="https://cdn.example.com/s.jpg"/>
    <meta property="og:site_name" content="어썸슈즈몰"/>
    """
    meta = extract_metadata(html, BASE)
    assert meta.site_name == "어썸슈즈몰"


def test_jsonld_aggregate_offer_low_price():
    html = """
    <script type="application/ld+json">
    {"@type": "Product", "name": "후드 집업",
     "image": "/img/hood.jpg",
     "offers": {"@type": "AggregateOffer", "lowPrice": "59,000", "highPrice": "79,000",
                "priceCurrency": "KRW"}}
    </script>
    """
    meta = extract_metadata(html, BASE)
    assert meta.price == 59000
    # highPrice 는 옵션 최고가일 수 있어 정가로 쓰지 않는다
    assert meta.original_price is None
    # 상대경로 이미지는 절대 URL 로 보정돼야 한다
    assert meta.image_url == "https://shop.example.com/img/hood.jpg"


def test_jsonld_list_price_and_sale_price():
    """offers.price=할인가, listPrice=정가."""
    html = """
    <script type="application/ld+json">
    {"@type": "Product", "name": "린넨 셔츠",
     "image": "https://cdn.example.com/s.jpg",
     "offers": {"@type": "Offer", "price": "39000", "listPrice": "59000",
                "priceCurrency": "KRW"}}
    </script>
    """
    meta = extract_metadata(html, BASE)
    assert meta.price == 39000
    assert meta.original_price == 59000


def test_jsonld_price_specification_list_price():
    html = """
    <script type="application/ld+json">
    {"@type": "Product", "name": "스니커즈",
     "image": "https://cdn.example.com/s.jpg",
     "offers": {"@type": "Offer", "price": "77000", "priceCurrency": "KRW",
                "priceSpecification": [
                  {"@type": "UnitPriceSpecification", "price": "77000",
                   "priceCurrency": "KRW"},
                  {"@type": "UnitPriceSpecification", "price": "100000",
                   "priceType": "https://schema.org/ListPrice",
                   "priceCurrency": "KRW"}
                ]}}
    </script>
    """
    meta = extract_metadata(html, BASE)
    assert meta.price == 77000
    assert meta.original_price == 100000


def test_og_sale_and_original_price():
    html = """
    <meta property="og:title" content="할인 상품"/>
    <meta property="og:image" content="https://cdn.example.com/d.jpg"/>
    <meta property="product:price:amount" content="100000"/>
    <meta property="product:sale_price:amount" content="77000"/>
    """
    meta = extract_metadata(html, BASE)
    assert meta.price == 77000
    assert meta.original_price == 100000


def test_broken_jsonld_block_is_ignored_and_og_used():
    """깨진 JSON-LD 가 있어도 죽지 않고 OG 로 폴백해야 한다."""
    html = """
    <head>
    <script type="application/ld+json">{ this is not json ]</script>
    <meta property="og:title" content="니트 스웨터"/>
    <meta property="og:image" content="https://cdn.example.com/knit.jpg"/>
    </head>
    """
    meta = extract_metadata(html, BASE)
    assert meta.title == "니트 스웨터"
    assert meta.sources == ["open-graph"]


# ---------------------------------------------------------------------------
# Open Graph: 무신사 실측(문서 4.4)과 같은 형태 — 가격 없는 OG
# ---------------------------------------------------------------------------

MUSINSA_LIKE_HTML = """
<html><head>
<meta property="og:type" content="product"/>
<meta property="og:title" content="제이에스티나(JESTINA) GINO SM 크로스 BK - 사이즈 &amp; 후기 | 무신사"/>
<meta property="og:image" content="https://image.msscdn.net/thumbnails/images/goods_img/1.jpg"/>
<meta property="og:description" content="제품분류: 가방 > 메신저/크로스 백, 브랜드: 제이에스티나"/>
<meta property="og:url" content="https://www.musinsa.com/products/4715870"/>
</head><body></body></html>
"""


def test_open_graph_only_page():
    meta = extract_metadata(MUSINSA_LIKE_HTML, "https://www.musinsa.com/products/4715870")
    assert meta.title.startswith("제이에스티나(JESTINA) GINO SM 크로스 BK")
    assert meta.image_url.startswith("https://image.msscdn.net/")
    assert meta.price is None          # 무신사는 초기 HTML 에 가격이 없다 (문서 4.4)
    assert meta.og_type == "product"
    assert not meta.has_product_core()  # 가격 없음 → Tier 2 미달


def test_og_product_price_tags():
    html = """
    <meta property="og:title" content="스니커즈"/>
    <meta property="og:image" content="https://cdn.example.com/s.jpg"/>
    <meta property="product:price:amount" content="99000"/>
    <meta property="product:price:currency" content="KRW"/>
    """
    meta = extract_metadata(html, BASE)
    assert meta.price == 99000
    assert meta.currency == "KRW"


def test_musinsa_basic_sale_and_normal_price_are_kept():
    """쿠폰가·옵션 추가금과 분리된 기본 판매가와 정가를 저장한다."""
    html = """
    <meta property="og:title" content="컴포트 썸머 와이드 팬츠"/>
    <meta property="og:image" content="https://image.msscdn.net/item.jpg"/>
    <meta property="product:price:amount" content="30400"/>
    <meta property="product:price:normal_price" content="32000"/>
    <meta property="product:price:sale_rate" content="5"/>
    """
    meta = extract_metadata(html, "https://www.musinsa.com/products/6152461")
    assert meta.price == 30400
    assert meta.original_price == 32000
    assert meta.has_product_core()


def test_conditional_jsonld_price_is_ignored():
    html = """
    <script type="application/ld+json">
    {"@type": "Product", "name": "회원 전용 상품",
     "image": "https://cdn.example.com/item.jpg",
     "offers": {"@type": "Offer", "price": "21000",
                "priceCurrency": "KRW",
                "validForMemberTier": {"name": "VIP"}}}
    </script>
    """
    meta = extract_metadata(html, BASE)
    assert meta.price is None


# ---------------------------------------------------------------------------
# 통합: JSON-LD 우선 + OG 로 빈 칸 보완
# ---------------------------------------------------------------------------

def test_jsonld_takes_priority_and_og_fills_gaps():
    html = """
    <head>
    <script type="application/ld+json">
    {"@type": "Product", "name": "JSON-LD 상품명",
     "offers": {"price": "45000", "priceCurrency": "KRW"}}
    </script>
    <meta property="og:title" content="OG 상품명 | 어떤샵"/>
    <meta property="og:image" content="https://cdn.example.com/og.jpg"/>
    <meta property="og:description" content="OG 설명"/>
    </head>
    """
    meta = extract_metadata(html, BASE)
    assert meta.title == "JSON-LD 상품명"      # JSON-LD 우선
    assert meta.price == 45000                  # JSON-LD 가격
    assert meta.image_url == "https://cdn.example.com/og.jpg"  # 빈 칸은 OG 보완
    assert meta.description == "OG 설명"
    assert meta.sources == ["json-ld", "open-graph"]


def test_page_with_no_metadata_at_all():
    meta = extract_metadata("<html><body><h1>hello</h1></body></html>", BASE)
    assert meta is None


def test_bare_title_tag_is_last_resort():
    meta = extract_metadata("<html><head><title>어떤 페이지</title></head></html>", BASE)
    assert meta.title == "어떤 페이지"
    assert not meta.has_product_core()   # 이미지·가격 없음 → Tier 2 미달
    assert meta.has_anything()           # 하지만 Tier 3 미리보기 저장은 가능
