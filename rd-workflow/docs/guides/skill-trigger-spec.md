# Skill 트리거 기대 명세 (skill-trigger-spec)

핵심 라우팅 skill이 **언제 트리거되어야 하고 언제 트리거되면 안 되는지**를 예시 쿼리 쌍으로 적어둔 문서입니다.

## 목적

- skill의 `description`을 수정할 때 "여전히 의도대로 라우팅되는가?"를 대조할 기준을 제공합니다.
- skill이 여러 개라 트리거 경계를 서로 나눠 가지므로, 한 곳의 수정이 인접 skill 라우팅을 망가뜨리는 회귀를 사람이 잡을 수 있게 합니다.
- 트리거 의도를 작성자 머릿속이 아니라 문서에 남깁니다.

## 사용법

skill의 `description`(SKILL.md frontmatter)을 바꿀 때:

1. 해당 skill의 should-trigger 쿼리가 여전히 그 skill로 향하는지 확인합니다.
2. should-NOT-trigger 쿼리가 여전히 **다른** skill로 향하는지 확인합니다.
3. 쿼리 쌍을 적다가 "이 쿼리는 A도 B도 맞는데?"가 보이면, 그게 description 경계가 모호하다는 신호입니다 — description을 다듬습니다.

## 한계 (중요)

- 이 문서는 **기대 명세이지 검증이 아닙니다.** 수동 대조라 사람이 보지 않으면 효과가 없습니다.
- 실제 LLM이 그렇게 라우팅하는지는 여기서 확인하지 않습니다. 의도와 실제 동작의 gap은 남습니다.
- 자동화(LLM eval harness)는 별도 항목(`skill-trigger-validation` FR)으로 분리되어 있으며, 그때 아래 쿼리 쌍을 테스트 입력으로 재사용합니다.

---

## 쿼리 쌍

각 항목의 `→`는 해당 쿼리가 향해야 할 skill입니다.

### workflow-router

다음에 어떤 워크플로 skill로 가야 할지 추천합니다. 경로가 불명확할 때의 진입점입니다.

- **should-trigger**
  - "이제 뭐부터 해야 해?"
  - "이 요구사항 어떻게 진행하지?"
  - "다음 단계 추천해줘"
- **should-NOT-trigger**
  - "이거 작은 수정이니 바로 고쳐줘" → `small-task-implement` (경로가 이미 명확)
  - "FR 목록 보여줘" → `fr`
  - "머지 전에 최종 리뷰하자" → `final-diff-review`

### request-to-reviewed-plan

REQUEST review → spec/plan 작성 → spec/plan review까지 끌고 갑니다. 새 기능·중간 이상 변경에 쓰며, 기존 `REQUEST.md`가 있어야 합니다.

- **should-trigger**
  - "이 요구사항으로 request-to-reviewed-plan으로 진행해줘"
  - "이거 큰 작업이니 spec부터 잡고 가자"
  - "기존 코드 중간 이상 바꾸는 거라 plan 리뷰까지 받자"
- **should-NOT-trigger**
  - "small-task로 보고 바로 구현해줘" → `small-task-implement`
  - "아직 요구사항이 자유 텍스트라 정리부터 해야 해" → `planning-design-intake` (REQUEST.md 선행 필요)
  - "plan은 이미 리뷰됐고 구현만 하면 돼" → `implement-reviewed-plan`

### small-task-implement

`REQUEST.md`에서 작은 변경을 바로 구현합니다. **사용자가 명시적으로 small-task로 지정한 경우에만** 사용하며, AI가 스스로 작은 작업이라 판단해 쓰지 않습니다.

- **should-trigger**
  - "small-task로 보고 바로 구현해줘"
  - "이거 작은 수정이니 바로 처리해줘"
