# parsing-engine — AI 완전 의존 상품 추출 서버

`ENGINE_DEVELOPMENT_HANDOFF.md` 0.9절에서 삭제됐던 `parsing-engine/` 폴더를 다른 방향으로
되살린 것이다 — 이전 버전(DOM 규칙 기반 Python 폴백)과는 무관하다. 이번 버전은 **몰별 규칙이
전혀 없고, 상품 페이지를 렌더링해서 AI(Gemini)에게 통째로 읽혀 이름/가격/이미지를 뽑는다.**

## 배경 — 반드시 먼저 읽을 것

이 폴더가 만들어진 시점(2026-09-19)에 `main` 브랜치의 `ENGINE_DEVELOPMENT_HANDOFF.md`는
여전히 "Python 서버 폴백은 채택하지 않음, WebView 우선"이라고 적혀 있었다(마지막 갱신
2026-08-21). 이 서버는 그 결정을 뒤집는 **2026-09-18 새 결정**("서버 AI 완전 의존" —
`engine-ai-prototype/design-doc-snapshot-2026-09-18.md` 0절)에 따라 만들어졌다. 두 문서가
당분간 서로 다른 이야기를 할 수 있으니, 이 폴더를 보고 헷갈리면 그 두 문서(및
`ENGINE_DEVELOPMENT_HANDOFF.md`에 새로 추가된 노트)를 먼저 대조해볼 것.

## 이 폴더와 `engine-ai-prototype`의 관계

`engine-ai-prototype/`(이 저장소 밖, 별도 폴더)은 이 파이프라인의 **원본 프로토타입**이다 —
로컬 배치 스크립트(`bakeoff.py`)로 골든셋 36개 상품에 대해 정확도만 검증했다(완전 일치
21/36=58%, 그라운딩 통과 31/36=86% — `bakeoff_results_run6_final.json`). 이 폴더
(`server/`)는 그 검증된 로직(`render.py`/`prompts.py`/`providers.py`/`compare.py`)을 실제
HTTP 요청에 응답하는 서버로 감싼 것 — 로직 자체(프롬프트 문구, few-shot, 가격 정책,
그라운딩 체크)는 바뀐 게 없고, 브라우저 생명주기만 "요청마다 새로 띄움"에서 "앱 시작 시
한 번 띄워서 재사용"으로 바뀌었다(자세한 이유는 `server/render.py` 상단 주석 참고).

engine-ai-prototype 폴더 자체는 건드리지 않았다 — 참고용 기준선(golden_catalog.json,
bakeoff_results_run6_final.json)은 그 폴더에 그대로 남아있고, `tools/
golden_regression_check.py`가 그걸 읽어서 이 서버의 회귀 여부를 확인한다.

## 구성

```
server/
  main.py       — FastAPI 앱, POST /extract, GET /healthz, 브라우저 생명주기(lifespan)
  render.py     — Playwright 렌더링(async, 브라우저 재사용). 로직은 engine-ai-prototype과 동일
  providers.py  — Gemini 호출/재시도/스크린샷 폴백. engine-ai-prototype과 동일 + 재시도
                  횟수만 환경변수로 뺌
  prompts.py    — 시스템 프롬프트/few-shot/JSON 스키마. engine-ai-prototype과 완전히 동일
                  (문구를 바꾸지 않았음)
  compare.py    — 그라운딩 체크(응답에 포함) + 골든셋 비교(회귀 테스트용)
  cache.py      — RenderCache Protocol + 캐시 키 정규화 (실제 구현은 아직 없음, NoOpCache만)
  metrics.py    — 요청별 elapsed_ms/peak_rss_mb 측정
  config.py     — 전부 환경변수로 오버라이드 가능한 설정값
tools/
  golden_regression_check.py — 로컬 서버에 골든셋 36개를 던져서 run6 기준선과 비교
```

## 실행

```bash
cd server
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
playwright install chrome   # 또는 이미 설치된 크롬을 쓰려면 생략(폴백 있음)
cp .env.example .env        # GEMINI_API_KEY 채우기
uvicorn main:app --host 0.0.0.0 --port 8000
```

```bash
# 다른 터미널에서 회귀 테스트
cd ../tools
python golden_regression_check.py \
  --golden-catalog ../../../../engine-ai-prototype/golden_catalog.json \
  --baseline ../../../../engine-ai-prototype/bakeoff_results_run6_final.json
```

(`--golden-catalog`/`--baseline` 경로는 이 저장소를 어디에 클론했는지에 따라 달라진다 —
engine-ai-prototype 폴더의 실제 위치로 맞춰서 넘길 것.)

## 하지 않은 것 (의도적으로 범위 밖에 둠)

- AWS 리소스 생성/배포, 실제 캐시 백엔드 구현, DB 연동, Flutter 앱 쪽 통합 — 전부 이 작업의
  범위가 아니다(보고서의 "다음에 결정이 필요한 것" 참고).
- 몰별 규칙 기반 폴백 — 이번 방향(AI 완전 대체)과 어긋나서 추가하지 않았다.
