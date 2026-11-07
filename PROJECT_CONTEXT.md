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

## Run
<!-- 앱을 로컬에서 띄우는 방법. 에이전트가 시제품 확인·런타임 검증에 씁니다.
     적을 것: 실행 명령, 필요한 런타임·컨테이너, 필요한 환경 변수 이름과 발급처, 띄운 뒤 접속 주소.
     비밀 값(토큰·비밀번호)은 적지 않습니다. 변수 이름과 발급처만 적습니다.
     앱이 없는 프로젝트(라이브러리·스크립트)는 "해당 없음" 한 줄을 적습니다. -->
-

## Feature Entry Paths
<!-- 기능별로 어디서 들어가 확인하는지. 한 줄에 기능 하나: `기능 — URL·entry ID·명령 — 테스트 계정 이름`.
     계정의 비밀번호는 적지 않습니다. -->
-

## Template Source
- template_repo: (배포 repo URL, 예: https://github.com/user/repo)

## Workflow & Intake Settings
`rd-workflow/config/workflow.json` 참조. 기본값은 `rd-workflow/config/workflow.json.example`.

## Verification Scope
- pre-commit: lint, format (무거운 테스트 금지)
- local: unit test, lint, typecheck, build
- CI: full test, integration, E2E
- 상세 가이드: `rd-workflow/docs/guides/verification-scope-guide.md`

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
