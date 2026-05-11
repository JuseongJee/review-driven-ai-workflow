#!/usr/bin/env bash
# test_overlay_branch_sync.sh — fixture-based automated tests for overlay_branch_sync.sh (T1)
# and install_overlay_branch_sync.sh (T2).
# 33 scenarios. Does NOT use -e so individual failures do not abort the run.
set -uo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
BODY="$SCRIPT_DIR/overlay_branch_sync.sh"
INSTALLER=$(cd "$SCRIPT_DIR/.." && pwd -P)/install_overlay_branch_sync.sh

TEST_PASS=0
TEST_FAIL=0
TEST_NAMES_FAILED=()

# All fixture dirs created during run; cleaned at EXIT
ALL_FIXTURES=()

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
cleanup() {
  local fx
  for fx in "${ALL_FIXTURES[@]:-}"; do
    [ -n "$fx" ] && [ -d "$fx" ] && rm -rf "$fx"
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Fixture creation helper
# ---------------------------------------------------------------------------
make_fixture() {
  local fx
  fx=$(mktemp -d)
  ALL_FIXTURES+=("$fx")

  mkdir -p "$fx/team" "$fx/overlay"

  # ---- overlay repo ----
  # Try -b main; fall back for older git
  (cd "$fx/overlay" && git init -q -b main 2>/dev/null) || \
    (cd "$fx/overlay" && git init -q && git checkout -q -b main 2>/dev/null)

  (cd "$fx/overlay" \
    && git config user.name t \
    && git config user.email t@t \
    && printf 'overlay\n' > CLAUDE.md \
    && git add CLAUDE.md \
    && git commit -q -m init \
    && rm CLAUDE.md \
    && mkdir rd-workflow \
    && printf 'rd-workflow\n' > rd-workflow/README.md \
    && printf 'overlay\n' > CLAUDE.md \
    && git add . \
    && git commit -q -m "add rd-workflow dir")

  # ---- team repo ----
  (cd "$fx/team" && git init -q -b main 2>/dev/null) || \
    (cd "$fx/team" && git init -q && git checkout -q -b main 2>/dev/null)

  (cd "$fx/team" \
    && git config user.name t \
    && git config user.email t@t \
    && printf 'team\n' > README.md \
    && ln -s "$fx/overlay/CLAUDE.md"    CLAUDE.md \
    && ln -s "$fx/overlay/rd-workflow"  rd-workflow \
    && git add README.md \
    && git commit -q -m init)

  printf '%s\n' "$fx"
}

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------
assert_eq() {
  # $1=expected  $2=actual  $3=msg
  if [ "$1" = "$2" ]; then return 0; fi
  printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$3" "$1" "$2" >&2
  return 1
}

assert_branch_eq() {
  # $1=repo  $2=expected_branch  $3=msg
  local actual
  actual=$(git -C "$1" symbolic-ref --short HEAD 2>/dev/null || printf 'DETACHED\n')
  assert_eq "$2" "$actual" "$3"
}

assert_branch_unchanged() {
  assert_branch_eq "$1" "$2" "$3"
}

assert_contains() {
  # $1=haystack  $2=needle  $3=msg
  case "$1" in *"$2"*) return 0 ;; esac
  printf 'FAIL: %s\n  text: %s\n  missing: %s\n' "$3" "$1" "$2" >&2
  return 1
}

assert_file_contains() {
  # $1=file  $2=needle  $3=msg
  local content
  content=$(cat "$1" 2>/dev/null || true)
  assert_contains "$content" "$2" "$3"
}

assert_not_contains() {
  # $1=haystack  $2=needle  $3=msg
  case "$1" in
    *"$2"*) printf 'FAIL: %s\n  text should NOT contain: %s\n' "$3" "$2" >&2; return 1 ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------
run_test() {
  local name="$1" fn="$2"
  if "$fn"; then
    TEST_PASS=$((TEST_PASS + 1))
    printf 'PASS: %s\n' "$name"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    TEST_NAMES_FAILED+=("$name")
    printf 'FAIL: %s\n' "$name"
  fi
}

