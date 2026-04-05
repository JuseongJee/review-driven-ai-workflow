---
name: gap-check
description: Check spec for gaps between planning docs, design, and implementation — missing error cases, missing UI states, planning-design mismatches. Run after spec is written, before spec/plan review.
disable-model-invocation: true
---

# Gap Check

spec의 기획-디자인-구현 간 갭을 점검하고 질문 목록을 생성한다.

Typical user requests:
- "갭 체크 해줘"
- "spec 갭 체크 진행해줘"
- "기획이랑 디자인 빠진 거 없는지 확인해줘"

Read these first (Always Read files are already loaded):
- `CURRENT_TASK.md`의 Spec 경로에 해당하는 spec 파일
- `REQUEST.md` (기획 원본 대조용)

## 트리거 시점

- spec 작성 직후, spec/plan review 전
- 독립 실행: 사용자가 spec 파일 경로를 직접 지정하면 `CURRENT_TASK.md` 없이도 실행 가능. `REQUEST.md`가 없으면 에러/엣지 케이스 점검만 수행하고, 기획-디자인 불일치 항목은 skip

## 점검 항목 (3대 필수)

### 1. 에러/엣지 케이스 누락

기획/spec에 명시되지 않은 에러 상황, 경계 조건을 점검한다.

확인 포인트:
- 네트워크 오류 / 타임아웃 처리
- 빈 데이터 / null 상태
- 권한 없음 / 인증 만료
- 입력 한도 초과 / 유효성 검증 실패
- 동시성 / 경쟁 조건
- 외부 서비스 장애

### 2. 디자인 빠진 상태

spec의 `## Design Reference` 섹션을 확인하여 누락된 UI 상태를 점검한다.

확인 포인트:
- 로딩 상태
- 빈 화면 (데이터 없음)
- 에러 화면
- 비활성/비인증 상태
- 부분 로딩 / 스켈레톤

**Design Reference가 없으면 이 항목은 skip한다.**

### 3. 기획-디자인 불일치

기획(REQUEST.md)과 디자인(spec의 Design Reference)을 대조하여 불일치를 찾는다.

확인 포인트:
- 기획에 있는데 디자인에 없는 기능/화면
- 디자인에 있는데 기획에 없는 요소
- 기획의 흐름과 디자인의 흐름 차이

**Design Reference가 없으면 이 항목은 skip한다.**

## 출력

spec 파일 끝에 `## Gap Check` 섹션을 추가한다:

```markdown
## Gap Check

> advisory — non-blocking. 사용자가 판단하여 반영 여부를 결정한다.

### 1. 에러/엣지 케이스 누락

| 항목 | 상태 | 설명 |
|------|------|------|
| 네트워크 오류 처리 | GAP | spec에 오프라인/타임아웃 동작이 정의되지 않음 |
| 빈 데이터 상태 | PASS | spec §3에 빈 목록 UI 명시됨 |
| ... | ... | ... |

### 2. 디자인 빠진 상태

| 상태 | 상태 | 설명 |
|------|------|------|
| 로딩 | GAP | 디자인에 로딩 스피너/스켈레톤이 없음 |
| ... | ... | ... |

### 3. 기획-디자인 불일치

| 항목 | 상태 | 설명 |
|------|------|------|
| 설정 화면 | GAP | 기획에 있으나 디자인에 없음 |
| ... | ... | ... |

### 기획자/디자이너 확인 질문

1. [질문 — GAP 항목 기반]
2. [질문]
```

## 완료 후 안내

> "갭 체크 완료. GAP 항목에 대한 질문 목록을 기획자/디자이너에게 전달하세요.
> 모든 GAP이 PASS이면 그대로 진행해도 됩니다.
> → spec/plan review 계속"

## 규칙

- 갭 체크 결과는 **advisory** (non-blocking). 사용자가 판단한다.
- spec을 직접 수정하지 않는다 — `## Gap Check` 섹션 추가만 한다.
- 기존 spec 내용을 변경하지 않는다.
- REQUEST.md 원본을 변경하지 않는다.
- `## Design Reference` 형식은 기존 design-review extension 계약을 따른다.
- 재실행 시 기존 `## Gap Check` 섹션을 **교체**한다 (누적 아님). 기존 섹션을 삭제 후 새로 작성.
