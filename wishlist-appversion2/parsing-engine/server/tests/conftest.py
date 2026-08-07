"""테스트 공통 설정: server/ 를 import 경로에 추가하고, 가짜 페처를 제공한다.

모든 테스트는 네트워크 없이(오프라인) 동작합니다. 실제 HTTP 대신
FakeFetcher / 가짜 transport 를 주입해 각 티어와 폴백 체인을 검증합니다.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest

from engine.fetch import FetchBlocked, FetchFailed, FetchResponse


class FakeFetcher:
    """정해진 HTML을 돌려주거나 정해진 예외를 던지는 가짜 HTTP 페처.

    fetch_count 로 "URL당 GET 1회" 불변식을 검증할 수 있다.
    """

    def __init__(self, html: str = "", final_url: str | None = None,
                 error: Exception | None = None):
        self.html = html
        self.final_url = final_url
        self.error = error
        self.fetch_count = 0

    def fetch(self, url: str) -> FetchResponse:
        self.fetch_count += 1
        if self.error is not None:
            raise self.error
        return FetchResponse(
            final_url=self.final_url or url, status=200, html=self.html
        )


@pytest.fixture
def make_fetcher():
    return FakeFetcher
