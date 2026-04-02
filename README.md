# AI Dev Template

Claude Code + Codex 기반 AI 코딩 워크플로 템플릿.

프로젝트에 적용하면 **REQUEST → spec → plan → implement → review** 파이프라인이 구조화됩니다.

## 빠른 시작

### 프로젝트에 적용

프로젝트 디렉토리에서 Claude Code를 열고 말합니다:

```
이 AI 개발 템플릿 적용해: <이 repo의 URL>
```

AI가 필요한 파일을 가져와서 프로젝트에 맞게 커스터마이징합니다.

### 템플릿 업데이트

이미 적용된 프로젝트에서:

```
템플릿 최신으로 업데이트해
```

AI가 변경사항을 비교하고 의미 기반으로 머지합니다.

## 구조

```
CLAUDE.md              ← AI에게 주는 프로젝트 규칙
PROJECT_CONTEXT.md     ← 프로젝트 기술 컨텍스트
REQUEST.md             ← 현재 작업 요청
CURRENT_TASK.md        ← 작업 진행 상태
WORKING_WITH_AI.md     ← 사용자 가이드
ai/
├── claude_skills/     ← Claude Code skill 정의
├── docs/              ← 가이드, 프롬프트, 정책, 라이브러리
└── scripts/           ← 빌드/검증 스크립트
```

## 워크플로

### 큰 작업
```
REQUEST 작성 → REQUEST review → spec → plan → spec/plan review → 구현 → 검증 → diff review
```

### 작은 작업
```
REQUEST 정리 → 구현 → 검증 → diff review
```

## 지원 환경

- macOS / Linux (Claude Code CLI)
- Claude Code Desktop App

## 상세 문서

- `WORKING_WITH_AI.md` — 사용자 가이드
- `ai/docs/flows/WORKFLOW.md` — 워크플로 상세
- `ai/docs/AI_DOC_MAP.md` — 문서 맵
