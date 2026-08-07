"""
HTTP 페처: 링크 미리보기(unfurl) 수준의 단일 URL 조회
======================================================

사용자가 위시리스트에 URL을 **명시적으로 저장**할 때, 카카오톡·슬랙이
링크 미리보기 카드를 만들 때와 같은 방식으로 HTML `<head>`의 JSON-LD /
Open Graph 를 GET 1회로 읽습니다.

  1) 표준 fetch — robots.txt 가 허용하면 정직한 UA(`WishlistBot`)로 시도
  2) 링크 미리보기 fetch — robots 차단·비정상 robots 일 때도
     **같은 WishlistBot UA**로 unfurl 1회 (무신사: robots Disallow 이지만 OG HTML 제공)

JS 렌더링·로그인·크롤링·다른 서비스 UA 위장(compat unfurl)은 하지 않습니다.
403이면 그대로 실패 → Tier 3으로 폴백합니다.
"""

from __future__ import annotations

import gzip
import io
import urllib.error
import urllib.request
import urllib.robotparser
from dataclasses import dataclass
from urllib.parse import urlsplit, urlunsplit

from .cache import TTLCache

HONEST_USER_AGENT = (
    "WishlistBot/1.0 (+https://github.com/sof-studio/wishlist-app; "
    "link-preview unfurl on explicit user save)"
)

DEFAULT_TIMEOUT = 10.0
MAX_BODY_BYTES = 3 * 2**20
ROBOTS_MAX_BYTES = 8192


class FetchBlocked(Exception):
    """(레거시) robots.txt 가 명시적으로 거부하고 unfurl 도 불가한 경우."""


class FetchFailed(Exception):
    """네트워크 오류·HTTP 오류 등으로 페이지를 얻지 못한 경우."""

    def __init__(self, message: str, status: int | None = None):
        super().__init__(message)
        self.status = status


@dataclass
class FetchResponse:
    final_url: str
    status: int
    html: str
    fetch_mode: str = "standard"  # standard | link_preview


@dataclass
class _RobotsState:
    parser: urllib.robotparser.RobotFileParser
    valid: bool


def _is_invalid_robots_body(body: str, status: int) -> bool:
    """Cloudflare 챌린지 등 가짜 robots.txt 를 걸러낸다."""
    if status >= 400:
        return True
    text = body.strip().lower()
    if text.startswith("<!doctype") or text.startswith("<html"):
        return True
    return "user-agent:" not in text


class RobotsPolicy:
    """robots.txt 확인. 비정상 응답은 '제한 없음'으로 간주한다."""

    def __init__(self, user_agent: str = HONEST_USER_AGENT, ttl_seconds: float = 60 * 60 * 24):
        self._product_token = user_agent.split("/")[0]
        self._cache = TTLCache(ttl_seconds=ttl_seconds, max_entries=512)

    def _load(self, url: str) -> _RobotsState:
        parts = urlsplit(url)
        host_key = f"{parts.scheme}://{parts.netloc}"
        cached = self._cache.get(host_key)
        if cached is not None:
            return cached

        robots_url = urlunsplit((parts.scheme, parts.netloc, "/robots.txt", "", ""))
        parser = urllib.robotparser.RobotFileParser()
        valid = True

        try:
            request = urllib.request.Request(
                robots_url,
                headers={"User-Agent": HONEST_USER_AGENT},
                method="GET",
            )
            with urllib.request.urlopen(request, timeout=DEFAULT_TIMEOUT) as response:
                raw = response.read(ROBOTS_MAX_BYTES)
                status = response.status
            body = raw.decode("utf-8", errors="replace")
            if _is_invalid_robots_body(body, status):
                valid = False
                parser.allow_all = True
            else:
                parser.parse(body.splitlines())
        except (urllib.error.URLError, OSError, ValueError):
            valid = False
            parser.allow_all = True

        state = _RobotsState(parser=parser, valid=valid)
        self._cache.set(host_key, state)
        return state

    def can_fetch(self, url: str) -> bool:
        state = self._load(url)
        if not state.valid:
            return True
        return state.parser.can_fetch(self._product_token, url)

    def is_valid(self, url: str) -> bool:
        return self._load(url).valid


def _decode_body(raw: bytes, content_type: str) -> str:
    charset = "utf-8"
    if "charset=" in content_type:
        charset = content_type.split("charset=")[-1].split(";")[0].strip() or "utf-8"
    try:
        return raw.decode(charset, errors="replace")
    except LookupError:
        return raw.decode("utf-8", errors="replace")


def _http_get(url: str, user_agent: str, timeout: float) -> FetchResponse:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": user_agent,
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.5",
            "Accept-Encoding": "gzip",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read(MAX_BODY_BYTES)
            if response.headers.get("Content-Encoding", "") == "gzip":
                try:
                    raw = gzip.GzipFile(fileobj=io.BytesIO(raw)).read(MAX_BODY_BYTES)
                except OSError:
                    pass
            html = _decode_body(raw, response.headers.get("Content-Type", ""))
            return FetchResponse(
                final_url=response.geturl(),
                status=response.status,
                html=html,
            )
    except urllib.error.HTTPError as e:
        raise FetchFailed(f"HTTP {e.code} for {url}", status=e.code) from e
    except (urllib.error.URLError, OSError, ValueError) as e:
        raise FetchFailed(f"network error for {url}: {e}") from e


class HttpFetcher:
    """정직한 WishlistBot UA로 HTML GET 1회. 다른 서비스 UA 위장은 하지 않는다."""

    def __init__(
        self,
        user_agent: str = HONEST_USER_AGENT,
        timeout: float = DEFAULT_TIMEOUT,
        robots: RobotsPolicy | None = None,
    ):
        self._user_agent = user_agent
        self._timeout = timeout
        self._robots = robots or RobotsPolicy(user_agent=user_agent)

    def fetch(self, url: str) -> FetchResponse:
        robots_ok = self._robots.is_valid(url) and self._robots.can_fetch(url)
        response = _http_get(url, self._user_agent, self._timeout)
        response.fetch_mode = "standard" if robots_ok else "link_preview"
        return response
