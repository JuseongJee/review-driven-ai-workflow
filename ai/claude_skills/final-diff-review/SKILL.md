---
name: final-diff-review
description: Prepare final handoff after implementation by checking verification status, drafting PR text, and orchestrating the final diff review until the branch is ready to merge or the user must decide.
disable-model-invocation: true
---

# Final Diff Review

Use this after implementation is done or nearly done.

Typical user request:
- "final-diff-review skill로 진행해줘"

Read these first:
- `CURRENT_TASK.md`
- `ai/docs/templates/PR_TEMPLATE.md`
- `ai/docs/review_prompts/diff_review.md`
- UI 작업이면: `CURRENT_TASK.md`의 Spec 경로에 해당하는 spec의 `## Design Reference` 섹션 (디자인 비교 baseline). Spec 경로가 `-`이거나 해당 spec에 Design Reference가 없으면 디자인 fidelity 검토를 skip한다.
- UI 작업이면: `PROJECT_CONTEXT.md` (플랫폼별 요구사항 확인)

Execution rules:
- `CURRENT_TASK.md`의 Spec 경로가 `-`가 아닌 경우(큰 작업), `Design Review`가 `approved` 또는 `not-required`인지 확인한다. 그렇지 않으면 final diff review를 시작하지 않고 `/design-review`를 먼저 권장한다. Spec 경로가 `-`인 경우(small-task)는 이 확인을 skip한다.
- If verification has not been run yet, run `bash ai/scripts/ai/test.sh`, `bash ai/scripts/ai/lint.sh`, and `bash ai/scripts/ai/typecheck.sh` first when possible.
- Draft the PR description with `ai/docs/templates/PR_TEMPLATE.md`.
- UI 작업인 경우, `CURRENT_TASK.md`의 Spec 경로에 해당하는 spec에 `## Design Reference`가 있으면 구현된 화면의 스크린샷을 사용자에게 요청하거나 직접 첨부하여 디자인 프로토타입과 비교한다. 스크린샷은 final diff review 세션에 함께 포함한다. Spec이 없거나 `Design Reference`가 없는 경우(small-task 등) 디자인 fidelity 검토를 skip하고 일반 diff review만 진행한다.
- Start the final diff review with `bash ai/scripts/ai/prepare_review_pipeline.sh diff` and continue with `bash ai/scripts/ai/run_review_turn.sh ...` until the session reaches `awaiting-user` or the latest Reviewer turn has no objections.
- Update `CURRENT_TASK.md` if the task status changes.

Final output:
- Verification status
- PR summary status
- final diff review session path
- merge readiness or the exact user decision still needed
