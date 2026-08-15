import json

import pytest

from engine.cache import TTLCache
from engine.models import PriceConfidence, PurchasePriceStatus
from engine.pipeline import ProductParsingEngine
from engine.site_adapters import extract_site_pricing

from conftest import FakeFetcher


MUSINSA_PRICE_STATE = """
<script>
window.__STATE__={"goodsPrice":{"salePrice":30400,"normalPrice":32000,
"discountRate":5,"type":"DEFAULT","couponPrice":21280,
"couponDiscount":true,"finalPrice":21280,"currency":"KRW"}};
</script>
"""

MUSINSA_PRODUCT_HTML = f"""
<head>
<meta property="og:title" content="컴포트 썸머 와이드 팬츠 브라운"/>
<meta property="og:image" content="https://image.msscdn.net/goods/6152461.jpg"/>
<meta property="product:price:amount" content="30400"/>
<meta property="product:price:normal_price" content="32000"/>
</head>
{MUSINSA_PRICE_STATE}
"""


def test_musinsa_adapter_excludes_coupon_and_final_prices():
    pricing = extract_site_pricing("musinsa", MUSINSA_PRICE_STATE)

    assert pricing is not None
    assert pricing.purchase_price == 30400
    assert pricing.regular_price == 32000
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED
    assert pricing.confidence == PriceConfidence.HIGH
    assert pricing.option_dependent is None
    assert all(
        evidence["field"] not in {"goodsPrice.couponPrice", "goodsPrice.finalPrice"}
        for evidence in pricing.evidence()
    )


def test_musinsa_pipeline_marks_price_as_confirmed_with_evidence():
    engine = ProductParsingEngine(
        fetcher=FakeFetcher(html=MUSINSA_PRODUCT_HTML),
        adapters={},
        cache=TTLCache(),
    )

    result = engine.parse("https://www.musinsa.com/products/6152461")
    pricing = result.product.to_dict()["pricing"]

    assert result.resolved_tier == 2
    assert pricing["purchase_price"] == 30400
    assert pricing["regular_price"] == 32000
    assert pricing["purchase_price_status"] == "confirmed"
    assert pricing["confidence"] == "high"
    assert pricing["option_dependent"] is None
    assert pricing["evidence"][0]["adapter"] == "musinsa"
    assert "pricing adapter=musinsa" in result.attempts[-1].reason


def test_generic_mall_price_stays_provisional():
    engine = ProductParsingEngine(
        fetcher=FakeFetcher(html=MUSINSA_PRODUCT_HTML),
        adapters={},
        cache=TTLCache(),
    )

    result = engine.parse("https://shop.example.com/products/6152461")
    pricing = result.product.to_dict()["pricing"]

    assert pricing["purchase_price"] == 30400
    assert pricing["purchase_price_status"] == "provisional"
    assert pricing["confidence"] == "medium"
    assert pricing["evidence"][0]["adapter"] is None


def test_musinsa_adapter_abstains_when_different_price_objects_are_mixed():
    mixed = MUSINSA_PRICE_STATE + MUSINSA_PRICE_STATE.replace(
        '"salePrice":30400', '"salePrice":15900'
    ).replace('"normalPrice":32000', '"normalPrice":20000')

    assert extract_site_pricing("musinsa", mixed) is None


def test_musinsa_adapter_abstains_for_unknown_price_type():
    unknown_type = MUSINSA_PRICE_STATE.replace('"DEFAULT"', '"MEMBER"')

    assert extract_site_pricing("musinsa", unknown_type) is None


def _wconcept_state(item: str, sale: int, regular: int) -> str:
    state = {
        "CouponPrice": 0,
        "CustomerPrice": float(regular),
        "FinalPrice": float(sale),
        "ItemCd": item,
        "SalePrice": float(sale),
        "Currency": "KRW",
    }
    encoded = json.dumps(state).replace('"', '&quot;')
    return f"""
    <input type="hidden" name="saleprice" value="{sale}">
    <input type="hidden" name="originalPrice" value="{regular}">
    <input type="hidden" name="GA4ItemObj_{item}" value="{encoded}">
    <span>쿠폰적용가 73,304원</span>
    <span>신규회원가 68,992원</span>
    """


@pytest.mark.parametrize("item,sale,regular", [
    ("305914779", 86240, 98000),
    ("307615241", 19900, 39900),
    ("307615250", 321300, 459000),
])
def test_wconcept_adapter_uses_order_form_price_not_coupon_price(
    item, sale, regular,
):
    pricing = extract_site_pricing(
        "wconcept", _wconcept_state(item, sale, regular)
    )

    assert pricing is not None
    assert pricing.purchase_price == sale
    assert pricing.regular_price == regular
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED
    assert pricing.adapter == "wconcept"
    assert pricing.purchase_field == "GA4ItemObj.SalePrice"


def test_wconcept_adapter_abstains_when_order_form_disagrees():
    html = _wconcept_state("305914779", 86240, 98000).replace(
        'name="saleprice" value="86240"',
        'name="saleprice" value="73304"',
    )

    assert extract_site_pricing("wconcept", html) is None


@pytest.mark.parametrize("sale,regular,display,coupon_type", [
    (159000, 159000, 159000, "NONE"),
    (19500, 39000, 17550, "PRODUCT_SINGLE_COUPON"),
    (99000, 99000, 99000, "NONE"),
])
def test_29cm_adapter_uses_sell_price_and_excludes_display_coupon(
    sale, regular, display, coupon_type,
):
    html = (
        rf'\"sellPrice\":{sale},\"consumerPrice\":{regular},'
        rf'\"internalDisplayPrice\":{{\"totalDiscountedItemPrice\":{display},'
        rf'\"totalDiscountedRate\":0,\"appliedCouponType\":\"{coupon_type}\"}},'
        r'\"visibleMaxExtraPrice\":0,\"visibleMinExtraPrice\":0,'
        r'\"hasVisibleOptionExtraPrice\":false'
    )

    pricing = extract_site_pricing("29cm", html)

    assert pricing is not None
    assert pricing.purchase_price == sale
    assert pricing.regular_price == regular
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED
    assert pricing.option_dependent is False
    assert pricing.purchase_field == "item.sellPrice"


def test_29cm_adapter_marks_option_price_range():
    html = (
        r'\"sellPrice\":20000,\"consumerPrice\":30000,'
        r'\"visibleMaxExtraPrice\":5000,\"visibleMinExtraPrice\":0,'
        r'\"hasVisibleOptionExtraPrice\":true'
    )

    pricing = extract_site_pricing("29cm", html)

    assert pricing is not None
    assert pricing.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert pricing.option_dependent is True
    assert pricing.option_price_min == 20000
    assert pricing.option_price_max == 25000


def _fila_state(prices: list[int], compare_at: int | None = None) -> str:
    selected = {
        "id": 51035251179556,
        "title": "WL(W95)",
        "available": True,
        "price": prices[0] * 100,
        "compare_at_price": (
            compare_at * 100 if compare_at is not None else None
        ),
    }
    group = {
        "@context": "http://schema.org/",
        "@type": "ProductGroup",
        "hasVariant": [
            {
                "@type": "Product",
                "offers": {
                    "@type": "Offer",
                    "price": str(price),
                    "priceCurrency": "KRW",
                },
            }
            for price in prices
        ],
    }
    return (
        '<script type="application/json" data-selected-variant>'
        f'{json.dumps(selected)}</script>'
        '<script type="application/ld+json">'
        f'{json.dumps(group)}</script>'
        '<a href="/account/register">신규회원 10,000원 할인 쿠폰</a>'
        '<a href="https://pf.kakao.com/">카카오톡 채널 10% 할인 쿠폰</a>'
    )