# ---------------------------------------------------------------------------
# ---- BODY SCRIPT TESTS (T01–T16) ----
# ---------------------------------------------------------------------------

# T01: overlay already has feat/foo branch — body checks it out
test_01_happy_path_existing_branch() {
  local fx
  fx=$(make_fixture)
  # pre-create feat/foo in overlay
  git -C "$fx/overlay" checkout -q -b feat/foo
  git -C "$fx/overlay" checkout -q main
  # switch team to feat/foo
  git -C "$fx/team" checkout -q -b feat/foo
  # run body from team root
  (cd "$fx/team" && bash "$BODY") 2>/dev/null
  assert_branch_eq "$fx/overlay" feat/foo "T01: overlay should be on feat/foo"
}

# T02: overlay has only main; body auto-creates feat/bar
test_02_auto_create() {
  local fx
  fx=$(make_fixture)
  git -C "$fx/team" checkout -q -b feat/bar
  (cd "$fx/team" && bash "$BODY") 2>/dev/null
  assert_branch_eq "$fx/overlay" feat/bar "T02: overlay should auto-create feat/bar"
}

# T03: overlay and team both on main — already on same branch → noop
test_03_same_branch_noop() {
  local fx
  fx=$(make_fixture)
  local stderr_out
  stderr_out=$((cd "$fx/team" && bash "$BODY") 2>&1)
  assert_branch_eq "$fx/overlay" main "T03: overlay should stay on main" || return 1
  assert_contains "$stderr_out" "already on main" "T03: stderr should contain 'already on main'"
}

# T04: overlay has unstaged change — body must skip
test_04_dirty_unstaged() {
  local fx
  fx=$(make_fixture)
  git -C "$fx/team" checkout -q -b feat/baz
  # make overlay dirty (unstaged)
  printf 'dirty\n' > "$fx/overlay/somefile.txt"
  git -C "$fx/overlay" add somefile.txt
  printf 'dirty-again\n' > "$fx/overlay/somefile.txt"  # unstaged change on tracked file
  local stderr_out
  stderr_out=$((cd "$fx/team" && bash "$BODY") 2>&1)
  assert_branch_unchanged "$fx/overlay" main "T04: overlay should not change branch" || return 1
  assert_contains "$stderr_out" "overlay is dirty" "T04: stderr should mention dirty"
}

# T05: overlay has untracked file — body must skip
test_05_dirty_untracked() {
  local fx
  fx=$(make_fixture)
  git -C "$fx/team" checkout -q -b feat/baz
  # create untracked file in overlay
  printf 'untracked\n' > "$fx/overlay/untracked.txt"
  local stderr_out
  stderr_out=$((cd "$fx/team" && bash "$BODY") 2>&1)
  assert_branch_unchanged "$fx/overlay" main "T05: overlay should not change branch" || return 1
  assert_contains "$stderr_out" "overlay is dirty" "T05: stderr should mention dirty"
}

# T06: team has detached HEAD — body should skip with msg, exit 0
test_06_detached_head_team() {
  local fx
  fx=$(make_fixture)
  local commit_hash
  commit_hash=$(git -C "$fx/team" rev-parse HEAD)
  git -C "$fx/team" checkout -q "$commit_hash" 2>/dev/null
  local stderr_out ec
  stderr_out=$((cd "$fx/team" && bash "$BODY") 2>&1); ec=$?
  assert_eq "0" "$ec" "T06: exit code should be 0" || return 1
  assert_contains "$stderr_out" "detached HEAD" "T06: stderr should mention detached HEAD" || return 1
  assert_branch_unchanged "$fx/overlay" main "T06: overlay should stay on main"
}

