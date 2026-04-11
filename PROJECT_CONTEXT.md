# Project Context

> **이 파일은 템플릿입니다.** 아래 각 섹션을 프로젝트에 맞게 채우세요. 예시 텍스트는 지우고 실제 내용으로 교체합니다.

## Project Type
Web / macOS / iOS / backend / library / script

## Product Summary
이 프로젝트가 무엇인지 1~3문장

## Main User Flows
- 

## Tech Stack
예: React / Next.js / SwiftUI / Node.js

## Build
실제 build 명령

## Test
실제 test 명령

## Lint
실제 lint 명령

## Typecheck
실제 typecheck 명령

## Template Source
- template_repo: (배포 repo URL, 예: https://github.com/user/repo)

## Workflow & Intake Settings
`ai/config/workflow.json` 참조. 기본값은 `ai/config/workflow.json.example`.

## Verification Scope
- pre-commit: lint, format (무거운 테스트 금지)
- local: unit test, lint, typecheck
- CI: full test, integration, E2E
- 상세 가이드: `ai/docs/guides/verification-scope-guide.md`

## Architecture Rules
- 기존 패턴을 우선 따른다
- 과도한 abstraction을 피한다
- 테스트 가능한 구조를 유지한다

## Code Style
- 기존 코드 스타일 우선
- 가독성 우선
- 불필요한 helper / wrapper 금지
- 현재 작업 범위를 넘는 구조 변경 금지

## Platform Notes
### Web
-

### macOS
-

### iOS
-

### Backend
-

## Avoid
- premature optimization
- unrelated refactor
- 근거 없는 대규모 구조 변경
- 임시 코드 방치

---

파일만으로 확정 가능한 내용은 먼저 채우고, 모르는 것만 질문합니다.
