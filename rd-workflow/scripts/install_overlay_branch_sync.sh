#!/usr/bin/env bash
# install_overlay_branch_sync.sh — idempotent installer for overlay-branch-sync git hooks
# Adds wrapper blocks to team repo's .git/hooks/post-checkout and post-merge.
# Usage: install_overlay_branch_sync.sh [--overlay <abs-path>] [--uninstall] [-h|--help]
set -euo pipefail

# ---------------------------------------------------------------------------
# Tmpfile cleanup trap (I2)
# ---------------------------------------------------------------------------
_CLEANUP_FILES=()
trap 'rm -f "${_CLEANUP_FILES[@]:-}" 2>/dev/null' EXIT

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
MARKER_START='# >>> overlay-branch-sync >>>'
MARKER_END='# <<< overlay-branch-sync <<<'

# ---------------------------------------------------------------------------
# Helper: print usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: install_overlay_branch_sync.sh [OPTIONS]

Installs wrapper git hooks (post-checkout, post-merge) in the team project
repo that call overlay_branch_sync.sh on branch switches.

OPTIONS:
  --overlay <abs-path>   Absolute path to overlay git repo. Stored in hook wrapper.
                         If omitted, body script auto-detects at runtime.
  --uninstall            Remove overlay-branch-sync marker block from hooks.
  -h, --help             Print this help and exit.

Run from inside the team project repository.
EOF
}

# ---------------------------------------------------------------------------
# Helper: print error to stderr
# ---------------------------------------------------------------------------
err() {
  printf '[overlay-branch-sync] ERROR: %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Helper: print info to stdout
# ---------------------------------------------------------------------------
info() {
  printf '[overlay-branch-sync] %s\n' "$*"
}

# ---------------------------------------------------------------------------
# Helper: normalize a path (make absolute and resolve symlinks if possible)
# Arguments: $1=path, $2=base (used if path is relative)
# Prints normalized path; exits 0 even if path doesn't exist (returns as-is absolute)
# ---------------------------------------------------------------------------
normalize_path() {
  local path="$1"
  local base="$2"

  # Make absolute
  case "$path" in
    /*) ;;
    *)  path="$base/$path" ;;
  esac

  # Strip trailing slash (unless root)
  case "$path" in
    */) path="${path%/}" ;;
  esac

  # Try realpath first
  if command -v realpath >/dev/null 2>&1; then
    if realpath "$path" 2>/dev/null; then
      return 0
    fi
  fi

  # Fallback: cd -P for existing directories
  if [ -d "$path" ]; then
    ( cd -P "$path" 2>/dev/null && pwd -P )
    return 0
  fi

  # Path doesn't exist or is a file — resolve parent directory
  local dir base_name
  dir="$(dirname "$path")"
  base_name="$(basename "$path")"
  if [ -d "$dir" ]; then
    printf '%s/%s\n' "$(cd -P "$dir" 2>/dev/null && pwd -P)" "$base_name"
    return 0
  fi

  # Nothing works — return absolute string as-is
  printf '%s\n' "$path"
}

# ---------------------------------------------------------------------------
# Helper: write marker block content for a given hook kind
# Arguments: $1=kind (post-checkout|post-merge), $2=bin_path, $3=overlay_path
# Prints the marker block (including markers) to stdout
# ---------------------------------------------------------------------------
make_marker_block() {
  local kind="$1"
  local bin_path="$2"
  local overlay_path="$3"

  printf '%s\n' "$MARKER_START"
  printf '# Managed by rd-workflow install_overlay_branch_sync.sh; do not edit between markers.\n'
  printf 'OVERLAY_BRANCH_SYNC_BIN="%s"\n' "$bin_path"
  printf 'OVERLAY_PATH="%s"\n' "$overlay_path"
  if [ "$kind" = "post-checkout" ]; then
    printf 'if [ "${3:-1}" = "1" ]; then\n'
    printf '    "$OVERLAY_BRANCH_SYNC_BIN" "$OVERLAY_PATH" || true\n'
    printf 'fi\n'
  else
    printf '"$OVERLAY_BRANCH_SYNC_BIN" "$OVERLAY_PATH" || true\n'
  fi
  printf '%s\n' "$MARKER_END"
}

