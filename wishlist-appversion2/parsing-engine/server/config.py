"""서버 설정값 — 전부 환경변수로 오버라이드 가능하게 뺐다(요구사항 7)."""
from __future__ import annotations

import os

# 요청 하나(렌더링 + Gemini 호출 + 필요시 스크린샷 폴백)의 전체 타임아웃. 이 시간을
# 넘기면 504로 응답하고 해당 요청을 취소한다 — 서버 전체나 다른 요청은 영향받지 않는다.
EXTRACT_TIMEOUT_S = float(os.environ.get("EXTRACT_TIMEOUT_S", "45"))

# Playwright page.goto()의 네비게이션 타임아웃 (render.py에 전달).
RENDER_NAV_TIMEOUT_MS = int(os.environ.get("RENDER_NAV_TIMEOUT_MS", "20000"))

# Gemini 429 재시도 최대 횟수 (providers.py의 DEFAULT_MAX_RETRIES와 동일 — 여기 있는 값은
# main.py가 명시적으로 넘길 때 쓰고, providers.py 쪽 기본값도 같은 환경변수를 본다).
GEMINI_MAX_RETRIES = int(os.environ.get("GEMINI_MAX_RETRIES", "4"))

# 동시에 실행 가능한 Gemini 호출 수 상한(세마포어). 원본 providers.py엔 RPM/TPM 같은 고정
# 한도가 코드로 박혀있지 않다(429의 retryDelay를 그때그때 따름) — 그 대신 여기서 "서버가
# 한 번에 얼마나 많은 요청을 동시에 Gemini에 밀어넣을지"를 직접 제어한다. 무료 티어
# 실측(분당 15회, 무거운 몰은 TPM 25만이 더 먼저 병목 → 실질 분당 4~5건)을 감안하면 기본값
# 3 정도가 안전하고, 유료 티어로 전환하면 이 값을 올리면 된다.
GEMINI_MAX_CONCURRENCY = int(os.environ.get("GEMINI_MAX_CONCURRENCY", "3"))

# 요청별 peak RSS 샘플링 주기 (metrics.py).
RSS_SAMPLE_INTERVAL_MS = int(os.environ.get("RSS_SAMPLE_INTERVAL_MS", "100"))

# 서버 바인드 주소/포트.
HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8000"))