# T07: overlay has no commits — body should skip
# Team must be on a DIFFERENT branch than the overlay's default HEAD so that the
# body reaches the "branch does not exist" path where the no-commits check lives.
test_07_overlay_no_commits() {
  local fx
  fx=$(make_fixture)

  # Create a fresh overlay with NO commits
  local empty_overlay
  empty_overlay=$(mktemp -d)
  ALL_FIXTURES+=("$empty_overlay")
  (cd "$empty_overlay" && git init -q -b main 2>/dev/null) || \
    (cd "$empty_overlay" && git init -q)

  # Switch team to a branch that does NOT exist in the empty overlay (not "main").
  # Without this, body hits Step 6 "already on main" before reaching the no-commits check.
  git -C "$fx/team" checkout -q -b feat/nocommit

  local stderr_out ec
  stderr_out=$((cd "$fx/team" && bash "$BODY" "$empty_overlay") 2>&1); ec=$?
  assert_eq "0" "$ec" "T07: exit code should be 0" || return 1
  assert_contains "$stderr_out" "no commits yet" "T07: stderr should mention no commits"
}

# T08: no symlinks in team repo — body should skip
test_08_auto_detect_no_symlink() {
  local fx
  fx=$(make_fixture)
  # Replace symlinks with regular files
  rm "$fx/team/CLAUDE.md" "$fx/team/rd-workflow"
  printf 'regular\n' > "$fx/team/CLAUDE.md"
  mkdir -p "$fx/team/rd-workflow"
  local stderr_out
  stderr_out=$((cd "$fx/team" && bash "$BODY") 2>&1)
  assert_contains "$stderr_out" "no overlay symlink found" "T08: stderr should mention no symlink"
}

# T09: symlinks point to two different repos — ambiguous
test_09_auto_detect_ambiguous() {
  local fx
  fx=$(make_fixture)

  # Create a second overlay
  local overlay_b
  overlay_b="$fx/overlay-b"
  mkdir -p "$overlay_b"
  (cd "$overlay_b" && git init -q -b main 2>/dev/null) || \
    (cd "$overlay_b" && git init -q)
  (cd "$overlay_b" \
    && git config user.name t \
    && git config user.email t@t \
    && printf 'overlay-b\n' > CLAUDE_b.md \
    && mkdir rd-workflow \
    && printf 'b\n' > rd-workflow/README.md \
    && git add . \
    && git commit -q -m init)

  # CLAUDE.md → overlay-a, rd-workflow → overlay-b
  rm "$fx/team/CLAUDE.md" "$fx/team/rd-workflow"
  ln -s "$fx/overlay/CLAUDE.md"     "$fx/team/CLAUDE.md"
  ln -s "$overlay_b/rd-workflow"    "$fx/team/rd-workflow"

  local stderr_out
  stderr_out=$((cd "$fx/team" && bash "$BODY") 2>&1)
  assert_contains "$stderr_out" "ambiguous overlay" "T09: stderr should mention ambiguous"
}

# T10: symlinks point back into team repo itself
test_10_overlay_same_as_team() {
  local fx
  fx=$(make_fixture)

  # Replace symlinks to point back inside team
  rm "$fx/team/CLAUDE.md" "$fx/team/rd-workflow"
  printf 'self\n' > "$fx/team/self.txt"
  git -C "$fx/team" add self.txt
  git -C "$fx/team" -c user.name=t -c user.email=t@t commit -q -m "add self"
  ln -s "$fx/team/self.txt"   "$fx/team/CLAUDE.md"
  mkdir -p "$fx/team/rd-workflow"
  ln -s "$fx/team/rd-workflow" "$fx/team/rd-workflow-link" 2>/dev/null || true
  # Simplest: put CLAUDE.md pointing into team's own file
  local stderr_out
  stderr_out=$((cd "$fx/team" && bash "$BODY") 2>&1)
  assert_contains "$stderr_out" "same repo" "T10: stderr should mention same repo"
}

# T11: overlay has origin/HEAD → origin/main; auto-create feat/x from main
test_11_base_origin_HEAD() {
  local fx
  fx=$(make_fixture)

  # Simulate origin/HEAD symbolic ref pointing to origin/main
  # We do this by creating a bare remote and configuring origin/HEAD
  local bare
  bare="$fx/bare"
  git clone -q --bare "$fx/overlay" "$bare" 2>/dev/null
  git -C "$fx/overlay" remote add origin "$bare" 2>/dev/null || true
  git -C "$fx/overlay" fetch -q origin 2>/dev/null || true
  git -C "$fx/overlay" remote set-head origin main 2>/dev/null || \
    git -C "$fx/overlay" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main 2>/dev/null || true

  git -C "$fx/team" checkout -q -b feat/x
  (cd "$fx/team" && bash "$BODY") 2>/dev/null
  assert_branch_eq "$fx/overlay" feat/x "T11: overlay should be on feat/x (from origin/HEAD base)"
}

