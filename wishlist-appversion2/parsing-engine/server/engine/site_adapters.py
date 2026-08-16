"""쇼핑몰별 가격 의미 어댑터.

범용 JSON-LD/OG 파서는 숫자를 찾는 역할까지만 한다. 이 모듈은 특정 쇼핑몰이
직접 제공하는 상태 필드의 의미가 확인된 경우에만 구매 가격을 confirmed로 올린다.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass

from bs4 import BeautifulSoup

from .models import PriceConfidence, PurchasePriceStatus


@dataclass(frozen=True)
class SitePricing:
    regular_price: int | None
    purchase_price: int | None
    purchase_price_status: PurchasePriceStatus
    confidence: PriceConfidence
    adapter: str
    purchase_field: str
    regular_field: str | None = None
    option_dependent: bool | None = None
    option_price_min: int | None = None
    option_price_max: int | None = None

    def evidence(self) -> list[dict]:
        result = [{
            "price_role": "purchase_price",
            "source": "embedded-state",
            "adapter": self.adapter,
            "field": self.purchase_field,
        }]
        if self.regular_price is not None and self.regular_field:
            result.append({
                "price_role": "regular_price",
                "source": "embedded-state",
                "adapter": self.adapter,
                "field": self.regular_field,
            })
        return result


_MUSINSA_GOODS_PRICE = re.compile(r'"goodsPrice"\s*:\s*\{')


def _object_fragment(html: str, start: int, max_size: int = 5000) -> str | None:
    """start 직전의 여는 중괄호와 짝인 JSON 객체 내용만 잘라낸다."""
    depth = 1
    in_string = False
    escaped = False
    for index in range(start, min(len(html), start + max_size)):
        char = html[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return html[start:index]
    return None


def _json_int(fragment: str, field: str) -> int | None:
    match = re.search(rf'"{re.escape(field)}"\s*:\s*(\d+)', fragment)
    if match is None:
        return None
    value = int(match.group(1))
    return value if value > 0 else None


def _json_string(fragment: str, field: str) -> str | None:
    match = re.search(
        rf'"{re.escape(field)}"\s*:\s*"([^"\\]*)"', fragment
    )
    return match.group(1) if match else None


def _extract_musinsa_pricing(html: str) -> SitePricing | None:
    """goodsPrice.salePrice/normalPrice만 채택하고 쿠폰·최종가는 제외한다."""
    candidates: set[tuple[int, int | None, str | None, str | None]] = set()
    for match in _MUSINSA_GOODS_PRICE.finditer(html):
        fragment = _object_fragment(html, match.end())
        if fragment is None:
            continue
        sale = _json_int(fragment, "salePrice")
        regular = _json_int(fragment, "normalPrice")
        currency = _json_string(fragment, "currency")
        price_type = _json_string(fragment, "type")
        if sale is None:
            continue
        if regular is not None and regular < sale:
            continue
        if currency not in (None, "KRW"):
            continue
        candidates.add((sale, regular, currency, price_type))

    # 추천 상품 등 서로 다른 가격 객체가 섞이면 억지로 하나를 고르지 않는다.
    if len(candidates) != 1:
        return None

    sale, regular, _, price_type = next(iter(candidates))
    if price_type not in (None, "DEFAULT"):
        return None

    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="musinsa",
        purchase_field="goodsPrice.salePrice",
        regular_field=(
            "goodsPrice.normalPrice" if regular is not None else None
        ),
        # 기본가는 확인했지만 모든 옵션의 추가금까지 펼쳐 본 것은 아니다.
        option_dependent=None,
    )


def _positive_int(value) -> int | None:
    if isinstance(value, bool):
        return None
    try:
        number = int(float(value))
    except (TypeError, ValueError):
        return None
    return number if number > 0 else None


def _extract_wconcept_pricing(html: str) -> SitePricing | None:
    """W컨셉 상품 상태와 주문 폼이 동시에 가리키는 기본가만 확정한다."""
    soup = BeautifulSoup(html, "lxml")
    hidden_sales = {
        value for tag in soup.select('input[name="saleprice"]')
        if (value := _positive_int(tag.get("value"))) is not None
    }
    hidden_regulars = {
        value for tag in soup.select('input[name="originalPrice"]')
        if (value := _positive_int(tag.get("value"))) is not None
    }

    candidates: set[tuple[int, int | None, str | None]] = set()
    for tag in soup.select('input[name^="GA4ItemObj_"]'):
        raw = tag.get("value")
        if not raw:
            continue
        try:
            state = json.loads(raw)
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        sale = _positive_int(state.get("SalePrice"))
        regular = _positive_int(state.get("CustomerPrice"))
        currency = state.get("Currency")
        item_code = str(state.get("ItemCd") or "")
        input_code = str(tag.get("name") or "").removeprefix("GA4ItemObj_")
        if sale is None or (regular is not None and regular < sale):
            continue
        if currency not in (None, "KRW"):
            continue
        if item_code and input_code and item_code != input_code:
            continue
        candidates.add((sale, regular, currency))

    if len(candidates) != 1:
        return None
    sale, regular, _ = next(iter(candidates))

    # 분석용 상태와 실제 옵션 주문 폼이 같은 숫자를 가리킬 때만 확정한다.
    if hidden_sales != {sale}:
        return None
    if regular is not None and hidden_regulars != {regular}:
        return None

    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="wconcept",
        purchase_field="GA4ItemObj.SalePrice",
        regular_field=(
            "GA4ItemObj.CustomerPrice" if regular is not None else None
        ),
        option_dependent=None,
    )


def _unescape_script_quotes(html: str) -> str:
    normalized = html
    for _ in range(4):
        updated = normalized.replace(r'\"', '"')
        if updated == normalized:
            break
        normalized = updated
    return normalized


def _extract_29cm_pricing(html: str) -> SitePricing | None:
    """29CM의 상품 원가/판매가와 옵션 추가금 상태를 읽는다."""
    normalized = _unescape_script_quotes(html)
    candidates = {
        (int(match.group(1)), int(match.group(2)))
        for match in re.finditer(
            r'"sellPrice"\s*:\s*(\d+)\s*,\s*"consumerPrice"\s*:\s*(\d+)',
            normalized,
        )
        if int(match.group(1)) > 0 and int(match.group(2)) >= int(match.group(1))
    }
    if len(candidates) != 1:
        return None
    sale, regular = next(iter(candidates))

    option_states = {
        (int(match.group(1)), int(match.group(2)), match.group(3) == "true")
        for match in re.finditer(
            r'"visibleMaxExtraPrice"\s*:\s*(-?\d+)\s*,\s*'
            r'"visibleMinExtraPrice"\s*:\s*(-?\d+)\s*,\s*'
            r'"hasVisibleOptionExtraPrice"\s*:\s*(true|false)',
            normalized,
        )
    }
    if len(option_states) > 1:
        return None

    option_dependent: bool | None = None
    option_min = None
    option_max = None
    status = PurchasePriceStatus.CONFIRMED
    if option_states:
        max_extra, min_extra, has_extra = next(iter(option_states))
        option_dependent = has_extra
        if has_extra:
            option_min = sale + min_extra
            option_max = sale + max_extra
            if option_min <= 0 or option_max < option_min:
                return None
            status = PurchasePriceStatus.OPTION_DEPENDENT

    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=status,
        confidence=PriceConfidence.HIGH,
        adapter="29cm",
        purchase_field="item.sellPrice",
        regular_field="item.consumerPrice",
        option_dependent=option_dependent,
        option_price_min=option_min,
        option_price_max=option_max,
    )


def _extract_fila_pricing(html: str) -> SitePricing | None:
    """Read FILA's Shopify variant price while keeping member coupons separate."""
    soup = BeautifulSoup(html, "lxml")

    selected_variants: list[dict] = []
    for tag in soup.select('script[type="application/json"][data-selected-variant]'):
        try:
            state = json.loads(tag.get_text(strip=True))
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if isinstance(state, dict):
            selected_variants.append(state)
    if len(selected_variants) != 1:
        return None

    selected = selected_variants[0]
    selected_price_cents = _positive_int(selected.get("price"))
    if selected_price_cents is None or selected_price_cents % 100:
        return None
    selected_price = selected_price_cents // 100

    compare_cents = _positive_int(selected.get("compare_at_price"))
    regular = None
    if compare_cents is not None:
        if compare_cents % 100:
            return None
        regular = compare_cents // 100
        if regular < selected_price:
            return None

    offer_prices: set[int] = set()
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(state, dict) or state.get("@type") != "ProductGroup":
            continue
        for variant in state.get("hasVariant") or []:
            if not isinstance(variant, dict):
                continue
            offer = variant.get("offers")
            if not isinstance(offer, dict):
                continue
            if offer.get("priceCurrency") not in (None, "KRW"):
                continue
            price = _positive_int(offer.get("price"))
            if price is not None:
                offer_prices.add(price)

    if not offer_prices or selected_price not in offer_prices:
        return None

    option_dependent = len(offer_prices) > 1
    return SitePricing(
        regular_price=regular,
        purchase_price=min(offer_prices),
        purchase_price_status=(
            PurchasePriceStatus.OPTION_DEPENDENT
            if option_dependent
            else PurchasePriceStatus.CONFIRMED
        ),
        confidence=PriceConfidence.HIGH,
        adapter="fila",
        purchase_field="ProductGroup.hasVariant.offers.price",
        regular_field=(
            "selectedVariant.compare_at_price" if regular is not None else None
        ),
        option_dependent=option_dependent,
        option_price_min=min(offer_prices) if option_dependent else None,
        option_price_max=max(offer_prices) if option_dependent else None,
    )


def _extract_hago_pricing(html: str) -> SitePricing | None:
    """Use HAGO's merchandise price, never its automatically applied coupon."""
    candidates: set[tuple[int, int, str]] = set()
    for match in re.finditer(
        r"var\s+goodsInfo\s*=\s*\{(?P<body>[\s\S]*?)\n\s*\};",
        html,
    ):
        body = match.group("body")
        regular_match = re.search(r"\bprice\s*:\s*(\d+)", body)
        discount_match = re.search(r"\bdcPrice\s*:\s*(\d+)", body)
        sale_match = re.search(r"\bsellPrice\s*:\s*(\d+)", body)
        soldout_match = re.search(r"\bsoldout\s*:\s*['\"]([YN])['\"]", body)
        if not all((regular_match, discount_match, sale_match, soldout_match)):
            continue
        regular = int(regular_match.group(1))
        discount = int(discount_match.group(1))
        sale = int(sale_match.group(1))
        soldout = soldout_match.group(1)
        if sale <= 0 or regular < sale or discount != sale:
            continue
        candidates.add((sale, regular, soldout))

    if len(candidates) != 1:
        return None
    sale, regular, soldout = next(iter(candidates))
    if soldout != "N":
        return None

    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="hago",
        purchase_field="goodsInfo.sellPrice",
        regular_field="goodsInfo.price",
        option_dependent=None,
    )


