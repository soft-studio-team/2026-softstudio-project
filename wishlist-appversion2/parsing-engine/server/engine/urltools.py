"""
URL 도구: 플랫폼 식별 + 상품 식별자 추출
==========================================

Tier 1의 첫 두 단계(문서 5.2)를 담당합니다.

  1. 공유받은 URL에서 플랫폼을 식별한다 (도메인 기준).
  2. URL 경로/쿼리에서 상품 식별자를 추출한다 (예: 쿠팡 URL의 products/{id}).

새 플랫폼 지원은 PLATFORMS 레지스트리에 한 줄 추가하는 것으로 끝나도록,
플랫폼 지식을 이 파일 한 곳에 모아둡니다.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from urllib.parse import parse_qs, urlparse


@dataclass(frozen=True)
class PlatformRule:
    """플랫폼 하나를 식별·해석하는 규칙."""

    platform: str                          # 내부 플랫폼 코드 (예: "coupang")
    label: str                             # 화면 표시용 이름 (예: "쿠팡")
    domains: tuple[str, ...]               # 이 플랫폼으로 판정할 도메인 접미사들
    id_patterns: tuple[str, ...] = ()      # 경로에서 상품 식별자를 뽑는 정규식들
    id_query_keys: tuple[str, ...] = ()    # 쿼리스트링에서 식별자를 뽑는 키들
    has_open_api: bool = False             # 공식 오픈 API 제공 여부 (문서 3절)


# 국내 주요 쇼핑 플랫폼 레지스트리.
# 문서 3절의 조사 결과를 반영: 오픈마켓형은 API를 열고(has_open_api=True),
# 편집샵형·단일 브랜드몰은 열지 않는다(False → Tier 2부터 시도).
PLATFORMS: tuple[PlatformRule, ...] = (
    PlatformRule(
        platform="coupang",
        label="쿠팡",
        domains=("coupang.com",),  # link.coupang.com 단축링크 포함
        id_patterns=(r"/(?:vp/)?products/(\d+)",),
        id_query_keys=("itemId", "vendorItemId"),
        has_open_api=True,
    ),
    PlatformRule(
        platform="naver",
        label="네이버 쇼핑",
        domains=(
            "smartstore.naver.com",
            "brand.naver.com",
            "shopping.naver.com",
            "m.shopping.naver.com",
            "naver.me",  # 네이버 공유 단축링크 (리다이렉트 후 재식별됨)
        ),
        id_patterns=(
            r"/products/(\d+)",          # smartstore.naver.com/{store}/products/{id}
            r"/catalog/(\d+)",           # shopping.naver.com/catalog/{id}
        ),
        id_query_keys=("nvMid", "productId"),
        has_open_api=True,
    ),
    PlatformRule(
        platform="11st",
        label="11번가",
        domains=("11st.co.kr",),
        id_patterns=(r"/products/(?:[a-z]+/)?(\d+)",),
        id_query_keys=("prdNo",),
        has_open_api=True,
    ),
    # ── 이하 편집샵형/단일 브랜드몰: API 없음 → Tier 2 대상 ──
    PlatformRule(
        platform="musinsa",
        label="무신사",
        domains=("musinsa.com",),
        id_patterns=(r"/products/(\d+)", r"/app/goods/(\d+)"),
    ),
    PlatformRule(
        platform="29cm",
        label="29CM",
        domains=("29cm.co.kr",),
        id_patterns=(r"/catalog/(\d+)", r"/products?/(\d+)"),
    ),
    PlatformRule(
        platform="wconcept",
        label="W컨셉",
        domains=("wconcept.co.kr",),
        id_patterns=(r"/[Pp]roduct/(\d+)",),
    ),
    PlatformRule(
        platform="fila",
        label="FILA",
        domains=("fila.co.kr",),
        id_patterns=(r"/products/([a-zA-Z0-9-]+)",),
    ),
    PlatformRule(
        platform="hago",
        label="하고",
        domains=("hago.kr",),
        id_patterns=(r"/goods/detail/(\d+)",),
    ),
    PlatformRule(
        platform="lookpin",
        label="룩핀",
        domains=("lookpin.co.kr",),
        id_patterns=(r"/products/(\d+)",),
    ),
    PlatformRule(
        platform="topten",
        label="탑텐",
        domains=("topten10.goodwearmall.com",),
        id_patterns=(r"/(?:m/)?product/([A-Za-z0-9]+)/detail",),
    ),
    PlatformRule(
        platform="muji",
        label="무인양품",
        domains=("mujikorea.co.kr",),
        id_patterns=(r"/products/view/(\d+)",),
    ),
    PlatformRule(
        platform="hmall",
        label="현대Hmall",
        domains=("hmall.com",),
        id_query_keys=("slitmCd",),
    ),
    PlatformRule(
        platform="lotteon",
        label="롯데온",
        domains=("lotteon.com",),
        id_patterns=(r"/p/product/(LO\d+)",),
    ),
    PlatformRule(
        platform="mixxo",
        label="미쏘",
        domains=("mixxo.com",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="dailyjou",
        label="데일리쥬",
        domains=("dailyjou.com",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="lee",
        label="리",
        domains=("leekorea.co.kr",),
        id_patterns=(r"/product/[^/]+/(\d+)/",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="filluminate",
        label="필루미네이트",
        domains=("filluminate.com",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="urbanstoff",
        label="어반스터프",
        domains=("urbanstoff.com",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="not4u",
        label="낫포유",
        domains=("not4u.kr",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="insilence",
        label="인사일런스",
        domains=("insilence.co.kr",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="fabregat",
        label="파브레가",
        domains=("fabregat.kr",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="hotping",
        label="핫핑",
        domains=("hotping.co.kr",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="uniqlo",
        label="유니클로",
        domains=("uniqlo.com",),
        id_patterns=(r"/products/(E\d+-\d+)",),
    ),
    PlatformRule(
        platform="ssg",
        label="SSG",
        domains=("ssg.com",),
        id_query_keys=("itemId",),
    ),
    PlatformRule(
        platform="thehyundai",
        label="더현대Hi",
        domains=("hi.thehyundai.com",),
        id_patterns=(r"/product/([A-Za-z0-9]+)",),
    ),
    PlatformRule(
        platform="ably",
        label="에이블리",
        domains=("a-bly.com",),
        id_patterns=(r"/goods/(\d+)",),
    ),
    PlatformRule(
        platform="zigzag",
        label="지그재그",
        domains=("zigzag.kr",),
        id_patterns=(r"/catalog/products/(\d+)",),
    ),
    PlatformRule(
        platform="kream",
        label="크림",
        domains=("kream.co.kr",),
        id_patterns=(r"/products/(\d+)",),
    ),
    PlatformRule(
        platform="guess",
        label="게스",
        domains=("guesskorea.com",),
        id_query_keys=("product_no",),
    ),
    PlatformRule(
        platform="levis",
        label="리바이스",
        domains=("levi.co.kr",),
        id_patterns=(r"/products/[^/?#]*-([A-Za-z0-9]+)$",),
    ),
    PlatformRule(
        platform="vans",
        label="반스",
        domains=("vans.co.kr",),
        id_patterns=(r"/PRODUCT/([A-Za-z0-9]+)",),
    ),
    PlatformRule(platform="covernat", label="커버낫", domains=("covernat.co.kr",), id_query_keys=("product_no",)),
    PlatformRule(platform="codegraphy", label="코드그라피", domains=("code-graphy.com",), id_query_keys=("product_no",)),
    PlatformRule(platform="whoau", label="후아유", domains=("whoau.com",), id_query_keys=("product_no",)),
    PlatformRule(platform="gap", label="Gap", domains=("gap.com",), id_query_keys=("pid",)),
    PlatformRule(platform="hm", label="H&M", domains=("hm.com",), id_patterns=(r"/productpage\.(\d+)\.html",)),
    PlatformRule(platform="aritzia", label="Aritzia", domains=("aritzia.com",), id_patterns=(r"/product/[^/]+/(\d+)\.html",)),
    PlatformRule(platform="noirer", label="노이아고", domains=("noirer.com",), id_query_keys=("product_no",)),
    PlatformRule(platform="liphop", label="립합", domains=("liphop.com",), id_query_keys=("product_no",)),
    PlatformRule(platform="marithe", label="마리떼", domains=("marithe-official.com",), id_query_keys=("product_no",)),
    PlatformRule(platform="mahagrid", label="마하그리드", domains=("mahagrid.com",), id_query_keys=("product_no",)),
    PlatformRule(platform="vivastudio", label="비바스튜디오", domains=("vivastudio.co.kr",), id_query_keys=("product_no",)),
    PlatformRule(platform="amomento", label="아모멘토", domains=("amomento.co",), id_patterns=(r"/product/[^/]+/(\d+)/",)),
    PlatformRule(platform="anderssonbell", label="앤더슨벨", domains=("anderssonbell.com",), id_query_keys=("product_no",)),
    PlatformRule(platform="yale", label="예일", domains=("yaleapparel.co.kr",), id_query_keys=("product_no",)),
    PlatformRule(platform="ohora", label="오호라", domains=("ohora.kr",), id_query_keys=("product_no",)),
    PlatformRule(platform="withyoon", label="위드윤", domains=("withyoon.com",), id_query_keys=("product_no",)),
    PlatformRule(platform="66girls", label="육육걸즈", domains=("66girls.co.kr",), id_patterns=(r"/product/[^/]+/(\d+)/",)),
    PlatformRule(platform="partimento", label="파르티멘토", domains=("partimento.com",), id_patterns=(r"/product/[^/]+/(\d+)/",)),
    PlatformRule(platform="fashionplus", label="패션플러스", domains=("fashionplus.co.kr",), id_patterns=(r"/goods/detail/(\d+)",)),
    PlatformRule(platform="frombeginning", label="프롬비기닝", domains=("frombeginning.co.kr",), id_query_keys=("product_no",)),
    PlatformRule(platform="lfmall", label="LF몰", domains=("lfmall.co.kr",), id_patterns=(r"/app/product/([A-Za-z0-9]+)",)),
    PlatformRule(platform="reformation", label="Reformation", domains=("thereformation.com",), id_patterns=(r"/products/[^/]+/([A-Za-z0-9]+)\.html",)),
    PlatformRule(
        platform="nike",
        label="나이키",
        domains=("nike.com",),
        id_patterns=(r"/t/[^/]+/([A-Z0-9-]+)",),
    ),
    PlatformRule(
        platform="oliveyoung",
        label="올리브영",
        domains=("oliveyoung.co.kr",),
        id_query_keys=("goodsNo",),
    ),
    PlatformRule(platform="queenit", label="퀸잇", domains=("queenit.kr",), id_patterns=(r"/product/([a-f0-9]{32})",)),
    PlatformRule(platform="brandi", label="브랜디", domains=("brandi.co.kr",), id_patterns=(r"/products/(\d+)",)),
    PlatformRule(platform="nugu", label="NUGU", domains=("nugu.jp",), id_patterns=(r"/product/([A-Za-z0-9]+)",)),
    PlatformRule(platform="cjonstyle", label="CJ온스타일", domains=("cjonstyle.com",), id_patterns=(r"/p/item/(\d+)",)),
    PlatformRule(platform="4910", label="4910", domains=("4910.kr",), id_patterns=(r"/(?:desktop/)?goods/(\d+)",)),
    PlatformRule(platform="ssfshop", label="SSF샵", domains=("ssfshop.com",), id_patterns=(r"/[^/]+/([A-Za-z0-9]+)/good",)),
    PlatformRule(platform="zara", label="ZARA", domains=("zara.com",), id_patterns=(r"-p(\d+)\.html",)),
    PlatformRule(platform="shein", label="SHEIN", domains=("shein.com",), id_patterns=(r"-p-(\d+)\.html",)),
    PlatformRule(platform="elandmall", label="이랜드몰", domains=("elandmall.co.kr",), id_query_keys=("itemNo",)),
)


@dataclass(frozen=True)
class UrlInfo:
    """URL 한 건에 대한 해석 결과."""

    url: str                       # 입력 그대로의 URL
    host: str                      # 소문자 호스트
    platform: str = "unknown"      # 플랫폼 코드 (미등록 도메인이면 "unknown")
    platform_label: str = ""       # 표시용 이름 (미등록이면 빈 문자열 → 파이프라인이 보완)
    product_id: str | None = None  # 추출된 상품 식별자
    has_open_api: bool = False     # Tier 1 시도 대상인지
    rule: PlatformRule | None = field(default=None, repr=False)


def _match_rule(host: str) -> PlatformRule | None:
    for rule in PLATFORMS:
        for domain in rule.domains:
            # "musinsa.com" 은 "www.musinsa.com", "m.musinsa.com" 도 매칭돼야 한다.
            if host == domain or host.endswith("." + domain):
                return rule
    return None


def _extract_product_id(rule: PlatformRule, path: str, query: str) -> str | None:
    for pattern in rule.id_patterns:
        m = re.search(pattern, path)
        if m:
            return m.group(1)
    if rule.id_query_keys and query:
        params = parse_qs(query)
        for key in rule.id_query_keys:
            values = params.get(key)
            if values and values[0]:
                return values[0]
    return None


def analyze_url(url: str) -> UrlInfo:
    """URL을 해석해 플랫폼·상품 식별자를 알아낸다.

    리다이렉트를 따라가지 않고 문자열만 해석하므로 네트워크 비용이 없습니다.
    단축링크(link.coupang.com, naver.me 등)는 fetch 후 최종 URL로 다시
    호출하면 정확한 식별자를 얻을 수 있습니다.
    """
    parsed = urlparse(url)
    host = (parsed.hostname or "").lower()
    rule = _match_rule(host)
    if rule is None:
        return UrlInfo(url=url, host=host)
    return UrlInfo(
        url=url,
        host=host,
        platform=rule.platform,
        platform_label=rule.label,
        product_id=_extract_product_id(rule, parsed.path, parsed.query),
        has_open_api=rule.has_open_api,
        rule=rule,
    )


def is_http_url(url: str) -> bool:
    """지원하는 스킴(http/https)의 URL인지 검사한다. (시스템 경계 입력 검증)"""
    parsed = urlparse(url)
    return parsed.scheme in ("http", "https") and bool(parsed.hostname)