# T12: overlay has only local main (no remote) — new branch created from main
test_12_base_main_fallback() {
  local fx
  fx=$(make_fixture)
  # Confirm no remote on overlay
  git -C "$fx/overlay" remote remove origin 2>/dev/null || true
  git -C "$fx/team" checkout -q -b feat/y
  (cd "$fx/team" && bash "$BODY") 2>/dev/null
  assert_branch_eq "$fx/overlay" feat/y "T12: overlay should be on feat/y (from main fallback)"
}

# T13: overlay has only master branch — body creates main from master
test_13_base_master_fallback() {
  local fx
  fx=$(make_fixture)
  # Rename main → master in overlay
  git -C "$fx/overlay" checkout -q -b master
  git -C "$fx/overlay" branch -D main 2>/dev/null || true
  # Team is on main; overlay has only master
  (cd "$fx/team" && bash "$BODY") 2>/dev/null
  assert_branch_eq "$fx/overlay" main "T13: overlay should have new 'main' branch from master"
}

# T14: overlay has no main/master — body should warn and skip
test_14_base_no_main_no_master() {
  local fx
  fx=$(make_fixture)
  # Rename main → dev in overlay
  git -C "$fx/overlay" checkout -q -b dev
  git -C "$fx/overlay" branch -D main 2>/dev/null || true
  git -C "$fx/team" checkout -q -b some-feature
  local stderr_out ec
  stderr_out=$((cd "$fx/team" && bash "$BODY") 2>&1); ec=$?
  assert_eq "0" "$ec" "T14: exit code should be 0" || return 1
  assert_contains "$stderr_out" "cannot determine overlay base branch" "T14: stderr should mention cannot determine base"
}

# T15: wrapper invoked with $3=0 (file-mode checkout) — body must NOT be called
test_15_post_checkout_file_mode() {
  local fx
  fx=$(make_fixture)

  # Install the wrapper
  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null
  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac

  # Switch team to feat/pcf in overlay first so any unwanted sync would be detectable
  git -C "$fx/overlay" checkout -q main

  # Invoke post-checkout with $3=0 (file mode)
  local old_sha new_sha
  old_sha=$(git -C "$fx/team" rev-parse HEAD)
  new_sha="$old_sha"
  (cd "$fx/team" && bash "$hooks_dir/post-checkout" "$old_sha" "$new_sha" 0) 2>/dev/null

  # overlay should NOT have moved
  assert_branch_unchanged "$fx/overlay" main "T15: overlay should stay on main when file-mode checkout"
}

# T16: wrapper (post-merge) when team and overlay on same branch — noop
test_16_post_merge_same_branch() {
  local fx
  fx=$(make_fixture)

  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null
  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac

  # Both team and overlay on main already
  local stderr_out
  stderr_out=$((cd "$fx/team" && bash "$hooks_dir/post-merge" 0) 2>&1)
  assert_contains "$stderr_out" "already on main" "T16: post-merge noop should log 'already on main'"
}

# ---------------------------------------------------------------------------
# ---- INSTALLER TESTS (T17–T24) ----
# ---------------------------------------------------------------------------

