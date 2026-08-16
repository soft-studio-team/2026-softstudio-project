from engine.models import (
    PriceConfidence,
    Product,
    PurchasePriceStatus,
)


def test_price_schema_keeps_regular_and_purchase_prices_independent():
    product = Product(
        original_url="https://shop.example/product/1",
        original_price=32000,
    )

    payload = product.to_dict()
    assert payload["pricing"]["regular_price"] == 32000
    assert payload["pricing"]["purchase_price"] is None
    assert payload["pricing"]["purchase_price_status"] == "unknown"


def test_price_schema_exposes_semantics_and_keeps_legacy_aliases():
    product = Product(
        original_url="https://www.musinsa.com/products/6152461",
        price=30400,
        original_price=32000,
        purchase_price_status=PurchasePriceStatus.CONFIRMED,
        price_confidence=PriceConfidence.HIGH,
        price_evidence=[{
            "price_role": "purchase_price",
            "source": "metadata",
            "adapter": "musinsa",
            "field": "product:price:amount",
        }],
    )

    payload = product.to_dict()
    assert payload["pricing"]["purchase_price"] == 30400
    assert payload["pricing"]["regular_price"] == 32000
    assert payload["pricing"]["purchase_price_status"] == "confirmed"
    assert payload["pricing"]["confidence"] == "high"
    assert payload["price"] == 30400
    assert payload["original_price"] == 32000
