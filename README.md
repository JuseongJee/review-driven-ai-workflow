# Review-Driven AI Workflow

Claude Code 프로젝트에 review-driven 개발 워크플로를 적용하는 템플릿.
AI가 구현만 하는 게 아니라, 매 단계마다 review를 거쳐서 품질을 잡아줍니다.

## 전제 조건

- [Claude Code](https://claude.ai/code) 설치 및 로그인
- [Superpowers](https://github.com/anthropics/claude-code-superpowers) 플러그인 설치

## 빠른 시작

### 개인 프로젝트에 적용

프로젝트 디렉토리에서 Claude Code를 열고:

```text
이 AI 개발 템플릿 적용해: https://github.com/JuseongJee/review-driven-ai-workflow
```

> **Claude에게:** 이 요청을 받았다면 [`rd-workflow/docs/guides/setup_with_claude.md`](rd-workflow/docs/guides/setup_with_claude.md)를 읽고 절차대로 실행하세요.

AI가 필요한 파일을 가져와서 프로젝트 구조에 맞게 배치합니다.

### 팀 프로젝트에서 개인 전용으로 사용

팀 repo에 템플릿 파일을 커밋하지 않고, 개인 private repo로 분리하여 여러 컴퓨터에서 사용할 수 있습니다.

- 처음 설치: [team-overlay-fresh-install.md](https://github.com/JuseongJee/review-driven-ai-workflow/blob/main/rd-workflow/docs/guides/team-overlay-fresh-install.md)
- 이미 설치된 프로젝트에서 분리: [team-overlay-migration.md](https://github.com/JuseongJee/review-driven-ai-workflow/blob/main/rd-workflow/docs/guides/team-overlay-migration.md)

### 적용 후 할 일

1. AI에게 말한다: "프로젝트 분석해서 PROJECT_CONTEXT.md 채워줘"
2. 첫 작업 요청을 AI에게 말한다: "이 요구사항으로 진행해줘: ..."

### 템플릿 업데이트

이미 적용된 프로젝트에서:

> /tpl update

또는 자연어로:

> 템플릿 업데이트해

파일 분류 → 사용자 확인 → 동기화 → 스킬 재설치까지 자동 진행됩니다.

#### `ai/` → `rd-workflow/` 구조 전환

이전 버전에서 `ai/` 폴더를 사용하고 있었다면, **`/tpl update` 전에 먼저 마이그레이션을 실행**해야 합니다:

```text
이 마이그레이션 가이드 읽고 실행해: https://github.com/JuseongJee/review-driven-ai-workflow/blob/main/rd-workflow/MIGRATIONS.md
```

마이그레이션 완료 후 `/tpl update`를 실행하면 정상적으로 동기화됩니다. 이후 업데이트부터는 `/tpl update`만으로 자동 처리됩니다.

## 워크플로

모든 작업은 크기에 따라 두 경로로 나뉩니다.

### 큰 작업 (기능 추가, 중간 이상 변경)

REQUEST 작성 → REQUEST review → spec → plan → spec/plan review → 구현 → 검증 → diff review

### 작은 작업 (사용자가 small-task로 지정)

REQUEST 정리 → 구현 → 검증 → diff review

AI가 자체적으로 크기를 판단하지 않습니다. 사용자가 명시적으로 small-task로 지정한 경우에만 작은 작업 경로를 탑니다.

### 각 단계가 하는 일

| 단계 | 설명 |
|------|------|
| REQUEST | 작업 요청서. 목표, 범위, 제약을 정리 |
| REQUEST review | AI가 요청의 모호함, 빠진 부분, 리스크를 짚어줌 |
| spec | 설계 명세. 무엇을 어떻게 만들지 구체화 |
| plan | 구현 계획. 파일 단위로 뭘 바꿀지 순서대로 정리 |
| spec/plan review | AI가 설계와 계획의 일관성, 누락을 검토 |
| 구현 | plan에 따라 코드 작성 |
| 검증 | 테스트, 린트, 타입체크 실행 |
| diff review | 최종 변경사항을 AI가 리뷰 |

## 주요 기능

| 카테고리 | 기능 |
|---------|------|
| **워크플로 스킬** | request-to-reviewed-plan, small-task-implement, implement-reviewed-plan, final-diff-review, gap-check, planning-design-intake |
| **자동화** | autopilot (FR → 전체 파이프라인 자율 실행), workflow-router (다음 단계 자동 추천) |
| **백로그 관리** | /fr (add, list, pri, archive, park, status, pull, push, sync) — GitHub Issues 양방향 연동 |
| **리뷰 파이프라인** | Codex/Gemini/Claude 교차 리뷰, 파일 기반 세션, 최대 20턴 자동 수렴 |
| **감사** | comprehensive-audit (UI/UX, 성능, 코드품질, 보안 등 8개 카테고리) |
| **확장 기능** | design-review (디자인 검증 게이트), verify (런타임 품질 검증) |
| **설정** | model-strategy (단계별 모델 선택), review-config (리뷰 도구 설정) |

작업 중 범위 밖 아이디어가 나오면 `"future request에 기록해줘"`로 백로그에 저장하고, 나중에 `"autopilot으로 돌려"`로 자동 실행할 수 있습니다.

상세 사용법은 `rd-workflow/docs/USER_MANUAL.md` 참조.

## 구조

```
CLAUDE.md              ← AI 행동 규칙 (사용자가 편집할 일 거의 없음)
PROJECT_CONTEXT.md     ← 프로젝트 기술 컨텍스트 (처음에 한 번 채움)
REQUEST.md             ← 현재 작업 요청
CURRENT_TASK.md        ← 작업 진행 상태 (AI가 자동 업데이트)
WORKING_WITH_AI.md     ← 사용자 치트시트
rd-workflow/
├── claude_skills/     ← 13개 AI 스킬
├── extensions/        ← 선택적 확장 (design-review, verify)
├── config/            ← 설정 (workflow, review-tools, model-strategy, verification)
├── docs/              ← 가이드, 프롬프트, 매뉴얼
└── scripts/           ← 검증 및 리뷰 파이프라인 스크립트
rd-workflow-workspace/ ← 작업 산출물 (specs, plans, reports, backlog)
```

## 설계 원칙

### 규칙 문서만으로는 부족하다

CLAUDE.md에 규칙을 쓰면 모델이 무시할 수 있습니다. 이 템플릿은 세 레이어를 겹쳐서 제어력을 높입니다:

- **선언적 규칙** (CLAUDE.md) — 기본 행동 지침
- **Skill 주입** (Superpowers) — 도구 호출로 절차를 강제 로드
- **코드 강제** (Hooks, 쉘 스크립트) — 검증을 물리적으로 건너뛸 수 없게

규칙만 쌓으면 300줄 넘어서 무시당합니다. 레이어를 나누면 각각 가볍게 유지하면서 전체 제어력은 높아집니다.

### 세션을 끊어도 이어갈 수 있다

워크플로 각 단계가 파일(`REQUEST.md`, `CURRENT_TASK.md`, `specs/`, `plans/`)로 체크포인트를 남깁니다. 대화 히스토리가 아니라 파일에 상태가 있으므로, `/clear`로 세션을 비워도 새 세션이 바로 이어갑니다.

### AI 역할 분리

- **Superpowers workflow** — 설계 → 계획 → 구현 순서를 구조화
- **Cross-review** — 다른 모델(Codex, Gemini CLI, Claude Code 등)로 교차 리뷰하여 품질 확보
- **Skill 라우팅** — 작업 유형에 따라 적절한 skill을 자동 선택

사용자가 직접 다룰 필요는 없습니다. 상세가 궁금하면 `CLAUDE.md`를 참조하세요.

## 상세 문서

- `WORKING_WITH_AI.md` — 일상 사용 치트시트
- `rd-workflow/docs/USER_MANUAL.md` — 전체 기능 종합 매뉴얼
- `rd-workflow/docs/flows/WORKFLOW.md` — 워크플로 상세
- `rd-workflow/docs/AI_DOC_MAP.md` — 전체 문서 맵