@pytest.mark.parametrize("price,compare_at", [
    (69900, None),
    (129000, 129000),
    (109000, None),
])
def test_fila_adapter_uses_variant_price_and_excludes_member_coupons(
    price, compare_at,
):
    pricing = extract_site_pricing("fila", _fila_state([price], compare_at))

    assert pricing is not None
    assert pricing.purchase_price == price
    assert pricing.regular_price == compare_at
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED
    assert pricing.option_dependent is False
    assert pricing.adapter == "fila"


def test_fila_adapter_marks_variant_price_range():
    pricing = extract_site_pricing("fila", _fila_state([69900, 79900]))

    assert pricing is not None
    assert pricing.purchase_price == 69900
    assert pricing.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert pricing.option_dependent is True
    assert pricing.option_price_min == 69900
    assert pricing.option_price_max == 79900


def test_fila_adapter_abstains_when_selected_and_offer_prices_disagree():
    html = _fila_state([69900]).replace('"price": "69900"', '"price": "59900"')

    assert extract_site_pricing("fila", html) is None


def _hago_state(regular: int, sale: int, coupon: int, soldout: str = "N") -> str:
    return f"""
    <script type="application/ld+json">
    {{"@type":"Product","offers":{{"Price":{coupon},"priceCurrency":"KRW"}}}}
    </script>
    <script>
    var goodsInfo = {{
        id: '750307', price: {regular}, dcPrice: {sale},
        sellPrice: {sale}, soldout: '{soldout}', stock: '10'
    }};
    var coupon = {{ sale_price: {coupon} }};
    </script>
    """


@pytest.mark.parametrize("regular,sale,coupon", [
    (246800, 205700, 168674),
    (108000, 75600, 52920),
    (79000, 79000, 79000),
])
def test_hago_adapter_uses_merchandise_price_not_coupon(
    regular, sale, coupon,
):
    pricing = extract_site_pricing("hago", _hago_state(regular, sale, coupon))

    assert pricing is not None
    assert pricing.purchase_price == sale
    assert pricing.regular_price == regular
    assert pricing.purchase_field == "goodsInfo.sellPrice"


def test_hago_adapter_abstains_for_sold_out_product():
    assert extract_site_pricing(
        "hago", _hago_state(79000, 79000, 79000, soldout="Y")
    ) is None


@pytest.mark.parametrize("sale,regular,reward", [
    (34000, 39000, 1020),
    (64900, 119800, 1947),
    (28900, 34900, 867),
])
def test_lookpin_adapter_ignores_reward_points(sale, regular, reward):
    html = f"""
    <h1>상품명</h1>
    <div class="mt-3">
      <span class="mr-2 text-h2-lg text-black font-bold">
        {sale:,}<span class="text-h3">원</span>
      </span>
      <del>{regular:,}</del>
    </div>
    <div>적립 {sale // 100:,}원 ~ {reward:,}원</div>
    """

    pricing = extract_site_pricing("lookpin", html)

    assert pricing is not None
    assert pricing.purchase_price == sale
    assert pricing.regular_price == regular
    assert str(reward) not in pricing.purchase_field


def test_lookpin_adapter_abstains_for_sold_out_product():
    html = """
    <span class="text-h2-lg text-black font-bold">34,000원</span>
    <del>39,000</del><button>품절</button>
    """
    assert extract_site_pricing("lookpin", html) is None


def _topten_state(sale: int | str, regular: int | str, *, live=True) -> str:
    state = {
        "@context": "https://schema.org/",
        "@type": "Product",
        "name": "여성) 코튼 립 브라탑" if live else "",
        "sku": "MSG2UL2205NVP" if live else "",
        "offers": {
            "@type": "Offer",
            "price": str(sale),
            "priceCurrency": "KRW",
            "availability": (
                "https://schema.org/InStock"
                if live else "https://schema.org/OutOfStock"
            ),
        },
        "additionalProperty": [
            {"@type": "PropertyValue", "name": "정가", "value": str(regular)}
        ],
    }
    return f'<script type="application/ld+json">{json.dumps(state)}</script>'


def test_topten_adapter_reads_offer_and_explicit_regular_price():
    pricing = extract_site_pricing("topten", _topten_state(19900, 29900))

    assert pricing is not None
    assert pricing.purchase_price == 19900
    assert pricing.regular_price == 29900
    assert pricing.adapter == "topten"


def test_topten_adapter_abstains_for_empty_archived_page():
    assert extract_site_pricing(
        "topten", _topten_state("", "", live=False)
    ) is None


def _muji_state(regular: int, sale: int, state: str = "ON") -> str:
    return rf'''
    <script>self.__next_f.push([1,"5:[\"state\":{{\"data\":{{\"row\":{{
    \"product\":{{\"client_session_info\":[],\"product_id\":1005531,
    \"sale_state\":\"{state}\",\"display_product_name\":\"상품\",
    \"code\":\"FCA02A6A\",\"retail_price\":{regular},
    \"discount_price\":0,\"discount_rate\":0,\"sell_price\":{sale},
    \"last_price\":{sale},\"discounts\":[]}}}}}}}}"]);</script>
    '''


def test_muji_adapter_reads_primary_product_prices():
    pricing = extract_site_pricing("muji", _muji_state(9900, 9900))

    assert pricing is not None
    assert pricing.regular_price == 9900
    assert pricing.purchase_price == 9900
    assert pricing.adapter == "muji"


def test_muji_adapter_abstains_for_sold_out_primary_product():
    assert extract_site_pricing(
        "muji", _muji_state(12900, 12900, state="SOLDOUT")
    ) is None


def _hmall_state(purchase: int, regular: int, soldout: bool = False) -> str:
    state = {
        "props": {"pageProps": {"respData": {"itemPtc": {
            "slitmCd": "2123645324",
            "slitmNm": "상품",
            "sellPrc": regular,
            "bbprc": purchase,
            "soldout": soldout,
        }}}},
    }
    return f'<script id="__NEXT_DATA__">{json.dumps(state)}</script>'


@pytest.mark.parametrize("purchase,regular", [
    (42900, 42900),
    (29900, 29900),
    (35650, 46900),
])
def test_hmall_adapter_uses_buying_price(purchase, regular):
    pricing = extract_site_pricing(
        "hmall", _hmall_state(purchase, regular)
    )

    assert pricing is not None
    assert pricing.purchase_price == purchase
    assert pricing.regular_price == regular
    assert pricing.purchase_field == "itemPtc.bbprc"


def test_hmall_adapter_abstains_for_stopped_product():
    assert extract_site_pricing(
        "hmall", _hmall_state(45000, 45000, soldout=True)
    ) is None


def _lotteon_state(price: int, *, soldout: bool = False) -> str:
    state = [{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "보노보노 유니폼",
        "sku": "LO2724337622",
        "offers": {
            "@type": "Offer",
            "price": str(price),
            "priceCurrency": "KRW",
            "availability": "https://schema.org/InStock",
        },
    }]
    button = "<button>품절된 상품입니다</button>" if soldout else ""
    return (
        f'<script type="application/ld+json">{json.dumps(state)}</script>'
        f'<div>판매가 {price:,}원</div>{button}'
    )


def test_lotteon_adapter_requires_live_offer_and_visible_price():
    pricing = extract_site_pricing("lotteon", _lotteon_state(105000))

    assert pricing is not None
    assert pricing.purchase_price == 105000
    assert pricing.regular_price is None
    assert pricing.adapter == "lotteon"


def test_lotteon_adapter_abstains_when_page_is_sold_out_despite_jsonld():
    assert extract_site_pricing(
        "lotteon", _lotteon_state(29800, soldout=True)
    ) is None


