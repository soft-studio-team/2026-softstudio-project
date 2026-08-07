"""
TTL 캐시
========

문서 5.3의 준수 원칙 중 하나:
  "결과를 캐싱해 동일 URL 중복 요청을 방지한다."

또한 Tier 1 API에는 호출량 제한(rate limit)이 있으므로(문서 5.2 제약사항)
API 응답도 캐싱이 필요합니다. 외부 의존성 없이 동작하는 단순한 인메모리
TTL 캐시로 두 용도를 모두 처리합니다. (운영 규모가 커지면 같은 인터페이스로
Redis 등으로 교체하면 됩니다.)
"""

from __future__ import annotations

import time
import threading
from typing import Any


class TTLCache:
    def __init__(self, ttl_seconds: float = 60 * 60 * 6, max_entries: int = 2048):
        self._ttl = ttl_seconds
        self._max = max_entries
        self._data: dict[str, tuple[float, Any]] = {}
        self._lock = threading.Lock()

    def get(self, key: str) -> Any | None:
        with self._lock:
            entry = self._data.get(key)
            if entry is None:
                return None
            expires_at, value = entry
            if time.monotonic() >= expires_at:
                del self._data[key]
                return None
            return value

    def set(self, key: str, value: Any) -> None:
        with self._lock:
            if len(self._data) >= self._max:
                # 가장 먼저 만료되는 항목부터 정리 (단순 전략으로 충분)
                oldest = min(self._data, key=lambda k: self._data[k][0])
                del self._data[oldest]
            self._data[key] = (time.monotonic() + self._ttl, value)

    def clear(self) -> None:
        with self._lock:
            self._data.clear()
