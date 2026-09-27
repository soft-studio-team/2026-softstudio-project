# Claude Code 세션 인수인계 — 2026-09-27 (Cowork 중간점검용, Fargate 검증 완료)

작성 시각: 2026-09-27 17:39 KST. 브랜치 `feat/ai-extraction-server`, `main`은 안 건드림.
`COWORK_HANDOFF_2026-09-25.md`(같은 작업의 이전 중간 상태 — SSM 파라미터 등록 전, 아직
막혀있던 시점)를 잇는 문서. 그 사이 있었던 일과 최종 결과를 정리한다.

## 요약

`REPORT_2026-09-19.md`의 ECS/Fargate 소견(로컬 실측 외삽)을 실제 AWS Fargate(서울
리전, 최소 구성)에서 재검증하는 작업을 **완료**했다. 결과는
`wishlist-appversion2/parsing-engine/REPORT_FARGATE_VALIDATION_2026-09-24.md`에 전부
정리했고, 이 문서는 그 과정에서 있었던 사고·의사결정과 **아직 커밋 안 된 파일**을
Cowork가 확인할 수 있게 정리한 것이다.

## ⚠️ 먼저 알아야 할 것 — 비용 사고 (46시간 방치)

`COWORK_HANDOFF_2026-09-25.md` 작성 이후 세션이 한 번 끊겼고, 재개된 시점(2026-09-27)에
확인해보니 **4GB 타겟 Fargate 태스크가 그 사이 약 46시간 동안 `RUNNING` 상태로 방치돼
있었다**(2026-09-25 18:52 시작 → 2026-09-27 17:06 발견 즉시 stop). 서울 리전 Fargate
온디맨드 요금(2vCPU+4GB 기준 어림)으로 **미화 4~5달러 내외로 추정**되나, 이건 어림
계산이고 **정확한 금액은 AWS Billing 콘솔/Cost Explorer에서 직접 확인이 필요**하다.

재발 방지를 위해 이후로는 태스크를 실행할 때마다 결과를 받는 즉시 stop하는 식으로
진행했다(4GB 골든/동시성 각각 실행 직후 stop, 6GB도 동일) — 이번 문서 작성 시점 기준
`aws ecs list-tasks`/`list-services`/EC2 인스턴스/NAT 게이트웨이 전부 0개 확인됨.

## 이번에 새로 한 일

1. **로컬 네트워크 문제 발견 및 우회**: 이 작업 머신(학교 네트워크로 추정)이 포트가
   아니라 목적지 IP/도메인 허용목록 방식으로 아웃바운드를 막고 있어서, Fargate 태스크의
   퍼블릭 IP에 (포트 8000이든 443/TLS든) 전혀 접근이 안 됐다. AWS API(`aws` CLI)나
   `docker pull`, `git push` 같은 잘 알려진 도메인 대상 트래픽은 문제없이 통과했다는 점에서
   포트 차단이 아니라 IP/도메인 기준 필터링으로 결론지었다.
   - 우회: 같은 VPC 안에 경량 "테스트 러너" Fargate 태스크(`wishkit-test-runner`,
     `python:3.13-slim` + `httpx`, 512cpu/1024mem)를 별도로 만들어서, 타겟 태스크의
     **프라이빗 IP**로 골든 리그레션/동시성 스크립트를 실행하고 결과는 CloudWatch
     Logs로 받았다. 새 ECR 태그(`wishkit-parsing-engine:test-runner`)와 로그 그룹
     (`/ecs/wishkit-test-runner`, 보존 3일)이 이 과정에서 추가됨.
2. **SSM 파라미터 등록 확인** — 사용자가 `/wishkit/parsing-engine/gemini-api-key`를
   SSM SecureString으로 등록 완료(권한 문제도 `AmazonSSMFullAccess`로 해결).
