# Claude-Orchestrated Review Design

이 문서는 파일 기반 review pipeline을 왜 이렇게 설계했는지 짧게 설명하는 배경 문서입니다.

실제 세션을 만들고 돌릴 때는 `FILE_BASED_REVIEW_PIPELINE.md`를 읽습니다.

## 목표

- 사용자가 Claude와 Codex 사이를 수동으로 중계하지 않게 만듭니다
- review 기록을 파일로 남깁니다
- 특정 CLI 도구에 포맷이 묶이지 않게 만듭니다

## 핵심 설계

- 표준은 항상 `ai/workspace/handoffs/review_pipeline/` 세션 구조입니다
- Claude는 오케스트레이터입니다
- Codex CLI는 교체 가능한 adapter입니다
- 상태 전이는 `SESSION.md`가 단일 기준입니다
- 사람 개입은 `awaiting-user`에서만 요구합니다

## 왜 이렇게 했는가

- 대화 로그보다 review 기록 파일이 나중에 다시 읽기 쉽습니다
- 중간에 멈췄다가 같은 세션을 다시 열기 쉽습니다
- 합의된 쟁점을 다시 꺼내기 어렵습니다
- Codex 외 다른 도구 adapter를 같은 구조에 붙이기 쉽습니다

## 구성 요소

- 세션 파일: `SESSION.md`, `CHECKPOINT.md`, `USER_ACTION.md`, `turns/*.md`
- 준비 스크립트: `prepare_review_pipeline.sh`, `init_review_pipeline.sh`
- 실행 adapter: `run_review_turn.sh`, `run_review_turn_codex.sh`

## 운영 감각

1. 사용자는 검토 시작만 요청한다
2. Claude가 자기 턴을 직접 쓴다
3. Codex 차례가 되면 Claude가 adapter를 실행한다
4. 수렴하거나 사람 결정이 필요할 때만 `awaiting-user`로 바꾸고 사용자에게 돌립니다

## 자세한 규칙

- 상태 값
- 턴 제한
- 종료 규칙
- 수동 fallback

실제 상태 값, 턴 제한, 종료 규칙은 `FILE_BASED_REVIEW_PIPELINE.md`에 적혀 있습니다.