def _cafe24_state(prices, availability=None) -> str:
    if availability is None:
        availability = ["InStock"] * len(prices)
    state = {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "상품",
        "offers": [
            {
                "price": price,
                "priceCurrency": "KRW",
                "availability": stock,
            }
            for price, stock in zip(prices, availability)
        ],
    }
    return f'<script type="application/ld+json">{json.dumps(state)}</script>'


@pytest.mark.parametrize("platform,price", [
    ("dailyjou", 36000),
    ("dailyjou", 39000),
    ("dailyjou", 28500),
])
def test_cafe24_adapter_reads_explicit_live_option_prices(platform, price):
    pricing = extract_site_pricing(platform, _cafe24_state([price, price]))

    assert pricing is not None
    assert pricing.purchase_price == price
    assert pricing.regular_price is None
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED


def test_cafe24_adapter_marks_option_price_range():
    pricing = extract_site_pricing(
        "dailyjou", _cafe24_state([28500, 30500])
    )

    assert pricing is not None
    assert pricing.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert pricing.option_price_min == 28500
    assert pricing.option_price_max == 30500


@pytest.mark.parametrize("platform", ["mixxo", "dailyjou"])
def test_cafe24_adapter_abstains_when_all_options_are_sold_out(platform):
    html = _cafe24_state(
        [39900, 39900], ["OutOfStock", "OutOfStock"]
    )
    assert extract_site_pricing(platform, html) is None


def test_lee_editorial_placeholder_is_not_treated_as_product_price():
    state = {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Lee Denim|end",
        "offers": [{"price": 99999, "priceCurrency": "KRW"}],
    }
    html = f'<script type="application/ld+json">{json.dumps(state)}</script>'

    assert extract_site_pricing("lee", html) is None


def _product_jsonld(price: int, availability="InStock", name="상품") -> str:
    offer = {"price": price, "priceCurrency": "KRW"}
    if availability is not None:
        offer["availability"] = availability
    state = {"@type": "Product", "name": name, "offers": [offer]}
    return f'<script type="application/ld+json">{json.dumps(state)}</script>'


def test_filluminate_uses_automatic_sale_instead_of_jsonld_regular_price():
    html = _product_jsonld(49000) + """
    <script>var product_price = '49000'; var product_sale_price = 39000;</script>
    """
    pricing = extract_site_pricing("filluminate", html)

    assert pricing is not None
    assert pricing.regular_price == 49000
    assert pricing.purchase_price == 39000


def test_filluminate_abstains_when_all_options_are_sold_out():
    html = _product_jsonld(54000, "OutOfStock") + """
    <script>var product_price = '54000'; var product_sale_price = 39900;</script>
    """
    assert extract_site_pricing("filluminate", html) is None


def test_urbanstoff_reads_guest_checkout_automatic_discount():
    html = _product_jsonld(69000) + """
    <script>var product_price = '69000'; var product_sale_price = 62100;</script>
    <select id="product_option_id1"><option value="M">M</option></select>
    <button>ADD TO CART</button>
    """
    pricing = extract_site_pricing("urbanstoff", html)

    assert pricing is not None
    assert pricing.regular_price == 69000
    assert pricing.purchase_price == 62100


def test_urbanstoff_accepts_live_option_when_jsonld_omits_availability():
    html = _product_jsonld(45000, None) + """
    <table><tr><th>판매가</th><td><span id="span_product_price_sale">40,500원</span></td></tr></table>
    <select id="product_option_id1"><option value="S">S</option></select>
    <button>ADD TO CART</button>
    """
    pricing = extract_site_pricing("urbanstoff", html)

    assert pricing is not None
    assert pricing.regular_price == 45000
    assert pricing.purchase_price == 40500


def _not4u_html(regular: int, sale: int, *, title="상품") -> str:
    return _product_jsonld(sale, None, title) + f"""
    <h1>{title}</h1>
    <table>
      <tr><th>소비자가</th><td>{regular:,}원</td></tr>
      <tr><th>판매가</th><td>{sale:,}원</td></tr>
    </table>
    <select id="product_option_id1"><option value="단품">단품</option></select>
    """


@pytest.mark.parametrize("regular,sale", [(17900, 15900), (21000, 12000)])
def test_not4u_reads_labelled_regular_and_sale_prices(regular, sale):
    pricing = extract_site_pricing("not4u", _not4u_html(regular, sale))

    assert pricing is not None
    assert pricing.regular_price == regular
    assert pricing.purchase_price == sale


def test_not4u_rejects_zero_price_event_test_page():
    assert extract_site_pricing(
        "not4u", _not4u_html(1, 1, title="이벤트테스트페이지")
    ) is None


def _cafe24_options(*labels: str) -> str:
    options = "".join(
        f'<option value="{index}">{label}</option>'
        for index, label in enumerate(labels, 1)
    )
    return f'<select id="product_option_id1">{options}</select>'


def test_insilence_reads_regular_and_guest_cart_price():
    html = _product_jsonld(49000, None, "개리슨 벨트 BLACK") + """
    <script>var product_price = '49000';</script>
    <div class="xans-product-detail"><div class="infoArea"><table>
      <tr><td>55,000원</td></tr><tr><td>49,000원</td></tr>
    </table></div></div>
    """ + _cafe24_options("FREE")
    pricing = extract_site_pricing("insilence", html)

    assert pricing is not None
    assert pricing.regular_price == 55000
    assert pricing.purchase_price == 49000


def test_insilence_abstains_when_all_options_are_sold_out():
    html = _product_jsonld(47200, None, "링거 티셔츠 BROWN") + """
    <script>var product_price = '47200';</script>
    """ + _cafe24_options("S [품절]", "M [품절]", "L [품절]")
    assert extract_site_pricing("insilence", html) is None


def test_insilence_rejects_placeholder_product_page():
    html = _product_jsonld(49000, None, "¥¥¥¥*") + """
    <script>var product_price = '49000';</script>
    """ + _cafe24_options("FREE")
    assert extract_site_pricing("insilence", html) is None


def test_fabregat_reads_automatic_sale_price():
    html = _product_jsonld(44000, None, "Brom Carabiner Leather Keyring") + """
    <script>var product_price = 44000; var product_sale_price = 39600;</script>
    """ + _cafe24_options("블랙-FREE")
    pricing = extract_site_pricing("fabregat", html)

    assert pricing is not None
    assert pricing.regular_price == 44000
    assert pricing.purchase_price == 39600


def test_fabregat_uses_displayed_sale_when_script_is_absent():
    html = _product_jsonld(44000, None, "Leather Keyring Dark Brown") + """
    <span id="span_product_price_sale">39,600원</span>
    """ + _cafe24_options("다크 브라운-FREE")
    pricing = extract_site_pricing("fabregat", html)

    assert pricing is not None
    assert pricing.purchase_price == 39600


def test_fabregat_rejects_zero_price_editorial_page():
    html = _product_jsonld(0, None, "Fabrégat 26 S/S Part. 2 Editorial")
    assert extract_site_pricing("fabregat", html) is None


def test_hotping_uses_option_range_and_ignores_coupon_price():
    html = _cafe24_state(
        [24800, 24800, 25800], ["InStock", "InStock", "InStock"]
    ) + """
    <script>var product_price = 24800;</script>
    <table><tr><th>판매가</th><td>24,800원</td></tr>
      <tr><th>쿠폰적용가</th><td>22,320원</td></tr></table>
    """
    pricing = extract_site_pricing("hotping", html)

    assert pricing is not None
    assert pricing.regular_price is None
    assert pricing.purchase_price == 24800
    assert pricing.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert pricing.option_price_min == 24800
    assert pricing.option_price_max == 25800


def test_hotping_abstains_on_listing_page_without_product_offers():
    assert extract_site_pricing("hotping", "<html><h1>BEST</h1></html>") is None


