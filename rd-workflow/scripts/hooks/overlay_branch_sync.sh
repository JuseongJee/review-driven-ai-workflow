#!/usr/bin/env bash
# overlay_branch_sync.sh — team-overlay branch sync body script
# Invoked by wrapper hooks in team repo's .git/hooks/post-checkout and post-merge.
# Usage: overlay_branch_sync.sh [OVERLAY_PATH]
#   $1 (optional): absolute path to overlay repo. If empty, auto-detect via symlinks.
# Always exits 0. All errors are logged to stderr and skipped gracefully.
set -uo pipefail

# ---------------------------------------------------------------------------
# Helper: log to stderr with prefix
# ---------------------------------------------------------------------------
log() {
  printf '[overlay-sync] %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Helper: resolve symlinks and normalize path (Bash 3.2 + POSIX compatible)
# ---------------------------------------------------------------------------
resolve_path() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
    return
  fi
  # POSIX fallback: follow symlink chain manually (no readlink -f)
  local max=40 target
  [ -e "$path" ] || return 1
  while [ -L "$path" ] && [ "$max" -gt 0 ]; do
    target=$(readlink "$path") || return 1
    case "$target" in
      /*) path="$target" ;;
      *)  path="$(dirname "$path")/$target" ;;
    esac
    max=$((max - 1))
  done
  (cd -P "$(dirname "$path")" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")") || return 1
}

# ---------------------------------------------------------------------------
# Helper: auto-detect overlay repo via symlinked entry points in team root
# ---------------------------------------------------------------------------
auto_detect_overlay() {
  local team_root="$1"
  local toplevels="" candidate path resolved dir toplevel
  local candidates
  candidates=(CLAUDE.md rd-workflow CURRENT_TASK.md REQUEST.md)

  for candidate in "${candidates[@]}"; do
    path="$team_root/$candidate"

    # skip if does not exist
    [ -e "$path" ] || continue

    # skip if not a symlink
    [ -L "$path" ] || continue

    # resolve symlink
    resolved=$(resolve_path "$path") || continue
    [ -n "$resolved" ] || continue

    # get containing dir for git -C
    if [ -d "$resolved" ]; then
      dir="$resolved"
    else
      dir="$(dirname "$resolved")"
    fi

    # get overlay git toplevel
    toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || continue
    [ -n "$toplevel" ] || continue

    # dedup: check if already in list (while IFS= read -r avoids word-split on spaces in paths)
    local already_found=0
    local existing
    while IFS= read -r existing; do
      [ -z "$existing" ] && continue
      if [ "$existing" = "$toplevel" ]; then
        already_found=1
        break
      fi
    done <<EOF
$toplevels
EOF
    if [ "$already_found" -eq 0 ]; then
      if [ -z "$toplevels" ]; then
        toplevels="$toplevel"
      else
        toplevels="$toplevels
$toplevel"
      fi
    fi
  done

  # Count unique toplevels
  local count=0
  local t
  if [ -n "$toplevels" ]; then
    while IFS= read -r t; do
      [ -n "$t" ] && count=$((count + 1))
    done <<EOF
$toplevels
EOF
  fi

  if [ "$count" -eq 0 ]; then
    log "no overlay symlink found in $team_root. Run: bash rd-workflow/scripts/install_overlay_branch_sync.sh --overlay <path>"
    return
  fi

  if [ "$count" -ge 2 ]; then
    local list
    list=$(printf '%s' "$toplevels" | tr '\n' ' ')
    log "ambiguous overlay (candidates point to: $list). Run: bash rd-workflow/scripts/install_overlay_branch_sync.sh --overlay <path>"
    return
  fi

  # exactly 1 unique toplevel
  local sole_toplevel="$toplevels"

  if [ "$sole_toplevel" = "$team_root" ]; then
    log "overlay resolves to same repo as team, skipping"
    return
  fi

  printf '%s\n' "$sole_toplevel"
}

# ---------------------------------------------------------------------------
# Helper: determine base branch in overlay repo
# ---------------------------------------------------------------------------
determine_base_branch() {
  local overlay="$1"
  local ref branch

  # Try origin/HEAD symbolic ref
  ref=$(git -C "$overlay" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || ref=""
  if [ -n "$ref" ]; then
    # strip "origin/" prefix
    branch="${ref#origin/}"
    printf '%s\n' "$branch"
    return
  fi

  # Try refs/heads/main
  if git -C "$overlay" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    printf 'main\n'
    return
  fi

  # Try refs/heads/master
  if git -C "$overlay" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    printf 'master\n'
    return
  fi

  # Could not determine — caller gets empty string via $()
  return
}

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------

# Step 1: Resolve team repo root
TEAM_ROOT=$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null) || TEAM_ROOT=""
if [ -z "$TEAM_ROOT" ]; then
  log "not inside a git repo, skipping"
  exit 0
fi

# Step 2: Get current branch
BRANCH=$(git -C "$TEAM_ROOT" symbolic-ref --short HEAD 2>/dev/null) || BRANCH=""
if [ -z "$BRANCH" ]; then
  log "detached HEAD detected, skipping branch sync"
  exit 0
fi

# Step 3: Determine overlay path
OVERLAY="${1:-}"
if [ -n "$OVERLAY" ]; then
  # Validate provided path
  if [ ! -d "$OVERLAY" ]; then
    log "invalid OVERLAY_PATH: not a directory, skipping"
    exit 0
  fi
  if ! git -C "$OVERLAY" rev-parse --show-toplevel >/dev/null 2>&1; then
    log "invalid OVERLAY_PATH: not a git repo, skipping"
    exit 0
  fi
else
  OVERLAY=$(auto_detect_overlay "$TEAM_ROOT")
  if [ -z "$OVERLAY" ]; then
    # auto_detect_overlay already logged the reason
    exit 0
  fi
fi

# Step 4: Get overlay current branch (may be empty for new repo / detached)
OVERLAY_BRANCH=$(git -C "$OVERLAY" symbolic-ref --short HEAD 2>/dev/null) || OVERLAY_BRANCH=""

# Step 5: Dirty check
STATUS_OUT=$(git -C "$OVERLAY" status --porcelain 2>/dev/null) || STATUS_OUT=""
if [ -n "$STATUS_OUT" ]; then
  log "overlay is dirty, skipping (current: $OVERLAY_BRANCH, target: $BRANCH)"
  exit 0
fi

# Step 6: Already on target branch
if [ "$OVERLAY_BRANCH" = "$BRANCH" ]; then
  log "already on $BRANCH"
  exit 0
fi

# Step 7: Checkout or create branch
if git -C "$OVERLAY" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
  # Branch exists in overlay: checkout
  out=$(git -C "$OVERLAY" -c core.hooksPath=/dev/null checkout "$BRANCH" 2>&1)
  ec=$?
  if [ "$ec" -ne 0 ]; then
    log "checkout $BRANCH FAILED (exit $ec): $out"
  else
    log "checkout $BRANCH: $out"
  fi
else
  # Branch does not exist: check overlay has commits
  if ! git -C "$OVERLAY" rev-parse --verify HEAD >/dev/null 2>&1; then
    log "overlay has no commits yet, skipping"
    exit 0
  fi

  BASE=$(determine_base_branch "$OVERLAY")
  if [ -z "$BASE" ]; then
    log "cannot determine overlay base branch (no origin/HEAD or non-origin remote, no main, no master), skipping"
    exit 0
  fi

  out=$(git -C "$OVERLAY" -c core.hooksPath=/dev/null checkout -b "$BRANCH" "$BASE" 2>&1)
  ec=$?
  if [ "$ec" -ne 0 ]; then
    log "checkout -b $BRANCH $BASE FAILED (exit $ec): $out"
  else
    log "checkout -b $BRANCH $BASE: $out"
  fi
fi

exit 0