def _extract_lookpin_pricing(html: str) -> SitePricing | None:
    """Read Lookpin's product price block and ignore its reward point range."""
    soup = BeautifulSoup(html, "lxml")
    if "품절" in soup.get_text(" ", strip=True):
        return None

    candidates: set[tuple[int, int]] = set()
    for sale_tag in soup.select("span.text-h2-lg.text-black.font-bold"):
        parent = sale_tag.parent
        if parent is None:
            continue
        regular_tag = parent.find("del")
        sale_text = re.sub(
            r"\D", "", sale_tag.get_text("", strip=True)
        )
        regular_text = (
            re.sub(r"\D", "", regular_tag.get_text("", strip=True))
            if regular_tag else None
        )
        sale = _positive_int(sale_text)
        regular = _positive_int(regular_text)
        if sale is None or regular is None or regular < sale:
            continue
        candidates.add((sale, regular))

    if len(candidates) != 1:
        return None
    sale, regular = next(iter(candidates))
    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="lookpin",
        purchase_field="product-price.sale",
        regular_field="product-price.del",
        option_dependent=None,
    )


def _extract_topten_pricing(html: str) -> SitePricing | None:
    """Read Goodwearmall's live Product offer and its explicitly labelled list price."""
    soup = BeautifulSoup(html, "lxml")
    candidates: set[tuple[int, int | None]] = set()
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(state, dict) or state.get("@type") != "Product":
            continue
        if not str(state.get("name") or "").strip() or not str(state.get("sku") or "").strip():
            continue
        offer = state.get("offers")
        if not isinstance(offer, dict):
            continue
        if offer.get("availability") == "https://schema.org/OutOfStock":
            continue
        if offer.get("priceCurrency") not in (None, "KRW"):
            continue
        sale = _positive_int(offer.get("price"))
        if sale is None:
            continue

        regular = None
        for prop in state.get("additionalProperty") or []:
            if isinstance(prop, dict) and prop.get("name") == "정가":
                regular = _positive_int(prop.get("value"))
        if regular is not None and regular < sale:
            continue
        candidates.add((sale, regular))

    if len(candidates) != 1:
        return None
    sale, regular = next(iter(candidates))
    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="topten",
        purchase_field="Product.offers.price",
        regular_field=("Product.additionalProperty[정가]" if regular else None),
        option_dependent=None,
    )


def _extract_muji_pricing(html: str) -> SitePricing | None:
    """Read only MUJI's primary product state, not coordinated products."""
    normalized = _unescape_script_quotes(html)
    matches = list(re.finditer(
        r'"row"\s*:\s*\{\s*"product"\s*:\s*\{'
        r'[\s\S]{0,1200}?"product_id"\s*:\s*(?P<id>\d+)\s*,'
        r'\s*"sale_state"\s*:\s*"(?P<state>[A-Z_]+)"\s*,'
        r'[\s\S]{0,1000}?"retail_price"\s*:\s*(?P<regular>\d+)\s*,'
        r'\s*"discount_price"\s*:\s*\d+\s*,'
        r'\s*"discount_rate"\s*:\s*\d+\s*,'
        r'\s*"sell_price"\s*:\s*(?P<sale>\d+)\s*,'
        r'\s*"last_price"\s*:\s*(?P<last>\d+)',
        normalized,
    ))
    if len(matches) != 1:
        return None

    match = matches[0]
    if match.group("state") != "ON":
        return None
    regular = int(match.group("regular"))
    sale = int(match.group("sale"))
    last = int(match.group("last"))
    if sale <= 0 or last != sale or regular < sale:
        return None

    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="muji",
        purchase_field="product.sell_price",
        regular_field="product.retail_price",
        option_dependent=None,
    )


def _extract_hmall_pricing(html: str) -> SitePricing | None:
    """Use Hmall's displayed buying price and reject stopped products."""
    soup = BeautifulSoup(html, "lxml")
    candidates: set[tuple[int, int]] = set()
    for tag in soup.select('script#__NEXT_DATA__'):
        try:
            state = json.loads(tag.get_text())
            item = state["props"]["pageProps"]["respData"]["itemPtc"]
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(item, dict) or item.get("soldout") is not False:
            continue
        purchase = _positive_int(item.get("bbprc"))
        regular = _positive_int(item.get("sellPrc"))
        if purchase is None or regular is None or regular < purchase:
            continue
        candidates.add((purchase, regular))

    if len(candidates) != 1:
        return None
    purchase, regular = next(iter(candidates))
    return SitePricing(
        regular_price=regular,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="hmall",
        purchase_field="itemPtc.bbprc",
        regular_field="itemPtc.sellPrc",
        option_dependent=None,
    )


def _extract_lotteon_pricing(html: str) -> SitePricing | None:
    """Trust LotteON's offer only when live page state agrees with it."""
    soup = BeautifulSoup(html, "lxml")
    page_text = soup.get_text(" ", strip=True)
    if "품절된 상품입니다" in page_text:
        return None

    candidates: set[int] = set()
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            states = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(states, list):
            states = [states]
        for state in states:
            if not isinstance(state, dict) or state.get("@type") != "Product":
                continue
            if not str(state.get("name") or "").strip() or not str(state.get("sku") or "").strip():
                continue
            offer = state.get("offers")
            if not isinstance(offer, dict):
                continue
            if offer.get("availability") != "https://schema.org/InStock":
                continue
            if offer.get("priceCurrency") not in (None, "KRW"):
                continue
            sale = _positive_int(offer.get("price"))
            if sale is None or f"{sale:,}원" not in page_text:
                continue
            candidates.add(sale)

    if len(candidates) != 1:
        return None
    sale = next(iter(candidates))
    return SitePricing(
        regular_price=None,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="lotteon",
        purchase_field="Product.offers.price",
        regular_field=None,
        option_dependent=None,
    )


def _extract_cafe24_offer_pricing(
    html: str, *, adapter: str, confidence: PriceConfidence,
) -> SitePricing | None:
    """Read option offers only when Cafe24 exposes explicit stock states."""
    soup = BeautifulSoup(html, "lxml")
    candidates: list[tuple[list[int], int]] = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        states = state if isinstance(state, list) else [state]
        for product in states:
            if not isinstance(product, dict) or product.get("@type") != "Product":
                continue
            if not str(product.get("name") or "").strip():
                continue
            raw_offers = product.get("offers")
            offers = raw_offers if isinstance(raw_offers, list) else [raw_offers]
            offers = [offer for offer in offers if isinstance(offer, dict)]
            if not offers:
                continue

            # Editorial/promotion pages often use a placeholder price without
            # availability. Treat those as non-products instead of guessing.
            states = {offer.get("availability") for offer in offers}
            if not states <= {"InStock", "OutOfStock"}:
                continue
            live_prices = [
                price for offer in offers
                if offer.get("availability") == "InStock"
                and (price := _positive_int(offer.get("price"))) is not None
                and offer.get("priceCurrency") in (None, "KRW")
            ]
            if not live_prices:
                continue
            if len(live_prices) != sum(
                offer.get("availability") == "InStock" for offer in offers
            ):
                continue
            candidates.append((live_prices, len(offers)))

    if len(candidates) != 1:
        return None
    live_prices, _ = candidates[0]
    low, high = min(live_prices), max(live_prices)
    option_dependent = low != high
    return SitePricing(
        regular_price=None,
        purchase_price=low,
        purchase_price_status=(
            PurchasePriceStatus.OPTION_DEPENDENT
            if option_dependent else PurchasePriceStatus.CONFIRMED
        ),
        confidence=confidence,
        adapter=adapter,
        purchase_field="Product.offers[InStock].price",
        regular_field=None,
        option_dependent=option_dependent,
        option_price_min=low if option_dependent else None,
        option_price_max=high if option_dependent else None,
    )


def _script_price(html: str, field: str) -> int | None:
    match = re.search(
        rf"(?:var\s+)?{re.escape(field)}\s*=\s*['\"]?(\d+(?:\.\d+)?)",
        html,
    )
    return _positive_int(match.group(1)) if match else None


def _labelled_won_price(soup: BeautifulSoup, label: str) -> int | None:
    """Read a price only from a table row whose header gives its meaning."""
    values: set[int] = set()
    for row in soup.select("tr"):
        cells = row.find_all(["th", "td"], recursive=False)
        if len(cells) < 2 or cells[0].get_text(" ", strip=True) != label:
            continue
        match = re.search(r"([\d,]+)\s*원", cells[1].get_text(" ", strip=True))
        if match and (value := _positive_int(match.group(1).replace(",", ""))):
            values.add(value)
    return next(iter(values)) if len(values) == 1 else None


def _cafe24_product_offers(html: str) -> list[dict] | None:
    soup = BeautifulSoup(html, "lxml")
    products: list[dict] = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        states = state if isinstance(state, list) else [state]
        products.extend(
            item for item in states
            if isinstance(item, dict)
            and item.get("@type") == "Product"
            and str(item.get("name") or "").strip()
        )
    if len(products) != 1:
        return None
    raw = products[0].get("offers")
    offers = raw if isinstance(raw, list) else [raw]
    offers = [offer for offer in offers if isinstance(offer, dict)]
    return offers or None


def _live_cafe24_options(soup: BeautifulSoup) -> list:
    """Return selectable product options, excluding placeholders and sold-out rows."""
    return [
        option for option in soup.select('select[id^="product_option_id"] option')
        if str(option.get("value") or "") not in ("", "*", "**")
        and "품절" not in option.get_text(" ", strip=True)
    ]


def _product_table_prices(soup: BeautifulSoup, purchase: int) -> set[int]:
    """Collect won prices only from a product-detail table containing purchase."""
    candidates: list[set[int]] = []
    for table in soup.select(
        ".xans-product-detaildesign table, .xans-product-detail .infoArea table, "
        "table[summary*='상품'], table[summary*='기본']"
    ):
        values = {
            value
            for match in re.finditer(
                r"([\d,]+)\s*원", table.get_text(" ", strip=True)
            )
            if (value := _positive_int(match.group(1).replace(",", "")))
        }
        if purchase in values:
            candidates.append(values)
    if len(candidates) != 1:
        return set()
    return candidates[0]


