"""
엔진 빠른 테스트 (에뮬레이터·앱 불필요)
=======================================

서버(api_server_engine)가 켜진 상태에서 POST /parse 를 여러 URL로 호출해
어느 티어로 처리됐는지·가격·빠진 필드를 표로 보여준다.

사용법:
    # 1) 서버 먼저 켜두기
    python -m uvicorn api_server_engine:app --port 8000

    # 2) 기본 샘플 URL 로 테스트
    python scripts/try_engine.py

    # 3) 원하는 URL 직접 지정
    python scripts/try_engine.py https://www.musinsa.com/products/3348384 https://...

주의: 이건 서버 엔진(Tier 1/2/3)만 검증한다. 앱의 Tier 2.5(단말 WebView)는
포함되지 않는다 — 그건 실기기/에뮬레이터에서만 확인 가능하다.
"""

import json
import sys
import urllib.request

# Windows 콘솔에서 한글이 깨지지 않도록 UTF-8 로 출력한다.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

BASE = "http://127.0.0.1:8000"

# 서버가 키 없이도 커버하는 편집샵형(Tier 2 기대)과, Tier 3 으로 내려가
# 앱 Tier 2.5 가 필요해지는 몰을 섞은 기본 샘플.
DEFAULT_URLS = [
    "https://www.29cm.co.kr/products/1577769",
    "https://www.ssg.com/item/itemView.ssg?itemId=1000277700787",
    "https://www.musinsa.com/products/3348384",
    "https://mujikorea.co.kr/products/view/1005528",
    "https://www.oliveyoung.co.kr/store/goods/getGoodsDetail.do?goodsNo=A000000171427",
]


def parse(url: str) -> dict:
    req = urllib.request.Request(
        f"{BASE}/parse",
        data=json.dumps({"url": url}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=40) as res:
        return json.loads(res.read())


def main() -> None:
    urls = sys.argv[1:] or DEFAULT_URLS
    print(f"{'TIER':5} {'플랫폼':10} {'가격':>10}  {'빠진필드':14} 제목")
    print("-" * 78)
    for url in urls:
        try:
            data = parse(url)
            p = data["product"]
            tier = data["resolved_tier"]
            missing = ",".join(data["missing_fields"]) or "-"
            price = p.get("price")
            price_s = f"{price:,}" if isinstance(price, int) else "-"
            platform = (p.get("platform_label") or p.get("source_platform") or "")[:10]
            title = (p.get("title") or "(제목없음)")[:30]
            print(f"tier{tier:<1} {platform:10} {price_s:>10}  {missing:14} {title}")
        except Exception as e:  # noqa: BLE001 — 테스트 스크립트라 모든 오류를 보여준다
            print(f"ERR   {url[:40]}  {e}")


if __name__ == "__main__":
    main()
