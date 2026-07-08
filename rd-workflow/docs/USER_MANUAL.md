# AI Dev Workflow 사용자 매뉴얼

Claude Code + Codex 기반 리뷰 주도 AI 개발 워크플로 템플릿의 전체 사용법.

---

## 목차

1. [개요](#1-개요)
2. [초기 설정](#2-초기-설정)
3. [핵심 개념](#3-핵심-개념)
4. [일상 작업 흐름](#4-일상-작업-흐름)
5. [스킬 레퍼런스](#5-스킬-레퍼런스)
6. [리뷰 파이프라인](#6-리뷰-파이프라인)
7. [설정 파일](#7-설정-파일)
8. [확장 기능 (Extensions)](#8-확장-기능-extensions)
9. [스크립트 레퍼런스](#9-스크립트-레퍼런스)
10. [디렉토리 구조](#10-디렉토리-구조)
11. [트러블슈팅](#11-트러블슈팅)

---

## 1. 개요

이 템플릿은 AI와 협업하여 소프트웨어를 개발할 때 **설계 → 리뷰 → 구현 → 검증** 프로세스를 구조화합니다.

### 무엇을 해결하는가

- AI가 요구사항을 충분히 분석하지 않고 바로 코드를 쓰는 문제
- 리뷰 없이 merge되는 코드 품질 문제
- 작업 이력이 남지 않아 맥락이 유실되는 문제
- 큰 작업에서 설계/계획 단계가 생략되는 문제

### 핵심 원리

- **리뷰 주도**: REQUEST, spec/plan, 최종 diff — 모든 주요 단계에서 리뷰를 거침
- **자연어 인터페이스**: 짧은 한국어 요청으로 모든 기능 사용 (`"이거 FR에 넣어줘"`, `"autopilot으로 돌려"`)
- **산출물 보존**: spec, plan, 리뷰 기록이 파일로 남아 이력 추적 가능
- **역할 분리**: Claude(Builder) + Codex(Reviewer) — 작성자와 검토자를 분리

---

## 2. 초기 설정

### 전제 조건

- [Claude Code](https://claude.ai/code) 설치 및 로그인
- [Superpowers](https://github.com/anthropics/claude-code-superpowers) 플러그인 설치

### 2.1 템플릿 설치

프로젝트 디렉토리에서 Claude Code를 열고:

```
"이 AI 개발 템플릿 적용해: <템플릿 배포 URL>"
```

배포 URL은 `PROJECT_CONTEXT.md`의 `Template Source`에 기록됩니다. GitHub 또는 내부 Git 서버(OSS) 모두 지원합니다.

AI가 `rd-workflow/docs/guides/setup_with_claude.md` 절차를 따릅니다:

1. 템플릿 파일 복사 (배포 repo → 프로젝트 루트)
2. `PROJECT_CONTEXT.md` 채우기 (프로젝트 타입, 기술 스택, 빌드 명령 등)
3. 검증 스크립트 설정 (`rd-workflow/scripts/test.sh`, `lint.sh`, `typecheck.sh`, `build.sh`)
4. 스킬 설치 (`rd-workflow/scripts/install_claude_skills.sh`)
5. 리뷰 도구 감지 (Codex 설치 여부 확인 + 안내)
6. (선택) 확장 기능 설치, PROJECT_CONTEXT review

### 2.2 필수 설정 파일

설치 후 `rd-workflow/config/` 아래 example 파일을 복사하여 설정합니다:

```bash
cp rd-workflow/config/workflow.json.example rd-workflow/config/workflow.json
cp rd-workflow/config/review-tools.json.example rd-workflow/config/review-tools.json
```

상세 설정은 [7. 설정 파일](#7-설정-파일) 참조.

### 2.3 기존 프로젝트에 적용

이미 코드베이스가 있는 프로젝트에 템플릿을 적용하려면:

```
"기존 프로젝트에 템플릿 마이그레이션해줘"
```

`rd-workflow/docs/guides/migrate_existing_project.md` 절차를 따릅니다.

### 2.4 팀 프로젝트에 개인 설치

팀 repo를 오염시키지 않고 개인 private repo로 분리 설치:

- **처음 설치**: [team-overlay-fresh-install.md](rd-workflow/docs/guides/team-overlay-fresh-install.md)
- **이미 설치된 프로젝트에서 분리**: [team-overlay-migration.md](rd-workflow/docs/guides/team-overlay-migration.md)

```
"팀 프로젝트에 개인 overlay로 설치해줘"
```

---

## 3. 핵심 개념

### 3.1 작업 분류

| 분류 | 기준 | 절차 |
|------|------|------|
| **작은 작업 (small-task)** | 사용자가 명시적으로 지정 | FR 자동 등록 → REQUEST 정리 → 구현 → 검증 → diff review → 아카이브 |
| **큰 작업** | 새 기능, 기존 코드 중간 이상 변경 | FR 자동 등록 → REQUEST → review → spec/plan → review → 구현 → 검증 → diff review → 아카이브 |

> 사용자가 작업을 요청하면 먼저 FR에 자동 등록됩니다. AI가 자체적으로 크기를 판단하지 않습니다. 사용자가 `small-task`라고 명시해야 합니다.

### 3.2 핵심 문서 4종

| 문서 | 역할 | 언제 수정되나 |
|------|------|-------------|
| **REQUEST.md** | 현재 작업의 요구사항 | 작업 시작 시 작성, 완료 시 아카이브 |
| **CURRENT_TASK.md** | 진행 상태 추적 | 각 단계 전환 시 자동 업데이트 |
| **PROJECT_CONTEXT.md** | 프로젝트 메타데이터 | 초기 설정 시 한 번, 이후 거의 불변 |
| **WORKING_WITH_AI.md** | 사용자 치트시트 | 참조용 (수정 불필요) |

### 3.3 Superpowers

Claude Code의 내장 워크플로 기능입니다. 큰 작업에서는 반드시 사용합니다.

| 단계 | Superpowers 모드 | 산출물 |
|------|-----------------|--------|
| 설계 | `brainstorming` | 요구사항 탐색, 설계 대안 비교 |
| 계획 | `writing-plans` | spec + plan 파일 |
| 구현 | `subagent-driven-development` (기본) | 코드 변경 |
| 구현 (대안) | `executing-plans` | 단일 세션 구현 (task 1개+파일 3개 이하, 또는 task 2개+동일 파일 1개일 때 자동 선택) |

### 3.4 Future Request (FR)

지금 범위 밖이지만 나중에 할 후보 목록입니다.

**상태 흐름:**
```
idea → validated → ready-for-request → (REQUEST로 승격)
  ↓                                       ↓
parked (보류)                           done / dropped
```

---

## 4. 일상 작업 흐름

### 4.1 새 기능 개발 (큰 작업)

```
사용자: "사용자 인증 기능을 추가해야 해"
```

AI가 자동으로:
1. `REQUEST.md` 작성
2. REQUEST review (Codex가 검토)
3. Brainstorming → spec → plan 작성
4. Spec/plan review
5. 구현 (subagent dispatch — 병렬·순차 모두 가능)
6. 검증 (`test.sh`, `lint.sh`, `typecheck.sh`, `build.sh`)
7. Final diff review
8. REQUEST 아카이브 + 완료 보고

또는 단계별로:

```
사용자: "이 요구사항으로 request-to-reviewed-plan으로 진행해줘"
(... spec/plan review 완료 후 ...)
사용자: "구현 시작해줘"
(... 구현 + 검증 완료 후 ...)
사용자: "diff review 해줘"
```

### 4.2 버그 수정 / 간단한 변경 (작은 작업)

```
사용자: "small-task로 이 버그 수정해줘: 로그인 버튼이 모바일에서 잘림"
```

AI가:
1. REQUEST.md 간략 작성
2. 바로 구현
3. 검증
4. Final diff review
5. 아카이브

### 4.3 아이디어 기록

```
사용자: "나중에 다크모드 지원해야 할 것 같아, FR에 넣어줘"
```

→ `/fr add` 실행 → `FUTURE_REQUESTS.md`에 등록

### 4.4 자동 실행 (Autopilot)

```
사용자: "autopilot으로 돌려줘"
```

FR 목록에서 작업을 선택하면, 모든 리뷰를 포함하여 끝까지 자동 실행합니다.
- 모든 선택지에서 추천안을 자율 선택
- 리뷰 50턴까지 허용
- 디버깅 3회 실패 시 멈춤

### 4.5 기획서에서 시작

Notion/Confluence 등에 기획서가 있을 때:

```
사용자: "기획서 붙여넣을게" (텍스트 붙여넣기)
```

→ `planning-design-intake` 스킬이 REQUEST.md로 변환

### 4.6 프로젝트 감사

```
사용자: "전체 코드 감사 돌려줘"
또는: "/audit code"  (code, ui, flow, perf, security 등 카테고리 지정)
```

→ `comprehensive-audit` 스킬이 8개 카테고리 병렬 점검 + FR 자동 등록

---

## 5. 스킬 레퍼런스

### 5.1 워크플로 스킬 (사용자 호출)

| 스킬 | 호출 방법 | 기능 |
|------|----------|------|
| **workflow-router** | 내부 자동 호출 | 현재 상태에 맞는 다음 스킬 추천 |
| **request-to-reviewed-plan** | `"request-to-reviewed-plan으로 진행"` | REQUEST → spec → plan → 리뷰 (큰 작업 전체 흐름) |
| **small-task-implement** | `"small-task로 구현해줘"` | 작은 작업 직접 구현 |
| **implement-reviewed-plan** | `"구현 시작해줘"` | 리뷰된 plan 기반 구현 |
| **final-diff-review** | `"diff review 해줘"` | 최종 코드 리뷰 (모든 작업의 마지막 단계) |
| **planning-design-intake** | `"기획서 붙여넣을게"` | 기획서 텍스트 → REQUEST 변환 |
| **gap-check** | `"갭 체크 해줘"` | 기획-디자인-구현 간 불일치 점검 |

### 5.2 관리 스킬

| 스킬 | 호출 방법 | 기능 |
|------|----------|------|
| **fr** | `/fr <subcommand>` | Future Request 관리 |
| **autopilot** | `"autopilot으로 돌려"` | FR에서 작업 선택 → 전체 자동 실행 |
| **comprehensive-audit** | `/audit [카테고리]` | 프로젝트 전방위 감사 |
| **review-config** | `/review-config setup` | 리뷰 도구 설정 |
| **model-strategy** | `"model strategy 설정해줘"` | 워크플로 단계별 AI 모델 설정 |
| **tpl** | `/tpl update` | 최신 템플릿으로 동기화 |

### 5.3 /fr 서브커맨드

| 커맨드 | 기능 |
|--------|------|
| `/fr add 내용` | FR 등록 |
| `/fr list` | 활성 항목 목록 (우선순위 순) |
| `/fr pri` | AI가 우선순위 평가 후 즉시 반영 |
| `/fr archive` | done/dropped 항목 인덱스에서 일괄 삭제 |
| `/fr park <제목>` | 항목을 parked로 이동 (재평가 조건 입력) |
| `/fr status <제목> <상태>` | 항목 상태 변경 (모든 전이 방향 지원) |
| `/fr pull` | GitHub Issues → 로컬 FR 가져오기 |
| `/fr push [제목]` | 로컬 FR → GitHub Issue 내보내기 |
| `/fr sync` | 연결된 항목 status 양방향 동기화 |

---

## 6. 리뷰 파이프라인

### 6.1 구조

모든 리뷰는 파일 기반 세션으로 진행됩니다:

```
rd-workflow-workspace/handoffs/review_pipeline/{session-id}/
├── SESSION.md        # 세션 상태 (awaiting-author / awaiting-reviewer / awaiting-user / closed)
├── CHECKPOINT.md     # 합의 사항 / 미해결 쟁점 추적
├── USER_ACTION.md    # 사용자 결정 필요 시 질문
├── PROMPTS.md        # 리뷰 진행 프롬프트
└── turns/
    ├── 001_author.md
    ├── 002_reviewer.md
    └── ...
```

### 6.2 리뷰 종류

| 종류 | 타이밍 | 검토 대상 |
|------|--------|----------|
| **REQUEST review** | REQUEST 작성 직후 | 요구사항 명확성, 리스크, 완료 조건 |
| **Spec/Plan review** | spec + plan 작성 직후 | 설계 적절성, 엣지 케이스, 더 단순한 대안 |
| **Final diff review** | 구현 + 검증 완료 후 | 논리 버그, 회귀 위험, 보안, 유지보수성 |

### 6.3 리뷰 흐름

```
Author 턴 작성 → Reviewer 턴 실행 (외부 AI)
       ↓                    ↓
  피드백 반영 ← 이의 제기    이의 없음 → 완료
```

- Reviewer가 "이의 없음"을 명시할 때까지 반복
- 일반 모드: 최대 20턴 / Autopilot 모드: 최대 50턴
- 턴 한도 도달 시 사용자에게 넘김 (`awaiting-user`)

### 6.4 리뷰 도구

| 도구 | 역할 | 설정 |
|------|------|------|
| **Codex (기본)** | 독립 Reviewer | `rd-workflow/scripts/adapter_codex.sh` |
| **Claude** | Self-review fallback | `rd-workflow/scripts/adapter_claude.sh` |

우선순위는 `rd-workflow/config/review-tools.json`의 `default_priority`로 설정.

---

## 7. 설정 파일

모든 설정은 `rd-workflow/config/`에 위치합니다. `.example` 파일을 복사하여 사용합니다.

> **설치 직후에는 설정 없이 동작합니다.** 리뷰 도구는 설치된 것을 자동 감지하여 fallback합니다 (Codex → Claude self-review 순). 외부 리뷰 도구가 없으면 Claude self-review로 진행됩니다. 필요할 때 아래 설정 스킬로 변경하세요.

### 7.1 workflow.json

```json
{
  "auto_completion_report": false,
  "intake_source": "text",
  "design_reference_format": "url+screenshot",
  "fr_github": false
}
```

| 키 | 설명 | 값 |
|----|------|-----|
| `auto_completion_report` | 작업 완료 시 report 자동 생성 | `true` / `false` |
| `intake_source` | 기획서 입력 방식 | `"text"` / `"text+design"` |
| `design_reference_format` | 디자인 참고 형식 | `"url+screenshot"` |
| `fr_github` | FR-GitHub Issues 연동 | `true` / `false` |

### 7.2 review-tools.json

리뷰 도구 우선순위와 모델 설정. `/review-config setup` 스킬로 대화형 설정 가능.

```json
{
  "default_priority": ["codex", "claude"],
  "tools": {
    "codex": { "bin": "codex", "model": "gpt-5.4" },
    "claude": { "bin": "claude", "model": "opus" }
  }
}
```

### 7.3 model-strategy.json

워크플로 단계별 AI 모델 설정. `"model strategy 설정해줘"` 또는 `/model-strategy` 스킬로 대화형 위저드 실행 가능.

```json
{
  "version": 1,
  "subagent": "sonnet"
}
```

subagent 구현 시 사용할 모델. 허용 값: `opus`, `sonnet`, `haiku`.

### 7.4 verification.json

런타임 검증(verify extension) 도구 설정. Lighthouse, Playwright, axe 등.

---

## 8. 확장 기능 (Extensions)

기본 워크플로에 추가할 수 있는 선택적 기능입니다.

### 8.1 design-review

UI 작업 시 디자인 레퍼런스 대비 검증 게이트.

- spec/plan review 통과 후, 구현 전에 실행
- 디자인 참고 자료(Figma, 스크린샷 등) 확인
- AI 체크리스트: 일관성, 누락, 반응형, 다중 surface
- CURRENT_TASK.md에 `Design Review: approved / revision-requested` 기록

### 8.2 verify

코드 리뷰를 넘어선 런타임 품질 검증.

- 구현 + 기본 검증 후, diff review 전에 실행
- `rd-workflow/config/verification.json`에서 도구 설정 (Lighthouse, Playwright, axe 등)
- 결과를 review pipeline으로 평가 → 개선 → 재실행 반복
- CURRENT_TASK.md에 `Verify: passed / in-progress` 기록

### 8.3 설치 방법

```
"design-review extension 설치해줘"
"verify extension 설치해줘"
```

설치 상태는 `rd-workflow/config/extensions.json`에 기록됩니다.

---

## 9. 스크립트 레퍼런스

### 9.1 검증 스크립트 (프로젝트별 수정 필수)

| 스크립트 | 용도 | 예시 |
|---------|------|------|
| `rd-workflow/scripts/build.sh` | 전체 빌드 (산출물 생성 — verify 게이트 포함) | `npm run build` |
| `rd-workflow/scripts/test.sh` | 테스트 | `npm test` |
| `rd-workflow/scripts/lint.sh` | 린트 | `npm run lint` |
| `rd-workflow/scripts/typecheck.sh` | 타입 체크 | `tsc --noEmit` |

> 설치 직후에는 placeholder입니다. 프로젝트에 맞게 실제 명령을 채워야 합니다.

### 9.2 리뷰 파이프라인 스크립트

| 스크립트 | 용도 |
|---------|------|
| `rd-workflow/scripts/prepare_review_pipeline.sh <종류>` | 리뷰 세션 생성 (`request` / `spec-plan` / `diff`) |
| `rd-workflow/scripts/run_review_turn.sh <session-path>` | 리뷰 턴 한 회 실행 |
| `rd-workflow/scripts/review_common.sh` | 공통 함수 (직접 실행 안 함) |

### 9.3 기타 스크립트

| 스크립트 | 용도 |
|---------|------|
| `rd-workflow/scripts/install_claude_skills.sh` | 스킬을 Claude Code에 설치 (link/copy) |
| `rd-workflow/scripts/sync_template.sh` | 배포 repo에서 최신 템플릿 동기화 |
| `rd-workflow/scripts/check_claudemd_size.sh` | CLAUDE.md 200줄 초과 경고 |
| `rd-workflow/scripts/adapter_codex.sh` | Codex 리뷰 어댑터 |
| `rd-workflow/scripts/adapter_claude.sh` | Claude 리뷰 어댑터 (self-review) |

---

## 10. 디렉토리 구조

```
프로젝트 루트/
├── CLAUDE.md                    # AI 행동 규칙 (절대 규칙, 워크플로 우선순위)
├── PROJECT_CONTEXT.md           # 프로젝트 메타데이터
├── REQUEST.md                   # 현재 작업 요구사항
├── CURRENT_TASK.md              # 진행 상태 추적
├── WORKING_WITH_AI.md           # 사용자 치트시트
│
└── rd-workflow/
    ├── config/                  # 설정 파일
    │   ├── workflow.json            # 워크플로 설정
    │   ├── review-tools.json        # 리뷰 도구 설정
    │   ├── model-strategy.json      # 모델 전략
    │   ├── verification.json        # 런타임 검증 도구
    │   └── extensions.json          # 확장 기능 상태
    │
    ├── claude_skills/           # AI 스킬 (SKILL.md)
    │   ├── workflow-router/         # 다음 단계 추천
    │   ├── request-to-reviewed-plan/# REQUEST → 리뷰된 plan
    │   ├── small-task-implement/    # 작은 작업 구현
    │   ├── implement-reviewed-plan/ # plan 기반 구현
    │   ├── final-diff-review/       # 최종 diff 리뷰
    │   ├── planning-design-intake/  # 기획서 → REQUEST 변환
    │   ├── gap-check/               # 기획-디자인-구현 갭 점검
    │   ├── fr/                      # Future Request 관리
    │   ├── autopilot/               # 전체 자동 실행
    │   ├── review-config/           # 리뷰 도구 설정
    │   ├── model-strategy/          # 모델 전략 설정
    │   ├── comprehensive-audit/     # 전방위 감사
    │   └── tpl/                     # 템플릿 동기화
    │
    ├── extensions/              # 선택적 확장 기능
    │   ├── design-review/           # 디자인 검증 게이트
    │   └── verify/                  # 런타임 품질 검증
    │
    ├── scripts/                 # 자동화 스크립트
    │   ├── build.sh, test.sh, lint.sh, typecheck.sh  # 검증
    │   ├── prepare_review_pipeline.sh                 # 리뷰 세션 생성
    │   ├── run_review_turn.sh                         # 리뷰 턴 실행
    │   ├── adapter_codex.sh, adapter_claude.sh  # 리뷰어
    │   ├── install_claude_skills.sh                   # 스킬 설치
    │   └── sync_template.sh                           # 템플릿 동기화
    │
    ├── docs/                    # 문서
    │   ├── AI_DOC_MAP.md            # 전체 문서 맵
    │   ├── AGENTS.md                # Git 워크플로 규칙
    │   ├── PR_TEMPLATE.md           # PR 템플릿
    │   ├── USER_MANUAL.md           # 이 문서
    │   ├── flows/                   # 워크플로 흐름
    │   │   ├── WORKFLOW.md              # 작업 분기 기준
    │   │   └── FILE_BASED_REVIEW_PIPELINE.md  # 리뷰 파이프라인 설계
    │   ├── guides/                  # 설정/운영 가이드
    │   │   ├── setup_with_claude.md     # 초기 설정
    │   │   ├── config_reference.md      # 설정 파일 레퍼런스
    │   │   ├── sync_template.md         # 템플릿 동기화
    │   │   ├── migrate_existing_project.md  # 기존 프로젝트 적용
    │   │   ├── adapter-interface.md     # 리뷰 어댑터 인터페이스
    │   │   ├── verification-scope-guide.md  # 검증 범위 가이드
    │   │   ├── team-overlay-fresh-install.md   # 팀 프로젝트 개인 설치
    │   │   └── team-overlay-migration.md      # 팀 프로젝트 분리 마이그레이션
    │   ├── prompts/                 # 프롬프트 (보정/수동 복구용)
    │   │   ├── review/                  # 리뷰 기준
    │   │   ├── recovery/                # 절차 보정
    │   │   └── manual/                  # 수동 진행
    │   └── adr/                     # 아키텍처 결정 기록
    │
    └── workspace/               # 작업 산출물
        ├── specs/
        │   ├── base/                # 새 기능 spec
        │   └── changes/             # 기존 코드 변경 spec
        ├── plans/                   # 구현 계획
        ├── backlog/
        │   ├── FUTURE_REQUESTS.md       # 활성 FR 인덱스
        │   ├── FUTURE_REQUESTS_PARKED.md # 보류 FR
        │   ├── items/                   # FR 상세 파일
        │   └── request-archive/         # 완료된 REQUEST 보관
        ├── handoffs/
        │   └── review_pipeline/         # 리뷰 세션
        └── reports/
            ├── reviews/                 # 리뷰 요약
            ├── completions/             # 완료 보고
            ├── autopilot/               # autopilot 보고
            └── audits/                  # 감사 보고
```

---

## 11. 트러블슈팅

### 자주 묻는 질문

**Q: AI가 바로 구현하려고 합니다.**
→ REQUEST.md가 비어있거나 Execution Path가 설정되지 않았을 수 있습니다. `"이건 큰 작업이야, request-to-reviewed-plan으로 진행해"` 라고 명시하세요.

**Q: 리뷰가 끝나지 않습니다.**
→ 20턴(autopilot은 50턴) 도달 시 자동으로 사용자에게 넘깁니다. `USER_ACTION.md`에 남은 쟁점이 정리되어 있습니다.

**Q: Codex 리뷰어를 사용할 수 없습니다.**
→ `rd-workflow/config/review-tools.json`에서 우선순위를 변경하거나, `/review-config setup`으로 재설정하세요. Claude self-review가 fallback입니다.

**Q: 템플릿을 업데이트하고 싶습니다.**
→ `/tpl update` 실행. 파일 분류(동기화/보존/삭제 후보) → 사용자 확인 → 동기화 → 스킬 재설치까지 자동 진행됩니다.

**Q: 작업 중간에 세션이 끊어졌습니다.**
→ `CURRENT_TASK.md`에 마지막 상태가 기록되어 있습니다. 새 세션에서 `"이어서 해줘"`라고 하면 AI가 상태를 읽고 이어갑니다.

### 보정 프롬프트

AI가 절차를 놓칠 때 수동으로 보정할 수 있습니다:

| 상황 | 프롬프트 파일 |
|------|-------------|
| REQUEST부터 plan까지 한 번에 | `rd-workflow/docs/prompts/recovery/request_to_reviewed_plan_full.md` |
| Superpowers 없이 plan 작성 | `rd-workflow/docs/prompts/recovery/write_plan_without_skill.md` |
| 리뷰 수동 시작 | `rd-workflow/docs/prompts/manual/review_pipeline_start_manual.md` |
| 리뷰 수동 이어가기 | `rd-workflow/docs/prompts/manual/review_pipeline_continue_manual.md` |

---

## 빠른 참조

### 가장 많이 쓰는 명령

```
"이 기능 구현해줘: [요구사항]"          # 큰 작업 시작
"small-task로 이거 고쳐줘: [설명]"      # 작은 작업
"/fr add [아이디어]"                    # FR 등록
"/fr list"                             # FR 목록
"autopilot으로 돌려"                    # 자동 실행
"/audit"                               # 전체 감사
"/tpl update"                          # 템플릿 업데이트
```

### 절대 규칙 (AI가 반드시 지키는 것)

1. 구현 완료 후 반드시 final diff review
2. 큰 작업에서 Superpowers 반드시 사용
3. 구현 후 검증 스크립트 실행 (`test.sh`, `lint.sh`, `typecheck.sh`, `build.sh`)