def _extract_filluminate_pricing(html: str) -> SitePricing | None:
    """Use Cafe24's automatic sale field, not its stale JSON-LD price."""
    offers = _cafe24_product_offers(html)
    if not offers:
        return None
    states = {offer.get("availability") for offer in offers}
    if not states <= {"InStock", "OutOfStock"}:
        return None
    live = [offer for offer in offers if offer.get("availability") == "InStock"]
    if not live:
        return None
    regulars = {
        price for offer in live
        if offer.get("priceCurrency") in (None, "KRW")
        and (price := _positive_int(offer.get("price"))) is not None
    }
    if len(regulars) != 1 or len(live) != sum(
        offer.get("priceCurrency") in (None, "KRW")
        and _positive_int(offer.get("price")) is not None
        for offer in live
    ):
        return None
    regular = next(iter(regulars))
    if _script_price(html, "product_price") != regular:
        return None
    sale = _script_price(html, "product_sale_price") or regular
    if sale > regular:
        return None
    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="filluminate",
        purchase_field="product_sale_price || product_price",
        regular_field="product_price",
        option_dependent=False,
    )


def _extract_urbanstoff_pricing(html: str) -> SitePricing | None:
    """Read the automatic order discount that is applied to guest checkout."""
    soup = BeautifulSoup(html, "lxml")
    offers = _cafe24_product_offers(html)
    if not offers:
        return None
    offer_prices = {
        price for offer in offers
        if offer.get("priceCurrency") in (None, "KRW")
        and (price := _positive_int(offer.get("price"))) is not None
    }
    if len(offer_prices) != 1:
        return None
    regular = next(iter(offer_prices))
    states = {offer.get("availability") for offer in offers}
    explicitly_live = "InStock" in states and states <= {"InStock", "OutOfStock"}
    option_values = [
        option for option in soup.select('select[id^="product_option_id"] option')
        if str(option.get("value") or "") not in ("", "*", "**")
        and "품절" not in option.get_text(" ", strip=True)
    ]
    page_text = soup.get_text(" ", strip=True)
    has_cart = any(
        "ADD TO CART" in tag.get_text(" ", strip=True)
        for tag in soup.select("button, a")
    )
    if not explicitly_live and not (option_values and has_cart and "품절" not in page_text):
        return None

    script_regular = _script_price(html, "product_price")
    if script_regular is not None and script_regular != regular:
        return None
    sale = (
        _script_price(html, "product_sale_price")
        or _labelled_won_price(soup, "판매가")
    )
    if sale is None:
        sale_match = re.search(
            r'id=["\']span_product_price_sale["\'][^>]*>[\s\S]{0,120}?([\d,]+)\s*원',
            html,
        )
        sale = _positive_int(sale_match.group(1).replace(",", "")) if sale_match else None
    if sale is None or sale > regular:
        return None
    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="urbanstoff",
        purchase_field="product_sale_price/displayed automatic discount",
        regular_field="Product.offers.price",
        option_dependent=False,
    )


def _extract_not4u_pricing(html: str) -> SitePricing | None:
    """Use the explicitly labelled consumer/selling prices and reject test pages."""
    soup = BeautifulSoup(html, "lxml")
    title_tag = soup.find(["h1", "h2"])
    title = title_tag.get_text(" ", strip=True) if title_tag else ""
    if not title or "테스트" in title or "이벤트" in title:
        return None
    regular = _labelled_won_price(soup, "소비자가")
    sale = _labelled_won_price(soup, "판매가")
    if regular is None or sale is None or regular < sale:
        return None
    options = [
        option for option in soup.select('select[id^="product_option_id"] option')
        if str(option.get("value") or "") not in ("", "*", "**")
        and "품절" not in option.get_text(" ", strip=True)
    ]
    if not options:
        return None
    offers = _cafe24_product_offers(html)
    offer_prices = {
        price for offer in (offers or [])
        if offer.get("priceCurrency") in (None, "KRW")
        and (price := _positive_int(offer.get("price"))) is not None
    }
    if offer_prices != {sale}:
        return None
    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="not4u",
        purchase_field="판매가 + Product.offers.price",
        regular_field="소비자가",
        option_dependent=False,
    )


def _extract_insilence_pricing(html: str) -> SitePricing | None:
    """Use the selectable guest price and abstain on sold-out/placeholder pages."""
    soup = BeautifulSoup(html, "lxml")
    products: list[dict] = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        states = state if isinstance(state, list) else [state]
        products.extend(
            item for item in states
            if isinstance(item, dict) and item.get("@type") == "Product"
        )
    if len(products) != 1:
        return None
    name = str(products[0].get("name") or "").strip()
    if len(name) < 2 or "¥" in name or not _live_cafe24_options(soup):
        return None

    offers = _cafe24_product_offers(html)
    offer_prices = {
        price for offer in (offers or [])
        if offer.get("priceCurrency") in (None, "KRW")
        and (price := _positive_int(offer.get("price"))) is not None
    }
    if len(offer_prices) != 1:
        return None
    purchase = next(iter(offer_prices))
    if _script_price(html, "product_price") != purchase:
        return None

    displayed = _product_table_prices(soup, purchase)
    larger = {value for value in displayed if value > purchase}
    regular = next(iter(larger)) if len(larger) == 1 else None
    return SitePricing(
        regular_price=regular,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="insilence",
        purchase_field="product_price + Product.offers.price",
        regular_field="product detail compare price" if regular else None,
        option_dependent=False,
    )


def _extract_fabregat_pricing(html: str) -> SitePricing | None:
    """Use Fabregat's automatic sale price; JSON-LD exposes the regular price."""
    soup = BeautifulSoup(html, "lxml")
    if not _live_cafe24_options(soup):
        return None
    offers = _cafe24_product_offers(html)
    regulars = {
        price for offer in (offers or [])
        if offer.get("priceCurrency") in (None, "KRW")
        and (price := _positive_int(offer.get("price"))) is not None
    }
    if len(regulars) != 1:
        return None
    regular = next(iter(regulars))
    sale = _script_price(html, "product_sale_price")
    if sale is None:
        sale_match = re.search(
            r'id=["\']span_product_price_sale["\'][^>]*>[\s\S]{0,160}?([\d,]+)\s*원',
            html,
        )
        sale = (
            _positive_int(sale_match.group(1).replace(",", ""))
            if sale_match else None
        )
    if sale is None:
        displayed = _product_table_prices(soup, regular)
        lower = {value for value in displayed if value < regular}
        sale = next(iter(lower)) if len(lower) == 1 else None
    if sale is None or sale > regular:
        return None
    script_regular = _script_price(html, "product_price")
    if script_regular is not None and script_regular != regular:
        return None
    return SitePricing(
        regular_price=regular,
        purchase_price=sale,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="fabregat",
        purchase_field="product_sale_price/displayed automatic sale",
        regular_field="Product.offers.price",
        option_dependent=False,
    )


def _extract_hotping_pricing(html: str) -> SitePricing | None:
    """Use live option offers and ignore the separately labelled coupon estimate."""
    pricing = _extract_cafe24_offer_pricing(
        html, adapter="hotping", confidence=PriceConfidence.HIGH,
    )
    if pricing is None:
        return None
    if _script_price(html, "product_price") != pricing.purchase_price:
        return None
    return pricing


def _extract_uniqlo_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    page_text = soup.get_text(" ", strip=True)
    groups = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        nodes = state.get("@graph", []) if isinstance(state, dict) else []
        if isinstance(state, dict) and state.get("@type") == "ProductGroup":
            nodes = [state]
        if isinstance(nodes, list):
            groups.extend(x for x in nodes if isinstance(x, dict) and x.get("@type") == "ProductGroup")
    if len(groups) != 1:
        return None
    group = groups[0]
    if not str(group.get("productGroupID") or "").strip() or not str(group.get("name") or "").strip():
        return None
    variants = group.get("hasVariant")
    if not isinstance(variants, list) or not variants:
        return None
    prices = set()
    for variant in variants:
        if not isinstance(variant, dict) or not str(variant.get("sku") or "").strip():
            continue
        offer = variant.get("offers")
        if not isinstance(offer, dict) or offer.get("priceCurrency") != "KRW":
            continue
        if offer.get("availability") != "https://schema.org/InStock":
            continue
        price = _positive_int(offer.get("price"))
        if price is not None:
            prices.add(price)
    if not prices or not any(f"{price:,}원" in page_text for price in prices):
        return None
    low, high = min(prices), max(prices)
    dependent = low != high
    return SitePricing(
        regular_price=None, purchase_price=low,
        purchase_price_status=(PurchasePriceStatus.OPTION_DEPENDENT if dependent else PurchasePriceStatus.CONFIRMED),
        confidence=PriceConfidence.MEDIUM, adapter="uniqlo",
        purchase_field="ProductGroup.hasVariant[].offers.price",
        option_dependent=dependent,
        option_price_min=low if dependent else None,
        option_price_max=high if dependent else None,
    )


def _extract_ssg_pricing(html: str) -> SitePricing | None:
    page_text = BeautifulSoup(html, "lxml").get_text(" ", strip=True)
    candidates = set()
    for fragment in re.findall(r"var\s+resultItemObj\s*=\s*\{([\s\S]{0,18000}?)\}\s*;", html):
        def value(pattern):
            match = re.search(pattern, fragment)
            return match.group(1) if match else None
        if not str(value(r"itemId\s*:\s*'([^']+)'") or "").isdigit():
            continue
        if value(r"sellStatCd\s*:\s*'([^']+)'") != "20":
            continue
        if value(r"soldOut\s*:\s*'([^']+)'") != "N" or value(r"soldOutPass\s*:\s*'([^']+)'") != "N":
            continue
        if value(r"uitemSamePrcYn\s*:\s*'([^']+)'") != "Y" or value(r"cpnYn\s*:\s*'([^']+)'") != "N":
            continue
        regular = _positive_int(value(r"sellprc\s*:\s*'(\d+)'") )
        purchase = _positive_int(value(r"bestAmt\s*:\s*parseInt\('(\d+)'") )
        pre_coupon = _positive_int(value(r"preCpnDcPrc\s*:\s*'(\d+)'") )
        if purchase is None or pre_coupon != purchase or (regular is not None and regular < purchase):
            continue
        if "최적가" not in page_text or f"{purchase:,}" not in page_text:
            continue
        if regular == purchase:
            regular = None
        elif regular is not None and f"{regular:,}" not in page_text:
            continue
        candidates.add((purchase, regular))
    if len(candidates) != 1:
        return None
    purchase, regular = next(iter(candidates))
    return SitePricing(
        regular_price=regular, purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH, adapter="ssg",
        purchase_field="resultItemObj.bestAmt",
        regular_field="resultItemObj.sellprc" if regular is not None else None,
        option_dependent=False,
    )