def _uniqlo_group(prices, availability=None, currency="KRW") -> str:
    availability = availability or ["InStock"] * len(prices)
    variants = [{"@type": "Product", "name": f"상품 {i}", "sku": f"486612-65-00{i}-000", "offers": {"price": str(price), "priceCurrency": currency, "availability": f"https://schema.org/{stock}"}} for i, (price, stock) in enumerate(zip(prices, availability), 1)]
    state = {"@context": "https://schema.org", "@graph": [{"@type": "ProductGroup", "productGroupID": "E486612-000", "name": "데님셔츠", "hasVariant": variants}]}
    return f'<main><h1>데님셔츠</h1><span>{prices[0]:,}원</span></main><script type="application/ld+json">{json.dumps(state)}</script>'


def test_uniqlo_reads_live_variant_price():
    pricing = extract_site_pricing("uniqlo", _uniqlo_group([49900, 49900]))
    assert pricing is not None
    assert pricing.regular_price is None
    assert pricing.purchase_price == 49900
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED


def test_uniqlo_marks_live_option_range_and_rejects_invalid_offers():
    pricing = extract_site_pricing("uniqlo", _uniqlo_group([14900, 19900, 29900], ["InStock", "InStock", "OutOfStock"]))
    assert pricing is not None
    assert pricing.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert pricing.option_price_min == 14900
    assert pricing.option_price_max == 19900
    assert extract_site_pricing("uniqlo", _uniqlo_group([1490], currency="USD")) is None
    assert extract_site_pricing("uniqlo", _uniqlo_group([19900], ["OutOfStock"])) is None


def _ssg_state(regular=23500, purchase=23030, *, sold="N", coupon="N", same="Y", item_id="1000571660298") -> str:
    return f'''<main><span>최적가</span><b>{purchase:,}원</b><del>{regular:,}원</del><span>카드혜택가 21,879원</span></main><script>var resultItemObj = {{itemId:'{item_id}', sellprc:'{regular}', sellStatCd:'20', bestAmt: parseInt('{purchase}', 10) || 0, soldOut : '{sold}', soldOutPass: 'N', uitemSamePrcYn : '{same}', preCpnDcPrc: '{purchase}', cpnYn: '{coupon}'}};</script>'''


def test_ssg_uses_best_amount_and_ignores_card_price():
    pricing = extract_site_pricing("ssg", _ssg_state())
    assert pricing is not None
    assert pricing.regular_price == 23500
    assert pricing.purchase_price == 23030


def test_ssg_rejects_conditional_unavailable_or_conflicting_states():
    assert extract_site_pricing("ssg", _ssg_state(coupon="Y")) is None
    assert extract_site_pricing("ssg", _ssg_state(sold="Y")) is None
    assert extract_site_pricing("ssg", _ssg_state(same="N")) is None
    assert extract_site_pricing("ssg", _ssg_state() + _ssg_state(77480, 75920, item_id="1000571660290")) is None


def _thehyundai_state(*, name="스티치 백 리본 블라우스 Z262MSC031", regular=179100, purchase=130300, closed="0", stock="0", qty=39, maximum=None) -> str:
    maximum = purchase if maximum is None else maximum
    state = {"slitmCd": "40B1406274", "slitmNm": name, "itemGbcd": "1", "empBuyLimtYn": "0", "empDcYn": "0", "clsrMallItemYn": closed, "ostkYn": stock, "sellPossQty": qty, "sellMdaPossYn": "1", "prcInfo": {"sellPrc": regular, "dcPrc": purchase, "maxDcPrc": maximum}}
    escaped = json.dumps(state, ensure_ascii=False).replace('"', r'\"')
    return f'<main><h1>{name}</h1><del>{regular:,}원</del><strong>{purchase:,}원</strong><span>카드 즉시할인</span></main><script>self.__next_f.push([1,"{escaped}"])</script>'


def test_thehyundai_uses_product_discount_not_card_benefit():
    pricing = extract_site_pricing("thehyundai", _thehyundai_state())
    assert pricing is not None
    assert pricing.regular_price == 179100
    assert pricing.purchase_price == 130300


def test_thehyundai_rejects_closed_employee_unavailable_or_conflicting_price():
    assert extract_site_pricing("thehyundai", _thehyundai_state(name="(임직원) 셔츠", closed="1")) is None
    assert extract_site_pricing("thehyundai", _thehyundai_state(stock="1", qty=0)) is None
    assert extract_site_pricing("thehyundai", _thehyundai_state(maximum=120000)) is None


def _meta(name, value):
    return f'<meta property="{name}" content="{value}">'


def _ably_html(*, price=17500, availability="in stock", instant=True, item_id="74156532"):
    labels = f'<span>나의 예상 구매가</span><b>{price:,}원</b><span>즉시 할인 20%</span>' if instant else f'<b>{price:,}원</b><span>할인 쿠폰 받기</span>'
    return f'''<html><head>{_meta("product:retailer_item_id", item_id)}{_meta("product:price:amount", f"{price:,}")}{_meta("product:price:currency", "KRW")}{_meta("product:availability", availability)}</head><body><main>{labels}<button>구매하기</button></main></body></html>'''


def test_ably_confirms_visible_instant_discount_and_ignores_points():
    pricing = extract_site_pricing("ably", _ably_html() + "<span>최대 350원 받기</span>")
    assert pricing is not None
    assert pricing.regular_price is None
    assert pricing.purchase_price == 17500
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED


def test_ably_rejects_coupon_only_sold_out_or_conflicting_main_meta():
    assert extract_site_pricing("ably", _ably_html(instant=False)) is None
    assert extract_site_pricing("ably", _ably_html(availability="out of stock")) is None
    assert extract_site_pricing("ably", _ably_html() + _meta("product:price:amount", "14,500")) is None


def _zigzag_html(*, purchasable=True, sale=34650, regular=38500, coupon=27720, product_id="144255443"):
    product = {"id": product_id, "name": "멜로디 코튼 캉캉 롱 스커트", "is_purchasable": purchasable, "sales_status": "ON_SALE", "display_status": "VISIBLE", "product_price": {"display_final_price": {"final_price": {"price": sale}, "final_price_additional": {"badge": {"text": "첫구매쿠폰"}, "price": coupon}}, "max_price_info": {"price": regular}, "coupon_discount_info": {"discount_price": coupon}}}
    state = {"props": {"pageProps": {"dehydratedState": {"queries": [{"state": {"data": {"product": product}}}]}}}}
    return f'<main><h1>{product["name"]}</h1><del>{regular:,}</del><b>{sale:,}원</b><span>첫구매쿠폰 {coupon:,}원</span><button>구매하기</button></main><script id="__NEXT_DATA__" type="application/json">{json.dumps(state, ensure_ascii=False)}</script>'


def test_zigzag_uses_unconditional_final_price_not_first_order_coupon():
    pricing = extract_site_pricing("zigzag", _zigzag_html())
    assert pricing is not None
    assert pricing.regular_price == 38500
    assert pricing.purchase_price == 34650
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED


def test_zigzag_rejects_unavailable_invalid_or_multiple_products():
    assert extract_site_pricing("zigzag", _zigzag_html(purchasable=False)) is None
    assert extract_site_pricing("zigzag", _zigzag_html(sale=40000, regular=38500)) is None
    assert extract_site_pricing("zigzag", _zigzag_html() + _zigzag_html(sale=90000, regular=120000, product_id="116435827")) is None


