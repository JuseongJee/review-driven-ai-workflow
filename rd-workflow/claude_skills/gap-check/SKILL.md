---
name: gap-check
description: Check spec for gaps between planning docs, design, and implementation — missing error cases, missing UI states, planning-design mismatches. Run after spec is written, before spec/plan review.
---

# Gap Check

`manual` 모드에서는 사용자의 단계 진입 지시 없이 이 skill 을 스스로 시작하지 않는다. 판정 기준은 `rd-workflow/docs/flows/AUTONOMY.md` 의 「실행 모드와 skill 호출 권한」 절이다.

spec의 기획-디자인-구현 간 갭을 점검하고 질문 목록을 생성한다.

Typical user requests:
- "갭 체크 해줘"
- "spec 갭 체크 진행해줘"
- "기획이랑 디자인 빠진 거 없는지 확인해줘"

Read these first (Always Read files are already loaded):
- `CURRENT_TASK.md`의 Spec 경로에 해당하는 spec 파일
- `REQUEST.md` (기획 원본 대조용)

## rd-workflow 버전 대조

이 skill 은 아래 `RD_SKILL_BASE` 보다 나중에 배포된 rd-workflow 를 전제한다. 첫 작업 단계보다 먼저, 프로젝트 루트에서 아래 명령을 이 호출에서 한 번 실행한다.

- 출력이 없으면 그대로 진행한다.
- 출력이 있으면 출력 전문을 사용자에게 알리고, 템플릿을 sync 할지 그대로 계속할지 묻고 멈춘다. 사용자가 계속을 지시하면 진행한다.
- autopilot·무인 실행처럼 물을 사람이 없으면 계속하지 않고 그 출력을 중단 사유로 보고한다.

```bash
bash -s <<'RD_SKILL_COMPAT'
RD_SKILL_BASE=2026-11-01-202303 RD_SKILL_NAME=gap-check
vf="rd-workflow/VERSION"
if [ ! -f "$vf" ] && [ -f "_ROOT_FILES/rd-workflow/VERSION" ]; then exit 0; fi
v=""; [ -f "$vf" ] && v="$(cat "$vf")"; v="${v#lite-}"
if [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ ]] && [[ "$v" > "$RD_SKILL_BASE" ]]; then exit 0; fi
echo "rd-workflow 버전 불일치 — skill '$RD_SKILL_NAME' 은 $RD_SKILL_BASE 보다 나중에 배포된 rd-workflow 가 필요합니다."
echo "프로젝트: $PWD"
echo "프로젝트 VERSION: ${v:-없음} (파일: $vf)"
echo "이 상태로 진행하면 skill 이 가리키는 문서 절·스크립트·인자가 없어 중간에 실패할 수 있습니다."
echo "해결: 템플릿을 sync 하십시오 (/tpl update 또는 rd-workflow/docs/guides/sync_template.md 절차)."
RD_SKILL_COMPAT
```

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
