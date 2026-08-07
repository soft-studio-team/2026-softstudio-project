"""URL 해석(플랫폼 식별 + 상품 식별자 추출) 테스트. — 문서 5.2 흐름 1~2"""

import pytest

from engine.urltools import analyze_url, is_http_url


@pytest.mark.parametrize("url, platform, product_id, has_api", [
    # 오픈마켓형 (Tier 1 대상)
    ("https://www.coupang.com/vp/products/7959219524?itemId=999", "coupang", "7959219524", True),
    ("https://link.coupang.com/a/bXYZ12", "coupang", None, True),  # 단축링크: id는 fetch 후
    ("https://smartstore.naver.com/somestore/products/8123456789", "naver", "8123456789", True),
    ("https://shopping.naver.com/catalog/51449387423", "naver", "51449387423", True),
    ("https://www.11st.co.kr/products/1234567890", "11st", "1234567890", True),
    ("https://www.11st.co.kr/products/pa/1234567890", "11st", "1234567890", True),
    # 편집샵형·브랜드몰 (Tier 2 대상)
    ("https://www.musinsa.com/products/4715870", "musinsa", "4715870", False),
    ("https://www.musinsa.com/app/goods/4715870", "musinsa", "4715870", False),
    ("https://www.29cm.co.kr/catalog/2764334", "29cm", "2764334", False),
    ("https://www.wconcept.co.kr/Product/305573391", "wconcept", "305573391", False),
    ("https://m.a-bly.com/goods/12345678", "ably", "12345678", False),
    ("https://www.nike.com/kr/t/dunk-low-shoes-KJFYnLZQ/DD1391-100", "nike", "DD1391-100", False),
    ("https://www.oliveyoung.co.kr/store/goods/getGoodsDetail.do?goodsNo=A000000210792",
     "oliveyoung", "A000000210792", False),
    # 미등록 도메인 → unknown (Tier 3까지 내려가더라도 저장은 가능해야 함)
    ("https://example-shop.example.com/item/1", "unknown", None, False),
])
def test_analyze_url(url, platform, product_id, has_api):
    info = analyze_url(url)
    assert info.platform == platform
    assert info.product_id == product_id
    assert info.has_open_api == has_api


def test_similar_domain_is_not_misidentified():
    # "notmusinsa.com" 처럼 접미사만 닮은 도메인이 musinsa 로 오인되면 안 된다
    assert analyze_url("https://notmusinsa.com/products/1").platform == "unknown"


@pytest.mark.parametrize("url, valid", [
    ("https://www.musinsa.com/products/1", True),
    ("http://example.com", True),
    ("ftp://example.com/file", False),
    ("javascript:alert(1)", False),
    ("무신사에서 봤던 그 가방", False),
    ("", False),
])
def test_is_http_url(url, valid):
    assert is_http_url(url) is valid
