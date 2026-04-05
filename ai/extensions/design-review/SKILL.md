---
name: design-review
description: Run the design review gate after spec/plan review — for UI tasks, verify prototype and run design checklist; for non-UI tasks, record not-required and exit immediately.
disable-model-invocation: true
---

# Design Review

Use this after spec/plan review passes. All tasks pass through this skill — non-UI tasks are immediately marked as not-required.

Typical user request:
- "디자인 리뷰 진행해줘"
- "프로토타입 준비됐어, 리뷰해줘"

Read these first (Always Read files are already loaded):
- `CURRENT_TASK.md`의 Spec 경로에 해당하는 spec
- `CURRENT_TASK.md`의 Plan 경로에 해당하는 plan
- `PROJECT_CONTEXT.md` (플랫폼별 요구사항 확인)

## UI 작업 판단

AI가 REQUEST/spec 내용을 보고 자동 판단한다.

UI 작업 기준:
- 화면, 컴포넌트, 레이아웃, 스타일, 프론트엔드 뷰 변경이 포함되면 UI 작업
- API만 바뀌고 화면은 그대로인 경우 비UI
- 판단이 애매하면 사용자에게 질문

비UI 작업이면:
- `CURRENT_TASK.md`의 `Design Review`를 `not-required`로 갱신
- "이 작업은 UI 변경이 없어 디자인 리뷰를 skip합니다. → `/implement-reviewed-plan`" 출력 후 종료

## 실행 순서

### 1. 디자인 레퍼런스 확인

spec의 `## Design Reference` 섹션에 디자인 의도를 확인할 수 있는 레퍼런스가 있는지 확인한다.

레퍼런스 형태는 자유:
- 참고 앱/화면 URL ("Notion 같은 사이드바 + 에디터 구조")
- Figma/스케치 링크 또는 스크린샷
- 손그림 사진
- 텍스트 설명 (레이아웃, 색상, 분위기 등)
- 프로토타입 (v0, Lovable, Claude Artifacts 등으로 생성)

레퍼런스가 없으면 사용자에게 선택지를 제시한다:

**(A) 레퍼런스 추가 후 진행**
- 가장 간단한 방법: 참고할 앱/화면 URL이나 스크린샷
- 더 구체적으로: Figma 링크, 프로토타입 도구(v0, Lovable, Claude Artifacts) 활용
- 레퍼런스를 spec의 `## Design Reference` 섹션에 기록

**(B) 디자인 리뷰 없이 진행**
- `→ /implement-reviewed-plan`로 바로 진행

레퍼런스가 있으면 다음 단계로 진행한다. 레퍼런스가 텍스트 설명만으로 부족해 보이면 프로토타입 생성을 권장할 수 있다.

### 2. AI 디자인 체크리스트

레퍼런스를 spec과 대조하여 아래 항목을 점검하고 피드백을 출력한다:

1. **디자인 레퍼런스 일관성** — spec에 명시한 참고 앱/화면과 디자인 방향 비교
2. **컴포넌트 누락** — spec에 정의된 UI 요소가 레퍼런스에 모두 있는지
3. **사용자 흐름 완성도** — spec의 user flow가 프로토타입에서 구현 가능한 구조인지
4. **반응형/접근성 기본 사항** — 명백한 문제만 (색상 대비, 터치 타겟 크기 등). `PROJECT_CONTEXT.md`에 플랫폼별 요구사항이 있으면 해당 기준으로 점검
5. **Multi-surface 증적** — reviewed spec 또는 `PROJECT_CONTEXT.md`가 여러 target surface/state를 명시하면, 각 surface/state별 프로토타입 증적이 `Design Reference`에 있는지 확인. 누락 시 WARN

각 항목을 PASS / WARN / FAIL로 표시하고 근거를 적는다.

### 3. 사람 디자인 리뷰 gate

AI 체크리스트 결과와 함께 프로토타입을 사용자에게 제시한다.

사용자 선택지:
- **승인** → 구현 진행
- **시안 수정 요청** (레이아웃 미세 변경, 색상 등) → `Design Review = revision-requested` 기록 → spec Design Reference에 아티팩트 링크 갱신 → 다시 Step 2부터 (체크리스트 통과 + 사람 승인 시 `approved`로 전환)
- **요구사항/flow 변경 필요** → "요구사항 변경이 필요합니다. spec/plan을 수정하고 spec/plan review를 다시 열까요?"로 안내 → 사람이 결정

## 디자인 리뷰 상태 관리

`CURRENT_TASK.md`에 `## Design Review` 필드로 gate 상태를 관리한다.

| 값 | 의미 |
|----|------|
| `-` | 아직 판단 전 |
| `not-required` | 비UI 작업 — skip |
| `approved` | 사람 승인 완료 |
| `revision-requested` | 수정 요청 중 |

Writer: `design-review` skill
Reader: `implement-reviewed-plan`, `workflow-router`
Invalidation: spec/plan review 재개, 또는 승인 후 Design Reference/PROJECT_CONTEXT.md 디자인 요구사항 변경 시 `-`로 리셋
Migration: 이 필드가 도입되기 전에 이미 구현 단계에 있던 task는 `not-required`로 설정하고 진행한다.

## 종료

- 사용자가 승인하면 `CURRENT_TASK.md`의 `Design Review`를 `approved`로 갱신
- `Next recommended skill: /implement-reviewed-plan`