def _kream_html(*, price=75000, availability="InStock", brand_delivery=True, market=False, product_id="1012767"):
    product = {"@context": "https://schema.org", "@type": "Product", "name": "KREAM 단독 레이어드 티셔츠", "productID": product_id, "offers": {"@type": "Offer", "price": price, "priceCurrency": "KRW", "availability": f"https://schema.org/{availability}"}}
    delivery = "브랜드배송 무료" if brand_delivery else "일반배송 3,000원"
    market_text = "판매 입찰 구매 입찰 옵션 선택" if market else ""
    return f'<main><h1>{product["name"]}</h1><b>{price:,}원</b><span>쿠폰 받기 67,500원 최대 혜택가</span><button>구매하기</button><span>{delivery}</span><span>{market_text}</span></main><script type="application/ld+json">{json.dumps(product, ensure_ascii=False)}</script>'


def test_kream_confirms_fixed_brand_delivery_and_ignores_coupon_benefit():
    pricing = extract_site_pricing("kream", _kream_html())
    assert pricing is not None
    assert pricing.regular_price is None
    assert pricing.purchase_price == 75000


def test_kream_abstains_on_resale_market_unavailable_or_multiple_products():
    assert extract_site_pricing("kream", _kream_html(brand_delivery=False, market=True)) is None
    assert extract_site_pricing("kream", _kream_html(availability="OutOfStock")) is None
    assert extract_site_pricing("kream", _kream_html() + _kream_html(price=119000, product_id="1012774")) is None


def _guess_html(*, regular=49000, sale=39000, stocks=("InStock", "OutOfStock")):
    offers = [{"name": f"상품 {i}", "price": sale, "priceCurrency": "KRW", "availability": stock} for i, stock in enumerate(stocks)]
    product = {"@context": "https://schema.org", "@type": "Product", "name": "게스 티셔츠", "offers": offers}
    return f'''<main><h1>게스 티셔츠</h1><div class="price_box"><span id="span_product_price_text">{sale:,}</span><span class="custom through">{regular:,}</span></div><button>장바구니 담기</button><button>바로 구매하기</button></main><script>var product_price = '{sale}';</script><script type="application/ld+json">{json.dumps(product, ensure_ascii=False)}</script>'''


def test_guess_uses_live_offer_sale_and_visible_regular_price():
    pricing = extract_site_pricing("guess", _guess_html())
    assert pricing is not None
    assert pricing.regular_price == 49000
    assert pricing.purchase_price == 39000


def test_guess_rejects_sold_out_option_conflict_or_multiple_products():
    assert extract_site_pricing("guess", _guess_html(stocks=("OutOfStock",))) is None
    assert extract_site_pricing("guess", _guess_html(sale=39000).replace("product_price = '39000'", "product_price = '29000'")) is None
    assert extract_site_pricing("guess", _guess_html() + _guess_html(regular=159000, sale=109000)) is None


def _levis_html(*, sale=139000, regular=199000, available=(True, False), product_id=8487070859417):
    variants = [{"id": i + 1, "title": f"{24+i} / 30", "sku": f"SKU{i}", "available": stock, "price": sale * 100, "compare_at_price": regular * 100} for i, stock in enumerate(available)]
    product = {"id": product_id, "title": "501 셀비지 진", "available": any(available), "price": sale * 100, "compare_at_price": regular * 100, "variants": variants}
    return f'''<main><h1>{product["title"]}</h1><span>할인가 ₩{sale:,}</span><span>정가 ₩{regular:,}</span><button>장바구니 담기</button><button>지금 구매</button></main><script>window.hulkappsWishlist = {{}}; window.hulkappsWishlist.productJSON = {json.dumps(product, ensure_ascii=False)};</script>'''


def test_levis_uses_available_shopify_variant_price_and_compare_at():
    pricing = extract_site_pricing("levis", _levis_html())
    assert pricing is not None
    assert pricing.regular_price == 199000
    assert pricing.purchase_price == 139000


def test_levis_rejects_sold_out_price_variation_or_multiple_products():
    assert extract_site_pricing("levis", _levis_html(available=(False, False))) is None
    mixed = _levis_html().replace('"price": 13900000, "compare_at_price": 19900000}', '"price": 14900000, "compare_at_price": 19900000}', 1)
    assert extract_site_pricing("levis", mixed) is None
    assert extract_site_pricing("levis", _levis_html() + _levis_html(product_id=1)) is None


def _vans_html(*, regular=95000, sale=57000, live=True, title="올드스쿨"):
    sale_meta = _meta("recopick:sale_price", sale) + _meta("recopick:sale_price:currency", "KRW") if sale else ""
    active = "variation-size selectable input-radio" if live else "variation-size selectable input-radio nonActive"
    shown = sale or regular
    return f'''<head>{_meta("recopick:title", title)}{_meta("recopick:price", regular)}{_meta("recopick:price:currency", "KRW")}{sale_meta}</head><main><h1>{title}</h1><span>{regular:,} 원</span><strong>{shown:,} 원</strong><label class="{active}">245</label><button>장바구니에 담기</button><button>바로구매</button></main>'''


def test_vans_uses_reco_sale_price_and_full_price_without_fabricating_regular():
    pricing = extract_site_pricing("vans", _vans_html())
    assert pricing is not None and pricing.regular_price == 95000 and pricing.purchase_price == 57000
    full = extract_site_pricing("vans", _vans_html(regular=189000, sale=None))
    assert full is not None and full.regular_price is None and full.purchase_price == 189000


def test_vans_rejects_all_inactive_sizes_or_conflicting_meta():
    assert extract_site_pricing("vans", _vans_html(live=False)) is None
    assert extract_site_pricing("vans", _vans_html() + _meta("recopick:sale_price", 66500)) is None


def _verified_cafe24_html(*, name="상품", regular=74000, sale=70300, stocks=("InStock", "OutOfStock"), item_id="6388", button="구매하기", coupon=60000):
    offers = [{"name": f"{name} {i}", "price": sale, "priceCurrency": "KRW", "availability": stock} for i, stock in enumerate(stocks)]
    product = {"@context": "https://schema.org", "@type": "Product", "name": name, "offers": offers}
    return f'''<head>{_meta("product:retailer_item_id", item_id)}{_meta("product:sale_price:amount", sale)}{_meta("product:sale_price:currency", "KRW")}</head><main><h1>{name}</h1><span id="span_product_price_custom"><strike>{regular:,}원</strike></span><strong id="span_product_price_text">{sale:,}원</strong><span>{coupon:,}원 쿠폰 적용가</span><button>{button}</button></main><script type="application/ld+json">{json.dumps(product, ensure_ascii=False)}</script>'''


@pytest.mark.parametrize("platform,button", [("covernat", "CART BUY"), ("codegraphy", "구매하기"), ("whoau", "구매하기")])
def test_verified_cafe24_malls_use_live_sale_and_ignore_coupon(platform, button):
    pricing = extract_site_pricing(platform, _verified_cafe24_html(button=button))
    assert pricing is not None
    assert pricing.regular_price == 74000
    assert pricing.purchase_price == 70300


@pytest.mark.parametrize("platform,button", [("covernat", "CART BUY"), ("codegraphy", "구매하기"), ("whoau", "구매하기")])
def test_verified_cafe24_malls_reject_sold_out_conflict_or_multiple_products(platform, button):
    assert extract_site_pricing(platform, _verified_cafe24_html(button=button, stocks=("OutOfStock",))) is None
    conflict = _verified_cafe24_html(button=button).replace('content="70300"', 'content="60300"', 1)
    assert extract_site_pricing(platform, conflict) is None
    assert extract_site_pricing(platform, _verified_cafe24_html(button=button) + _verified_cafe24_html(name="추천 상품", sale=49000, regular=59000, item_id="9999", button=button)) is None