# ---------------------------------------------------------------------------
# Helper: check whether a file contains the marker block
# Returns 0 if found, 1 if not found
# ---------------------------------------------------------------------------
has_marker_block() {
  local file="$1"
  grep -qF "$MARKER_START" "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Helper: update a hook file (create / replace-block / append-block)
# Arguments: $1=hook_path, $2=kind (post-checkout|post-merge),
#            $3=bin_path, $4=overlay_path
# Prints action taken: create | update | add-block | no-op
# ---------------------------------------------------------------------------
update_hook() {
  local hook_path="$1"
  local kind="$2"
  local bin_path="$3"
  local overlay_path="$4"

  local new_block tmpfile

  new_block=$(make_marker_block "$kind" "$bin_path" "$overlay_path")

  tmpfile="${hook_path}.overlay-sync-tmp.$$"
  _CLEANUP_FILES+=("$tmpfile")

  # Case 1: file does not exist — create fresh
  if [ ! -e "$hook_path" ]; then
    {
      printf '#!/usr/bin/env bash\n'
      printf '\n'
      printf '%s\n' "$new_block"
    } > "$tmpfile"
    mv "$tmpfile" "$hook_path"
    chmod +x "$hook_path"
    printf 'create\n'
    return 0
  fi

  # Case 2: file exists with marker block — replace block
  if has_marker_block "$hook_path"; then
    # Paired-marker preflight check (I1)
    local start_count end_count
    start_count=$(grep -cF "$MARKER_START" "$hook_path" || true)
    end_count=$(grep -cF "$MARKER_END"   "$hook_path" || true)
    if [ "$start_count" -gt 0 ] && [ "$end_count" -eq 0 ]; then
      err "$hook_path is malformed: MARKER_START found without matching MARKER_END. Fix manually then re-run."
      exit 1
    fi
    if [ "$start_count" -eq 0 ] && [ "$end_count" -gt 0 ]; then
      err "$hook_path is malformed: MARKER_END found without matching MARKER_START. Fix manually then re-run."
      exit 1
    fi

    # no-op check (M1): if existing block is byte-identical to new block, skip write
    local existing_block
    existing_block=$(awk -v s="$MARKER_START" -v e="$MARKER_END" \
      '$0==s{f=1} f{print} $0==e{f=0; exit}' "$hook_path")
    if [ "$existing_block" = "$new_block" ]; then
      printf 'no-op\n'
      return 0
    fi

    # Use awk to replace start-to-end marker block with new content
    # We write new_block to a temp file and read it in awk
    local block_tmpfile
    block_tmpfile="${hook_path}.overlay-sync-block.$$"
    _CLEANUP_FILES+=("$block_tmpfile")
    printf '%s\n' "$new_block" > "$block_tmpfile"

    awk -v marker_start="$MARKER_START" \
        -v marker_end="$MARKER_END" \
        -v block_file="$block_tmpfile" \
    'BEGIN {
        # Read replacement block into an array
        block_count = 0
        while ((getline line < block_file) > 0) {
            block[block_count++] = line
        }
        close(block_file)
        in_block = 0
        replaced = 0
    }
    {
        if (!replaced && $0 == marker_start) {
            in_block = 1
            # Print the replacement block
            for (i = 0; i < block_count; i++) {
                print block[i]
            }
            next
        }
        if (in_block) {
            if ($0 == marker_end) {
                in_block = 0
                replaced = 1
            }
            next
        }
        print
    }' "$hook_path" > "$tmpfile"

    rm -f "$block_tmpfile"
    mv "$tmpfile" "$hook_path"
    chmod +x "$hook_path"
    printf 'update\n'
    return 0
  fi

  # Case 3: file exists but has no marker block — append
  # Determine if we need a leading blank line before the block
  local needs_blank
  needs_blank=1
  if [ -s "$hook_path" ]; then
    # Use awk to check if file ends with an empty line
    needs_blank=$(awk 'END { if (NR > 0 && $0 == "") print 0; else print 1 }' "$hook_path")
  fi

  {
    cat "$hook_path"
    if [ "$needs_blank" = "1" ]; then
      printf '\n'
    fi
    printf '%s\n' "$new_block"
  } > "$tmpfile"

  mv "$tmpfile" "$hook_path"
  chmod +x "$hook_path"
  printf 'add-block\n'
}

