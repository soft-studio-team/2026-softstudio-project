"""
3단계 폴백 파이프라인 (문서 5절 아키텍처의 본체)
==================================================

    공유받은 URL
    │
    ├─ [Tier 1] 공식 오픈 API 연동      (쿠팡·네이버·11번가 등)
    │
    ├─ [Tier 2] 표준 메타데이터 파싱     (무신사·29CM·W컨셉 등)
    │
    └─ [Tier 3] 미리보기 수준 + 사용자 보완 (그 외 모든 사이트)

URL이 들어오면 위 순서로 시도하고, 실패하면 자동으로 다음 단계로 내려갑니다
(graceful degradation). 어떤 단계로 수집됐는지(source_type)와 각 단계의
시도 기록(attempts)을 결과에 함께 남깁니다.

설계 불변식(invariant):
  - 상품 페이지 HTTP GET은 URL당 최대 1회(WishlistBot). Tier 1이 페이지를
    가져왔다면 Tier 2/3이 그 결과를 재사용한다. 다른 서비스 UA 위장은 하지 않는다.
  - Tier 2는 제목·이미지·가격이 모두 있을 때만 성공한다. 가격만 없으면 Tier 3.
  - Tier 3은 실패하지 않는다. 따라서 parse()는 (URL 형식 오류를 제외하면)
    항상 ParseResult 를 반환한다 — 파싱 엔진의 실패가 앱의 실패가 되지 않는다.
"""

from __future__ import annotations

import dataclasses
import logging

from .cache import TTLCache
from .fetch import FetchBlocked, FetchFailed, FetchResponse, HttpFetcher
from .metadata import ExtractedMetadata, extract_metadata
from .models import ParseResult, Product, TierAttempt, TierOutcome
from .tiers.tier1_api import (
    AdapterError,
    OpenApiAdapter,
    clean_title_for_search,
    default_adapters,
)
from .tiers.tier2_metadata import build_metadata_product
from .tiers.tier3_preview import build_preview_product
from .urltools import UrlInfo, analyze_url, is_http_url

logger = logging.getLogger("parsing_engine")


class InvalidUrlError(ValueError):
    """http/https URL이 아닌 입력. (문서의 [분기 1] — URL 없음/불량 → 실패)"""


class _ParseContext:
    """한 번의 parse() 동안 티어들이 공유하는 상태.

    핵심 역할은 "페이지 GET 1회"를 강제하는 것: 어느 티어가 먼저 페이지를
    필요로 하든 fetch는 한 번만 일어나고 결과가 공유된다.
    """

    def __init__(self, url: str, fetcher: HttpFetcher,
                 share_title_hint: str | None = None):
        self.original_url = url
        self._fetcher = fetcher
        self._share_hint = share_title_hint
        self._fetched = False
        self._response: FetchResponse | None = None
        self._fetch_error: FetchBlocked | FetchFailed | None = None
        self._metadata: ExtractedMetadata | None = None
        self._url_info = analyze_url(url)

    @property
    def url_info(self) -> UrlInfo:
        return self._url_info

    def _ensure_fetched(self) -> None:
        if self._fetched:
            return
        self._fetched = True
        try:
            self._response = self._fetcher.fetch(self.original_url)
        except (FetchBlocked, FetchFailed) as e:
            self._fetch_error = e
            return
        # 단축링크(naver.me, link.coupang.com 등)가 풀렸으면 최종 URL 기준으로
        # 플랫폼·상품 식별자를 다시 해석한다.
        if self._response.final_url != self.original_url:
            final_info = analyze_url(self._response.final_url)
            if final_info.platform != "unknown":
                self._url_info = dataclasses.replace(
                    final_info, url=self.original_url
                )

    def fetch_error(self) -> FetchBlocked | FetchFailed | None:
        self._ensure_fetched()
        return self._fetch_error

    def metadata(self) -> ExtractedMetadata | None:
        self._ensure_fetched()
        if self._response is not None and self._metadata is None:
            self._metadata = extract_metadata(
                self._response.html, self._response.final_url
            )
        return self._metadata

    def platform_label(self) -> str:
        """화면 표시용 쇼핑몰 이름.

        레지스트리에 등록된 플랫폼이면 그 라벨("무신사", "쿠팡"),
        미등록 사이트면 og:site_name, 그것도 없으면 도메인으로 보완한다.
        """
        if self._url_info.platform_label:
            return self._url_info.platform_label
        meta = self.metadata()
        if meta and meta.site_name:
            return meta.site_name
        return self._url_info.host

    def share_hint(self) -> str | None:
        """공유 텍스트에서 온 상품명 힌트 (없으면 None)."""
        return self._share_hint

    def title_hint(self) -> str | None:
        """Tier 1 어댑터가 검색 키워드로 쓸 상품명 힌트. (LookupContext 구현)

        공유 텍스트에 상품명이 있으면 그것을 우선 사용한다 — 쇼핑 앱의 공유
        텍스트는 보통 "상품명 - 쿠팡 https://link.coupang.com/..." 형태라서,
        페이지 fetch 없이도(즉 사이트가 서버 요청을 거절하는 쿠팡 같은 곳도)
        Tier 1 검색이 가능해진다. 힌트가 없을 때만 페이지 제목을 쓴다.
        """
        if self._share_hint:
            return self._share_hint
        meta = self.metadata()
        return meta.title if meta else None