def _hm_html(*, prices=(39900, 39900), stocks=("InStock", "OutOfStock"), currency="KRW", article="1346684001"):
    variants = []
    for index, (price, stock) in enumerate(zip(prices, stocks), 1):
        variants.append({
            "@type": "Product",
            "name": f"벨티드 배럴 팬츠 {index}",
            "sku": f"{article}-{index}",
            "offers": {
                "price": price,
                "priceCurrency": currency,
                "availability": f"https://schema.org/{stock}",
                "url": f"https://www2.hm.com/ko_kr/productpage.{article}.html?variant={index}",
            },
        })
    group = {"@context": "https://schema.org", "@type": "ProductGroup", "productGroupID": "1346684", "hasVariant": variants}
    symbol = "₩" if currency == "KRW" else "$"
    return f'''<head><link rel="canonical" href="https://www2.hm.com/ko_kr/productpage.{article}.html"></head><main><h1>벨티드 배럴 팬츠</h1><strong>{symbol} {prices[0]:,}</strong><span>멤버 전제품 15% OFF</span><button>쇼핑백에 추가하기</button></main><script type="application/ld+json">{json.dumps(group, ensure_ascii=False)}</script>'''


def test_hm_uses_current_article_live_krw_variants_and_ignores_member_offer():
    pricing = extract_site_pricing("hm", _hm_html())
    assert pricing is not None
    assert pricing.regular_price is None
    assert pricing.purchase_price == 39900
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED


def test_hm_marks_option_range_and_rejects_usd_sold_out_or_wrong_article():
    ranged = extract_site_pricing("hm", _hm_html(prices=(39900, 49900), stocks=("InStock", "InStock")))
    assert ranged is not None
    assert ranged.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert ranged.option_price_min == 39900 and ranged.option_price_max == 49900
    assert extract_site_pricing("hm", _hm_html(currency="USD")) is None
    assert extract_site_pricing("hm", _hm_html(stocks=("OutOfStock", "OutOfStock"))) is None
    assert extract_site_pricing("hm", _hm_html().replace("productpage.1346684001.html?variant", "productpage.9999999999.html?variant")) is None


def test_gap_abstains_from_usd_and_checkout_only_discount():
    product = {"@context": "https://schema.org", "@type": "Product", "name": "Gap shirt", "offers": {"price": "39.95", "priceCurrency": "USD", "availability": "https://schema.org/InStock"}}
    html = f'<main><h1>Gap shirt</h1><b>$39.95</b><span>40% off at checkout</span><span>Guest cart total $23.97</span><button>Add to Bag</button></main><script type="application/ld+json">{json.dumps(product)}</script>'
    assert extract_site_pricing("gap", html) is None


def test_aritzia_abstains_when_localized_display_conflicts_with_jsonld():
    product = {"@context": "https://schema.org", "@type": "Product", "name": "Technique Dress", "offers": {"price": "75", "priceCurrency": "GBP", "availability": "https://schema.org/OutOfStock"}}
    html = f'<main><h1>Technique Dress</h1><del>₩257,400</del><b>₩128,700</b><button>Add to Bag — ₩75</button></main><script type="application/ld+json">{json.dumps(product)}</script>'
    assert extract_site_pricing("aritzia", html) is None


def _aritzia_html(*, product_id="129937", name="Leiden Dress - Crepette™", color="11420", regular=None, purchase=257400, live=(False, True), extra_product=False):
    variants = [
        {
            "productId": f"{product_id}{index:03d}", "price": 158,
            "orderable": orderable, "maxOrderQuantity": 5 if orderable else 0,
            "variationValues": {"color": color, "size": str(index)},
        }
        for index, orderable in enumerate(live, 1)
    ]
    products = {product_id: {"variants": variants}}
    if extra_product:
        products["999999"] = {"variants": []}
    state = {
        "__PRELOADED_STATE__": {
            "pageProps": {"structuredDataProps": {
                "seoProduct": {"id": product_id, "displayName": name},
                "structuredData": [{
                    "@type": "Product", "sku": product_id,
                    "@id": f"https://www.aritzia.com/intl/en/product/item/{product_id}.html?color={color}",
                    "offers": {"price": "158", "priceCurrency": "GBP", "availability": "http://schema.org/OutOfStock"},
                }],
            }},
            "__STATE_MANAGEMENT_LIBRARY": {"store": {"productStore": {"productsById": products}}},
        }
    }
    regular_html = f'<p data-testid="product-list-price-text">₩{regular:,}</p>' if regular else f'<p data-testid="product-list-price-text">₩{purchase:,}</p>'
    sale_html = f'<p data-testid="product-list-sale-text">₩{purchase:,}</p>' if regular else ""
    return f'''<main><h1>{name}</h1><span>#{product_id}</span><div data-testid="product-price-text">{regular_html}{sale_html}</div><button>Add to Bag — ₩{purchase:,}</button></main><script id="mobify-data" type="application/json">{json.dumps(state, ensure_ascii=False)}</script>'''


def test_aritzia_uses_localized_krw_price_with_selected_live_variants():
    full = extract_site_pricing("aritzia", _aritzia_html())
    assert full is not None
    assert full.regular_price is None and full.purchase_price == 257400
    assert full.confidence == PriceConfidence.HIGH

    sale = extract_site_pricing("aritzia", _aritzia_html(
        product_id="128841", name="Original Contour Waver Dress",
        color="36528", regular=168600, purchase=118000,
    ))
    assert sale is not None
    assert sale.regular_price == 168600 and sale.purchase_price == 118000


def test_aritzia_rejects_sold_out_corrupt_localization_or_ambiguous_state():
    assert extract_site_pricing("aritzia", _aritzia_html(live=(False, False))) is None
    assert extract_site_pricing("aritzia", _aritzia_html(purchase=40)) is None
    assert extract_site_pricing("aritzia", _aritzia_html(extra_product=True)) is None
    assert extract_site_pricing("aritzia", _aritzia_html().replace("color=11420", "color=99999")) is None


def _cafe24_meta_sale_html(*, name="상품", regular=99000, sale=89100, item_id="5485", stocks=("InStock",), action="구매하기", offer_price=None, custom=None):
    offer_price = regular if offer_price is None else offer_price
    offers = [{"availability": stock, "name": f"{name} {i}", "price": offer_price, "priceCurrency": "KRW"} for i, stock in enumerate(stocks)]
    product = {"@context": "https://schema.org", "@type": "Product", "name": name, "offers": offers}
    custom_html = f'<span id="span_product_price_custom">{custom:,}원</span>' if custom else ""
    return f'''<head>{_meta("product:retailer_item_id", item_id)}{_meta("product:price:amount", regular)}{_meta("product:price:currency", "KRW")}{_meta("product:sale_price:amount", sale)}{_meta("product:sale_price:currency", "KRW")}</head><main><h1>{name}</h1>{custom_html}<del>{regular:,}원</del><strong>{sale:,}원</strong><button>{action}</button></main><script type="application/ld+json">{json.dumps(product, ensure_ascii=False)}</script>'''


@pytest.mark.parametrize("platform,action", [
    ("noirer", "BUY NOW"), ("liphop", "BUY IT NOW"),
    ("marithe", "장바구니 담기"), ("vivastudio", ""),
    ("amomento", "Add To Bag"), ("anderssonbell", "ADD TO BAG"),
    ("yale", "구매하기"), ("mixxo", "바로 구매하기"),
    ("lee", "바로 구매하기"), ("withyoon", "Buy It Now"),
    ("66girls", "바로 구매하기"), ("partimento", "Add to Cart"),
    ("frombeginning", "바로구매"),
])
def test_cafe24_meta_sale_malls_use_live_options_and_automatic_sale(platform, action):
    pricing = extract_site_pricing(platform, _cafe24_meta_sale_html(action=action))
    assert pricing is not None
    assert pricing.regular_price == 99000
    assert pricing.purchase_price == 89100