def _extract_thehyundai_pricing(html: str) -> SitePricing | None:
    normalized = _unescape_script_quotes(html)
    page_text = BeautifulSoup(html, "lxml").get_text(" ", strip=True)
    anchors = list(re.finditer(
        r'"slitmCd"\s*:\s*"(?P<id>[A-Za-z0-9]+)"\s*,\s*"slitmNm"\s*:\s*"(?P<name>[^"]+)"',
        normalized,
    ))
    candidates = set()
    for anchor in anchors:
        fragment = normalized[anchor.start():anchor.start() + 30000]
        if '"itemGbcd"' not in fragment[:1500]:
            continue
        def field(name):
            match = re.search(rf'"{name}"\s*:\s*"([^"]+)"', fragment)
            return match.group(1) if match else None
        if any(field(name) != "0" for name in ("empBuyLimtYn", "empDcYn", "clsrMallItemYn", "ostkYn")):
            continue
        if field("sellMdaPossYn") != "1":
            continue
        qty = re.search(r'"sellPossQty"\s*:\s*(\d+)', fragment)
        if not qty or int(qty.group(1)) <= 0:
            continue
        prices = re.search(
            r'"prcInfo"\s*:\s*\{[^}]*?"sellPrc"\s*:\s*(\d+)[^}]*?"dcPrc"\s*:\s*(\d+)[^}]*?"maxDcPrc"\s*:\s*(\d+)',
            fragment,
        )
        if not prices:
            continue
        regular, purchase, maximum = map(int, prices.groups())
        name = anchor.group("name")
        if purchase <= 0 or regular < purchase or maximum != purchase or "임직원" in name:
            continue
        if name not in page_text or f"{regular:,}원" not in page_text or f"{purchase:,}원" not in page_text:
            continue
        candidates.add((purchase, regular, anchor.group("id")))
    if len(candidates) != 1:
        return None
    purchase, regular, _ = next(iter(candidates))
    return SitePricing(
        regular_price=regular, purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM, adapter="thehyundai",
        purchase_field="prcInfo.dcPrc", regular_field="prcInfo.sellPrc",
        option_dependent=None,
    )


def _unique_meta_content(soup: BeautifulSoup, property_name: str) -> str | None:
    values = {
        str(tag.get("content") or "").strip()
        for tag in soup.select(f'meta[property="{property_name}"]')
        if str(tag.get("content") or "").strip()
    }
    return next(iter(values)) if len(values) == 1 else None


def _extract_ably_pricing(html: str) -> SitePricing | None:
    """Use Ably's main-product OG amount only when the guest instant sale is visible."""
    soup = BeautifulSoup(html, "lxml")
    # lxml discards nodes appended after a closing </html> tag. Inspect the raw
    # metadata with html.parser as well so duplicate/conflicting product prices
    # cannot bypass the single-main-product guard on imperfect HTML.
    meta_soup = BeautifulSoup(html, "html.parser")
    page_text = soup.get_text(" ", strip=True)
    item_id = _unique_meta_content(meta_soup, "product:retailer_item_id")
    currency = _unique_meta_content(meta_soup, "product:price:currency")
    availability = _unique_meta_content(meta_soup, "product:availability")
    amount = _unique_meta_content(meta_soup, "product:price:amount")
    purchase = _positive_int(amount.replace(",", "") if amount else None)
    if not item_id or not item_id.isdigit() or currency != "KRW":
        return None
    if availability.lower() != "in stock" or purchase is None:
        return None
    if "구매하기" not in page_text or f"{purchase:,}원" not in page_text:
        return None
    # On the audited PDPs this pair labels the automatic product discount. A
    # coupon-only estimate must never promote the OG amount to confirmed.
    if "나의 예상 구매가" not in page_text or "즉시 할인" not in page_text:
        return None
    return SitePricing(
        regular_price=None,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="ably",
        purchase_field="meta[property=product:price:amount] / 즉시 할인",
        option_dependent=None,
    )


def _extract_zigzag_pricing(html: str) -> SitePricing | None:
    """Ignore Zigzag's OG/extra price, which can be a first-order coupon price."""
    soup = BeautifulSoup(html, "lxml")
    page_text = soup.get_text(" ", strip=True)
    candidates: set[tuple[int, int | None]] = set()
    for tag in soup.select("script#__NEXT_DATA__"):
        try:
            root = json.loads(tag.get_text())
            queries = root["props"]["pageProps"]["dehydratedState"]["queries"]
        except (TypeError, KeyError, ValueError, json.JSONDecodeError):
            continue
        for query in queries if isinstance(queries, list) else []:
            try:
                data = query["state"]["data"]
                product = data["product"]
                price_state = product["product_price"]
            except (TypeError, KeyError):
                continue
            if not isinstance(product, dict) or not str(product.get("id") or "").isdigit():
                continue
            if product.get("is_purchasable") is not True:
                continue
            if product.get("sales_status") != "ON_SALE" or product.get("display_status") != "VISIBLE":
                continue
            try:
                purchase = _positive_int(price_state["display_final_price"]["final_price"]["price"])
                regular = _positive_int(price_state["max_price_info"]["price"])
            except (TypeError, KeyError):
                continue
            if purchase is None or (regular is not None and regular < purchase):
                continue
            name = str(product.get("name") or "").strip()
            if not name or name not in page_text or "구매하기" not in page_text:
                continue
            if f"{purchase:,}" not in page_text:
                continue
            candidates.add((purchase, regular if regular != purchase else None))
    if len(candidates) != 1:
        return None
    purchase, regular = next(iter(candidates))
    return SitePricing(
        regular_price=regular,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="zigzag",
        purchase_field="product.product_price.display_final_price.final_price.price",
        regular_field="product.product_price.max_price_info.price" if regular is not None else None,
        option_dependent=None,
    )


def _extract_kream_pricing(html: str) -> SitePricing | None:
    """Confirm fixed-price brand delivery; abstain on size-priced resale markets."""
    soup = BeautifulSoup(html, "lxml")
    page_text = soup.get_text(" ", strip=True)
    if "브랜드배송" not in page_text:
        return None
    if "판매 입찰" in page_text or "구매 입찰" in page_text or "옵션 선택" in page_text:
        return None
    products = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if isinstance(state, dict) and state.get("@type") == "Product":
            products.append(state)
    if len(products) != 1:
        return None
    product = products[0]
    offer = product.get("offers")
    if not isinstance(offer, dict) or offer.get("priceCurrency") != "KRW":
        return None
    if offer.get("availability") != "https://schema.org/InStock":
        return None
    if not str(product.get("productID") or "").isdigit():
        return None
    purchase = _positive_int(offer.get("price"))
    name = str(product.get("name") or "").strip()
    if purchase is None or not name or name not in page_text:
        return None
    if "구매하기" not in page_text or f"{purchase:,}원" not in page_text:
        return None
    return SitePricing(
        regular_price=None,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="kream",
        purchase_field="Product.offers.price / 브랜드배송",
        option_dependent=None,
    )


def _extract_guess_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    products = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if isinstance(state, dict) and state.get("@type") == "Product":
            products.append(state)
    if len(products) != 1:
        return None
    offers = products[0].get("offers")
    if not isinstance(offers, list) or not offers:
        return None
    live_prices = {
        _positive_int(offer.get("price"))
        for offer in offers
        if isinstance(offer, dict)
        and offer.get("priceCurrency") == "KRW"
        and offer.get("availability") == "InStock"
    }
    live_prices.discard(None)
    if len(live_prices) != 1:
        return None
    purchase = next(iter(live_prices))
    shown = soup.select_one(".price_box #span_product_price_text")
    regular_tag = soup.select_one(".price_box .custom.through")
    shown_price = _positive_int(re.sub(r"\D", "", shown.get_text()) if shown else None)
    regular = _positive_int(re.sub(r"\D", "", regular_tag.get_text()) if regular_tag else None)
    if shown_price != purchase or (regular is not None and regular < purchase):
        return None
    if _script_price(html, "product_price") != purchase:
        return None
    page_text = soup.get_text(" ", strip=True)
    if "장바구니 담기" not in page_text or "바로 구매하기" not in page_text:
        return None
    return SitePricing(
        regular_price=regular if regular != purchase else None,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="guess",
        purchase_field="Product.offers[].price / product_price",
        regular_field=".price_box .custom.through" if regular and regular != purchase else None,
        option_dependent=False,
    )


_LEVIS_PRODUCT_JSON = re.compile(r"window\.hulkappsWishlist\.productJSON\s*=\s*\{")


def _extract_levis_pricing(html: str) -> SitePricing | None:
    candidates = []
    for match in _LEVIS_PRODUCT_JSON.finditer(html):
        fragment = _object_fragment(html, match.end())
        if fragment is None:
            continue
        try:
            product = json.loads("{" + fragment + "}")
        except (ValueError, json.JSONDecodeError):
            continue
        candidates.append(product)
    if len(candidates) != 1:
        return None
    product = candidates[0]
    if product.get("available") is not True or not str(product.get("id") or "").isdigit():
        return None
    variants = product.get("variants")
    if not isinstance(variants, list) or not variants:
        return None
    live = [v for v in variants if isinstance(v, dict) and v.get("available") is True]
    prices = {_positive_int(v.get("price")) for v in live}
    compares = {_positive_int(v.get("compare_at_price")) for v in live}
    prices.discard(None)
    compares.discard(None)
    if len(prices) != 1 or len(compares) > 1:
        return None
    purchase_cents = next(iter(prices))
    if purchase_cents % 100:
        return None
    purchase = purchase_cents // 100
    regular = next(iter(compares)) // 100 if compares else None
    if regular is not None and regular < purchase:
        return None
    page_text = BeautifulSoup(html, "lxml").get_text(" ", strip=True)
    if str(product.get("title") or "") not in page_text or f"₩{purchase:,}" not in page_text:
        return None
    if "장바구니 담기" not in page_text or "지금 구매" not in page_text:
        return None
    dependent = False
    return SitePricing(
        regular_price=regular if regular != purchase else None,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="levis",
        purchase_field="hulkappsWishlist.productJSON.variants[].price / 100",
        regular_field="variants[].compare_at_price / 100" if regular and regular != purchase else None,
        option_dependent=dependent,
    )


def _extract_vans_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    title = _unique_meta_content(soup, "recopick:title")
    currency = _unique_meta_content(soup, "recopick:price:currency")
    regular = _positive_int(_unique_meta_content(soup, "recopick:price"))
    sale_tags = soup.select('meta[property="recopick:sale_price"]')
    sale_content = _unique_meta_content(soup, "recopick:sale_price")
    if sale_tags and sale_content is None:
        return None
    sale = _positive_int(sale_content)
    purchase = sale or regular
    if not title or currency != "KRW" or purchase is None:
        return None
    if regular is not None and regular < purchase:
        return None
    live_sizes = [
        tag for tag in soup.select("label.variation-size.selectable")
        if "nonActive" not in (tag.get("class") or [])
    ]
    page_text = soup.get_text(" ", strip=True)
    if not live_sizes or title not in page_text or f"{purchase:,} 원" not in page_text:
        return None
    if "장바구니에 담기" not in page_text or "바로구매" not in page_text:
        return None
    return SitePricing(
        regular_price=regular if sale is not None and regular != sale else None,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="vans",
        purchase_field="meta[recopick:sale_price]" if sale is not None else "meta[recopick:price]",
        regular_field="meta[recopick:price]" if sale is not None and regular != sale else None,
        option_dependent=False,
    )


