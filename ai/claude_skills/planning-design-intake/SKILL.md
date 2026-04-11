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

Read these first:
- Always Read 파일 (이미 로드됨)
- `ai/config/workflow.json`의 `intake_source`, `design_reference_format` (파일이 없으면 `.example` 기본값 사용)

## v1 범위

- 입력: 사용자가 붙여넣은 기획서 텍스트만 처리
- URL/API/PDF 직접 호출 없음
- 디자인: 사용자가 직접 제공한 URL/스크린샷 참조만. Figma API 호출 없음

## 기존 REQUEST.md 처리

REQUEST.md가 이미 존재하면 사용자에게 알린다:

> "기존 REQUEST.md가 있습니다. 덮어쓸까요? (기존 파일은 request-archive에 백업됩니다)"

- 승인: 기존 REQUEST.md를 `ai/workspace/backlog/request-archive/YYYY-MM-DD-HHMMSS-intake-backup.md`에 백업 후 새로 생성 (초 단위 timestamp로 충돌 방지)
- 거부: 중단

## 실행 흐름

### 1. 기획서 텍스트 요청

사용자가 기획서 텍스트를 이미 붙여넣었으면 바로 2단계로 간다.
아직 없으면 요청한다:

> "기획서 텍스트를 붙여넣어 주세요. (v1은 텍스트 붙여넣기만 지원합니다)"

### 2. REQUEST.md 필드 매핑

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

### 3. 빈 필드 알림 + 신뢰도 판단

한 번에 변환한 뒤, 못 채운 필드를 목록으로 제시한다:

> "다음 필드를 기획서에서 찾지 못했습니다:
> - Constraints
> - Risks
>
> 보충해주시거나, '그대로 진행'이라고 하시면 빈 채로 REQUEST를 생성합니다."

6개 필드(User Goal, Change Description, Constraints, Acceptance Criteria, Risks, Affected Area) 중 3개 이상 비어있으면 `low-confidence` 경고:

> "⚠ 기획서 정보가 부족합니다 (6개 필드 중 N개 미채움). 추가 입력을 권장합니다. 그대로 진행하시겠습니까?"

### 4. 디자인 레퍼런스

기획서 변환 후 디자인 레퍼런스를 묻는다:

> "디자인 레퍼런스(피그마 URL, 스크린샷 등)가 있으면 공유해주세요. 없으면 '없음'이라고 해주세요."

디자인이 있으면 REQUEST.md 하단에 `## Design Reference Memo` 섹션을 추가한다:

```markdown
## Design Reference Memo

> spec 작성 시 `## Design Reference` 섹션으로 옮길 참고 자료

- [피그마 URL / 스크린샷 경로 / 설명]
```

### 5. REQUEST.md 저장

REQUEST.md를 저장하고 안내한다:

> "REQUEST.md 생성 완료. 다음: `/request-to-reviewed-plan`으로 REQUEST review부터 시작하세요."

## 규칙

- 기획서 원본을 직접 수정하지 않는다
- REQUEST.md 범위를 기획서 이상으로 넓히지 않는다
- Platform은 PROJECT_CONTEXT.md에서 가져온다. 없으면 빈 필드 목록에 포함
- `## Design Reference` 형식은 기존 design-review extension 계약을 따른다 (`ai/extensions/design-review/rules.md` 참조)
- `## Design Reference Memo`가 있으면 안내에 포함: "spec 작성 시 이 메모를 `## Design Reference` 섹션으로 옮겨주세요"