@pytest.mark.parametrize("platform,action", [
    ("noirer", "BUY NOW"), ("liphop", "BUY IT NOW"),
    ("marithe", "장바구니 담기"), ("vivastudio", ""),
    ("amomento", "Add To Bag"), ("anderssonbell", "ADD TO BAG"),
    ("yale", "구매하기"), ("mixxo", "바로 구매하기"),
    ("lee", "바로 구매하기"), ("withyoon", "Buy It Now"),
    ("66girls", "바로 구매하기"), ("partimento", "Add to Cart"),
    ("frombeginning", "바로구매"),
])
def test_cafe24_meta_sale_malls_reject_sold_out_conflict_or_multiple_products(platform, action):
    assert extract_site_pricing(platform, _cafe24_meta_sale_html(action=action, stocks=("OutOfStock",))) is None
    assert extract_site_pricing(platform, _cafe24_meta_sale_html(action=action, offer_price=77700)) is None
    mixed = _cafe24_meta_sale_html(action=action) + _cafe24_meta_sale_html(name="추천 상품", regular=59000, sale=49000, item_id="9999", action=action)
    assert extract_site_pricing(platform, mixed) is None


def test_yale_uses_explicit_custom_regular_when_offer_is_sale_price():
    pricing = extract_site_pricing("yale", _cafe24_meta_sale_html(regular=79900, sale=79900, offer_price=79900, custom=99900, action="구매하기"))
    assert pricing is not None
    assert pricing.regular_price == 99900 and pricing.purchase_price == 79900


def test_mixxo_accepts_duplicate_equivalent_main_product_jsonld_names():
    html = _cafe24_meta_sale_html(
        name="페이크레더 버클 점퍼 RE JLG33SS_MIWJLG92QC",
        regular=129000, sale=129000, item_id="13633", action="바로 구매하기",
    )
    short = {
        "@context": "https://schema.org", "@type": "Product",
        "name": "페이크레더 버클 점퍼",
        "offers": {"price": 129000, "priceCurrency": "KRW", "availability": "https://schema.org/InStock"},
    }
    pricing = extract_site_pricing("mixxo", html + f'<script type="application/ld+json">{json.dumps(short, ensure_ascii=False)}</script>')
    assert pricing is not None and pricing.regular_price is None and pricing.purchase_price == 129000


def _fashionplus_html(*, prices=(63460, 63460), sale=63460, regular=100190, availability="InStock", product_id="360285660", name="린넨 루즈핏 로브 셔츠"):
    product = {
        "@context": "https://schema.org", "@type": "Product", "name": name,
        "mpn": product_id,
        "offers": {"price": regular, "sale_price": sale, "priceCurrency": "KRW", "availability": f"https://schema.org/{availability}"},
    }
    buttons = "".join(f'<button class="btn_option">색상 {index} {price:,}원</button>' for index, price in enumerate(prices))
    return f'<main><h1>{name}</h1><del>{regular:,}원</del><b>{sale:,}원</b>{buttons}<button>장바구니</button><button>구매하기</button><span>신규회원 54,460원</span></main><script type="application/ld+json">{json.dumps(product, ensure_ascii=False)}</script>'


def test_fashionplus_uses_automatic_sale_and_enabled_option_prices():
    pricing = extract_site_pricing("fashionplus", _fashionplus_html())
    assert pricing is not None
    assert pricing.regular_price == 100190 and pricing.purchase_price == 63460
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED


def test_fashionplus_marks_bundle_range_without_fabricating_regular():
    pricing = extract_site_pricing(
        "fashionplus", _fashionplus_html(prices=(15660, 16530, 71520), sale=16530, regular=29000),
    )
    assert pricing is not None and pricing.regular_price is None
    assert pricing.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert pricing.purchase_price == 15660
    assert pricing.option_price_min == 15660 and pricing.option_price_max == 71520


def test_fashionplus_rejects_unavailable_conflicting_or_multiple_products():
    assert extract_site_pricing("fashionplus", _fashionplus_html(availability="OutOfStock")) is None
    assert extract_site_pricing("fashionplus", _fashionplus_html(sale=55555)) is None
    mixed = _fashionplus_html() + _fashionplus_html(product_id="999", name="추천 상품")
    assert extract_site_pricing("fashionplus", mixed) is None


def test_lfmall_abstains_from_jsonld_without_loaded_options_or_availability():
    product = {"@context": "https://schema.org", "@type": "Product", "name": "닥스 셔츠", "offers": {"price": 95000, "priceCurrency": "KRW"}}
    html = f'<main><h1>로딩중</h1><span>관련 상품 36,430원</span><button>바로구매</button></main><script type="application/ld+json">{json.dumps(product, ensure_ascii=False)}</script>'
    assert extract_site_pricing("lfmall", html) is None


def _reformation_html(*, prices=(525500, 525500), stocks=("OutOfStock", "InStock"), currency="KRW", name="Sol Linen Dress"):
    offers = [
        {"price": price, "priceCurrency": currency, "availability": f"https://schema.org/{stock}"}
        for price, stock in zip(prices, stocks)
    ]
    product = {"@context": "https://schema.org", "@type": "Product", "name": name, "offers": offers}
    shown = " ".join(f'₩{price:,}' for price in prices)
    return f'<main><h1>{name}</h1><strong>{shown}</strong><span>30% off sale banner</span><button>Add to bag</button></main><script type="application/ld+json">{json.dumps(product)}</script>'


def test_reformation_uses_live_localized_krw_price_not_sale_banner():
    pricing = extract_site_pricing("reformation", _reformation_html())
    assert pricing is not None
    assert pricing.regular_price is None and pricing.purchase_price == 525500
    assert pricing.confidence == PriceConfidence.HIGH


def test_reformation_marks_live_option_range_and_rejects_unsafe_products():
    ranged = extract_site_pricing("reformation", _reformation_html(prices=(400000, 525500), stocks=("InStock", "InStock")))
    assert ranged is not None and ranged.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert ranged.option_price_min == 400000 and ranged.option_price_max == 525500
    assert extract_site_pricing("reformation", _reformation_html(stocks=("OutOfStock", "OutOfStock"))) is None
    assert extract_site_pricing("reformation", _reformation_html(currency="USD")) is None
    assert extract_site_pricing("reformation", _reformation_html() + _reformation_html(name="Related Dress")) is None


def _single_offer_html(*, name, regular, sale, item_id, action, sold_out=False):
    product = {"@context": "https://schema.org", "@type": "Product", "name": name, "offers": {"price": regular, "priceCurrency": "KRW"}}
    state = "품절" if sold_out else action
    return f'''<head>{_meta("product:retailer_item_id", item_id)}{_meta("product:price:amount", regular)}{_meta("product:price:currency", "KRW")}{_meta("product:sale_price:amount", sale)}{_meta("product:sale_price:currency", "KRW")}</head><main><h1>{name}</h1><del>{regular:,}원</del><b>{sale:,}원</b><span>{state}</span></main><script type="application/ld+json">{json.dumps(product, ensure_ascii=False)}</script>'''


def test_mahagrid_uses_sale_meta_only_with_active_purchase_actions():
    html = _single_offer_html(name="THIRD LOGO BACKPACK", regular=109000, sale=65400, item_id="3854", action="장바구니 구매하기")
    pricing = extract_site_pricing("mahagrid", html)
    assert pricing is not None and pricing.regular_price == 109000 and pricing.purchase_price == 65400
    assert extract_site_pricing("mahagrid", html.replace("장바구니 구매하기", "품절")) is None


def test_ohora_requires_selected_main_product_total_and_rejects_restock_page():
    html = _single_offer_html(name="N 듀이 민트 네일", regular=12800, sale=10880, item_id="2137", action="장바구니 바로 구매 총 상품금액 10,880원")
    pricing = extract_site_pricing("ohora", html)
    assert pricing is not None and pricing.regular_price == 12800 and pricing.purchase_price == 10880
    assert extract_site_pricing("ohora", html.replace("장바구니 바로 구매 총 상품금액 10,880원", "재입고 알림 신청")) is None