# T17: install auto-detect (no args) — hooks created with empty OVERLAY_PATH, executable
test_17_install_auto_detect() {
  local fx
  fx=$(make_fixture)

  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null

  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac

  local pc="$hooks_dir/post-checkout"
  local pm="$hooks_dir/post-merge"

  [ -f "$pc" ] || { printf 'FAIL: T17: post-checkout not found\n' >&2; return 1; }
  [ -f "$pm" ] || { printf 'FAIL: T17: post-merge not found\n' >&2; return 1; }
  [ -x "$pc" ] || { printf 'FAIL: T17: post-checkout not executable\n' >&2; return 1; }
  [ -x "$pm" ] || { printf 'FAIL: T17: post-merge not executable\n' >&2; return 1; }
  assert_file_contains "$pc" '# >>> overlay-branch-sync >>>' "T17: post-checkout marker" || return 1
  assert_file_contains "$pm" '# >>> overlay-branch-sync >>>' "T17: post-merge marker"
}

# T18: install with --overlay /abs/path — OVERLAY_PATH in hook matches
test_18_install_overlay_path() {
  local fx
  fx=$(make_fixture)

  (cd "$fx/team" && bash "$INSTALLER" --overlay "$fx/overlay") 2>/dev/null

  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac

  local pc="$hooks_dir/post-checkout"
  assert_file_contains "$pc" "OVERLAY_PATH=\"$fx/overlay\"" "T18: post-checkout has correct OVERLAY_PATH"
}

# T19: idempotent reinstall — no duplicate marker block, second run no-op
test_19_idempotent_reinstall() {
  local fx
  fx=$(make_fixture)

  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null
  local out2
  out2=$((cd "$fx/team" && bash "$INSTALLER") 2>&1)

  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac

  # Count marker starts — should be exactly 1
  local count_pc count_pm
  count_pc=$(grep -cF '# >>> overlay-branch-sync >>>' "$hooks_dir/post-checkout" || true)
  count_pm=$(grep -cF '# >>> overlay-branch-sync >>>' "$hooks_dir/post-merge" || true)

  assert_eq "1" "$count_pc" "T19: only one marker block in post-checkout" || return 1
  assert_eq "1" "$count_pm" "T19: only one marker block in post-merge" || return 1
  assert_contains "$out2" "no-op" "T19: second install should report no-op"
}

# T20: auto install then --overlay reinstall — OVERLAY_PATH updated
test_20_auto_then_overlay_reinstall() {
  local fx
  fx=$(make_fixture)

  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null
  (cd "$fx/team" && bash "$INSTALLER" --overlay "$fx/overlay") 2>/dev/null

  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac

  assert_file_contains "$hooks_dir/post-checkout" "OVERLAY_PATH=\"$fx/overlay\"" "T20: OVERLAY_PATH updated"
}

# T21: --overlay /nonexistent — exit non-zero, error message
test_21_invalid_overlay_path() {
  local fx
  fx=$(make_fixture)

  local stderr_out ec
  stderr_out=$((cd "$fx/team" && bash "$INSTALLER" --overlay /nonexistent/path/xyz) 2>&1); ec=$?
  assert_eq "1" "$ec" "T21: exit code should be 1 for nonexistent overlay" || return 1
  assert_contains "$stderr_out" "does not exist" "T21: stderr should mention does not exist"
}

# T22: install then --uninstall — marker blocks removed
test_22_uninstall() {
  local fx
  fx=$(make_fixture)

  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null
  (cd "$fx/team" && bash "$INSTALLER" --uninstall) 2>/dev/null

  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac

  local count_pc count_pm
  count_pc=$(grep -cF '# >>> overlay-branch-sync >>>' "$hooks_dir/post-checkout" 2>/dev/null || true)
  count_pm=$(grep -cF '# >>> overlay-branch-sync >>>' "$hooks_dir/post-merge" 2>/dev/null || true)

  assert_eq "0" "$count_pc" "T22: marker block removed from post-checkout" || return 1
  assert_eq "0" "$count_pm" "T22: marker block removed from post-merge"
}

# T23: --uninstall when no block exists — exit 0, message
test_23_uninstall_no_block() {
  local fx
  fx=$(make_fixture)

  local out ec
  out=$((cd "$fx/team" && bash "$INSTALLER" --uninstall) 2>&1); ec=$?
  assert_eq "0" "$ec" "T23: uninstall with no block should exit 0" || return 1
  # Should mention no block found (either "no overlay-branch-sync block" or "not found" / "does not exist")
  assert_contains "$out" "no overlay-branch-sync block" "T23: output should indicate no block found"
}

