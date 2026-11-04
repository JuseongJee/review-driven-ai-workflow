---
name: implement-reviewed-plan
description: Implement code from the latest reviewed spec and plan, follow .claude/rules/rd-workflow/core.md execution mode rules for subagent-driven-development or executing-plans, update CURRENT_TASK.md, and run verification scripts. Requires a reviewed spec and plan (spec / plan review converged); run /request-to-reviewed-plan first if they do not exist.
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
- **착수 전 Status 확인**: 구현을 시작하기 전에 `bash rd-workflow/scripts/rd task status` 로 현재 Status 를 읽고 아래 표대로 처리한다. 전이표가 `대기 중 → 구현 중` 직행을 허용해도 그것을 spec/plan review 를 건너뛴 근거로 쓰지 않는다. 전이는 리뷰가 실제로 끝났다는 증거가 있을 때만 기록하며, `--force` 로 우회하지 않는다. 이 전이들은 되돌릴 수 있는 로컬 작업이므로 묻지 않고 진행한다. **구현을 새로 시작하는 모든 경로(`구현 대기` 포함)는 어떤 전이·구현보다 먼저 아래 증거를 검사한다.**

  | 진입 Status | 처리 |
  |---|---|
  | `구현 대기` | 증거를 먼저 검사한다. 유효하면 구현 착수 직전에 `bash rd-workflow/scripts/rd task set-status "구현 중"` 을 실행하고 진행한다. 무효이면(예: 종결 뒤 skill 밖에서 spec 이 수정됨) 상태·구현 모두 바꾸지 않고 「증거가 무효일 때」를 따른다 |
  | `대기 중` · `REQUEST review 대기` · `spec/plan review 대기` | 증거를 먼저 검사한다. 유효하면 `request-to-reviewed-plan` 의 `## Status 전이` 표에서 남은 전이를 순서대로 실행해 `구현 대기` 로 맞춘 뒤 `구현 중` 으로 전이한다. 무효이면 상태·구현 모두 바꾸지 않고 「증거가 무효일 때」를 따른다 |
  | `구현 중` | 이미 착수한 재개이므로 증거를 다시 검사하지 않고 전이 없이 진행한다. 착수 뒤 spec/plan 변경이 필요해지면 `구현 중` → `spec/plan 작성 중` 으로 되돌려 `/request-to-reviewed-plan` 으로 보낸다 |
  | `spec/plan 작성 중` | 재작업 중이므로 구현하지 않고 `/request-to-reviewed-plan` 을 안내하며 중단한다. 아래 복구 (나) 는 이 값에 적용하지 않는다 |
  | `검증 중` · `diff review 대기` · `아카이브 보류` | 이 skill 의 착수 지점이 아니므로 상태를 바꾸지 않고 현재 단계의 skill 을 안내한다 |

  **유효한 증거** — 두 조건을 모두 만족해야 하며 하나라도 불명확하면 무효다.
  1. `CURRENT_TASK.md` `## Notes` 에 `spec/plan review 종결:` 기록이 있고, 그 세션 `SESSION.md` 의 `Review Target` 이 `CURRENT_TASK.md` 의 `## Spec`·`## Plan` 경로와 같으며, 그 세션 최신 Reviewer 턴이 `이의 없음` 을 명시한다.
  2. 현재 `git hash-object <spec> <plan>` 출력이 그 기록의 `spec=`·`plan=` 값과 같다 (미커밋 파일도 같은 방식으로 비교한다. 커밋·파일 시각은 쓰지 않는다).

  **증거가 무효일 때** 구현하지 않고 상태도 바꾸지 않은 채 사용자에게 보고하고 재리뷰를 안내한다: `/request-to-reviewed-plan` 으로 재리뷰해 종결 기록을 새로 남긴다. 기록의 해시와 현재 해시가 다르면(승인 뒤 내용 변경) 재리뷰만 길이다.

  **복구 (나) — 기록만 없는 기존 작업 한정.** 아래를 모두 만족할 때만 사용자에게 "그 리뷰 이후 spec/plan 이 바뀌지 않았다" 확인을 받아 진행할 수 있다: Notes 에 `spec/plan review 종결:` 기록이 없고, `Review Target` 이 현재 Spec·Plan 과 같은 spec/plan review 세션이 있으며 그 최신 Reviewer 턴이 `이의 없음` 이고, 현재 Status 가 `spec/plan 작성 중` 이 아니다. 사용자가 확인하면 skill 은 **정상 종결 기록과 같은 형식**으로 `spec/plan review 종결: <그 세션 경로> | spec=<hash> | plan=<hash> | 사용자 확인: <사유>` 를 Notes 에 남기고, 이후 검사는 같은 규칙(조건 1·2)으로 소비하므로 재진입에서 다시 묻지 않는다. 리뷰를 하지 않았거나 수렴하지 않았거나 이의가 남았으면 사용자 확인으로 대신하지 않고 재리뷰로 보낸다. 자율 모드는 이 확인을 스스로 하지 않는다.
