"""엔진 전용 API 서버(api_server_engine) 테스트."""

import pytest
from fastapi.testclient import TestClient

from conftest import FakeFetcher

import api_server_engine as api_server
from engine.cache import TTLCache
from engine.pipeline import ProductParsingEngine
from wishlist_store import WishlistStore

MUSINSA_HTML = """
<head>
<meta property="og:title" content="제이에스티나 GINO SM 크로스 BK | 무신사"/>
<meta property="og:image" content="https://image.msscdn.net/goods/1.jpg"/>
</head>
"""


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(api_server, "engine", ProductParsingEngine(
        fetcher=FakeFetcher(html=MUSINSA_HTML), adapters={}, cache=TTLCache(),
    ))
    monkeypatch.setattr(api_server, "store",
                        WishlistStore(path=tmp_path / "wishlist.json"))
    return TestClient(api_server.app)


URL = "https://www.musinsa.com/products/4715870"


def test_scrap_extracts_url_from_share_text(client):
    response = client.post("/api/scrap", json={
        "input": f"이 가방 어때? {URL} 무신사에서 봄",
    })
    assert response.status_code == 200
    body = response.json()
    assert body["isNew"] is True
    assert body["product"]["title"].startswith("제이에스티나")
    assert body["product"]["missing_fields"] == ["price"]


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_parse_endpoint(client):
    response = client.post("/parse", json={"url": URL})
    assert response.status_code == 200
    assert response.json()["product"]["title"].startswith("제이에스티나")
