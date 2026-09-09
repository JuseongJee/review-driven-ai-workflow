---
name: implement-reviewed-plan
description: Implement code from the latest reviewed spec and plan, follow CLAUDE.md execution mode rules for subagent-driven-development or executing-plans, update CURRENT_TASK.md, and run verification scripts. Requires a reviewed spec and plan (spec / plan review converged); run /request-to-reviewed-plan first if they do not exist.
---

# Implement Reviewed Plan

`manual` 모드에서는 사용자의 단계 진입 지시 없이 이 skill 을 스스로 시작하지 않는다. 판정 기준은 `rd-workflow/docs/flows/AUTONOMY.md` 의 「실행 모드와 skill 호출 권한」 절이다.

Use this when reviewed spec / plan work is done and implementation is the next step.

Typical user request:
- "implement-reviewed-plan skill로 진행해줘"

Read these first (Always Read files are already loaded):
- latest spec from `rd-workflow-workspace/specs/base/` or `rd-workflow-workspace/specs/changes/`
- latest plan from `rd-workflow-workspace/plans/`

Execution rules:
- 이 skill 은 `CURRENT_TASK.md` 의 `## Short Title` 을 read-only 로 사용한다 (변경 / 삭제 금지). short-title 은 작업 시작 시점 (`/fr add`, `planning-design-intake`, 또는 `promote.sh` 승격) 에 1회 부여되고 archive 까지 immutable 이다.
- If there is no credible reviewed spec / plan yet, stop and recommend `/request-to-reviewed-plan`.
- **구현 시작 전 `REQUEST.md`의 Acceptance Criteria를 읽는다.** AC가 비어있거나(`-`) 모호하면 구현을 시작하지 않고 사용자에게 확인을 요청한다.
- **Superpowers가 사용 가능하면 반드시 사용한다.** CLAUDE.md 실행 모드 규칙에 따라 `subagent-driven-development` 또는 `executing-plans`를 선택한다. 사용 불가능할 때만 직접 구현한다.
- `subagent-driven-development` 선택 시 worktree가 가능하면 `using-git-worktrees`와 함께 사용한다.
- subagent dispatch 시 `rd-workflow/docs/guides/subagent-git-safety.md`의 Subagent Git 안전 문구를 dispatch prompt에 포함한다 (공유 워킹트리 git 전환 금지, read-only git만 허용).
- **model-strategy 적용**: `rd-workflow/config/model-strategy.json`이 존재하면 `subagent` 값을 읽어 subagent dispatch 시 Agent 도구의 `model` 파라미터로 전달한다. 파일 미존재/JSON 파싱 실패/키 누락/허용되지 않은 값(`opus`, `sonnet`, `haiku` 외) → 기본값 `"sonnet"`을 사용한다. 설정 형식 상세는 `/model-strategy` skill 참조.
- Update `CURRENT_TASK.md`.
- Run `bash rd-workflow/scripts/test.sh`, `bash rd-workflow/scripts/lint.sh`, `bash rd-workflow/scripts/typecheck.sh`, and `bash rd-workflow/scripts/build.sh`.
- **구현 완료 후 커밋 전 재분류를 거쳐 `/final-diff-review`로 넘긴다 (`standard`·`full` 필수). 이 단계를 건너뛰고 merge하거나 작업을 종료하지 않는다.**

Final output:
- Implementation summary
- Verification summary
- Remaining risks or blockers
- `Next recommended skill: /final-diff-review` (`standard`·`full` 필수)
