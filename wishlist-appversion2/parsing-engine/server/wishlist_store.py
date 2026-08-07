"""
위시리스트 저장소
=================

앱(Flutter)이 담은 상품 목록을 서버에 보관하는 아주 단순한 저장 계층입니다.
JSON 파일 하나에 저장하므로 서버를 재시작해도 목록이 유지되고,
데모·시뮬레이터 용도로는 충분합니다. (운영 규모가 되면 같은 인터페이스로
SQLite/Postgres 로 교체하면 됩니다.)

항목의 id 는 원본 상품 URL입니다 — 같은 URL을 다시 담으면 새 항목을 만들지
않고 기존 항목을 갱신합니다(중복 방지).
"""

from __future__ import annotations

import json
import os
import threading
from pathlib import Path

DEFAULT_DB_PATH = Path(__file__).parent / "data" / "wishlist.json"


class WishlistStore:
    def __init__(self, path: Path | None = None):
        env_path = os.environ.get("WISHLIST_DB_PATH")
        self._path = path or (Path(env_path) if env_path else DEFAULT_DB_PATH)
        self._lock = threading.Lock()
        self._items: dict[str, dict] = {}
        self._order: list[str] = []  # 최신 저장이 앞에 오도록 id 순서 유지
        self._load()

    def _load(self) -> None:
        if not self._path.exists():
            return
        try:
            saved = json.loads(self._path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return  # 깨진 파일이면 빈 목록에서 다시 시작
        self._order = [item["id"] for item in saved if "id" in item]
        self._items = {item["id"]: item for item in saved if "id" in item}

    def _flush(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        payload = [self._items[item_id] for item_id in self._order]
        self._path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8"
        )

    def upsert(self, item: dict) -> bool:
        """항목을 저장한다. 반환값은 '새 항목이었는지'(isNew)."""
        item_id = item["id"]
        with self._lock:
            is_new = item_id not in self._items
            if not is_new:
                self._order.remove(item_id)
            self._order.insert(0, item_id)  # 방금 담은 것이 맨 위
            self._items[item_id] = item
            self._flush()
            return is_new

    def list_items(self) -> list[dict]:
        with self._lock:
            return [self._items[item_id] for item_id in self._order]

    def update_fields(self, item_id: str, fields: dict) -> dict | None:
        """사용자 보완 입력(Tier 3 UX)으로 특정 필드만 갱신한다."""
        with self._lock:
            item = self._items.get(item_id)
            if item is None:
                return None
            item.update(fields)
            self._flush()
            return item

    def delete(self, item_id: str) -> bool:
        with self._lock:
            if item_id not in self._items:
                return False
            del self._items[item_id]
            self._order.remove(item_id)
            self._flush()
            return True
