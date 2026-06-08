# Subagent Git 안전 가이드

subagent-driven-development으로 dispatch한 subagent는 **공유 git 워킹트리**에서 실행된다. subagent가 브랜치를 전환하면 진행 중인 fr branch가 바뀌어 메인 세션의 REQUEST.md/CURRENT_TASK.md/FR items가 baseline 상태로 노출된다. 이 가이드는 그 교란을 막는 단일 출처다.

## 1. Subagent Git 안전 문구 (dispatch prompt 삽입용)

subagent를 dispatch할 때 아래 문구를 dispatch prompt에 **그대로 포함**한다:

> 이 작업은 공유 git 워킹트리에서 실행됩니다. `git checkout` / `git switch` / `git branch` / `git worktree` 등 브랜치·작업트리를 전환하거나 생성/삭제하는 명령을 절대 실행하지 마십시오. git은 읽기 전용(`git log` / `git diff` / `git show` / `git status` / `git rev-parse`)으로만 사용하십시오. 브랜치 전환이 필요하다고 판단되면 실행하지 말고 그 사실을 결과에 보고하십시오. commit은 메인 세션이 수행합니다.

이 문구는 **advisory**다 — LLM이 무시할 수 있다. 구조적 차단은 2번(worktree 격리)만 보장한다.

## 2. worktree 격리 권장 (선택)

`isolation: "worktree"`(Claude Code Agent 도구의 파라미터)로 격리한 subagent는 공유 워킹트리와 물리적으로 분리되어 git 전환 교란을 구조적으로 차단한다. 단, 격리 worktree는 **commit된 branch 상태만** 복제하므로 메인 워킹트리의 unstaged/uncommitted 변경과 미추적 파일은 보이지 않는다.

- **적합**: 검토 대상이 commit된 branch 상태로 충분한 read-only 탐색/리뷰/감사.
- **부적합 / 대안**: 미커밋 변경·미추적 파일을 검토해야 하면, 격리 worktree에 diff/context를 명시 전달하거나 격리를 쓰지 않고 1번 강제 문구만 적용한다.

이번 단계에서는 강제하지 않는다. 전면 강제·cleanup/naming/concurrent 정책 설계는 후속 FR `subagent-worktree-isolation-enforce`에서 다룬다.

## 3. 사고 감지·복구 절차

subagent dispatch 후 워킹트리가 교란된 것으로 의심되면:

1. **현재 브랜치 확인**: `git rev-parse --abbrev-ref HEAD` — 의도한 fr branch가 아니면 교란 발생.
2. **커밋 보존 확인**: `git log --oneline -5 <fr-branch>` 와 `git reflog` — 작업이 commit돼 있으면 손실 없음.
3. **미커밋 변경 확인**: 전환 전 미커밋 변경이 있으면 `git status` / `git stash list`로 확인한다. 미커밋 변경이 있으면 `git switch`가 거부할 수 있으니 먼저 commit하거나 stash한다.
4. **복구**: `git switch <fr-branch>` — 워킹트리를 원래 fr branch로 되돌린다. stash했다면 복귀 후 `git stash pop`으로 복원한다.

대부분의 경우 모든 작업이 commit돼 있어 `git switch`만으로 손실 없이 복구된다.

## 4. 적용 대상 (본 repo 통제 dispatch 지점)

아래 dispatch 지점은 subagent dispatch 시 1번의 Subagent Git 안전 문구를 dispatch prompt에 포함한다.

- `CLAUDE.md` 실행 모드 규칙 (subagent-driven-development 기본 dispatch)
- `rd-workflow/claude_skills/autopilot/SKILL.md` (§4 자율 구현)
- `rd-workflow/claude_skills/implement-reviewed-plan/SKILL.md`
- `rd-workflow/claude_skills/comprehensive-audit/SKILL.md` (Phase 2 Explore dispatch)

외부 superpowers skill(`subagent-driven-development`, `using-git-worktrees`)은 본 repo에서 직접 수정할 수 없으므로, 위 통제 지점에서 dispatch prompt에 1번 문구를 주입하는 방식으로 우회한다.