def _extract_verified_cafe24_pricing(
    html: str, *, adapter: str, purchase_label: str,
) -> SitePricing | None:
    """Cafe24 sale price with main-product ID, live stock and visible price checks."""
    soup = BeautifulSoup(html, "lxml")
    item_id = _unique_meta_content(soup, "product:retailer_item_id")
    currency = _unique_meta_content(soup, "product:sale_price:currency")
    meta_sale = _positive_int(_unique_meta_content(soup, "product:sale_price:amount"))
    if not item_id or not item_id.isdigit() or currency != "KRW" or meta_sale is None:
        return None
    candidate_sets: set[tuple[int, ...]] = set()
    names: set[str] = set()
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            product = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(product, dict) or product.get("@type") != "Product":
            continue
        name = str(product.get("name") or "").strip()
        raw = product.get("offers")
        offers = raw if isinstance(raw, list) else [raw]
        offers = [offer for offer in offers if isinstance(offer, dict)]
        live_prices = []
        for offer in offers:
            availability = str(offer.get("availability") or "")
            is_live = availability == "InStock" or availability.endswith("/InStock")
            if not is_live:
                continue
            if offer.get("priceCurrency") not in (None, "KRW"):
                continue
            if (price := _positive_int(offer.get("price"))) is not None:
                live_prices.append(price)
        if live_prices:
            candidate_sets.add(tuple(sorted(set(live_prices))))
            if name:
                names.add(name)
    if len(candidate_sets) != 1 or len(names) != 1:
        return None
    prices = next(iter(candidate_sets))
    low, high = min(prices), max(prices)
    if meta_sale != low:
        return None
    shown_values = {
        _positive_int(re.sub(r"\D", "", tag.get_text()))
        for tag in soup.select("#span_product_price_text")
    }
    shown_values.discard(None)
    if shown_values != {low}:
        return None
    regular_values = {
        _positive_int(re.sub(r"\D", "", tag.get_text()))
        for tag in soup.select("#span_product_price_custom")
    }
    regular_values.discard(None)
    if len(regular_values) > 1:
        return None
    regular = next(iter(regular_values)) if regular_values else None
    if regular is not None and regular < high:
        return None
    page_text = soup.get_text(" ", strip=True)
    if next(iter(names)) not in page_text or purchase_label not in page_text:
        return None
    dependent = low != high
    return SitePricing(
        regular_price=regular if regular != low else None,
        purchase_price=low,
        purchase_price_status=(PurchasePriceStatus.OPTION_DEPENDENT if dependent else PurchasePriceStatus.CONFIRMED),
        confidence=PriceConfidence.MEDIUM,
        adapter=adapter,
        purchase_field="Product.offers[InStock].price / product:sale_price:amount",
        regular_field="#span_product_price_custom" if regular and regular != low else None,
        option_dependent=dependent,
        option_price_min=low if dependent else None,
        option_price_max=high if dependent else None,
    )


def _extract_hm_pricing(html: str) -> SitePricing | None:
    """Read only the currently selected H&M article's live KRW variants."""
    soup = BeautifulSoup(html, "lxml")
    article_ids = set()
    for tag in soup.select('link[rel="canonical"]'):
        match = re.search(r"/productpage\.(\d+)\.html", str(tag.get("href") or ""))
        if match:
            article_ids.add(match.group(1))
    if len(article_ids) != 1:
        return None
    article_id = next(iter(article_ids))

    groups = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            state = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        nodes = state.get("@graph", []) if isinstance(state, dict) else []
        if isinstance(state, dict) and state.get("@type") == "ProductGroup":
            nodes = [state]
        if isinstance(nodes, list):
            groups.extend(
                node for node in nodes
                if isinstance(node, dict) and node.get("@type") == "ProductGroup"
            )
    if len(groups) != 1 or not str(groups[0].get("productGroupID") or "").isdigit():
        return None

    variants = groups[0].get("hasVariant")
    if not isinstance(variants, list) or not variants:
        return None
    prices = set()
    for variant in variants:
        if not isinstance(variant, dict):
            continue
        raw_offers = variant.get("offers")
        offers = raw_offers if isinstance(raw_offers, list) else [raw_offers]
        for offer in offers:
            if not isinstance(offer, dict) or article_id not in str(offer.get("url") or ""):
                continue
            availability = str(offer.get("availability") or "")
            if not availability.endswith("/InStock") and availability != "InStock":
                continue
            if offer.get("priceCurrency") != "KRW":
                return None
            if (price := _positive_int(offer.get("price"))) is not None:
                prices.add(price)
    if not prices:
        return None
    low, high = min(prices), max(prices)
    page_text = soup.get_text(" ", strip=True)
    if "쇼핑백에 추가하기" not in page_text:
        return None
    if not any(re.search(rf"₩\s*{price:,}(?!\d)", page_text) for price in prices):
        return None
    dependent = low != high
    return SitePricing(
        regular_price=None,
        purchase_price=low,
        purchase_price_status=(
            PurchasePriceStatus.OPTION_DEPENDENT if dependent
            else PurchasePriceStatus.CONFIRMED
        ),
        confidence=PriceConfidence.MEDIUM,
        adapter="hm",
        purchase_field="ProductGroup.hasVariant[].offers[current article, InStock].price",
        option_dependent=dependent,
        option_price_min=low if dependent else None,
        option_price_max=high if dependent else None,
    )


def _extract_gap_pricing(html: str) -> SitePricing | None:
    """Guard Gap until decimal foreign-currency prices are modelled."""
    # The automatic checkout promotion was verified in a guest cart, but the
    # current integer-only price model has no currency field and cannot safely
    # represent USD 23.97. Never convert it to KRW or cents implicitly.
    return None


def _extract_aritzia_pricing(html: str) -> SitePricing | None:
    """Use localized KRW PDP prices only with the selected live Mobify variants."""
    soup = BeautifulSoup(html, "lxml")
    state_tags = soup.select("#mobify-data")
    if len(state_tags) != 1:
        return None
    try:
        root = json.loads(state_tags[0].get_text())
        preloaded = root["__PRELOADED_STATE__"]
        page_props = preloaded["pageProps"]["structuredDataProps"]
        seo_product = page_props["seoProduct"]
        store = preloaded["__STATE_MANAGEMENT_LIBRARY"]["store"]["productStore"]
        products = store["productsById"]
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None
    product_id = str(seo_product.get("id") or "") if isinstance(seo_product, dict) else ""
    display_name = str(seo_product.get("displayName") or "").strip() if isinstance(seo_product, dict) else ""
    if not product_id.isdigit() or not display_name or not isinstance(products, dict):
        return None
    if set(products) != {product_id} or not isinstance(products.get(product_id), dict):
        return None

    selected_colors = set()
    structured = page_props.get("structuredData")
    for product in structured if isinstance(structured, list) else []:
        if not isinstance(product, dict) or product.get("@type") != "Product":
            continue
        if str(product.get("sku") or "") != product_id:
            continue
        product_url = str(product.get("@id") or product.get("url") or "")
        if match := re.search(r"[?&]color=(\d+)", product_url):
            selected_colors.add(match.group(1))
    if len(selected_colors) != 1:
        return None
    selected_color = next(iter(selected_colors))

    variants = products[product_id].get("variants")
    if not isinstance(variants, list):
        return None
    live_variant_prices = set()
    for variant in variants:
        if not isinstance(variant, dict):
            continue
        values = variant.get("variationValues")
        if not isinstance(values, dict) or str(values.get("color") or "") != selected_color:
            continue
        if variant.get("orderable") is not True:
            continue
        if _positive_int(variant.get("maxOrderQuantity")) is None:
            continue
        if (price := _positive_int(variant.get("price"))) is not None:
            live_variant_prices.add(price)
    if len(live_variant_prices) != 1:
        return None

    price_boxes = soup.select('[data-testid="product-price-text"]')
    if len(price_boxes) != 1:
        return None

    def localized_price(selector: str) -> int | None:
        nodes = price_boxes[0].select(selector)
        if len(nodes) != 1:
            return None
        match = re.fullmatch(r"₩\s*([\d,]+)", nodes[0].get_text(" ", strip=True))
        if not match:
            return None
        value = _positive_int(match.group(1).replace(",", ""))
        # Values such as `₩40` were observed when Global-e localization failed.
        return value if value is not None and value >= 1000 else None

    list_price = localized_price('[data-testid="product-list-price-text"]')
    sale_nodes = price_boxes[0].select('[data-testid="product-list-sale-text"]')
    if list_price is None or len(sale_nodes) > 1:
        return None
    if sale_nodes:
        purchase = localized_price('[data-testid="product-list-sale-text"]')
        regular = list_price
        if purchase is None or regular <= purchase:
            return None
    else:
        purchase = list_price
        regular = None

    page_text = soup.get_text(" ", strip=True)
    if (
        display_name not in page_text or f"#{product_id}" not in page_text
        or f"Add to Bag — ₩{purchase:,}" not in page_text
    ):
        return None
    return SitePricing(
        regular_price=regular,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.HIGH,
        adapter="aritzia",
        purchase_field="localized product-list-sale/list price + selected orderable Mobify variants",
        regular_field="product-list-price-text" if regular is not None else None,
        option_dependent=False,
    )


