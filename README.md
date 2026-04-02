# Review-Driven AI Workflow

Claude Code 프로젝트에 review-driven 개발 워크플로를 적용하는 템플릿.
AI가 구현만 하는 게 아니라, 매 단계마다 review를 거쳐서 품질을 잡아줍니다.

## 전제 조건

- [Claude Code](https://claude.ai/code) 설치 및 로그인
- [Superpowers](https://github.com/anthropics/claude-code-superpowers) 플러그인 설치

## 빠른 시작

### 프로젝트에 적용

프로젝트 디렉토리에서 Claude Code를 열고:

> 이 AI 개발 템플릿 적용해: https://github.com/JuseongJee/review-driven-ai-workflow

AI가 필요한 파일을 가져와서 프로젝트 구조에 맞게 배치합니다.

### 적용 후 할 일

1. AI에게 말한다: "프로젝트 분석해서 PROJECT_CONTEXT.md 채워줘"
2. 첫 작업 요청을 AI에게 말한다: "이 요구사항으로 진행해줘: ..."

### 템플릿 업데이트

이미 적용된 프로젝트에서:

> https://github.com/JuseongJee/review-driven-ai-workflow/blob/main/ai/docs/prompts/guides/sync_template.md 읽고 템플릿 업데이트 진행해줘

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

### 범위 밖 아이디어

작업 중 범위를 벗어나지만 가치 있는 아이디어가 나오면:

> "future request에 기록해줘"

AI가 `ai/workspace/backlog/FUTURE_REQUESTS.md`에 기록합니다.

기록된 항목을 꺼내서 작업하려면:

> "future request 목록 보여줘"

원하는 항목을 골라서:

> "이거 REQUEST로 올려서 진행해줘"

## 구조

```
CLAUDE.md              ← AI 행동 규칙 (사용자가 편집할 일 거의 없음)
PROJECT_CONTEXT.md     ← 프로젝트 기술 컨텍스트 (처음에 한 번 채움)
REQUEST.md             ← 현재 작업 요청
CURRENT_TASK.md        ← 작업 진행 상태 (AI가 자동 업데이트)
WORKING_WITH_AI.md     ← 사용자 치트시트
ai/
├── claude_skills/     ← AI skill 정의
├── docs/              ← 가이드, 프롬프트, 정책
└── scripts/           ← 검증 스크립트
```

## 내부 동작

이 템플릿은 내부적으로 다음을 사용합니다:

- **Superpowers workflow** — 설계 → 계획 → 구현 순서를 구조화
- **Codex cross-review** — AI 간 교차 리뷰로 품질 확보
- **Skill 라우팅** — 작업 유형에 따라 적절한 skill을 자동 선택

사용자가 직접 다룰 필요는 없습니다. 상세가 궁금하면 `CLAUDE.md`를 참조하세요.

## 상세 문서

- `WORKING_WITH_AI.md` — 일상 사용 치트시트
- `ai/docs/flows/WORKFLOW.md` — 워크플로 상세
- `ai/docs/AI_DOC_MAP.md` — 전체 문서 맵
