# Migrations

템플릿 구조 변경 시 기존 프로젝트에 적용할 마이그레이션 목록.
`sync_template.md` Step 4에서 이 파일(**clone된 템플릿의 사본**)을 읽고 해당하는 항목을 실행합니다.

---

## M001: `ai/` → `rd-workflow/` 디렉토리 rename

**조건**: 프로젝트 루트에 `ai/` 디렉토리가 존재하고 `rd-workflow/`가 없을 때

**실행 절차**:
1. `git mv ai rd-workflow` (git 추적 중이면) 또는 `mv ai rd-workflow` (아니면)
2. 아래 파일들에서 `ai/` 경로 참조를 `rd-workflow/`로 일괄 치환:
   - `CLAUDE.md`, `PROJECT_CONTEXT.md`, `WORKING_WITH_AI.md`
   - `.claude/settings.json` (hooks 경로)
   - `rd-workflow/` 하위 스크립트, skill, 문서 파일
3. `rd-workflow-workspace/reports/`, `rd-workflow-workspace/backlog/request-archive/`, `rd-workflow-workspace/specs/`, `rd-workflow-workspace/handoffs/`는 과거 기록이므로 치환하지 않음
4. 치환 시 URL의 `.ai/` (예: `claude.ai/code`)는 보존해야 함 — `(?<!\.)ai/` 패턴 사용
5. 스크립트 문법 검증: `find rd-workflow/scripts -name "*.sh" -exec bash -n {} \;`

**주의**: `.claude/settings.json`의 hooks에 `ai/scripts/` 경로가 있으면 반드시 `rd-workflow/scripts/`로 변경해야 세션 시작 훅이 작동합니다.

## M002: `rd-workflow/workspace/` → `rd-workflow-workspace/` 분리

**조건**: `rd-workflow/workspace/` 디렉토리가 존재하고 루트에 `rd-workflow-workspace/`가 없을 때

**실행 절차**:
1. `git mv rd-workflow/workspace rd-workflow-workspace` (git 추적 중이면) 또는 `mv rd-workflow/workspace rd-workflow-workspace`
2. 아래 파일들에서 `rd-workflow/workspace/` 경로 참조를 `rd-workflow-workspace/`로 일괄 치환:
   - `CLAUDE.md`, `PROJECT_CONTEXT.md`
   - `rd-workflow/` 하위 스크립트, skill, 문서 파일
3. `rd-workflow-workspace/reports/`, `rd-workflow-workspace/backlog/request-archive/`, `rd-workflow-workspace/specs/`, `rd-workflow-workspace/handoffs/`는 과거 기록이므로 치환하지 않음

**참고**: M001과 M002는 동시에 적용될 수 있습니다. M001을 먼저 실행한 후 M002를 실행합니다.