def _extract_cafe24_meta_sale_pricing(
    html: str, *, adapter: str, purchase_label: str | None = None,
) -> SitePricing | None:
    """Cross-check Cafe24's automatic sale meta with explicitly live options."""
    soup = BeautifulSoup(html, "lxml")
    item_id = _unique_meta_content(soup, "product:retailer_item_id")
    base_currency = _unique_meta_content(soup, "product:price:currency")
    sale_currency = _unique_meta_content(soup, "product:sale_price:currency")
    base = _positive_int(_unique_meta_content(soup, "product:price:amount"))
    purchase = _positive_int(_unique_meta_content(soup, "product:sale_price:amount"))
    if (
        not item_id or not item_id.isdigit()
        or base_currency != "KRW" or sale_currency != "KRW"
        or base is None or purchase is None or base < purchase
    ):
        return None

    product_names = set()
    live_price_sets = set()
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            product = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(product, dict) or product.get("@type") != "Product":
            continue
        raw_offers = product.get("offers")
        offers = raw_offers if isinstance(raw_offers, list) else [raw_offers]
        live_prices = []
        for offer in offers:
            if not isinstance(offer, dict):
                continue
            availability = re.sub(r"[^a-z]", "", str(offer.get("availability") or "").lower())
            if not availability.endswith("instock"):
                continue
            if offer.get("priceCurrency") != "KRW":
                continue
            if (price := _positive_int(offer.get("price"))) is not None:
                live_prices.append(price)
        if live_prices:
            live_price_sets.add(tuple(sorted(set(live_prices))))
            if (name := str(product.get("name") or "").strip()):
                product_names.add(name)
    if len(live_price_sets) != 1 or not product_names:
        return None
    # Some Cafe24 themes emit the same main product twice: once with the full
    # option title and once with its shorter catalogue title. Accept only
    # nested/equivalent names; unrelated recommendation Products still abstain.
    name = max(product_names, key=len)
    if any(candidate not in name for candidate in product_names):
        return None
    live_prices = next(iter(live_price_sets))
    if len(live_prices) != 1 or live_prices[0] not in {base, purchase}:
        return None

    custom_values = {
        _positive_int(re.sub(r"\D", "", tag.get_text()))
        for tag in soup.select("#span_product_price_custom")
    }
    custom_values.discard(None)
    if len(custom_values) > 1:
        return None
    custom = next(iter(custom_values)) if custom_values else None
    regular = base if base > purchase else custom
    if custom is not None and custom > purchase and regular not in (None, custom):
        return None
    if regular is not None and regular < purchase:
        return None

    page_text = soup.get_text(" ", strip=True)
    if name not in page_text or f"{purchase:,}" not in page_text:
        return None
    if purchase_label and purchase_label not in page_text:
        return None
    return SitePricing(
        regular_price=regular if regular != purchase else None,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter=adapter,
        purchase_field="product:sale_price:amount + Product.offers[InStock]",
        regular_field=(
            "product:price:amount" if base > purchase
            else "#span_product_price_custom" if custom and custom > purchase
            else None
        ),
        option_dependent=False,
    )


def _extract_mahagrid_pricing(html: str) -> SitePricing | None:
    """Use the automatic sale only while the PDP exposes active purchase actions."""
    soup = BeautifulSoup(html, "lxml")
    page_text = soup.get_text(" ", strip=True)
    if "품절" in page_text or "장바구니" not in page_text or "구매하기" not in page_text:
        return None
    item_id = _unique_meta_content(soup, "product:retailer_item_id")
    regular = _positive_int(_unique_meta_content(soup, "product:price:amount"))
    purchase = _positive_int(_unique_meta_content(soup, "product:sale_price:amount"))
    if not item_id or not item_id.isdigit() or regular is None or purchase is None or regular < purchase:
        return None
    products = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            product = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if isinstance(product, dict) and product.get("@type") == "Product":
            products.append(product)
    if len(products) != 1 or str(products[0].get("name") or "") not in page_text:
        return None
    offer = products[0].get("offers")
    if not isinstance(offer, dict) or offer.get("priceCurrency") != "KRW":
        return None
    if _positive_int(offer.get("price")) != regular or f"{purchase:,}원" not in page_text:
        return None
    return SitePricing(
        regular_price=regular if regular != purchase else None,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="mahagrid",
        purchase_field="product:sale_price:amount / active purchase actions",
        regular_field="product:price:amount" if regular != purchase else None,
        option_dependent=False,
    )


def _extract_ohora_pricing(html: str) -> SitePricing | None:
    """Require Ohora's selected main-product total, not related-product prices."""
    soup = BeautifulSoup(html, "lxml")
    page_text = soup.get_text(" ", strip=True)
    if "재입고 알림 신청" in page_text or "바로 구매" not in page_text or "장바구니" not in page_text:
        return None
    item_id = _unique_meta_content(soup, "product:retailer_item_id")
    regular = _positive_int(_unique_meta_content(soup, "product:price:amount"))
    purchase = _positive_int(_unique_meta_content(soup, "product:sale_price:amount"))
    if not item_id or not item_id.isdigit() or regular is None or purchase is None or regular < purchase:
        return None
    products = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            product = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if isinstance(product, dict) and product.get("@type") == "Product":
            products.append(product)
    if len(products) != 1:
        return None
    offer = products[0].get("offers")
    if not isinstance(offer, dict) or offer.get("priceCurrency") != "KRW":
        return None
    if _positive_int(offer.get("price")) != regular:
        return None
    name = str(products[0].get("name") or "").strip()
    if not name or name not in page_text or f"총 상품금액 {purchase:,}원" not in page_text:
        return None
    return SitePricing(
        regular_price=regular if regular != purchase else None,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        confidence=PriceConfidence.MEDIUM,
        adapter="ohora",
        purchase_field="product:sale_price:amount / selected main-product total",
        regular_field="product:price:amount" if regular != purchase else None,
        option_dependent=False,
    )


def _extract_fashionplus_pricing(html: str) -> SitePricing | None:
    """Use the main offer's automatic sale and the enabled option price range."""
    soup = BeautifulSoup(html, "lxml")
    products = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            value = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if isinstance(value, dict) and value.get("@type") == "Product":
            products.append(value)
    if len(products) != 1:
        return None
    product = products[0]
    name = str(product.get("name") or "").strip()
    product_id = str(product.get("mpn") or product.get("productID") or "").strip()
    offer = product.get("offers")
    if not name or not product_id.isdigit() or not isinstance(offer, dict):
        return None
    availability = re.sub(r"[^a-z]", "", str(offer.get("availability") or "").lower())
    regular = _positive_int(offer.get("price"))
    sale = _positive_int(offer.get("sale_price"))
    if not availability.endswith("instock") or offer.get("priceCurrency") != "KRW" or sale is None:
        return None

    option_prices = set()
    for button in soup.select("button.btn_option"):
        classes = {str(value).lower() for value in button.get("class", [])}
        if button.has_attr("disabled") or "disabled" in classes or "soldout" in classes:
            continue
        match = re.search(r"([\d,]+)\s*원?\s*$", button.get_text(" ", strip=True))
        if match and (price := _positive_int(match.group(1).replace(",", ""))) is not None:
            option_prices.add(price)
    page_text = soup.get_text(" ", strip=True)
    if (
        not option_prices or sale not in option_prices or name not in page_text
        or "장바구니" not in page_text or "구매" not in page_text
    ):
        return None
    low, high = min(option_prices), max(option_prices)
    dependent = low != high
    # A bundle's representative comparison price is not a regular price for
    # every option when it is lower than an enabled option's purchase price.
    safe_regular = regular if regular and regular > sale and regular >= high else None
    return SitePricing(
        regular_price=safe_regular,
        purchase_price=low,
        purchase_price_status=(
            PurchasePriceStatus.OPTION_DEPENDENT if dependent
            else PurchasePriceStatus.CONFIRMED
        ),
        confidence=PriceConfidence.MEDIUM,
        adapter="fashionplus",
        purchase_field="Product.offers.sale_price + button.btn_option[enabled]",
        regular_field="Product.offers.price" if safe_regular else None,
        option_dependent=dependent,
        option_price_min=low if dependent else None,
        option_price_max=high if dependent else None,
    )


def _extract_lfmall_pricing(html: str) -> SitePricing | None:
    """Guard LFmall until its client-side option/availability state is verified."""
    # Audited PDP HTML exposed a KRW JSON-LD price but no availability, while
    # the main product UI remained in a loading state. Related-product prices
    # were visible, so the isolated JSON-LD number is not enough to confirm.
    return None


def _extract_reformation_pricing(html: str) -> SitePricing | None:
    """Confirm localized KRW prices from explicitly live main-product offers."""
    soup = BeautifulSoup(html, "lxml")
    products = []
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            value = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if isinstance(value, dict) and value.get("@type") == "Product":
            products.append(value)
    if len(products) != 1:
        return None
    product = products[0]
    name = str(product.get("name") or "").strip()
    raw_offers = product.get("offers")
    offers = raw_offers if isinstance(raw_offers, list) else [raw_offers]
    live_prices = set()
    for offer in offers:
        if not isinstance(offer, dict) or offer.get("priceCurrency") != "KRW":
            continue
        availability = re.sub(r"[^a-z]", "", str(offer.get("availability") or "").lower())
        if availability.endswith("instock") and (price := _positive_int(offer.get("price"))) is not None:
            live_prices.add(price)
    page_text = soup.get_text(" ", strip=True)
    if not name or name not in page_text or not live_prices or "Add to bag" not in page_text:
        return None
    if not any(f"₩{price:,}" in page_text or f"₩ {price:,}" in page_text for price in live_prices):
        return None
    low, high = min(live_prices), max(live_prices)
    dependent = low != high
    return SitePricing(
        regular_price=None,
        purchase_price=low,
        purchase_price_status=(
            PurchasePriceStatus.OPTION_DEPENDENT if dependent
            else PurchasePriceStatus.CONFIRMED
        ),
        confidence=PriceConfidence.HIGH,
        adapter="reformation",
        purchase_field="Product.offers[InStock, KRW].price",
        option_dependent=dependent,
        option_price_min=low if dependent else None,
        option_price_max=high if dependent else None,
    )


def _extract_nike_pricing(html: str) -> SitePricing | None:
    """Use the URL-selected Nike colorway and its live size offers."""
    soup = BeautifulSoup(html, "lxml")
    next_tag = soup.select_one("script#__NEXT_DATA__")
    if next_tag is None:
        return None
    try:
        state = json.loads(next_tag.get_text())
        groups = state["props"]["pageProps"]["productGroups"]
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None
    if not isinstance(groups, list) or len(groups) != 1:
        return None

    products_by_style: dict[str, dict] = {}
    raw_products = groups[0].get("products") if isinstance(groups[0], dict) else None
    if not isinstance(raw_products, dict):
        return None
    for product in raw_products.values():
        if not isinstance(product, dict):
            continue
        style = str(product.get("styleColor") or "").strip()
        if not style or style in products_by_style:
            return None
        products_by_style[style] = product

    og_url = soup.select_one('meta[property="og:url"]')
    selected_styles = {
        style for style in products_by_style
        if og_url is not None and style in str(og_url.get("content") or "")
    }
    if len(selected_styles) != 1:
        return None
    style = next(iter(selected_styles))
    product = products_by_style[style]
    if product.get("statusModifier") != "BUYABLE_BUY":
        return None

    prices = product.get("prices")
    if not isinstance(prices, dict) or prices.get("currency") != "KRW":
        return None
    purchase = _positive_int(prices.get("currentPrice"))
    initial = _positive_int(prices.get("initialPrice"))
    if purchase is None or initial is None or initial < purchase:
        return None

    live_offer_prices = set()
    selected_offer_prices = set()
    has_explicit_availability = False
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            value = json.loads(tag.get_text())
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        values = value if isinstance(value, list) else [value]
        for item in values:
            if not isinstance(item, dict) or item.get("@type") != "ProductGroup":
                continue
            for variant in item.get("hasVariant") or []:
                if not isinstance(variant, dict) or variant.get("mpn") != style:
                    continue
                offer = variant.get("offers")
                if not isinstance(offer, dict) or offer.get("priceCurrency") != "KRW":
                    continue
                if (value := _positive_int(offer.get("price"))) is not None:
                    selected_offer_prices.add(value)
                availability = re.sub(
                    r"[^a-z]", "", str(offer.get("availability") or "").lower()
                )
                has_explicit_availability = has_explicit_availability or bool(availability)
                if availability.endswith("instock"):
                    if (value := _positive_int(offer.get("price"))) is not None:
                        live_offer_prices.add(value)
    sizes = product.get("sizes")
    if selected_offer_prices != {purchase} or not isinstance(sizes, list) or not sizes:
        return None
    # Browser-rendered JSON-LD adds per-size availability. The fetched SSR
    # document can omit that property, in which case BUYABLE_BUY plus the
    # selected style's size/offer set is the server-side availability signal.
    if has_explicit_availability and live_offer_prices != {purchase}:
        return None

    title = str((product.get("productInfo") or {}).get("title") or "").strip()
    page_text = soup.get_text(" ", strip=True)
    if not title or title not in page_text:
        return None
    if f"{purchase:,} 원" not in page_text and f"{purchase:,}원" not in page_text:
        return None

    regular = initial if initial > purchase else None
    return SitePricing(
        regular_price=regular,
        purchase_price=purchase,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        # Page, live option and embedded price agree; guest cart was blocked.
        confidence=PriceConfidence.MEDIUM,
        adapter="nike",
        purchase_field="__NEXT_DATA__.productGroups[].products[styleColor].prices.currentPrice",
        regular_field=(
            "__NEXT_DATA__.productGroups[].products[styleColor].prices.initialPrice"
            if regular is not None else None
        ),
        option_dependent=False,
    )