class ProductParsingEngine:
    """URL 하나를 받아 3단계 폴백으로 정규화된 상품 정보를 만들어내는 엔진."""

    def __init__(
        self,
        fetcher: HttpFetcher | None = None,
        adapters: dict[str, OpenApiAdapter] | None = None,
        cache: TTLCache | None = None,
    ):
        self._fetcher = fetcher or HttpFetcher()
        self._adapters = adapters if adapters is not None else default_adapters()
        self._cache = cache or TTLCache()

    # ------------------------------------------------------------------
    # 공개 진입점
    # ------------------------------------------------------------------

    def parse(self, url: str, title_hint: str | None = None) -> ParseResult:
        """URL 하나를 3단계 폴백으로 파싱한다.

        title_hint: 공유 텍스트에서 얻은 상품명 힌트(선택).
        쇼핑 앱 공유 텍스트("상품명 - 쿠팡 https://...")의 상품명 부분을
        넘기면, 페이지 fetch가 거절되는 사이트에서도 Tier 1 API 검색이
        가능해진다.
        """
        url = (url or "").strip()
        if not is_http_url(url):
            raise InvalidUrlError(f"not a valid http(s) URL: {url!r}")

        # 동일 URL 중복 요청 방지 (문서 5.3 준수 원칙 + API rate limit 대응)
        cached = self._cache.get(url)
        if cached is not None:
            return dataclasses.replace(cached, from_cache=True)

        ctx = _ParseContext(url, self._fetcher, share_title_hint=title_hint)
        attempts: list[TierAttempt] = []

        product, tier = self._try_tier1(ctx, attempts)
        if product is None:
            product, tier = self._try_tier2(ctx, attempts)
        if product is None:
            product, tier = self._build_tier3(ctx, attempts)

        result = ParseResult(
            product=product,
            resolved_tier=tier,
            missing_fields=product.missing_core_fields(),
            attempts=attempts,
        )
        self._log_result(result)
        self._cache.set(url, result)
        return result

    # ------------------------------------------------------------------
    # Tier 1 — 공식 오픈 API
    # ------------------------------------------------------------------

    def _try_tier1(
        self, ctx: _ParseContext, attempts: list[TierAttempt]
    ) -> tuple[Product | None, int]:
        info = ctx.url_info
        if not info.has_open_api:
            attempts.append(TierAttempt(
                1, "open_api", TierOutcome.SKIPPED,
                f"platform '{info.platform}' does not provide an open API",
            ))
            return None, 0
        adapter = self._adapters.get(info.platform)
        if adapter is None:
            attempts.append(TierAttempt(
                1, "open_api", TierOutcome.SKIPPED,
                f"no adapter registered for platform '{info.platform}'",
            ))
            return None, 0
        adapter_name = f"{info.platform}_api"
        if not adapter.is_configured():
            attempts.append(TierAttempt(
                1, adapter_name, TierOutcome.SKIPPED,
                "API credentials not configured",
            ))
            return None, 0
        try:
            product = adapter.lookup(ctx)
        except AdapterError as e:
            attempts.append(TierAttempt(1, adapter_name, TierOutcome.FAILED, str(e)))
            return None, 0
        except Exception as e:  # 어댑터 버그가 저장 실패로 번지지 않게 방어
            logger.exception("unexpected tier-1 adapter error for %s", ctx.original_url)
            attempts.append(TierAttempt(
                1, adapter_name, TierOutcome.FAILED, f"unexpected error: {e}",
            ))
            return None, 0
        attempts.append(TierAttempt(1, adapter_name, TierOutcome.SUCCESS))
        return product, 1

    # ------------------------------------------------------------------
    # Tier 2 — 표준 메타데이터 (JSON-LD 우선, OG 보완)
    # ------------------------------------------------------------------

    def _try_tier2(
        self, ctx: _ParseContext, attempts: list[TierAttempt]
    ) -> tuple[Product | None, int]:
        error = ctx.fetch_error()
        if isinstance(error, FetchBlocked):
            # robots.txt 를 존중한다 — 우회하지 않고 Tier 3으로 내려간다
            attempts.append(TierAttempt(
                2, "metadata", TierOutcome.SKIPPED,
                "robots.txt disallows fetching this URL (respected, no bypass)",
            ))
            return None, 0
        if isinstance(error, FetchFailed):
            attempts.append(TierAttempt(2, "metadata", TierOutcome.FAILED, str(error)))
            return None, 0

        meta = ctx.metadata()
        if meta is None:
            attempts.append(TierAttempt(
                2, "metadata", TierOutcome.FAILED,
                "no JSON-LD or Open Graph metadata found in page",
            ))
            return None, 0
        product = build_metadata_product(
            meta, ctx.original_url, ctx.url_info.platform, ctx.platform_label()
        )
        if product is None:
            missing = []
            if not meta.title:
                missing.append("title")
            if not meta.image_url:
                missing.append("image_url")
            if meta.price is None:
                missing.append("price")
            attempts.append(TierAttempt(
                2, "metadata", TierOutcome.FAILED,
                "metadata incomplete for Tier 2 "
                f"(need title+image+price; missing: {', '.join(missing)}) "
                f"[found via: {', '.join(meta.sources)}]",
            ))
            return None, 0
        attempts.append(TierAttempt(
            2, "metadata", TierOutcome.SUCCESS,
            f"extracted via {', '.join(meta.sources)}",
        ))
        return product, 2

    # ------------------------------------------------------------------
    # Tier 3 — 미리보기 저장 + 사용자 보완 (항상 성공)
    # ------------------------------------------------------------------

    def _build_tier3(
        self, ctx: _ParseContext, attempts: list[TierAttempt]
    ) -> tuple[Product, int]:
        meta = ctx.metadata()  # fetch 실패 시 None — 그래도 원본 링크는 저장한다
        product = build_preview_product(
            meta, ctx.original_url, ctx.url_info.platform, ctx.platform_label()
        )
        # "얻은 것은 전부 미리 채운다"(문서 5.4): 사이트가 접근을 전면 차단해
        # 페이지에서 아무것도 못 얻었어도, 공유 텍스트에 상품명이 있었다면
        # (사용자가 직접 건네준 데이터다) 제목만큼은 미리 채워준다.
        # 예: 에이블리(Cloudflare 차단) — 공유 텍스트의 상품명으로 제목 확보.
        if product.title is None and ctx.share_hint():
            product.title = clean_title_for_search(ctx.share_hint())
        attempts.append(TierAttempt(
            3, "preview", TierOutcome.SUCCESS,
            "preview-level save; user completes: "
            + (", ".join(product.missing_core_fields()) or "nothing"),
        ))
        return product, 3

    # ------------------------------------------------------------------
    # 모니터링 훅: 플랫폼별 실패율로 구조 변화를 감지한다 (문서 7절)
    # ------------------------------------------------------------------

    @staticmethod
    def _log_result(result: ParseResult) -> None:
        """운영에서는 이 로그를 지표로 집계한다.

        예: musinsa 의 resolved_tier 가 2 → 3 으로 쏠리기 시작하면
        무신사가 메타데이터 제공을 중단/변경했다는 신호다.
        """
        logger.info(
            "parsed platform=%s tier=%d source_type=%s missing=%s",
            result.product.source_platform,
            result.resolved_tier,
            result.product.source_type.value,
            ",".join(result.missing_fields) or "-",
        )
