#!/usr/bin/env bash
# Lifecycle 공통 함수 — git 상태 / remote 검출 / metadata I/O / branch ref helpers

LIFECYCLE_METADATA_PATH="${LIFECYCLE_METADATA_PATH:-rd-workflow-workspace/.lifecycle/active-fr}"

# detect_remote_mode: stdout = "remote" | "local-only"
detect_remote_mode() {
  if [[ -n "${RD_LIFECYCLE_NO_REMOTE:-}" ]]; then printf 'local-only\n'; return 0; fi
  if git remote get-url origin >/dev/null 2>&1; then printf 'remote\n'; else printf 'local-only\n'; fi
}

# ensure_worktree_clean: exit 0 if clean, 1 if dirty
ensure_worktree_clean() {
  if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then return 0; fi
  return 1
}

# resolve_unique_ref <kind=branch|tag> <base>: 충돌 시 -N suffix 적용한 ref 반환
resolve_unique_ref() {
  local kind="$1" base="$2"
  local ref_prefix
  case "$kind" in
    branch) ref_prefix="refs/heads/" ;;
    tag) ref_prefix="refs/tags/" ;;
    *) printf 'resolve_unique_ref: unknown kind: %s\n' "$kind" >&2; return 1 ;;
  esac
  local candidate="$base"
  local n=2
  # cap at base-100 to prevent runaway loops (Nit N2)
  while git rev-parse --verify "${ref_prefix}${candidate}" >/dev/null 2>&1; do
    [[ $n -gt 100 ]] && { printf 'resolve_unique_ref: too many collisions for %s\n' "$base" >&2; return 1; }
    candidate="${base}-${n}"
    n=$((n+1))
  done
  printf '%s\n' "$candidate"
}

# main worktree path 검출 — whitespace-safe full-line extraction
get_main_worktree_path() {
  local p
  p="$(git worktree list --porcelain | awk '
    /^worktree /{p=$0; sub(/^worktree /,"",p); next}
    $0=="branch refs/heads/main"{print p; exit}
  ')"
  if [[ -z "$p" ]]; then
    printf 'get_main_worktree_path: no worktree on refs/heads/main\n' >&2
    return 1
  fi
  printf '%s\n' "$p"
}

# Lifecycle metadata I/O (key=value lines)
metadata_read_field() {
  local key="$1"
  # Returns empty stdout if file missing OR key missing OR value empty.
  # Callers should use metadata_exists() + [[ -n "$val" ]] for full check.
  [[ -f "$LIFECYCLE_METADATA_PATH" ]] || return 0
  awk -F'=' -v k="$key" '$1==k{sub(/^[^=]+=/,""); print; exit}' "$LIFECYCLE_METADATA_PATH"
}

metadata_write() {
  local fr_branch="$1" short_title="$2" worktree_path="$3"
  if [[ "$fr_branch" == *$'\n'* || "$short_title" == *$'\n'* || "$worktree_path" == *$'\n'* ]]; then
    printf 'metadata_write: values must not contain newlines\n' >&2; return 1
  fi
  mkdir -p "$(dirname "$LIFECYCLE_METADATA_PATH")"
  cat > "$LIFECYCLE_METADATA_PATH" <<EOF
fr-branch=$fr_branch
short-title=$short_title
worktree-path=${worktree_path:-null}
created-at=$(date +%Y-%m-%d-%H%M)
status=active
EOF
}

metadata_clear() {
  [[ -f "$LIFECYCLE_METADATA_PATH" ]] && rm -f "$LIFECYCLE_METADATA_PATH"
  return 0
}

metadata_exists() {
  [[ -f "$LIFECYCLE_METADATA_PATH" ]]
}

# CURRENT_TASK.md baseline form (Reviewer Turn 008 Issue 2 — runtime accessible inline heredoc)
emit_current_task_baseline() {
  cat <<'EOF'
# Current Task

## Task
-

## Short Title
-

## Status
대기 중

## Request
[REQUEST.md](REQUEST.md)

## Spec
-

## Plan
-

## Branch / Worktree
main

## Next Step
-

## Notes
-
EOF
}

# === loop-guard state (safeguard-autopilot-loop-detection) ===
LOOP_STATE_PATH="${LOOP_STATE_PATH:-rd-workflow-workspace/.lifecycle/loop-state}"

# 키 검증: [A-Za-z0-9_:./-]+ 만 허용 (개행 / '=' 금지)
_loop_state_valid_key() {
  case "$1" in
    "" ) return 1 ;;
    *[!A-Za-z0-9_:./-]* ) return 1 ;;
    * ) return 0 ;;
  esac
}

# loop_state_get <key> → stdout 정수 (미존재 0)
loop_state_get() {
  local key="$1" v
  [[ -f "$LOOP_STATE_PATH" ]] || { printf '0\n'; return 0; }
  v="$(awk -F'=' -v k="$key" '$1==k{print $2; exit}' "$LOOP_STATE_PATH")"
  if [[ "$v" =~ ^[0-9]+$ ]]; then printf '%s\n' "$v"; else printf '0\n'; fi
}