3. **4GB/6GB 태스크 둘 다 실제 실행 + 골든 리그레션(36개) + 동시성(1/3/6/10건) 실측 완료**
   — 상세 수치와 해석은 `REPORT_FARGATE_VALIDATION_2026-09-24.md` 참고. 핵심만 요약:
   - 9/19의 "4GB→동시 6~7건 안전" 소견은 **검증됨**(6건 100% 성공).
   - 9/19의 "6GB→동시 10건 안전" 소견은 **기각**(6GB도 10건에서 7/10만 성공, 실패
     원인은 메모리 부족이 아니라 `RENDER_MAX_CONCURRENCY=6` 세마포어+45초 타임아웃).
   - 반대로 메모리 실측치 자체는 로컬 추정보다 낮게 나와서(동시 6건 기준 로컬 4.3GB vs
     Fargate 2.2~2.6GB), 그 부분은 9/19 소견이 오히려 보수적이었다.
   - 골든 리그레션 정확도(4GB 13/36, 6GB 14/36)는 9/19 로컬 기준선(23/36)보다 낮지만,
     원인 대부분이 이미 알려진 몰별 이슈(카테고리 A 가격 정책 불일치, 에이블리 차단 등)
     — 새로 발견된 건 **KREAM 3건 전부 실패**뿐, 서버 포팅 자체의 회귀는 아님.
4. **최종 정리 완료**: 모든 Fargate 태스크 stop 확인, `parsing-engine-cli` IAM
   사용자에서 `IAMFullAccess`·`AmazonSSMFullAccess` 제거(검증 작업 끝났으니 상시 보유할
   이유 없음 — 남은 정책은 `AmazonECS_FullAccess`/`AmazonEC2ContainerRegistryFullAccess`/
   `CloudWatchLogsFullAccess`/`AmazonEC2FullAccess`).

## 아직 커밋 안 된 파일 (Cowork 확인 후 진행 예정)

브랜치 `feat/ai-extraction-server` 워킹 디렉터리에 아래 4개가 untracked 상태:

- `wishlist-appversion2/parsing-engine/server/Dockerfile`
- `wishlist-appversion2/parsing-engine/server/.dockerignore`
- `wishlist-appversion2/parsing-engine/REPORT_FARGATE_VALIDATION_2026-09-24.md`
- `wishlist-appversion2/COWORK_HANDOFF_2026-09-25.md` (이 문서 이전 버전)

이번 문서(`COWORK_HANDOFF_2026-09-27.md`)까지 포함해서 커밋·push할지 사용자 확인 대기
중 — PR #56이 이미 이 브랜치로 열려 있어서(Draft), 커밋하면 그 PR에 자동으로 반영된다.

## 남아있는 결정 사항 (REPORT_FARGATE_VALIDATION_2026-09-24.md §5와 동일)

- Gemini 유료 Tier RPM/TPM 정확한 값 (사용자 계정 콘솔 확인 필요, AI가 대신 못 함)
- 7~9건 사이 정확한 동시성 손익분기점 (이번엔 1/3/6/10만 찍음)
- ALB/오토스케일링 포함한 실제 서비스 형태의 수평 확장 검증
- DB/캐시 백엔드 선정
- 위 46시간 방치 건의 정확한 청구 금액 확인 (Cowork/사용자가 Billing 콘솔에서)

## 다음 대화 시작 프롬프트 (Cowork 중간점검용)

```text
2026-softstudio-project의 feat/ai-extraction-server 브랜치, AWS Fargate 실측 검증 건
중간점검 부탁해.

먼저 읽을 것:
1. wishlist-appversion2/COWORK_HANDOFF_2026-09-27.md — 이번 검증 전체 요약, 특히
   "먼저 알아야 할 것 — 비용 사고(46시간 방치)" 항목부터.
2. wishlist-appversion2/parsing-engine/REPORT_FARGATE_VALIDATION_2026-09-24.md —
   실측 결과 전체(골든 리그레션, 동시성 테스트, 9/19 로컬 기준선과의 비교, 실무 권장사항).

확인/결정 필요한 것:
- 46시간 방치로 발생한 비용 — 실제 Billing 콘솔 금액 확인, 문제 없는 수준인지 판단.
- 브랜치에 미커밋 상태인 4개 파일(Dockerfile, .dockerignore, 두 보고서) 커밋·push 여부 —
  push하면 이미 열려있는 Draft PR #56에 자동 반영됨.
- REPORT_FARGATE_VALIDATION_2026-09-24.md §5에 남은 결정 사항(Gemini 유료 Tier 한도,
  수평 확장 검증, DB/캐시 백엔드 선정) 우선순위 정리.

하지 말 것:
- main 브랜치, Firebase Auth/Firestore/Storage/Messaging 관련 코드는 손대지 말 것.
- AWS 리소스는 이미 전부 정리됨(태스크 stop, IAMFullAccess/AmazonSSMFullAccess 제거
  확인됨) — 추가로 새 AWS 리소스를 만들 필요는 없음, 확인만 하면 됨.
```
