# Claude Code 세션 인수인계 — 2026-09-25 (Cowork 중간점검용)

작성 시각: 2026-09-25 17:43 KST. 브랜치 `feat/ai-extraction-server`에서 작업 중, `main`은
안 건드림.

## 목적

`REPORT_2026-09-19.md`의 ECS/Fargate 소견은 전부 **로컬 개발 머신 실측을 외삽한 값**이었다
(순차 1건 peak_rss 1.4~1.9GB, 동시 요청 1건당 +400~650MB, "4GB→동시 6~7건, 6GB→동시 10건
안전선"은 실측 범위 밖 추정). 이번 세션은 실제 AWS Fargate(서울 리전, ALB/NAT/오토스케일링
없이 최소 구성)에 `parsing-engine/server`를 띄워서 이 소견을 검증하는 게 목표다.

## 사전 준비 (완료)

이 작업을 하려면 이 로컬 머신에 AWS CLI와 Docker가 전혀 없었다 — 세션 중 설치 안내부터
시작했다.

- AWS CLI v2, Docker(`docker.io` 29.1.3) 설치 완료
- AWS 계정: 학교에서 발급한 계정, `console.aws.amazon.com` 아이디/비밀번호 로그인 방식 —
  root가 아니라 **IAM 사용자 `parsing-engine-cli`**로 액세스 키 발급(root 액세스 키는
  AWS 공식 비권장이라 만들지 않음). 계정 ID `220133863621`.
- 이 계정이 **AWS Organization에 속해있어서 Free Plan → Paid Plan으로 자동 전환**된 상태
  확인됨(학교 측 메일로 통보받음) — 프리티어 크레딧은 소멸했고 지금부터는 순수 종량제.
  Fargate는 어차피 프리티어 대상이 아니라 이번 검증 자체는 원래도 실비 과금 대상이었음.

## 지금까지 만든 AWS 리소스 (전부 서울 리전 `ap-northeast-2`)

Cowork 쪽에서 비용 노출을 확인하고 싶으면 이 목록이 현재 계정에 떠 있는 전부다.

| 리소스 | 식별자 | 비고 |
|---|---|---|
| ECR 리포지토리 | `wishkit-parsing-engine` | 이미지 `latest` 태그, 약 1.09GB push 완료 |
| 보안그룹 | `sg-0488a8f0561098e02` (`wishkit-fargate-validation`) | 인바운드 TCP 8000, 이 작업 머신의 공인 IP(`182.161.224.29/32`)만 허용 |
| ECS 클러스터 | `wishkit-parsing-engine-validation` | 태스크 0개, 실행 중인 것 없음 |
| IAM 실행 역할 | `wishkitParsingEngineTaskExecutionRole` | `AmazonECSTaskExecutionRolePolicy` + SSM/KMS 인라인 정책(아래 참고) |
| CloudWatch 로그 그룹 | `/ecs/wishkit-parsing-engine` | 보존 기간 3일로 설정 |
| 태스크 정의 | `wishkit-parsing-engine-2048cpu-4096mb:1` (4GB), `wishkit-parsing-engine-2048cpu-6144mb:1` (6GB) | 둘 다 2vCPU, 등록만 돼 있고 **실행 중인 태스크는 없음** |
| IAM CLI 사용자 | `parsing-engine-cli` | `AmazonECS_FullAccess`/`AmazonEC2ContainerRegistryFullAccess`/`CloudWatchLogsFullAccess`/`AmazonEC2FullAccess`/`IAMFullAccess` 부착 — 검증 끝나면 `IAMFullAccess`는 떼는 걸 권장(상시로 들고 있기엔 과함) |

**현재 실행 중이거나 과금되고 있는 컴퓨트 리소스는 없다** — Fargate 태스크 2회 시도 모두
아래 이유로 `RUNNING`에 도달하지 못하고 50초 안에 `STOPPED`돼서 Fargate 컴퓨트 과금은
사실상 $0이다. ECR 이미지 저장(~1GB)과 빈 로그 그룹만 소액 상시 비용이다.

## 현재 막힌 지점 — SSM 파라미터 미등록

Gemini API 키를 컨테이너에 주입하는 방법으로 (환경변수 평문 대신) **SSM Parameter Store
SecureString**을 쓰기로 했다 — `secrets` 필드로 주입하는 게 `aws-containers` 스킬의
권장 방식이고, API 키가 내 대화 맥락에 노출되는 걸 막을 수 있는 방법이기도 했다(Claude
Code의 credential-leakage 방지 정책이 `.env`에서 값을 직접 읽어 셸 변수에 담는 걸
막아서, 대신 사용자가 로컬에서 직접 SSM에 등록하는 방식으로 우회함).

**사용자에게 아래 명령을 두 번 요청했지만 아직 실행이 안 된 상태로 보인다** — 태스크를
2번 돌려봤는데 둘 다 똑같은 이유로 실패했다:

```
ResourceInitializationError: unable to pull secrets or registry auth: execution resource
retrieval failed: unable to retrieve secrets from ssm: service call has been retried 1
time(s): invalid ssm parameters: /wishkit/parsing-engine/gemini-api-key
```

필요한 명령(사용자가 본인 터미널에서 직접 실행해야 함 — API 키가 로컬 `.env`에만 있고
Claude Code 세션에는 노출 안 시키는 게 목적이라 내가 대신 실행할 수 없음):