def _nike_html(*, style="HM9697-002", current=126600, initial=149000,
               currency="KRW", availability="InStock", status="BUYABLE_BUY",
               extra_product=False, ld_price=None):
    title = "나이키 아바 X"
    product = {
        "styleColor": style,
        "statusModifier": status,
        "prices": {
            "currency": currency, "currentPrice": current,
            "initialPrice": initial, "discountPercentage": 15,
        },
        "productInfo": {"title": title},
        "sizes": [{"localizedLabel": "260", "status": "ACTIVE"}],
    }
    products = {style: product}
    if extra_product:
        products["OTHER-100"] = {
            **product, "styleColor": style,
            "prices": {**product["prices"], "currentPrice": 99900},
        }
    next_data = {"props": {"pageProps": {"productGroups": [{"products": products}]}}}
    variant = {
        "@type": "Product", "mpn": style,
        "offers": {
            "price": current if ld_price is None else ld_price,
            "priceCurrency": currency,
            "availability": f"https://schema.org/{availability}",
        },
    }
    group = {"@context": "https://schema.org", "@type": "ProductGroup", "hasVariant": [variant]}
    return f'''<head><meta property="og:url" content="https://www.nike.com/kr/t/product/{style}"></head>
    <main><h1>{title}</h1><del>{initial:,} 원</del><strong>{current:,} 원</strong><button>장바구니</button><span>쿠폰 적용가 1,000원</span></main>
    <script id="__NEXT_DATA__" type="application/json">{json.dumps(next_data, ensure_ascii=False)}</script>
    <script type="application/ld+json">{json.dumps([group], ensure_ascii=False)}</script>'''


def test_nike_uses_selected_colorway_current_and_initial_prices():
    pricing = extract_site_pricing("nike", _nike_html())
    assert pricing is not None
    assert pricing.regular_price == 149000 and pricing.purchase_price == 126600
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED
    assert pricing.confidence == PriceConfidence.MEDIUM

    full = extract_site_pricing("nike", _nike_html(current=139000, initial=139000))
    assert full is not None and full.regular_price is None and full.purchase_price == 139000


def test_nike_rejects_unavailable_currency_conflict_or_ambiguous_product():
    assert extract_site_pricing("nike", _nike_html(availability="OutOfStock")) is None
    assert extract_site_pricing("nike", _nike_html(currency="USD")) is None
    assert extract_site_pricing("nike", _nike_html(ld_price=125000)) is None
    assert extract_site_pricing("nike", _nike_html(extra_product=True)) is None
    assert extract_site_pricing("nike", _nike_html().replace("/HM9697-002\"", "/UNKNOWN-000\"", 1)) is None


def _oliveyoung_html(*, goods_no="A000000260600", name="셀라딕스 앰플",
                     options=None, promotion=26900, final=25400,
                     has_coupon=True, saleable=True, displayable=True,
                     status="20"):
    if options is None:
        options = [{
            "goodsNumber": goods_no, "optionNumber": "001",
            "optionName": "기본", "soldOutFlag": False,
            "orderableMinimumQuantity": 1, "orderableMaximumQuantity": 999,
            "salePrice": 28900, "finalPrice": final,
        }]
    representative = next((value for value in options if not value.get("soldOutFlag")), options[0])
    state = {
        "saleableFlag": saleable, "displayableFlag": displayable,
        "soldOutFlag": all(value.get("soldOutFlag") for value in options),
        "status": status, "goodsNumber": goods_no, "goodsName": name,
        "options": options,
        "maxBenefitPriceDto": {
            "optionNumber": representative["optionNumber"],
            "originalSalePrice": representative["salePrice"],
            "promotionSalePrice": promotion,
            "finalPrice": representative["finalPrice"],
            "hasPromotion": promotion < representative["salePrice"],
            "hasCoupon": has_coupon,
            "coupon": {"discountAmount": promotion - final} if has_coupon else None,
        },
    }
    decoded = "f:" + json.dumps({"state": {"queries": [{"state": {"data": {"data": state}}}]}}, ensure_ascii=False)
    flight = "self.__next_f.push(" + json.dumps([1, decoded], ensure_ascii=False) + ")"
    return f'''<main><h1>{name}</h1><del>{representative["salePrice"]:,}원</del>
    <b>{representative["finalPrice"]:,}원</b><span>쿠폰 최적가</span>
    <button>장바구니</button><button>바로구매</button></main><script>{flight}</script>'''


def test_oliveyoung_excludes_coupon_and_uses_automatic_promotion_price():
    pricing = extract_site_pricing("oliveyoung", _oliveyoung_html())
    assert pricing is not None
    assert pricing.regular_price == 28900
    assert pricing.purchase_price == 26900
    assert pricing.purchase_price_status == PurchasePriceStatus.CONFIRMED
    assert pricing.confidence == PriceConfidence.MEDIUM


def test_oliveyoung_uses_only_live_options_and_marks_safe_range():
    options = [
        {"goodsNumber": "A1", "optionNumber": "001", "soldOutFlag": False,
         "orderableMinimumQuantity": 1, "orderableMaximumQuantity": 5,
         "salePrice": 29000, "finalPrice": 23300},
        {"goodsNumber": "A1", "optionNumber": "002", "soldOutFlag": False,
         "orderableMinimumQuantity": 1, "orderableMaximumQuantity": 5,
         "salePrice": 39000, "finalPrice": 31000},
        {"goodsNumber": "A1", "optionNumber": "003", "soldOutFlag": True,
         "orderableMinimumQuantity": 1, "orderableMaximumQuantity": 5,
         "salePrice": 99000, "finalPrice": 1000},
    ]
    pricing = extract_site_pricing(
        "oliveyoung",
        _oliveyoung_html(goods_no="A1", options=options, promotion=23300,
                         final=23300, has_coupon=False),
    )
    assert pricing is not None and pricing.regular_price is None
    assert pricing.purchase_price_status == PurchasePriceStatus.OPTION_DEPENDENT
    assert pricing.purchase_price == 23300
    assert pricing.option_price_min == 23300 and pricing.option_price_max == 31000


def test_oliveyoung_rejects_sold_out_conflict_multiple_products_and_unsafe_coupon_options():
    sold = [{"goodsNumber": "A1", "optionNumber": "001", "soldOutFlag": True,
             "orderableMinimumQuantity": 1, "orderableMaximumQuantity": 5,
             "salePrice": 29000, "finalPrice": 23300}]
    assert extract_site_pricing("oliveyoung", _oliveyoung_html(options=sold)) is None
    assert extract_site_pricing("oliveyoung", _oliveyoung_html(displayable=False)) is None
    assert extract_site_pricing("oliveyoung", _oliveyoung_html().replace("바로구매", "재입고 알림")) is None
    mixed = _oliveyoung_html() + _oliveyoung_html(goods_no="A000000999999", name="추천 상품")
    assert extract_site_pricing("oliveyoung", mixed) is None

    differing_coupon = [
        {"goodsNumber": "A1", "optionNumber": "001", "soldOutFlag": False,
         "orderableMinimumQuantity": 1, "orderableMaximumQuantity": 5,
         "salePrice": 29000, "finalPrice": 23300},
        {"goodsNumber": "A1", "optionNumber": "002", "soldOutFlag": False,
         "orderableMinimumQuantity": 1, "orderableMaximumQuantity": 5,
         "salePrice": 39000, "finalPrice": 31000},
    ]
    assert extract_site_pricing(
        "oliveyoung", _oliveyoung_html(goods_no="A1", options=differing_coupon)
    ) is None
