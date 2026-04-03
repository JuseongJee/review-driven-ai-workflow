# AI Doc Map

## 루트 문서

`CLAUDE.md`
- 작업 원칙과 기본 행동 규칙

`PROJECT_CONTEXT.md`
- 프로젝트 이해, 제약, 실행 명령

`REQUEST.md`
- 이번 작업의 정리된 요구사항

`CURRENT_TASK.md`
- 현재 작업 상태

`WORKING_WITH_AI.md`
- 평상시 작업 순서

`ai/workspace/handoffs/review_pipeline/`
- Author <-> Reviewer review 세션 파일

## 진입점

- 저장소 도입과 초기 설정은 템플릿 저장소의 `README.md`를 봅니다
- 프로젝트에 복사된 뒤 평소 보는 문서는 `WORKING_WITH_AI.md`입니다

## ai/docs

`prompts/`
- 사용자용 프롬프트 도구 상자
- 어떤 폴더를 열지 고를 때는 `prompts/README.md`

`review_prompts/`
- review 세션에 그대로 붙여 넣는 검토 기준

`backlog/FUTURE_REQUESTS.md`
- 지금 작업에서 빼고 나중에 처리할 후보

`backlog/request-archive/`
- 완료된 REQUEST.md 보관소 (과거 작업 이력 추적용)

`flows/WORKFLOW.md`
- 작업 분기와 권장 순서 요약

`flows/FILE_BASED_REVIEW_PIPELINE.md`
- review 세션을 만들고 이어가는 규칙

`flows/CLAUDE_ORCHESTRATED_REVIEW_DESIGN.md` _(선택 — 배경 설명, 평소 읽지 않음)_
- review 구조를 왜 이렇게 만들었는지 설명

`templates/`
- PR 템플릿 등 재사용 포맷

`policies/AGENTS.md`
- Git 워크플로 규칙과 핸드오프 규칙

`library/` _(선택 — 필요할 때만 참조)_
- 특정 분석이나 별도 검토를 시킬 때 쓰는 가이드 모음 (외부 AI 핸드오프 가이드 포함)

`adr/`
- 운영 규칙과 구조 결정을 남긴 기록

`superpowers/specs/base/`
- 새 기능 spec 저장 위치

`superpowers/specs/changes/`
- 기존 코드 변경 change spec 저장 위치

`superpowers/plans/`
- plan 저장 위치

## ai/scripts/ai

`build.sh`
- build 실행

`test.sh`
- test 실행

`lint.sh`
- lint 실행

`typecheck.sh`
- typecheck 실행

`prepare_review_pipeline.sh`
- review 세션 생성

`init_review_pipeline.sh`
- review 세션 수동 생성

`run_review_turn.sh`
- review 한 턴 실행

`review_common.sh`
- 리뷰 파이프라인 공통 함수

`adapter_codex.sh`
- Codex 어댑터

`adapter_claude.sh`
- Claude CLI 셀프 리뷰 어댑터

`install_claude_skills.sh`
- project/personal skill 설치
