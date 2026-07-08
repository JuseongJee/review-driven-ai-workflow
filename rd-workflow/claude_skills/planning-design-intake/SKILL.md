---
name: planning-design-intake
description: Convert planning document text into REQUEST.md. Use when the user has external planning docs (from Notion, Confluence, etc.) to convert into a structured REQUEST. v1 requires pasted planning text; design references (Figma URLs, screenshots) are optional.
disable-model-invocation: true
---

# Planning Design Intake

기획서 텍스트를 REQUEST.md로 변환한다. (v1: 기획서 텍스트 필수, 디자인 레퍼런스는 선택)

Typical user requests:
- "기획서 붙여넣을게, REQUEST로 만들어줘"
- "이 기획서로 intake 진행해줘"
- "디자인이랑 기획서 있어, REQUEST 만들어줘"

Read these first (Always Read files are already loaded):
- `PROJECT_CONTEXT.md`의 `## Intake Settings` (있으면)

## v1 범위

- 입력: 사용자가 붙여넣은 기획서 텍스트만 처리
- URL/API/PDF 직접 호출 없음
- 디자인: 사용자가 직접 제공한 URL/스크린샷 참조만. Figma API 호출 없음

## 기존 REQUEST.md 처리 — overwrite-backup (implicit archive)

**실행 시점: 사용자 입력(기획서 텍스트)을 받은 후, short-title 부여 전에 실행한다.**
(skill 진입 직후가 아님 — 사용자가 입력을 주기 전에 기존 REQUEST 를 silent archive 하는 eager archive 방지)

### 분기 1a: REQUEST.md 존재 + `CURRENT_TASK.md ## Short Title` = non-`-` (정상 happy path)

- `CURRENT_TASK.md ## Short Title` 에서 `SHORT_TITLE` 변수를 read
- 기존 REQUEST.md 를 collision-safe 백업:
  ```bash
  bash rd-workflow/scripts/rd task backup-request   # 실패(exit 2) 시 출력된 경고를 사용자에게 보이고 중단
  ```
- 같은 short-title 의 `request`/`spec`/`plan` stage 캡처를 frontmatter exact match 로 `raw-captures/archive/` 로 이동:
  ```bash
  bash rd-workflow/scripts/rd task archive-captures --stages request,spec,plan
  ```
- `CURRENT_TASK.md ## Short Title` 을 default `-` 로 reset
- 사용자에게 한 줄 알림: "기존 REQUEST `{old-title}` 을 archive 했습니다 — 캡처 N 건 이동, short-title reset"
- 이후 새 REQUEST 작성 단계 진행 — `## Short Title` 이 `-` 이므로 baseline 분기로 새 short-title 부여

### 분기 1b: REQUEST.md 존재 + `## Short Title` = `-` 또는 부재 (drift 상태)

archive key 가 없으므로 캡처 매칭 불가:
- REQUEST.md 백업은 collision-safe 로 정상 진행:
  ```bash
  bash rd-workflow/scripts/rd task backup-request --orphan
  ```
- **캡처 archive 는 skip** (short-title 모름)
- 사용자에게 명시적 경고:
  > 경고: `CURRENT_TASK.md ## Short Title` 이 비어 있어 raw capture archive 매칭을 skip 했습니다.
  > `rd-workflow-workspace/raw-captures/` 디렉토리에서 미archive 된 이전 작업 캡처를 수동으로 정리하세요.
- `## Short Title` 은 이미 `-`/부재이므로 reset 불필요
- baseline 분기 진행

## 실행 흐름

### 1. 기획서 텍스트 요청

사용자가 기획서 텍스트를 이미 붙여넣었으면 바로 2단계로 간다.
아직 없으면 요청한다:

> "기획서 텍스트를 붙여넣어 주세요. (v1은 텍스트 붙여넣기만 지원합니다)"

**사용자 입력(기획서 텍스트)을 받은 직후** → overwrite-backup (분기 1a / 1b) 수행 후 2단계로 진행.

### 2. short-title 부여 (equality-aware 3-way)

사용자 입력 / REQUEST 후보 제목에서 short-title 후보 추론 → `CANDIDATE`

canonical 정규화: `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$` (영문 kebab-case, 영숫자 시작·끝, 사이만 `-` 허용)

추가 거절 케이스: `-` 단독, empty, hyphen-only (`---` 등) — reserved sentinel 충돌이므로 보정 요청.

위반 시 1줄 보정 요청:
> "short-title 후보: `{CANDIDATE}`. 이대로 진행할까요? (`^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`, `-` 단독 금지)"

확정 후 현재 `## Short Title` 값 read → `CURRENT_TITLE` 변수