# ---------------------------------------------------------------------------
# Helper: remove marker block from a hook file
# Arguments: $1=hook_path
# Returns action: removed | not-found | no-file
# ---------------------------------------------------------------------------
remove_hook_block() {
  local hook_path="$1"

  if [ ! -e "$hook_path" ]; then
    printf 'no-file\n'
    return 0
  fi

  if ! has_marker_block "$hook_path"; then
    printf 'not-found\n'
    return 0
  fi

  local tmpfile
  tmpfile="${hook_path}.overlay-sync-tmp.$$"
  _CLEANUP_FILES+=("$tmpfile")

  # Paired-marker preflight check (I1)
  local block_count end_count
  block_count=$(grep -cF "$MARKER_START" "$hook_path" || true)
  end_count=$(grep -cF "$MARKER_END"   "$hook_path" || true)
  if [ "$block_count" -gt 0 ] && [ "$end_count" -eq 0 ]; then
    err "$hook_path is malformed: MARKER_START found without matching MARKER_END. Fix manually then re-run."
    exit 1
  fi
  if [ "$block_count" -eq 0 ] && [ "$end_count" -gt 0 ]; then
    err "$hook_path is malformed: MARKER_END found without matching MARKER_START. Fix manually then re-run."
    exit 1
  fi

  # Warn about multiple blocks
  if [ "$block_count" -gt 1 ]; then
    printf '[overlay-branch-sync] WARNING: %s has %s marker blocks; removing first only.\n' \
      "$hook_path" "$block_count" >&2
  fi

  # Use awk to remove the FIRST marker block only
  awk -v marker_start="$MARKER_START" \
      -v marker_end="$MARKER_END" \
  'BEGIN {
      in_block = 0
      removed = 0
  }
  {
      if (!removed && $0 == marker_start) {
          in_block = 1
          next
      }
      if (in_block) {
          if ($0 == marker_end) {
              in_block = 0
              removed = 1
          }
          next
      }
      print
  }' "$hook_path" > "$tmpfile"

  mv "$tmpfile" "$hook_path"
  # Keep file executable if it was before
  chmod +x "$hook_path"
  printf 'removed\n'
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
OVERLAY_PATH=""
DO_UNINSTALL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --overlay)
      if [ "$#" -lt 2 ]; then
        err "--overlay requires an argument"
        usage >&2
        exit 2
      fi
      OVERLAY_PATH="$2"
      shift 2
      ;;
    --uninstall)
      DO_UNINSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Step 2: Determine TEAM_ROOT
# ---------------------------------------------------------------------------
TEAM_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || true
if [ -z "$TEAM_ROOT" ]; then
  err "Run from inside the team project repo."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 3: Resolve HOOKS_DIR (repo-root-anchored, worktree-safe)
# Use --git-common-dir (not --git-path hooks) so that core.hooksPath is NOT
# honoured here. --git-path hooks returns core.hooksPath when set, which would
# make the conflict-detection below compare core.hooksPath against itself
# (always equal, never fires). --git-common-dir returns the shared .git dir
# for both normal repos and worktrees, and ignores core.hooksPath.
# ---------------------------------------------------------------------------
GIT_COMMON_DIR=$(git -C "$TEAM_ROOT" rev-parse --git-common-dir 2>/dev/null) || true
if [ -z "$GIT_COMMON_DIR" ]; then
  err "could not determine git common dir"
  exit 1
fi

