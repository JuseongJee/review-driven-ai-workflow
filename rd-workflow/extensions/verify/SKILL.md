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
- small-task나 VC 미기입 작업도 verification.json이 있으면 런타임 검증 대상

## 실행 순서

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