- **should-NOT-trigger**
  - "이거 큰 작업 같은데 어떻게 할까" → `workflow-router` / `request-to-reviewed-plan` (규모가 큼 — AI의 자체 small 판단 금지)
  - "리뷰 끝난 plan대로 구현해" → `implement-reviewed-plan`
  - "이거 나중에 하게 기록만 해둬" → `fr`

### implement-reviewed-plan

리뷰를 통과한 spec/plan을 근거로 코드를 구현합니다.

- **should-trigger**
  - "리뷰 끝난 plan대로 구현 시작해줘"
  - "spec/plan 통과했으니 구현 단계로 가자"
- **should-NOT-trigger**
  - "아직 plan을 안 만들었는데 구현부터 하자" → `request-to-reviewed-plan` (plan 선행)
  - "작은 수정이라 plan 없이 바로 해" → `small-task-implement`
  - "구현 다 됐고 최종 리뷰만 남았어" → `final-diff-review`

### final-diff-review

구현 후 최종 핸드오프 단계입니다 — 검증 상태 확인, PR 텍스트 작성, 최종 diff 리뷰를 거쳐 merge 준비까지 진행합니다. 이 워크플로의 마지막 게이트입니다.

- **should-trigger**
  - "구현 끝났으니 final-diff-review로 넘겨줘"
  - "머지 전에 최종 diff 리뷰하자"
  - "PR 올리기 전에 마지막으로 점검해줘"
- **should-NOT-trigger**
  - "이 코드 품질 좀 봐줘" → `code-review` (일반 코드 리뷰, 워크플로 게이트 아님)
  - "spec/plan 리뷰해줘" → `request-to-reviewed-plan` (구현 전 단계)
  - "이 GitHub PR 번호 리뷰해줘" → `review` (외부 PR 리뷰)

> **경계 주의**: "리뷰"라는 단어 하나로 `final-diff-review`·`code-review`·`review`가 모두 후보가 됩니다. final-diff-review는 *이 repo 워크플로의 최종 게이트*, code-review는 *변경 코드의 일반 품질 리뷰*, review는 *GitHub PR 리뷰*로 구분합니다.

### fr

future request(backlog) 관리입니다 — 등록·목록·우선순위·아카이브·park·상태 변경·GitHub 동기화.

- **should-trigger**
  - "이거 FR에 넣어줘" / "future request에 기록해줘"
  - "FR 목록 보여줘"
  - "done 항목 정리해줘" / "이거 parked로 옮겨줘"
- **should-NOT-trigger**
  - "이 FR 지금 구현하자" → `small-task-implement` / `request-to-reviewed-plan` (구현은 fr 영역 아님)
  - "FR 골라서 끝까지 자율로 돌려" → `autopilot`
  - "다음에 뭐 할지 추천해줘" → `workflow-router`

### autopilot

`FUTURE_REQUESTS.md`에서 task를 골라 전체 파이프라인(리뷰 포함)을 자율 실행합니다.

- **should-trigger**
  - "autopilot으로 돌려줘"
  - "FR에서 하나 골라서 끝까지 자율로 진행해"
  - "리뷰까지 알아서 다 하고 완료해줘"
- **should-NOT-trigger**
  - "이 작업 단계별로 같이 보면서 하자" → 수동 워크플로 (`workflow-router` 등)
  - "FR 목록만 보여줘" → `fr`
  - "small-task로 바로 구현해줘" → `small-task-implement`

---

## 알려진 경계 모호성

- **request-to-reviewed-plan ↔ small-task-implement**: 규모로 갈립니다. 프로젝트 규칙상 AI가 스스로 small-task로 판단하는 것은 금지이며, 사용자가 명시해야 small-task-implement로 갑니다. 모호하면 `workflow-router`로 보냅니다.
- **implement-reviewed-plan ↔ request-to-reviewed-plan**: reviewed plan 존재 여부로 갈립니다. plan이 아직 없으면 r2rp가 먼저입니다.
- **final-diff-review ↔ code-review ↔ review**: 위 final-diff-review 항목의 경계 주의 참고.