def _oliveyoung_product_states(html: str) -> list[dict]:
    """Decode the product objects embedded in Next.js flight-data scripts."""
    soup = BeautifulSoup(html, "lxml")
    states: dict[str, dict] = {}
    for tag in soup.select("script"):
        raw = tag.string or tag.get_text() or ""
        match = re.fullmatch(r"\s*self\.__next_f\.push\((\[.*\])\)\s*", raw, re.DOTALL)
        if match is None:
            continue
        try:
            payload = json.loads(match.group(1))
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(payload, list) or len(payload) < 2 or not isinstance(payload[1], str):
            continue
        decoded = payload[1]
        for data_match in re.finditer(
            r'"data"\s*:\s*\{\s*"data"\s*:\s*\{', decoded
        ):
            fragment = _object_fragment(decoded, data_match.end(), max_size=50000)
            if fragment is None:
                continue
            try:
                candidate = json.loads("{" + fragment + "}")
            except (TypeError, ValueError, json.JSONDecodeError):
                continue
            goods_number = str(candidate.get("goodsNumber") or "").strip()
            if not goods_number:
                continue
            fingerprint = json.dumps(candidate, sort_keys=True, ensure_ascii=False)
            if goods_number in states and json.dumps(
                states[goods_number], sort_keys=True, ensure_ascii=False
            ) != fingerprint:
                return []
            states[goods_number] = candidate
    return list(states.values())


def _extract_oliveyoung_pricing(html: str) -> SitePricing | None:
    """Exclude coupon prices and keep only automatic sale prices for live options."""
    states = _oliveyoung_product_states(html)
    if len(states) != 1:
        return None
    state = states[0]
    if (
        state.get("saleableFlag") is not True
        or state.get("displayableFlag") is not True
        or state.get("soldOutFlag") is True
        or str(state.get("status") or "") != "20"
    ):
        return None

    options = state.get("options")
    if not isinstance(options, list):
        return None
    live = []
    for option in options:
        if not isinstance(option, dict) or option.get("soldOutFlag") is True:
            continue
        minimum = _positive_int(option.get("orderableMinimumQuantity"))
        maximum = _positive_int(option.get("orderableMaximumQuantity"))
        if minimum is None or maximum is None or maximum < minimum:
            continue
        live.append(option)
    if not live:
        return None

    benefit = state.get("maxBenefitPriceDto")
    if not isinstance(benefit, dict):
        return None
    rep_number = str(benefit.get("optionNumber") or "")
    representative = next(
        (option for option in live if str(option.get("optionNumber") or "") == rep_number),
        None,
    )
    promotion_price = _positive_int(benefit.get("promotionSalePrice"))
    original_sale = _positive_int(benefit.get("originalSalePrice"))
    final_price = _positive_int(benefit.get("finalPrice"))
    if representative is None or promotion_price is None or original_sale is None:
        return None
    if final_price is None or promotion_price > original_sale or final_price > promotion_price:
        return None
    if _positive_int(representative.get("salePrice")) != original_sale:
        return None
    if _positive_int(representative.get("finalPrice")) != final_price:
        return None

    has_coupon = benefit.get("hasCoupon") is True
    purchase_prices = []
    for option in live:
        option_sale = _positive_int(option.get("salePrice"))
        option_final = _positive_int(option.get("finalPrice"))
        if option_sale is None or option_final is None or option_final > option_sale:
            return None
        if str(option.get("optionNumber") or "") == rep_number:
            purchase_prices.append(promotion_price)
        elif not has_coupon:
            purchase_prices.append(option_final)
        elif option_sale == original_sale and option_final == final_price:
            purchase_prices.append(promotion_price)
        else:
            # The coupon discount for a differently priced option cannot be
            # reversed safely from the representative benefit object.
            return None

    name = str(state.get("goodsName") or "").strip()
    page_text = BeautifulSoup(html, "lxml").get_text(" ", strip=True)
    if not name or name not in page_text or "장바구니" not in page_text or "바로구매" not in page_text:
        return None
    if not any(
        f"{value:,}원" in page_text or f"{value:,} 원" in page_text
        for value in {final_price, original_sale}
    ):
        return None

    low, high = min(purchase_prices), max(purchase_prices)
    dependent = low != high
    live_regulars = {_positive_int(option.get("salePrice")) for option in live}
    regular = None
    if len(live_regulars) == 1:
        candidate = next(iter(live_regulars))
        if candidate is not None and candidate > low and candidate >= high:
            regular = candidate
    return SitePricing(
        regular_price=regular,
        purchase_price=low,
        purchase_price_status=(
            PurchasePriceStatus.OPTION_DEPENDENT if dependent
            else PurchasePriceStatus.CONFIRMED
        ),
        confidence=PriceConfidence.MEDIUM,
        adapter="oliveyoung",
        purchase_field=(
            "goods.maxBenefitPriceDto.promotionSalePrice + "
            "goods.options[soldOutFlag=false]"
        ),
        regular_field="goods.options[].salePrice" if regular is not None else None,
        option_dependent=dependent,
        option_price_min=low if dependent else None,
        option_price_max=high if dependent else None,
    )


