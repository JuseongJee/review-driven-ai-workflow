---
name: final-diff-review
description: Prepare final handoff after implementation by checking verification status, drafting PR text, and orchestrating the final Codex diff review until the branch is ready to merge or the user must decide.
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

Execution rules:
- If verification has not been run yet, run `bash ai/scripts/ai/test.sh`, `bash ai/scripts/ai/lint.sh`, and `bash ai/scripts/ai/typecheck.sh` first when possible.
- Draft the PR description with `ai/docs/templates/PR_TEMPLATE.md`.
- Start the final diff review with `bash ai/scripts/ai/prepare_review_pipeline.sh diff` and continue with `bash ai/scripts/ai/run_review_turn.sh codex ...` until the session reaches `awaiting-user` or the latest Codex turn has no objections.
- Update `CURRENT_TASK.md` if the task status changes.

Final output:
- Verification status
- PR summary status
- final diff review session path
- merge readiness or the exact user decision still needed
