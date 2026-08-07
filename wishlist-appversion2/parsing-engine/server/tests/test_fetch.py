"""HTTP 페처 · 링크 미리보기 unfurl 테스트 (네트워크 mock)."""

from unittest.mock import patch

import pytest

from engine.fetch import (
    HONEST_USER_AGENT,
    FetchFailed,
    FetchResponse,
    HttpFetcher,
    RobotsPolicy,
    _is_invalid_robots_body,
)


def test_invalid_robots_detects_cloudflare_html():
    html = "<!DOCTYPE html><html><title>보안 확인</title></html>"
    assert _is_invalid_robots_body(html, 403) is True


def test_invalid_robots_accepts_real_file():
    body = "User-agent: *\nDisallow: /\n"
    assert _is_invalid_robots_body(body, 200) is False


def test_standard_fetch_when_robots_allows():
    fetcher = HttpFetcher(robots=RobotsPolicy())
    with patch("engine.fetch._http_get") as get:
        get.return_value = FetchResponse("https://shop.example/p/1", 200, "<html/>")
        with patch.object(fetcher._robots, "is_valid", return_value=True), patch.object(
            fetcher._robots, "can_fetch", return_value=True
        ):
            result = fetcher.fetch("https://shop.example/p/1")

    assert result.fetch_mode == "standard"
    get.assert_called_once_with(
        "https://shop.example/p/1", HONEST_USER_AGENT, fetcher._timeout
    )


def test_link_preview_when_robots_disallows_uses_same_honest_ua():
    """무신사 패턴: robots Disallow 이어도 WishlistBot 으로 unfurl 1회만."""
    fetcher = HttpFetcher(robots=RobotsPolicy())
    with patch("engine.fetch._http_get") as get:
        get.return_value = FetchResponse("https://www.musinsa.com/products/1", 200, "<og/>")
        with patch.object(fetcher._robots, "is_valid", return_value=True), patch.object(
            fetcher._robots, "can_fetch", return_value=False
        ):
            result = fetcher.fetch("https://www.musinsa.com/products/1")

    assert result.fetch_mode == "link_preview"
    get.assert_called_once_with(
        "https://www.musinsa.com/products/1", HONEST_USER_AGENT, fetcher._timeout
    )


def test_honest_ua_403_does_not_retry_with_compat_ua():
    """에이블리 패턴: WishlistBot 403이면 다른 UA로 재시도하지 않고 실패."""
    fetcher = HttpFetcher(robots=RobotsPolicy())
    with patch("engine.fetch._http_get") as get:
        get.side_effect = FetchFailed("HTTP 403", status=403)
        with patch.object(fetcher._robots, "is_valid", return_value=False), patch.object(
            fetcher._robots, "can_fetch", return_value=True
        ):
            with pytest.raises(FetchFailed) as exc:
                fetcher.fetch("https://m.a-bly.com/goods/1")

    assert exc.value.status == 403
    get.assert_called_once()


@pytest.mark.integration
def test_live_musinsa_link_preview():
    """실네트워크: 무신사 — WishlistBot unfurl.
    가격까지 있으면 Tier 2, 없으면 Tier 3(제목·이미지만 미리 채움)."""
    from engine import ProductParsingEngine

    result = ProductParsingEngine().parse("https://www.musinsa.com/products/4715870")
    assert result.product.title
    assert result.product.image_url
    if result.product.price is not None:
        assert result.resolved_tier == 2
        assert result.missing_fields == []
    else:
        assert result.resolved_tier == 3
        assert result.missing_fields == ["price"]


@pytest.mark.integration
def test_live_ably_falls_to_tier3_without_compat_ua():
    """실네트워크: 에이블리 — compat UA 없이 WishlistBot만 → 보통 Tier 3."""
    from engine import ProductParsingEngine

    result = ProductParsingEngine().parse("https://m.a-bly.com/goods/10062919")
    assert result.resolved_tier == 3
    assert result.product.original_url.startswith("https://m.a-bly.com/")