# T24: core.hooksPath set to a path different from .git/hooks — installer must refuse (exit non-zero)
# and print both options: manually install at core.hooksPath, or unset core.hooksPath.
test_24_core_hookspath_conflict() {
  local fx
  fx=$(make_fixture)

  git -C "$fx/team" config core.hooksPath /tmp/different-not-real

  local stderr_out ec
  stderr_out=$((cd "$fx/team" && bash "$INSTALLER") 2>&1); ec=$?
  assert_eq "1" "$ec" "T24: installer must exit non-zero on core.hooksPath conflict" || return 1
  assert_contains "$stderr_out" "core.hooksPath" "T24: stderr must mention core.hooksPath" || return 1
  # Must show both options: manually install (option a) and unset (option b)
  assert_contains "$stderr_out" "Manually" "T24: stderr must offer manual-install option" || return 1
  assert_contains "$stderr_out" "unset" "T24: stderr must offer unset option"
}

# ---------------------------------------------------------------------------
# ---- ADDITIONAL SCENARIOS (T25–T33) ----
# ---------------------------------------------------------------------------

# T25: pre-existing hook content preserved; marker block appended
test_25_preserve_existing_hook_content() {
  local fx
  fx=$(make_fixture)

  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac
  mkdir -p "$hooks_dir"

  # Pre-create post-checkout with user content
  printf '#!/bin/sh\necho "user hook"\n' > "$hooks_dir/post-checkout"
  chmod +x "$hooks_dir/post-checkout"

  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null

  local content
  content=$(cat "$hooks_dir/post-checkout")
  assert_contains "$content" 'echo "user hook"' "T25: user content preserved" || return 1
  assert_contains "$content" '# >>> overlay-branch-sync >>>' "T25: marker block appended"
}

# T26: end-to-end — install wrapper, then real git checkout triggers body
test_26_end_to_end_git_checkout() {
  local fx
  fx=$(make_fixture)

  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null

  # Create the target branch in team, do actual git checkout
  git -C "$fx/team" checkout -q -b feat/e2e

  # The post-checkout hook should have fired and synced overlay
  assert_branch_eq "$fx/overlay" feat/e2e "T26: overlay branch synced via real git checkout"
}