# loop_state_record <key> <incr|reset>
loop_state_record() {
  local key="$1" op="$2" cur new tmp
  if ! _loop_state_valid_key "$key"; then
    printf 'loop_state_record: invalid key: %s\n' "$key" >&2; return 1
  fi
  cur="$(loop_state_get "$key")"
  case "$op" in
    incr) new=$((cur + 1)) ;;
    reset) new=0 ;;
    *) printf 'loop_state_record: unknown op: %s\n' "$op" >&2; return 1 ;;
  esac
  mkdir -p "$(dirname "$LOOP_STATE_PATH")"
  tmp="$(mktemp "$(dirname "$LOOP_STATE_PATH")/.loop-state.XXXXXX")"
  if [[ -f "$LOOP_STATE_PATH" ]]; then
    awk -F'=' -v k="$key" -v val="$new" '
      $1==k {print k"="val; found=1; next}
      {print}
      END{if(!found) print k"="val}
    ' "$LOOP_STATE_PATH" > "$tmp"
  else
    printf '%s=%s\n' "$key" "$new" > "$tmp"
  fi
  mv "$tmp" "$LOOP_STATE_PATH"
}

# within-attempt 키만 제거 (verify-fail::, reedit::). rollback:: 보존.
loop_state_clear_attempt() {
  local tmp
  [[ -f "$LOOP_STATE_PATH" ]] || return 0
  tmp="$(mktemp "$(dirname "$LOOP_STATE_PATH")/.loop-state.XXXXXX")"
  awk -F'=' '$1 !~ /^(verify-fail::|reedit::)/' "$LOOP_STATE_PATH" > "$tmp"
  mv "$tmp" "$LOOP_STATE_PATH"
}

# 전체 상태 제거 (FR 종결)
loop_state_clear_all() {
  [[ -f "$LOOP_STATE_PATH" ]] && rm -f "$LOOP_STATE_PATH"
  return 0
}

LOOP_GUARD_CONFIG="${LOOP_GUARD_CONFIG:-rd-workflow/config/loop-guard.json}"

# enabled (default true). enabled=false면 return 1
loop_guard_enabled() {
  local v
  if [[ -f "$LOOP_GUARD_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
    v="$(jq -r '.enabled' "$LOOP_GUARD_CONFIG" 2>/dev/null || echo true)"
    [[ "$v" == "false" ]] && return 1
  fi
  return 0
}

# loop_guard_threshold <signal> → 정수 (기본 3)
loop_guard_threshold() {
  local signal="$1" v
  if [[ -f "$LOOP_GUARD_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
    v="$(jq -r --arg s "$signal" '.thresholds[$s] // empty' "$LOOP_GUARD_CONFIG" 2>/dev/null || true)"
    if [[ "$v" =~ ^[0-9]+$ ]]; then printf '%s\n' "$v"; return 0; fi
  fi
  printf '3\n'
}

# loop_guard_check [slug] → 임계 초과 시 사유 stdout + return 1, 아니면 return 0
# slug 미지정 시 metadata short-title 사용. slug 없으면 판정 대상 없음 → return 0.
# 현재 slug 키만 판정한다 (FR scoping — Reviewer turn 002 Finding 1).
loop_guard_check() {
  loop_guard_enabled || return 0
  [[ -f "$LOOP_STATE_PATH" ]] || return 0
  local slug="${1:-}"
  [[ -z "$slug" ]] && slug="$(metadata_read_field short-title 2>/dev/null || true)"
  [[ -z "$slug" || "$slug" == "-" ]] && return 0
  local th_vf th_rb th_re half max_vf=0 reasons="" k v
  th_vf="$(loop_guard_threshold verify_fail)"
  th_rb="$(loop_guard_threshold rollback)"
  th_re="$(loop_guard_threshold reedit)"
  half=$(( (th_vf + 1) / 2 ))   # ceil(th_vf/2)
  local vf_pfx="verify-fail::${slug}::" re_pfx="reedit::${slug}::" rb_key="rollback::${slug}"
  # 1패스: 현재 slug 의 verify-fail / rollback
  while IFS='=' read -r k v; do
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    case "$k" in
      "$vf_pfx"*)
        if (( v > max_vf )); then max_vf=$v; fi
        if (( v >= th_vf )); then reasons="${reasons}검증 연속 실패 ${k#"$vf_pfx"}=$v (임계 $th_vf)"$'\n'; fi
        ;;
      "$rb_key")
        if (( v >= th_rb )); then reasons="${reasons}반복 rollback ${slug}=$v (임계 $th_rb)"$'\n'; fi
        ;;
    esac
  done < "$LOOP_STATE_PATH"
  # 2패스: 현재 slug 의 reedit 결합 조건 (reedit≥임계 AND max verify-fail ≥ ceil(임계/2))
  while IFS='=' read -r k v; do
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    case "$k" in
      "$re_pfx"*)
        if (( v >= th_re )) && (( max_vf >= half )); then
          reasons="${reasons}동일 파일 churn ${k#"$re_pfx"}=$v (임계 $th_re) + 검증 실패 동반"$'\n'
        fi
        ;;
    esac
  done < "$LOOP_STATE_PATH"
  if [[ -n "$reasons" ]]; then printf '%s' "$reasons"; return 1; fi
  return 0
}
