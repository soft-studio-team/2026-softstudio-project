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
    ("https://www.fila.co.kr/products/1100fs262rs11m001490", "fila", "1100fs262rs11m001490", False),
    ("https://www.hago.kr/goods/detail/750307", "hago", "750307", False),
    ("https://www.lookpin.co.kr/products/2724519", "lookpin", "2724519", False),
    ("https://topten10.goodwearmall.com/product/MSG2UL2205NVP/detail", "topten", "MSG2UL2205NVP", False),
    ("https://mujikorea.co.kr/products/view/1005531", "muji", "1005531", False),
    ("https://www.hmall.com/md/pda/itemPtc?slitmCd=2060464676", "hmall", "2060464676", False),
    ("https://www.lotteon.com/p/product/LO2724337622", "lotteon", "LO2724337622", False),
    ("https://mixxo.com/product/detail.html?product_no=9813", "mixxo", "9813", False),
    ("https://dailyjou.com/product/detail.html?product_no=22794", "dailyjou", "22794", False),
    ("https://leekorea.co.kr/product/lee-denimend/3114/", "lee", "3114", False),
    ("https://filluminate.com/product/detail.html?product_no=11734", "filluminate", "11734", False),
    ("https://urbanstoff.com/product/detail.html?product_no=507", "urbanstoff", "507", False),
    ("https://not4u.kr/product/detail.html?product_no=261", "not4u", "261", False),
    ("https://insilence.co.kr/product/detail.html?product_no=7303", "insilence", "7303", False),
    ("https://fabregat.kr/product/detail.html?product_no=1038", "fabregat", "1038", False),
    ("https://hotping.co.kr/product/detail.html?product_no=29570", "hotping", "29570", False),
    ("https://www.uniqlo.com/kr/ko/products/E486612-000/00", "uniqlo", "E486612-000", False),
    ("https://www.ssg.com/item/itemView.ssg?itemId=1000571660298", "ssg", "1000571660298", False),
    ("https://hi.thehyundai.com/product/40B1406274?sectId=1031", "thehyundai", "40B1406274", False),
    ("https://m.a-bly.com/goods/12345678", "ably", "12345678", False),
    ("https://zigzag.kr/catalog/products/144255443", "zigzag", "144255443", False),
    ("https://kream.co.kr/products/748804", "kream", "748804", False),
    ("https://www.guesskorea.com/product/detail.html?product_no=45471", "guess", "45471", False),
    ("https://levi.co.kr/products/501-90s-%EC%A7%84-a19590086", "levis", "a19590086", False),
    ("https://www.vans.co.kr/PRODUCT/VN000D6WBOM", "vans", "VN000D6WBOM", False),
    ("https://covernat.co.kr/product/detail.html?product_no=18025", "covernat", "18025", False),
    ("https://code-graphy.com/product/detail.html?product_no=6388", "codegraphy", "6388", False),
    ("https://whoau.com/product/detail.html?product_no=4847", "whoau", "4847", False),
    ("https://www.gap.com/browse/product.do?pid=1185082032", "gap", "1185082032", False),
    ("https://www2.hm.com/ko_kr/productpage.1346684001.html", "hm", "1346684001", False),
    ("https://www.aritzia.com/intl/en/product/technique-dress/124784.html", "aritzia", "124784", False),
    ("https://noirer.com/product/detail.html?product_no=2141", "noirer", "2141", False),
    ("https://liphop.com/product/detail.html?product_no=17849", "liphop", "17849", False),
    ("https://marithe-official.com/product/detail.html?product_no=8883", "marithe", "8883", False),
    ("https://mahagrid.com/product/detail.html?product_no=3854", "mahagrid", "3854", False),
    ("https://vivastudio.co.kr/product/detail.html?product_no=5485", "vivastudio", "5485", False),
    ("https://amomento.co/product/button-neck-knit-2colors/1642/", "amomento", "1642", False),
    ("https://www.anderssonbell.com/product/detail.html?product_no=10605", "anderssonbell", "10605", False),
    ("https://yaleapparel.co.kr/product/detail.html?product_no=18179", "yale", "18179", False),
    ("https://ohora.kr/product/detail.html?product_no=2137", "ohora", "2137", False),
    ("https://withyoon.com/product/detail.html?product_no=19342", "withyoon", "19342", False),
    ("https://www.66girls.co.kr/product/1/158101/", "66girls", "158101", False),
    ("https://partimento.com/product/snap-puffer-jacketred/14368/", "partimento", "14368", False),
    ("https://www.fashionplus.co.kr/goods/detail/418168398", "fashionplus", "418168398", False),
    ("https://frombeginning.co.kr/product/detail.html?product_no=22025", "frombeginning", "22025", False),
    ("https://www.lfmall.co.kr/app/product/K560XX01194", "lfmall", "K560XX01194", False),
    ("https://www.thereformation.com/products/silver-bell-bag/1320285HTL.html", "reformation", "1320285HTL", False),
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