# T27: Installer run from inside a git worktree.
# git's actual worktree hook execution uses the SHARED .git/hooks dir (via --git-common-dir),
# NOT a worktree-specific subdirectory like .git/worktrees/<name>/hooks/.
# This test verifies the installer correctly resolves the shared hooks dir from inside a worktree
# and places the wrapper hooks there.
test_27_worktree() {
  local fx
  fx=$(make_fixture)

  # Create a worktree
  local wt_path="$fx/team-wt"
  git -C "$fx/team" worktree add -b feat/wt "$wt_path" 2>/dev/null

  # Run installer from inside worktree
  (cd "$wt_path" && bash "$INSTALLER") 2>/dev/null

  # The worktree's git path for hooks should be used
  local wt_hooks_dir
  wt_hooks_dir=$(git -C "$wt_path" rev-parse --git-path hooks 2>/dev/null || true)
  case "$wt_hooks_dir" in /*) ;; *) wt_hooks_dir="$wt_path/$wt_hooks_dir" ;; esac

  [ -f "$wt_hooks_dir/post-checkout" ] || { printf 'FAIL: T27: post-checkout not in worktree hooks dir\n' >&2; return 1; }
  assert_file_contains "$wt_hooks_dir/post-checkout" '# >>> overlay-branch-sync >>>' "T27: marker in worktree hook"
}

# T28: core.hooksPath = .git/hooks (exact default string) — installer succeeds
test_28_hookspath_dot_git_hooks() {
  local fx
  fx=$(make_fixture)

  git -C "$fx/team" config core.hooksPath .git/hooks

  local ec
  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null; ec=$?
  assert_eq "0" "$ec" "T28: .git/hooks hooksPath should not conflict"
}

# T29: core.hooksPath = .git/hooks/ (trailing slash) — installer succeeds
test_29_hookspath_dot_git_hooks_trailing_slash() {
  local fx
  fx=$(make_fixture)

  git -C "$fx/team" config core.hooksPath ".git/hooks/"

  local ec
  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null; ec=$?
  assert_eq "0" "$ec" "T29: trailing slash hooksPath should not conflict"
}

# T30: core.hooksPath = absolute path to .git/hooks — installer succeeds
test_30_hookspath_absolute() {
  local fx
  fx=$(make_fixture)

  local abs_hooks="$fx/team/.git/hooks"
  git -C "$fx/team" config core.hooksPath "$abs_hooks"

  local ec
  (cd "$fx/team" && bash "$INSTALLER") 2>/dev/null; ec=$?
  assert_eq "0" "$ec" "T30: absolute path to .git/hooks should not conflict"
}

# T31: core.hooksPath set to a clearly different absolute path — installer must refuse (exit non-zero)
# and emit a hint. Distinct from T24 by using a different path string (/tmp/custom-hooks).
test_31_hookspath_real_conflict() {
  local fx
  fx=$(make_fixture)

  git -C "$fx/team" config core.hooksPath /tmp/custom-hooks

  local stderr_out ec
  stderr_out=$((cd "$fx/team" && bash "$INSTALLER") 2>&1); ec=$?
  assert_eq "1" "$ec" "T31: installer must exit non-zero on core.hooksPath=/tmp/custom-hooks conflict" || return 1
  assert_contains "$stderr_out" "core.hooksPath" "T31: stderr must mention core.hooksPath"
}

# T32: run installer from a subdirectory — hooks installed in team root .git/hooks/
test_32_subdir_install() {
  local fx
  fx=$(make_fixture)

  mkdir -p "$fx/team/subdir"
  (cd "$fx/team/subdir" && bash "$INSTALLER") 2>/dev/null

  local hooks_dir
  hooks_dir=$(git -C "$fx/team" rev-parse --git-path hooks)
  case "$hooks_dir" in /*) ;; *) hooks_dir="$fx/team/$hooks_dir" ;; esac

  [ -f "$hooks_dir/post-checkout" ] || { printf 'FAIL: T32: hook not in team root hooks dir\n' >&2; return 1; }
  assert_file_contains "$hooks_dir/post-checkout" '# >>> overlay-branch-sync >>>' "T32: marker in team root hook"
}

# T33: when realpath is genuinely unavailable, body falls back to POSIX cd -P and still syncs.
# Tests the body's actual fallback path by building a PATH that excludes any directory containing
# an executable realpath. If realpath and git share a directory (common on Linux in /usr/bin),
# stripping that dir would also remove git, breaking the test body. In that case the test SKIPs
# (counted as pass) to avoid false failures on Linux.
test_33_realpath_fallback() {
  local fx
  fx=$(make_fixture)

  # Set up: overlay has branch feat/test33 already
  (cd "$fx/overlay" && git checkout -q -b feat/test33 main && git checkout -q main) || return 1

  # Switch team to feat/test33
  git -C "$fx/team" checkout -q -b feat/test33

  # Build a PATH that excludes all directories containing an executable realpath.
  local stripped_path=""
  local OLD_IFS="$IFS"
  IFS=':'
  for d in $PATH; do
    IFS="$OLD_IFS"
    if [ -x "$d/realpath" ]; then
      IFS=':'
      continue  # skip dirs that contain realpath
    fi
    if [ -z "$stripped_path" ]; then
      stripped_path="$d"
    else
      stripped_path="$stripped_path:$d"
    fi
    IFS=':'
  done
  IFS="$OLD_IFS"

  # If realpath was not on PATH at all, keep PATH as-is (fallback is already the only path).
  if [ -z "$stripped_path" ]; then
    stripped_path="$PATH"
  fi

  # Verify git is still findable in stripped_path (fails on Linux when realpath and git share /usr/bin).
  local git_found=0
  IFS=':'
  for d in $stripped_path; do
    IFS="$OLD_IFS"
    if [ -x "$d/git" ]; then
      git_found=1
      break
    fi
    IFS=':'
  done
  IFS="$OLD_IFS"

  if [ "$git_found" -ne 1 ]; then
    # realpath and git share a PATH directory — cannot isolate realpath without removing git.
    # Skip the test and count it as pass to avoid false failures on Linux.
    printf 'SKIP: T33 — realpath and git share a PATH directory; cannot test fallback in isolation\n' >&2
    return 0
  fi

  # Run body with stripped PATH (realpath should be unavailable in the subshell).
  local stderr_out
  stderr_out=$(cd "$fx/team" && PATH="$stripped_path" /bin/bash "$BODY" 2>&1 >/dev/null)

  # Body should have used POSIX fallback to resolve symlinks, then synced overlay to feat/test33.
  assert_branch_eq "$fx/overlay" "feat/test33" "T33: overlay synced to feat/test33 via realpath fallback (stderr was: $stderr_out)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  printf '=== overlay_branch_sync tests ===\n\n'

  run_test "01 happy path existing branch"      test_01_happy_path_existing_branch
  run_test "02 auto create from main"           test_02_auto_create
  run_test "03 same branch noop"                test_03_same_branch_noop
  run_test "04 dirty unstaged"                  test_04_dirty_unstaged
  run_test "05 dirty untracked"                 test_05_dirty_untracked
  run_test "06 detached HEAD team"              test_06_detached_head_team
  run_test "07 overlay no commits"              test_07_overlay_no_commits
  run_test "08 auto detect no symlink"          test_08_auto_detect_no_symlink
  run_test "09 auto detect ambiguous"           test_09_auto_detect_ambiguous
  run_test "10 overlay same as team"            test_10_overlay_same_as_team
  run_test "11 base origin HEAD"                test_11_base_origin_HEAD
  run_test "12 base main fallback"              test_12_base_main_fallback
  run_test "13 base master fallback"            test_13_base_master_fallback
  run_test "14 base no main no master"          test_14_base_no_main_no_master
  run_test "15 post-checkout file mode"         test_15_post_checkout_file_mode
  run_test "16 post-merge same branch noop"     test_16_post_merge_same_branch
  run_test "17 install auto detect"             test_17_install_auto_detect
  run_test "18 install overlay path"            test_18_install_overlay_path
  run_test "19 idempotent reinstall"            test_19_idempotent_reinstall
  run_test "20 auto then overlay reinstall"     test_20_auto_then_overlay_reinstall
  run_test "21 invalid overlay path"            test_21_invalid_overlay_path
  run_test "22 uninstall"                       test_22_uninstall
  run_test "23 uninstall no block"              test_23_uninstall_no_block
  run_test "24 core.hooksPath conflict"         test_24_core_hookspath_conflict
  run_test "25 preserve existing hook content"  test_25_preserve_existing_hook_content
  run_test "26 end to end git checkout"         test_26_end_to_end_git_checkout
  run_test "27 worktree"                        test_27_worktree
  run_test "28 hooksPath dot-git-hooks"         test_28_hookspath_dot_git_hooks
  run_test "29 hooksPath trailing slash"        test_29_hookspath_dot_git_hooks_trailing_slash
  run_test "30 hooksPath absolute"              test_30_hookspath_absolute
  run_test "31 hooksPath real conflict"         test_31_hookspath_real_conflict
  run_test "32 subdir install"                  test_32_subdir_install
  run_test "33 realpath fallback"               test_33_realpath_fallback

  printf '\n--- Test Summary ---\n'
  printf 'Passed: %d\n' "$TEST_PASS"
  printf 'Failed: %d\n' "$TEST_FAIL"
  if [ "$TEST_FAIL" -gt 0 ]; then
    printf 'Failed tests:\n'
    local name
    for name in "${TEST_NAMES_FAILED[@]:-}"; do
      printf '  - %s\n' "$name"
    done
    exit 1
  fi
  printf 'ALL TESTS PASSED\n'
  exit 0
}
main "$@"