- **구현 시작 전 `REQUEST.md`의 Acceptance Criteria를 읽는다.** AC가 비어있거나(`-`) 모호하면 구현을 시작하지 않고 사용자에게 확인을 요청한다.
- **Superpowers가 사용 가능하면 반드시 사용한다.** `.claude/rules/rd-workflow/core.md` 실행 모드 규칙에 따라 `subagent-driven-development` 또는 `executing-plans`를 선택한다. 사용 불가능할 때만 직접 구현한다.
- `subagent-driven-development` 선택 시 worktree가 가능하면 `using-git-worktrees`와 함께 사용한다.
- subagent dispatch 시 `rd-workflow/docs/guides/subagent-git-safety.md`의 Subagent Git 안전 문구를 dispatch prompt에 포함한다 (공유 워킹트리 git 전환 금지, read-only git만 허용).
- 다단계·파괴적 상태 task 는 `rd-workflow/docs/guides/subagent-git-safety.md` 1-2 의 진행 기록 문구와 보고서 경로를 함께 dispatch prompt에 넣는다.
- **변이 확인**: plan 의 task 에 `변이:` 줄이 있으면 dispatch prompt 에 그 줄을 그대로 넣고, 구현자가 `rd-workflow/docs/guides/mutation-check.md` 「절차」대로 주입·원복해 결과표 행(실제 출력 포함)을 결과로 반환하게 한다. 출력 없는 "확인했다" 는 받지 않는다. task review 는 `검증됨` 행이 유효 증거 4조건을 지키는지 점검하고, `생존` 행은 그 task 의 결함으로 되돌린다. 필수 대상 단언을 만들거나 바꾸는 task 인데 `변이:` 줄이 없으면 구현 전에 plan 결함으로 보고한다.
- **model-strategy 적용**: `rd-workflow/config/model-strategy.json`이 존재하면 `subagent` 값을 읽어 subagent dispatch 시 Agent 도구의 `model` 파라미터로 전달한다. 파일 미존재/JSON 파싱 실패/키 누락/허용되지 않은 값(`opus`, `sonnet`, `haiku` 외) → 기본값 `"sonnet"`을 사용한다. 설정 형식 상세는 `/model-strategy` skill 참조.
- Update `CURRENT_TASK.md`.
- Run `bash rd-workflow/scripts/test.sh`, `bash rd-workflow/scripts/lint.sh`, `bash rd-workflow/scripts/typecheck.sh`, and `bash rd-workflow/scripts/build.sh`.
- **구현 완료 후 커밋 전 재분류를 거쳐 `/final-diff-review`로 넘긴다 (`standard`·`full` 필수). 이 단계를 건너뛰고 merge하거나 작업을 종료하지 않는다.**

Final output:
- Implementation summary
- Verification summary
- Remaining risks or blockers
- `Next recommended skill: /final-diff-review` (`standard`·`full` 필수)

## rd-workflow 버전 대조

이 skill 은 아래 `RD_SKILL_BASE` 보다 나중에 배포된 rd-workflow 를 전제한다. 첫 작업 단계보다 먼저, 프로젝트 루트에서 아래 명령을 이 호출에서 한 번 실행한다.

- 출력이 없으면 그대로 진행한다.
- 출력이 있으면 출력 전문을 사용자에게 알리고, 템플릿을 sync 할지 그대로 계속할지 묻고 멈춘다. 사용자가 계속을 지시하면 진행한다.
- autopilot·무인 실행처럼 물을 사람이 없으면 계속하지 않고 그 출력을 중단 사유로 보고한다.

```bash
bash -s <<'RD_SKILL_COMPAT'
RD_SKILL_BASE=2026-11-01-202303 RD_SKILL_NAME=implement-reviewed-plan
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
