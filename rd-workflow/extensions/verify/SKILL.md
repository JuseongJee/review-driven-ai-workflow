---
name: verify
description: Run runtime verification loop — execute verification tools, evaluate results with AI criteria, fix issues, repeat until no improvements needed. Skip if verification.json is not configured.
disable-model-invocation: true
---

# Verify

Use this after implementation and basic verification (test/lint/typecheck) are done.

Typical user request:
- "verify 진행해줘"
- "런타임 검증 돌려줘"

Read these first (Always Read files are already loaded):
- `CURRENT_TASK.md`
- `rd-workflow/config/verification.json` (없으면 skip)
- `CURRENT_TASK.md`의 Spec 경로에 해당하는 spec의 `## Verification Criteria`

## 진입 조건

`rd-workflow/config/verification.json`이 없으면:
- `CURRENT_TASK.md`의 `Verify`를 `not-required`로 갱신
- "검증 설정이 없어 skip합니다. → `/final-diff-review`" 출력 후 종료

`CURRENT_TASK.md`의 Spec 경로에 해당하는 spec에 `## Verification Criteria` 섹션이 없으면:
- verification.json의 criteria만으로 검증을 진행한다 (VC 없이도 실행 가능)
- `standard` 등급이나 VC 미기입 작업도 verification.json이 있으면 런타임 검증 대상

## 실행 순서

### 0. 설정 점검

verifier 를 제시하기 전에 설정을 점검한다. 이 명령은 adapter 와 `run` 을 실행하지 않고 `.verification/` 에 아무것도 쓰지 않는다.

```bash
bash rd-workflow/extensions/verify/verify.sh --check
```

종료 코드: 0 미완료 0건 / 2 미완료 1건 이상 / 3 설정 없음 / 1 점검 불가. 마지막 줄은 `verify-check: status=<complete|incomplete|absent> incomplete=<N> attention=<M>` 이다.

- 미완료와 확인 필요 목록을 사용자에게 그대로 제시한다.
- 미완료의 뜻을 알린다. 환경 변수 미설정과 실행 대상 0개는 일반 실행이 그 verifier 를 건너뛴다. 채점 기준의 `TODO` 는 경고만 하고 실행하지만 채점 기준이 모호해진다.
- 확인 필요는 추론으로 찾은 항목이다. 실행은 막지 않는다.
- 사용자에게 채울지, 그대로 진행할지 묻는다. 종료 코드 3 이면 진입 조건대로 skip 한다.
- `설정 완료`(`status=complete`)는 도구 설치와 adapter 구현까지 보장하지 않는다. `xcuitest`·`xcuitest-macos` adapter 는 프로젝트에 맞게 구현해야 한다.

verifier 의 선택 필드 `requires_env`(문자열 배열)는 사용자가 필수라고 선언한 환경 변수다. 값이 unset 이거나 빈 문자열이면 그 verifier 는 미완료가 되어 일반 실행에서 건너뛴다. 이 필드가 없는 기존 설정은 그대로 동작한다. 제공 프리셋 `api`·`cli`·`react-web` 에 들어 있다.

`requires_env` 의 `URL` 같은 실행 주소와 앱을 띄우는 명령은 `PROJECT_CONTEXT.md` 의 `## Run` 절에서 찾는다. 그 절이 비어 있으면 추측하지 않고 사용자에게 묻는다.

### 1. verifier 목록 확인

`rd-workflow/config/verification.json`에서 verifier 목록을 읽고 사용자에게 제시한다:

```
실행할 verifier:
1. [✓] lighthouse — 성능/접근성
2. [✓] playwright — 디자인/UI
3. [✓] axe — 접근성

제외할 번호를 입력하세요 (예: 2,3 또는 Enter로 전체 실행):
```

사용자가 번호를 입력하면 해당 verifier를 `--skip`으로 제외한다.

### 2. verify.sh 실행

`CURRENT_TASK.md`의 `Verify`를 `in-progress`로 갱신한다.

```bash
bash rd-workflow/extensions/verify/verify.sh --all                    # 전체 실행
bash rd-workflow/extensions/verify/verify.sh --skip playwright,axe     # 제외 항목 있으면
```

결과를 확인한다:
- 성공한 verifier: review pipeline으로 평가 진행
- 실패한 verifier / adapter 없음: 사용자에게 수동 확인 체크리스트로 제시

### 3. 검증 루프 시작

성공한 verifier 결과가 있으면 review pipeline을 시작한다:

```bash
bash rd-workflow/scripts/init_review_pipeline.sh "verify-review" "verify-review" ".verification/latest/" "verification.json의 criteria와 evaluate 프롬프트를 기준으로 도구 실행 결과를 평가하고, 3점 미만 항목의 구체적 개선사항을 제시하라."
```

Author 턴을 작성한다:
- `.verification/latest/` 결과 요약 (run ID 명시)
- verification.json의 criteria + evaluate 프롬프트 제시
- spec의 Verification Criteria 중 자동 검증 항목과 결과 매핑

Reviewer 턴을 실행한다:
```bash
bash rd-workflow/scripts/run_review_turn.sh <session-path>
```

### 4. 반복

Reviewer가 개선사항을 제시하면:
1. 코드 수정
2. `bash rd-workflow/extensions/verify/verify.sh --all` 재실행
3. 새 결과로 Author 턴 작성
4. Reviewer 재평가

Reviewer가 "이의 없음"을 명시하면 루프 종료.

### 5. 수동 확인 항목

도구 실행이 실패하거나 adapter가 없는 항목은:
- spec의 Verification Criteria에서 해당 항목을 추출
- 사용자에게 수동 확인 체크리스트로 제시
- 사용자 확인 후 진행
- 수동 확인 항목이 하나라도 미확인인 동안은 `Verify=in-progress` 유지
- 고친 기능을 어디서 확인할지(URL·entry ID·명령·테스트 계정 이름)는 `PROJECT_CONTEXT.md` 의 `## Feature Entry Paths` 절에서 찾는다. 그 절에 없으면 사용자에게 묻고, 답을 그 절에 적자고 제안한다.

## 상태 관리

`CURRENT_TASK.md`의 `## Verify` 필드로 상태를 관리한다.

| 값 | 의미 |
|----|------|
| `-` | 아직 판단 전 |
| `not-required` | verification.json 없음 — skip |
| `passed` | 검증 통과 |
| `in-progress` | 검증 루프 진행 중 |

- verification.json 없으면 `not-required` 기록 후 즉시 종료
- 루프 시작 시 `in-progress` 기록
- 모든 자동+수동 항목이 해결된 후에만 `passed`로 전환
- 수동 확인 항목이 하나라도 미확인인 동안은 `in-progress` 유지

## 종료

- `CURRENT_TASK.md`의 `Verify`를 `passed`로 갱신
- Notes에 verify 세션 경로 기록
- `Next recommended skill: /final-diff-review`