- **legacy 케이스 (`## Short Title` 섹션 자체가 부재):** `## Task` 다음에 `## Short Title\n{CANDIDATE}\n` 섹션을 자동 추가 + 사용자 알림 ("legacy 템플릿이므로 `## Short Title` 섹션을 추가했습니다 — sync_template 마이그레이션 권장") → 그 후 baseline 분기 (a) 와 동일하게 진행. (`/fr add` 와 다름 — `planning-design-intake` 는 명시적 새 작업 시작 진입점이라 자동 추가 안전)

**3-way 분기 (섹션이 있는 경우):**

`bash rd-workflow/scripts/rd task guard --candidate "${CANDIDATE}" --mode intake` 를 실행하고 출력의 `decision` 에 따라 진행한다:
- `write` / `rebind`: `message` 를 사용자에게 알리고 진행
- `proceed-readonly`: 변경 없이 진행
- `block-parse` / `block-active` (exit 2): `message` 를 출력하고 skill 진행을 중단

비고: REQUEST.md 가 있는 overwrite-backup 케이스는 분기 1 에서 implicit archive 후 `## Short Title = -` 이 되므로 `block-*` 도달 안 함.

### 3. REQUEST.md 신규 생성 직전 raw capture

- 경로: `rd-workflow-workspace/raw-captures/{date}-request-{short-title}.md`
- frontmatter(date/stage/short-title/source)는 CLI가 생성한다. stdin에는 본문만 전달한다:
  ```bash
  bash rd-workflow/scripts/rd task capture --stage request --source direct <<'CAPTURE_EOF'
  ## 원본 입력
  {사용자 원본 입력 무가공}
  CAPTURE_EOF
  ```
  (`--source`: 직접 호출이면 `--source direct`, 자연어 라우팅이면 `--source routed`. CLI 기본값은 `routed`)
- 충돌 시 `-2`, `-3` suffix
- 캡처 실패 시 경고만 (REQUEST 작성 차단 안 함) — CLI 가 fail-open (exit 0) 으로 처리
- 원문 접근 불가 (routed) 시 캡처 생략 + 경고

### 4. REQUEST.md 필드 매핑

기획서 텍스트를 분석하여 REQUEST.md 필드를 채운다:

| REQUEST 필드 | 기획서에서 추출 |
|---|---|
| Task Type | new feature / existing-code-change (추론) |
| Execution Path | Task Type 기반 자동 설정 |
| User Goal | 기획서의 목적/배경 |
| Change Description | 기능 요구사항 목록 |
| Constraints | 제약 조건, 비기능 요구사항 |
| Acceptance Criteria | 완료 조건, QA 기준 |
| Risks | 리스크, 의존성 |
| Affected Area | 영향 범위 (추론) |
| Platform | PROJECT_CONTEXT.md 참조 |

### 5. 빈 필드 알림 + 신뢰도 판단

한 번에 변환한 뒤, 못 채운 필드를 목록으로 제시한다:

> "다음 필드를 기획서에서 찾지 못했습니다:
> - Constraints
> - Risks
>
> 보충해주시거나, '그대로 진행'이라고 하시면 빈 채로 REQUEST를 생성합니다."

6개 필드(User Goal, Change Description, Constraints, Acceptance Criteria, Risks, Affected Area) 중 3개 이상 비어있으면 `low-confidence` 경고:

> "⚠ 기획서 정보가 부족합니다 (6개 필드 중 N개 미채움). 추가 입력을 권장합니다. 그대로 진행하시겠습니까?"

### 6. 디자인 레퍼런스

기획서 변환 후 디자인 레퍼런스를 묻는다:

> "디자인 레퍼런스(피그마 URL, 스크린샷 등)가 있으면 공유해주세요. 없으면 '없음'이라고 해주세요."

디자인이 있으면 REQUEST.md 하단에 `## Design Reference Memo` 섹션을 추가한다:

```markdown
## Design Reference Memo

> spec 작성 시 `## Design Reference` 섹션으로 옮길 참고 자료

- [피그마 URL / 스크린샷 경로 / 설명]
```

### 7. REQUEST.md 저장

REQUEST.md를 저장하고 안내한다:

> "REQUEST.md 생성 완료. 다음: `/request-to-reviewed-plan`으로 REQUEST review부터 시작하세요."

## 규칙

- 기획서 원본을 직접 수정하지 않는다
- REQUEST.md 범위를 기획서 이상으로 넓히지 않는다
- Platform은 PROJECT_CONTEXT.md에서 가져온다. 없으면 빈 필드 목록에 포함
- `## Design Reference` 형식은 기존 design-review extension 계약을 따른다 (`rd-workflow/extensions/design-review/rules.md` 참조)
- `## Design Reference Memo`가 있으면 안내에 포함: "spec 작성 시 이 메모를 `## Design Reference` 섹션으로 옮겨주세요"
