---
name: request-to-reviewed-plan
description: Create REQUEST.md from free-text requirements, run REQUEST review, write spec or change spec and plan, and run spec / plan review until the task is ready for implementation. Use for new features and non-trivial existing code changes.
disable-model-invocation: true
---

# Request To Reviewed Plan

Use this when the user wants to start a non-trivial task from a free-text requirement.

Canonical workflow:
- `ai/docs/prompts/recovery/request_to_reviewed_plan_full.md`

Read these first (Always Read files are already loaded):
- `ai/docs/prompts/recovery/request_to_reviewed_plan_full.md`

Typical user requests can be short:
- "이 요구사항으로 request-to-reviewed-plan skill로 진행해줘"
- "큰 작업으로 보고 reviewed plan까지 만들어줘"

Execution rules:
- Keep the original scope. Do not widen the request.
- Ask only when a missing fact is required to create `REQUEST.md` or to choose the execution path safely.
- 사용자가 명시적으로 `small-task`로 지정한 경우에만 spec / plan 흐름을 중단하고 `/small-task-implement`를 추천한다. AI가 자체적으로 small-task로 재분류하지 않는다.
- If `Execution Path` is `existing-code-change` or `new-feature-or-large-task`, continue through request review, spec or change spec, plan, and spec / plan review.
- Use `bash ai/scripts/ai/prepare_review_pipeline.sh request` and `bash ai/scripts/ai/run_review_turn.sh ...` for `REQUEST` review.
- Use `bash ai/scripts/ai/prepare_review_pipeline.sh spec-plan` or the explicit spec / plan paths plus `bash ai/scripts/ai/run_review_turn.sh ...` for spec / plan review.
- **Superpowers가 사용 가능하면 반드시 `brainstorming`과 `writing-plans`를 사용한다.** 사용 불가능할 때만 같은 산출물을 직접 작성한다.
- UI 작업인 경우 spec에 `## Design Reference` 섹션을 포함한다. 내용: 참고 앱/화면 URL, 스크린샷, 스타일 방향. 비UI 작업이면 이 섹션을 생략한다.
- Update `CURRENT_TASK.md` at the major checkpoints.
- Stop before implementation.

Final output:
- `Execution Path`
- `REQUEST.md` status
- spec path
- plan path
- request review session path
- spec / plan review session path
- `Next recommended skill: /design-review` (큰 작업) or `/small-task-implement` (작은 작업)
- Any remaining user question, only if it is actually blocking