def _walk_dicts(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_dicts(child)


def _script_json(soup: BeautifulSoup, *, script_id: str | None = None) -> list:
    selector = f"script#{script_id}" if script_id else 'script[type="application/ld+json"]'
    values = []
    for script in soup.select(selector):
        try:
            values.append(json.loads(script.string or script.get_text() or ""))
        except (TypeError, json.JSONDecodeError):
            continue
    return values


def _confirmed(adapter: str, purchase: int, purchase_field: str,
               regular: int | None = None, regular_field: str | None = None,
               *, option_dependent: bool = False,
               option_min: int | None = None,
               option_max: int | None = None) -> SitePricing:
    return SitePricing(
        regular_price=regular if regular and regular > purchase else None,
        purchase_price=purchase,
        purchase_price_status=(PurchasePriceStatus.OPTION_DEPENDENT
                               if option_dependent else PurchasePriceStatus.CONFIRMED),
        confidence=PriceConfidence.MEDIUM,
        adapter=adapter,
        purchase_field=purchase_field,
        regular_field=regular_field if regular and regular > purchase else None,
        option_dependent=option_dependent,
        option_price_min=option_min if option_dependent else None,
        option_price_max=option_max if option_dependent else None,
    )


def _extract_queenit_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    candidates = set()
    for root in _script_json(soup, script_id="__NEXT_DATA__"):
        for item in _walk_dicts(root):
            if not {"productId", "name", "originalPrice", "finalPrice", "salesStatus"} <= item.keys():
                continue
            try:
                original, final = int(item["originalPrice"]), int(item["finalPrice"])
            except (TypeError, ValueError):
                continue
            if (item.get("display") is True and original >= final > 0
                    and str(item["salesStatus"]).upper() not in {"ARCHIVED", "SOLD_OUT", "STOPPED"}):
                candidates.add((str(item["productId"]), str(item["name"]), original, final))
    if len(candidates) != 1 or "구매하기" not in soup.get_text(" ", strip=True):
        return None
    _, name, original, final = candidates.pop()
    text = soup.get_text(" ", strip=True)
    if name not in text or f"{final:,}" not in text:
        return None
    return _confirmed("queenit", final, "product.finalPrice", original, "product.originalPrice")


def _extract_brandi_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    candidates = set()
    for root in _script_json(soup, script_id="prefetch-data"):
        item = root.get("data") if isinstance(root, dict) else None
        if not isinstance(item, dict) or not str(item.get("id", "")).isdigit():
            continue
        try:
            regular, sale = int(item["price"]), int(item["sale_price"])
        except (KeyError, TypeError, ValueError):
            continue
        price_info = item.get("original_price_info") or {}
        consistent = (int(item.get("original_sale_price", sale)) == sale
                      and int(price_info.get("sale_price", sale)) == sale)
        if (item.get("is_sell") is True and item.get("is_sold_out") is False
                and item.get("is_temporary_sold_out") is False
                and regular >= sale > 0 and consistent):
            candidates.add((str(item["id"]), str(item.get("name", "")), regular, sale))
    if len(candidates) != 1:
        return None
    _, _, regular, sale = candidates.pop()
    return _confirmed("brandi", sale, "prefetch-data.data.sale_price",
                      regular, "prefetch-data.data.price")


def _extract_4910_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    candidates = set()
    for root in _script_json(soup, script_id="__NEXT_DATA__"):
        for node in _walk_dicts(root):
            goods = node.get("goods")
            if not isinstance(goods, dict) or "first_page_rendering" not in goods:
                continue
            first = goods.get("first_page_rendering") or {}
            linked = goods.get("linked_option") or {}
            try:
                price = int(goods["price"])
                first_price = int(first["price"])
                linked_price = int(linked.get("price", price))
                original = int(first.get("original_price", price))
            except (KeyError, TypeError, ValueError):
                continue
            if (goods.get("is_soldout") is False and linked.get("is_soldout") is not True
                    and price == first_price == linked_price > 0 and original >= price):
                candidates.add((str(first.get("goods_name", "")), original, price))
    if len(candidates) != 1:
        return None
    name, original, price = candidates.pop()
    text = soup.get_text(" ", strip=True)
    if name and name not in text or "구매하기" not in text or f"{price:,}" not in text:
        return None
    return _confirmed("4910", price, "goods.price", original, "goods.first_page_rendering.original_price")


def _single_product_ld(soup: BeautifulSoup) -> dict | None:
    products = []
    for root in _script_json(soup):
        for item in _walk_dicts(root):
            if item.get("@type") == "Product" and isinstance(item.get("offers"), dict):
                products.append(item)
    unique = {(str(item.get("sku") or item.get("productID") or item.get("name")),
               json.dumps(item, sort_keys=True, ensure_ascii=False)): item for item in products}
    return next(iter(unique.values())) if len(unique) == 1 else None


def _extract_ssfshop_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    product = _single_product_ld(soup)
    hidden = soup.select_one("#lastSalePrc")
    if product is None or hidden is None:
        return None
    offer = product["offers"]
    try:
        purchase, hidden_price = int(float(offer["price"])), int(hidden.get("value", "0"))
    except (KeyError, TypeError, ValueError):
        return None
    text = soup.get_text(" ", strip=True)
    if (offer.get("priceCurrency") != "KRW" or not str(offer.get("availability", "")).endswith("InStock")
            or purchase <= 0 or purchase != hidden_price or "바로구매" not in text
            or "장바구니" not in text or f"{purchase:,}" not in text):
        return None
    regular = None
    cost = soup.select_one(".price-info .cost del, .price-info del")
    if cost:
        digits = re.sub(r"\D", "", cost.get_text())
        regular = int(digits) if digits else None
        if regular is not None and regular < purchase:
            return None
    return _confirmed("ssfshop", purchase, "Product.offers.price + #lastSalePrc",
                      regular, ".price-info .cost del")


def _extract_cjonstyle_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    product = _single_product_ld(soup)
    if product is None:
        return None
    offer = product["offers"]
    try:
        purchase = int(float(offer["price"]))
    except (KeyError, TypeError, ValueError):
        return None
    text = soup.get_text(" ", strip=True)
    code = str(product.get("sku") or product.get("productID") or "")
    if (offer.get("priceCurrency") != "KRW" or not str(offer.get("availability", "")).endswith("InStock")
            or purchase <= 0 or f"{purchase:,}" not in text or "판매가격" not in text
            or "장바구니" not in text or "바로구매" not in text
            or (code and code not in text)):
        return None
    return _confirmed("cjonstyle", purchase, "Product.offers.price")


def _extract_elandmall_pricing(html: str) -> SitePricing | None:
    def js_value(name: str) -> str | None:
        match = re.search(rf"(?:var\s+)?{re.escape(name)}\s*=\s*[\"']([^\"']+)", html)
        return match.group(1) if match else None
    item_no, name = js_value("s_item_no"), js_value("s_item_name")
    try:
        purchase = int(js_value("final_price") or "0")
        page_price = int(js_value("s_price") or "0")
        regular = int(js_value("regular_price") or "0")
        stock = int(js_value("item_stock_qty") or "0")
    except ValueError:
        return None
    text = BeautifulSoup(html, "lxml").get_text(" ", strip=True)
    if (not item_no or not name or purchase <= 0 or purchase != page_price
            or regular < purchase or stock <= 0 or js_value("soldout_yn") != "N"
            or name not in text or f"{purchase:,}" not in text
            or not any(label in text for label in ("바로구매", "구매하기"))):
        return None
    return _confirmed("elandmall", purchase, "final_price + s_price",
                      regular, "regular_price")


def _extract_zara_pricing(html: str) -> SitePricing | None:
    soup = BeautifulSoup(html, "lxml")
    analytics = []
    for match in re.finditer(r"zara\.analyticsData\s*=\s*(\{.*?\});", html, re.DOTALL):
        try:
            analytics.append(json.loads(match.group(1)))
        except json.JSONDecodeError:
            pass
    groups = []
    for root in _script_json(soup):
        for item in _walk_dicts(root):
            if item.get("@type") == "ProductGroup" and item.get("productGroupID"):
                groups.append(item)
    if len(analytics) != 1 or len(groups) != 1:
        return None
    state, group = analytics[0], groups[0]
    if state.get("pageType") != "PRODUCT_DETAILS" or state.get("page", {}).get("currency") != "KRW":
        return None
    try:
        purchase = int(state["mainPrice"])
    except (KeyError, TypeError, ValueError):
        return None
    live_prices = set()
    for variant in group.get("hasVariant", []):
        offer = variant.get("offers", {}) if isinstance(variant, dict) else {}
        if offer.get("priceCurrency") == "KRW" and str(offer.get("availability", "")).endswith("InStock"):
            try:
                live_prices.add(int(float(offer["price"])) * 100)
            except (KeyError, TypeError, ValueError):
                return None
    text = soup.get_text(" ", strip=True)
    ref = str(state.get("productRef", "")).split("-")[0]
    if (purchase <= 0 or live_prices != {purchase} or ref != str(group["productGroupID"])
            or str(group.get("name", "")) not in text or f"{purchase:,}" not in text
            or "장바구니에 담기" not in text):
        return None
    return _confirmed("zara", purchase, "zara.analyticsData.mainPrice (ProductGroup offer ×100 cross-check)")


def extract_site_pricing(platform: str, html: str | None) -> SitePricing | None:
    if not html:
        return None
    if platform == "musinsa":
        return _extract_musinsa_pricing(html)
    if platform == "wconcept":
        return _extract_wconcept_pricing(html)
    if platform == "29cm":
        return _extract_29cm_pricing(html)
    if platform == "fila":
        return _extract_fila_pricing(html)
    if platform == "hago":
        return _extract_hago_pricing(html)
    if platform == "lookpin":
        return _extract_lookpin_pricing(html)
    if platform == "topten":
        return _extract_topten_pricing(html)
    if platform == "muji":
        return _extract_muji_pricing(html)
    if platform == "hmall":
        return _extract_hmall_pricing(html)
    if platform == "lotteon":
        return _extract_lotteon_pricing(html)
    if platform == "mixxo":
        return _extract_cafe24_meta_sale_pricing(
            html, adapter="mixxo", purchase_label="바로 구매하기",
        )
    if platform == "dailyjou":
        return _extract_cafe24_offer_pricing(
            html, adapter="dailyjou", confidence=PriceConfidence.HIGH,
        )
    if platform == "lee":
        return _extract_cafe24_meta_sale_pricing(
            html, adapter="lee", purchase_label="바로 구매하기",
        )
    if platform == "filluminate":
        return _extract_filluminate_pricing(html)
    if platform == "urbanstoff":
        return _extract_urbanstoff_pricing(html)
    if platform == "not4u":
        return _extract_not4u_pricing(html)
    if platform == "insilence":
        return _extract_insilence_pricing(html)
    if platform == "fabregat":
        return _extract_fabregat_pricing(html)
    if platform == "hotping":
        return _extract_hotping_pricing(html)
    if platform == "uniqlo":
        return _extract_uniqlo_pricing(html)
    if platform == "ssg":
        return _extract_ssg_pricing(html)
    if platform == "thehyundai":
        return _extract_thehyundai_pricing(html)
    if platform == "ably":
        return _extract_ably_pricing(html)
    if platform == "zigzag":
        return _extract_zigzag_pricing(html)
    if platform == "kream":
        return _extract_kream_pricing(html)
    if platform == "guess":
        return _extract_guess_pricing(html)
    if platform == "levis":
        return _extract_levis_pricing(html)
    if platform == "vans":
        return _extract_vans_pricing(html)
    if platform == "covernat":
        return _extract_verified_cafe24_pricing(html, adapter="covernat", purchase_label="CART")
    if platform == "codegraphy":
        return _extract_verified_cafe24_pricing(html, adapter="codegraphy", purchase_label="구매하기")
    if platform == "whoau":
        return _extract_verified_cafe24_pricing(html, adapter="whoau", purchase_label="구매하기")
    if platform == "hm":
        return _extract_hm_pricing(html)
    if platform == "gap":
        return _extract_gap_pricing(html)
    if platform == "aritzia":
        return _extract_aritzia_pricing(html)
    if platform == "noirer":
        return _extract_cafe24_meta_sale_pricing(html, adapter="noirer", purchase_label="BUY NOW")
    if platform == "liphop":
        return _extract_cafe24_meta_sale_pricing(html, adapter="liphop", purchase_label="BUY IT NOW")
    if platform == "marithe":
        return _extract_cafe24_meta_sale_pricing(html, adapter="marithe", purchase_label="장바구니 담기")
    if platform == "mahagrid":
        return _extract_mahagrid_pricing(html)
    if platform == "vivastudio":
        return _extract_cafe24_meta_sale_pricing(html, adapter="vivastudio")
    if platform == "amomento":
        return _extract_cafe24_meta_sale_pricing(html, adapter="amomento", purchase_label="Add To Bag")
    if platform == "anderssonbell":
        return _extract_cafe24_meta_sale_pricing(html, adapter="anderssonbell", purchase_label="ADD TO BAG")
    if platform == "yale":
        return _extract_cafe24_meta_sale_pricing(html, adapter="yale", purchase_label="구매하기")
    if platform == "ohora":
        return _extract_ohora_pricing(html)
    if platform == "withyoon":
        return _extract_cafe24_meta_sale_pricing(html, adapter="withyoon", purchase_label="Buy It Now")
    if platform == "66girls":
        return _extract_cafe24_meta_sale_pricing(html, adapter="66girls", purchase_label="바로 구매하기")
    if platform == "partimento":
        return _extract_cafe24_meta_sale_pricing(html, adapter="partimento", purchase_label="Add to Cart")
    if platform == "fashionplus":
        return _extract_fashionplus_pricing(html)
    if platform == "frombeginning":
        return _extract_cafe24_meta_sale_pricing(html, adapter="frombeginning", purchase_label="바로구매")
    if platform == "lfmall":
        return _extract_lfmall_pricing(html)
    if platform == "reformation":
        return _extract_reformation_pricing(html)
    if platform == "nike":
        return _extract_nike_pricing(html)
    if platform == "oliveyoung":
        return _extract_oliveyoung_pricing(html)
    if platform == "queenit":
        return _extract_queenit_pricing(html)
    if platform == "brandi":
        return _extract_brandi_pricing(html)
    if platform == "4910":
        return _extract_4910_pricing(html)
    if platform == "ssfshop":
        return _extract_ssfshop_pricing(html)
    if platform == "cjonstyle":
        return _extract_cjonstyle_pricing(html)
    if platform == "elandmall":
        return _extract_elandmall_pricing(html)
    if platform == "zara":
        return _extract_zara_pricing(html)
    # NUGU는 JPY 전용이고 SHEIN은 세션별 쿠폰/앱 가격 충돌을 해소하지 못했다.
    # 통화 인식 및 조건 판별이 확장되기 전에는 일반 메타 가격을 confirmed로 올리지 않는다.
    if platform in {"nugu", "shein"}:
        return None
    return None
