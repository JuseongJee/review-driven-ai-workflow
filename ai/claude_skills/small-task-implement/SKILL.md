---
name: small-task-implement
description: Implement a small-task change directly from REQUEST.md and PROJECT_CONTEXT.md, keep the change tightly scoped, run verification scripts, and update CURRENT_TASK.md. Use when the task is clearly a small-task.
disable-model-invocation: true
---

# Small Task Implement

Use this only when the user explicitly designated the task as `small-task`. Do NOT use this based on AI's own judgment about task size.

Read these first (Always Read files are already loaded):
- `ai/docs/prompts/examples/implement_small_task.md`

Typical user requests can be short:
- "small-task로 보고 바로 구현해줘"
- "이거 작은 수정으로 처리해줘"

Execution rules:
- **구현 시작 전 `REQUEST.md`의 Acceptance Criteria를 읽는다.** AC가 비어있거나(`-`) 모호하면 구현을 시작하지 않고 사용자에게 확인을 요청한다.
- Keep the change small and direct.
- Do not introduce unnecessary structure or speculative refactors.
- If the task no longer looks like a `small-task`, stop and recommend `/request-to-reviewed-plan`.
- Update `CURRENT_TASK.md`.
- Run `bash ai/scripts/ai/test.sh`, `bash ai/scripts/ai/lint.sh`, and `bash ai/scripts/ai/typecheck.sh` unless the repository clearly lacks one of them.
- **구현 완료 후 반드시 `/final-diff-review`로 넘긴다. 이 단계를 건너뛰고 merge하거나 작업을 종료하지 않는다.**

Final output:
- What changed
- Verification status
- `Next recommended skill: /final-diff-review` (필수 — 건너뛸 수 없음)
- Any blocker that still needs user input
