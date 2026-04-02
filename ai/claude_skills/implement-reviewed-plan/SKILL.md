---
name: implement-reviewed-plan
description: Implement code from the latest reviewed spec and plan, prefer Superpowers executing-plans and subagent-driven-development with using-git-worktrees when available, update CURRENT_TASK.md, and run verification scripts.
disable-model-invocation: true
---

# Implement Reviewed Plan

Use this when reviewed spec / plan work is done and implementation is the next step.

Typical user request:
- "implement-reviewed-plan skill로 진행해줘"

Read these first (Always Read files are already loaded):
- latest spec from `ai/docs/superpowers/specs/base/` or `ai/docs/superpowers/specs/changes/`
- latest plan from `ai/docs/superpowers/plans/`

Execution rules:
- If there is no credible reviewed spec / plan yet, stop and recommend `/request-to-reviewed-plan`.
- **구현 시작 전 `REQUEST.md`의 Acceptance Criteria를 읽는다.** AC가 비어있거나(`-`) 모호하면 구현을 시작하지 않고 사용자에게 확인을 요청한다.
- **Superpowers가 사용 가능하면 반드시 `executing-plans`를 사용한다.** 사용 불가능할 때만 직접 구현한다.
- subagent가 사용 가능하면 반드시 `subagent-driven-development`를 사용하고, worktree가 가능하면 `using-git-worktrees`와 함께 사용한다.
- Update `CURRENT_TASK.md`.
- Run `bash ai/scripts/ai/test.sh`, `bash ai/scripts/ai/lint.sh`, and `bash ai/scripts/ai/typecheck.sh`.
- **구현 완료 후 반드시 `/final-diff-review`로 넘긴다. 이 단계를 건너뛰고 merge하거나 작업을 종료하지 않는다.**

Final output:
- Implementation summary
- Verification summary
- Remaining risks or blockers
- `Next recommended skill: /final-diff-review` (필수 — 건너뛸 수 없음)