# If GIT_COMMON_DIR is relative, anchor it to TEAM_ROOT
case "$GIT_COMMON_DIR" in
  /*) ;;
  *) GIT_COMMON_DIR="$TEAM_ROOT/$GIT_COMMON_DIR" ;;
esac

HOOKS_DIR="$GIT_COMMON_DIR/hooks"

# ---------------------------------------------------------------------------
# Step 4: core.hooksPath conflict detection (normalized path comparison)
# ---------------------------------------------------------------------------
core_hooks=$(git -C "$TEAM_ROOT" config --get core.hooksPath 2>/dev/null || true)
if [ -n "$core_hooks" ]; then
  canonical_hooks_dir=$(normalize_path "$HOOKS_DIR" "$TEAM_ROOT")
  canonical_core_hooks=$(normalize_path "$core_hooks" "$TEAM_ROOT")
  if [ "$canonical_hooks_dir" != "$canonical_core_hooks" ]; then
    err "core.hooksPath conflict detected."
    printf '[overlay-branch-sync] core.hooksPath raw:       %s\n' "$core_hooks" >&2
    printf '[overlay-branch-sync] core.hooksPath canonical: %s\n' "$canonical_core_hooks" >&2
    printf '[overlay-branch-sync] hooks dir raw:            %s\n' "$HOOKS_DIR" >&2
    printf '[overlay-branch-sync] hooks dir canonical:      %s\n' "$canonical_hooks_dir" >&2
    printf '[overlay-branch-sync]\n' >&2
    printf '[overlay-branch-sync] Options:\n' >&2
    printf '[overlay-branch-sync]   (a) Manually install the wrapper at: %s\n' "$core_hooks" >&2
    printf '[overlay-branch-sync]   (b) Run: git -C "%s" config --unset core.hooksPath\n' "$TEAM_ROOT" >&2
    printf '[overlay-branch-sync]       then re-run this installer.\n' >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Step 5: Validate --overlay path if provided
# ---------------------------------------------------------------------------
if [ -n "$OVERLAY_PATH" ]; then
  case "$OVERLAY_PATH" in
    /*)
      ;;
    *)
      err "overlay path is not absolute: $OVERLAY_PATH"
      exit 1
      ;;
  esac
  if [ ! -d "$OVERLAY_PATH" ]; then
    err "overlay path does not exist or is not a directory: $OVERLAY_PATH"
    exit 1
  fi
  if ! git -C "$OVERLAY_PATH" rev-parse --show-toplevel >/dev/null 2>&1; then
    err "overlay is not a git repo: $OVERLAY_PATH"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Step 6: Resolve body script absolute path
# ---------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
BODY_REL="hooks/overlay_branch_sync.sh"
BODY_PATH="$SCRIPT_DIR/$BODY_REL"

if [ ! -f "$BODY_PATH" ]; then
  err "body script not found at: $BODY_PATH"
  err "Expected: $BODY_REL relative to installer directory ($SCRIPT_DIR)"
  exit 1
fi

# Resolve to absolute path
if command -v realpath >/dev/null 2>&1; then
  OVERLAY_BRANCH_SYNC_BIN=$(realpath "$BODY_PATH")
else
  OVERLAY_BRANCH_SYNC_BIN=$(cd -P "$(dirname "$BODY_PATH")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$BODY_PATH")")
fi

# ---------------------------------------------------------------------------
# Step 7 / 8: Perform install or uninstall
# ---------------------------------------------------------------------------
HOOK_POST_CHECKOUT="$HOOKS_DIR/post-checkout"
HOOK_POST_MERGE="$HOOKS_DIR/post-merge"

# Ensure hooks directory exists
mkdir -p "$HOOKS_DIR"

if [ "$DO_UNINSTALL" -eq 1 ]; then
  # Uninstall: remove marker blocks
  action_pc=$(remove_hook_block "$HOOK_POST_CHECKOUT")
  action_pm=$(remove_hook_block "$HOOK_POST_MERGE")

  case "$action_pc" in
    removed)    info "post-checkout: marker block removed" ;;
    not-found)  info "post-checkout: no overlay-branch-sync block found in $HOOK_POST_CHECKOUT" ;;
    no-file)    info "post-checkout: no overlay-branch-sync block in $HOOK_POST_CHECKOUT (file does not exist)" ;;
  esac

  case "$action_pm" in
    removed)    info "post-merge: marker block removed" ;;
    not-found)  info "post-merge: no overlay-branch-sync block found in $HOOK_POST_MERGE" ;;
    no-file)    info "post-merge: no overlay-branch-sync block in $HOOK_POST_MERGE (file does not exist)" ;;
  esac

  info "hooks directory: $HOOKS_DIR"
else
  # Install: add/update wrapper blocks
  action_pc=$(update_hook "$HOOK_POST_CHECKOUT" "post-checkout" "$OVERLAY_BRANCH_SYNC_BIN" "$OVERLAY_PATH")
  action_pm=$(update_hook "$HOOK_POST_MERGE"    "post-merge"    "$OVERLAY_BRANCH_SYNC_BIN" "$OVERLAY_PATH")

  # Step 10: Summary output
  info "hooks directory: $HOOKS_DIR"
  info "post-checkout: $action_pc"
  info "post-merge: $action_pm"
  if [ -n "$OVERLAY_PATH" ]; then
    info "overlay path: $OVERLAY_PATH"
  else
    info "overlay path: auto-detect"
  fi
fi