```bash
aws ssm put-parameter \
  --name /wishkit/parsing-engine/gemini-api-key \
  --type SecureString \
  --value "$(grep '^GEMINI_API_KEY=' wishlist-appversion2/parsing-engine/server/.env | cut -d= -f2-)" \
  --region ap-northeast-2 \
  --overwrite
```

실행 역할(`wishkitParsingEngineTaskExecutionRole`)에는 이 파라미터 경로(`/wishkit/parsing-engine/*`)에 대한 `ssm:GetParameters` + 해당 KMS 키(`alias/aws/ssm`) `kms:Decrypt` 권한을
이미 인라인 정책으로 붙여놨다 — 파라미터만 등록되면 바로 될 것으로 예상.

## 컨테이너화 — 완료, 로컬 검증 통과 (캐비어트 있음)

- `wishlist-appversion2/parsing-engine/server/Dockerfile` 작성: 베이스 이미지
  `mcr.microsoft.com/playwright/python:v1.63.0-noble` — `requirements.txt`가 설치하는
  playwright 패키지 버전(1.63.0)과 정확히 맞춘 태그. **이 파일은 아직 커밋 안 함**(브랜치에
  Dockerfile/.dockerignore만 추가하는 커밋을 이어서 할 예정, 이번 문서화 작업과 분리해서
  진행할지 사용자 확인 필요).
- `.dockerignore` 추가 — `venv/`, `.env`, 캐시 디렉터리 제외(특히 `.env`가 이미지 레이어에
  절대 안 들어가게 하는 게 중요했음).
- 로컬 `docker build` 성공, `docker run --env-file .env`로 기동 → `GET /healthz` 즉시
  200(`browser_connected:true`), `POST /extract` 1건 성공(무신사 URL).
  - **캐비어트**: 이 `/extract` 테스트 도중 Gemini API(`gemini-3.5-flash-lite`)가 계속
    `503 UNAVAILABLE — high demand` 를 반환했다(우리 코드/컨테이너 문제 아님, Google 쪽
    일시적 과부하로 판단). 여러 번 재시도 끝에 성공한 호출도 `gemini_text_elapsed_ms=41758`
    로, 9/19 기준선 평균(2.8초)보다 훨씬 느렸다. **사용자 확인 후 "이 상태로 계속 진행"
    결정함** — 앞으로 나올 Fargate 응답시간 실측치는 이 Gemini 혼잡 캐비어트를 감안해서
    읽어야 하고, `peak_rss_mb`나 "동시 몇 건까지 성공하는지" 같은 인프라 지표는 상대적으로
    이 캐비어트의 영향이 적을 것으로 예상.

## ECR push — 두 번 실패 후 성공

- 1차 시도: 40분 넘게 걸리다 실제로는 대부분 레이어가 이미 올라간 상태에서 `connection
  reset by peer`로 중단.
- 2차 시도: 재시도 도중 `403 Forbidden` — ECR 인증 토큰 문제로 판단, `docker login`
  재인증.
- 3차 시도: 성공. `220133863621.dkr.ecr.ap-northeast-2.amazonaws.com/wishkit-parsing-engine:latest`, digest `sha256:6dc9d0b600e5...`, 2026-09-25 17:35 KST push 완료.

## 태스크 정의 — 등록 완료, 아직 실행 검증 안 됨

두 태스크 정의(`wishkit-parsing-engine-2048cpu-4096mb`, `wishkit-parsing-engine-2048cpu-6144mb`)
모두 `aws ecs register-task-definition`으로 문제없이 등록됐다. 컨테이너 정의는
`GEMINI_MODEL`은 평문 환경변수, `GEMINI_API_KEY`는 위 SSM `secrets` 참조로 구성.
awsvpc 네트워크 모드 + `subnet-04d099a9630800b16`(기본 VPC ap-northeast-2a, 퍼블릭
서브넷, IGW 라우트 확인함) + 위 보안그룹으로 `assignPublicIp=ENABLED` 실행 설정까지
준비 끝났고, **SSM 파라미터만 등록되면 바로 재시도 가능**한 상태.

## 다음 단계 (SSM 파라미터 등록 확인되는 대로)

1. 4GB 태스크 실행 → `RUNNING` 확인 → 퍼블릭 IP로 `GET /healthz`
2. `tools/golden_regression_check.py --server http://<퍼블릭IP>:8000 --golden-catalog engine-ai-prototype/golden_catalog.json` 로 회귀 확인
3. `tools/concurrency_load_test.py --server http://<퍼블릭IP>:8000 --concurrency 1 3 6 10` 로 동시성 실측
4. 태스크 stop → 6GB로 반복
5. 로컬(9/19) vs Fargate(이번) 비교표 작성, `parsing-engine/REPORT_FARGATE_VALIDATION_2026-09-24.md`(요청받은 파일명 그대로 사용, 실제 작성일은 25일이지만 내용에 명시)로 정리
6. **작업 종료 시 반드시**: 실행 중인 태스크 전부 stop, `aws ecs list-tasks`/`list-services`로 과금 리소스 없는지 재확인, IAM 사용자에서 `IAMFullAccess` 제거 권장

## 하지 않은 것 (지침대로)

- `main`, Firebase Auth/Firestore/Storage/Messaging 관련 코드는 손대지 않음
- ALB, 오토스케일링, NAT 게이트웨이, RDS/DynamoDB — 생성 안 함
- pytest/ruff는 이번 세션에서 서버 코드를 변경하지 않아서 별도로 다시 돌리지 않음(직전 커밋 `e9cea24`에서 통과 확인된 상태 그대로)
