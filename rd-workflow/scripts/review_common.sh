#!/usr/bin/env bash
# review_common.sh — 리뷰 파이프라인 공통 함수
# source로 로드하여 사용

set -euo pipefail

resolve_path() {
  local input="$1"
  if [[ "$input" = /* ]]; then
    printf '%s\n' "$input"
  else
    printf '%s\n' "${PROJECT_ROOT:-.}/${input}"
  fi
}

extract_section() {
  local file="$1"
  local section="$2"
  awk -v target="## ${section}" '
    $0 == target { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$file"
}

trim_blank_lines() {
  awk '
    NF { last = NR }
    { lines[NR] = $0 }
    END {
      start = 1
      while (start <= NR && lines[start] ~ /^[[:space:]]*$/) start++
      for (i = start; i <= last; i++) print lines[i]
    }
  '
}

validate_owner_input() {
  local owner="$1"
  case "$owner" in
    Author|Claude|Reviewer|Codex|User)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_owner_output() {
  local owner="$1"
  case "$owner" in
    Author|Claude|User)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# 세션 디렉토리 구조 검증
# 사용: validate_session_dir <session_dir>
# 설정: SESSION_FILE, CHECKPOINT_FILE, USER_ACTION_FILE, TURNS_DIR 변수
validate_session_dir() {
  local session_dir="$1"

  SESSION_FILE="${session_dir}/SESSION.md"
  CHECKPOINT_FILE="${session_dir}/CHECKPOINT.md"
  USER_ACTION_FILE="${session_dir}/USER_ACTION.md"
  TURNS_DIR="${session_dir}/turns"

  for required_file in "$SESSION_FILE" "$CHECKPOINT_FILE" "$USER_ACTION_FILE"; do
    if [[ ! -f "$required_file" ]]; then
      echo "required file not found: $required_file" >&2
      return 1
    fi
  done

  if [[ ! -d "$TURNS_DIR" ]]; then
    echo "turns directory not found: $TURNS_DIR" >&2
    return 1
  fi
}

# 세션 상태 추출
# 사용: load_session_state <session_file>
# 설정: STATUS, CURRENT_OWNER, REVIEW_TYPE, REVIEW_TARGET, REVIEW_GOAL 변수
load_session_state() {
  local session_file="$1"
  STATUS="$(extract_section "$session_file" "Status" | trim_blank_lines)"
  CURRENT_OWNER="$(extract_section "$session_file" "Current Owner" | trim_blank_lines)"
  REVIEW_TYPE="$(extract_section "$session_file" "Review Type" | trim_blank_lines)"
  REVIEW_TARGET="$(extract_section "$session_file" "Review Target" | trim_blank_lines)"
  REVIEW_GOAL="$(extract_section "$session_file" "Review Goal" | trim_blank_lines)"
}

# Turn Limit을 SESSION.md에서 읽음 (source-of-truth).
# session_file 우선 → REVIEW_TURN_LIMIT env → default 20 순.
# SESSION.md의 "## Turn Limit" 섹션 첫 줄에서 첫 숫자를 추출.
read_session_turn_limit() {
  local session_file="$1"
  local from_session=""
  if [[ -f "$session_file" ]]; then
    from_session="$(extract_section "$session_file" "Turn Limit" \
      | trim_blank_lines \
      | awk 'NR==1 { for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }')"
  fi
  if [[ -n "$from_session" && "$from_session" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$from_session"
  elif [[ -n "${REVIEW_TURN_LIMIT:-}" && "${REVIEW_TURN_LIMIT}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$REVIEW_TURN_LIMIT"
  else
    printf '20\n'
  fi
}

# 다음 턴 번호 계산
# 사용: compute_next_turn <turns_dir> <agent_label>
# 설정: LATEST_TURN_FILE, NEXT_TURN_NUMBER, NEXT_TURN_INDEX, EXPECTED_TURN_FILE, EXISTING_TURN_COUNT 변수
compute_next_turn() {
  local turns_dir="$1"
  local agent_label="$2"

  LATEST_TURN_FILE="$(find "$turns_dir" -maxdepth 1 -type f -name '*.md' | sort | tail -n 1)"

  if [[ -z "$LATEST_TURN_FILE" ]]; then
    echo "session has no prior turns; Author should write the first turn before Reviewer runs" >&2
    return 1
  fi

  local latest_turn_base
  latest_turn_base="$(basename "$LATEST_TURN_FILE")"
  local latest_turn_number="${latest_turn_base%%_*}"
  local latest_turn_agent="${latest_turn_base#*_}"
  latest_turn_agent="${latest_turn_agent%.md}"

  # legacy 파일명 alias 정규화 (codex→reviewer, claude→author)
  case "$latest_turn_agent" in
    codex) latest_turn_agent="reviewer" ;;
    claude) latest_turn_agent="author" ;;
  esac

  # 최신 턴이 이미 같은 역할인지 충돌 방지 검사
  if [[ "$latest_turn_agent" == "$agent_label" ]]; then
    echo "latest turn already belongs to ${agent_label}; refusing to run due to session state conflict" >&2
    return 1
  fi

  EXISTING_TURN_COUNT="$(find "$turns_dir" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d '[:space:]')"

  NEXT_TURN_NUMBER="$(printf '%03d' "$((10#${latest_turn_number} + 1))")"
  NEXT_TURN_INDEX="$((10#${NEXT_TURN_NUMBER}))"
  EXPECTED_TURN_FILE="${turns_dir}/${NEXT_TURN_NUMBER}_${agent_label}.md"
}

# === M2: cross-attempt Attempt History (safeguard-autopilot-loop-detection) ===
# 사용: build_attempt_history <slug> <current_session_dir_rel>
# 현재 slug 의 loop-state(reedit/rollback) + 직전 동일 slug review session 종결 사유를
# 읽어 주입 블록 문자열을 stdout 으로. 주입할 내용이 전혀 없으면 빈 문자열.
build_attempt_history() {
  local short_title="$1" cur_session="${2:-}"
  local loop_state="${LOOP_STATE_PATH:-rd-workflow-workspace/.lifecycle/loop-state}"
  local reedit_block="없음" rollback=0 prev_reason="없음"

  if [[ -f "$loop_state" ]]; then
    local re
    # 현재 slug 의 reedit 키만 (reedit::<slug>::<path>), 카운트 내림차순 상위 5.
    # head 미사용 — pipefail 환경에서 head 조기 종료가 sort SIGPIPE 를 유발해
    # 비-local 할당 `re=$(...)` 가 set -e 를 트리거하는 문제를 피하기 위해 awk NR<=5 로 제한 (Reviewer turn 004).
    re="$(awk -F'=' -v p="reedit::${short_title}::" 'index($1,p)==1 && $2 ~ /^[0-9]+$/ {print $2"\t"substr($1,length(p)+1)}' "$loop_state" \
      | sort -rn | awk -F'\t' 'NR<=5 {print "  - "$2"="$1}')"
    [[ -n "$re" ]] && reedit_block="$re"
    rollback="$(awk -F'=' -v st="$short_title" '$1=="rollback::"st && $2 ~ /^[0-9]+$/{print $2; exit}' "$loop_state")"
    [[ "$rollback" =~ ^[0-9]+$ ]] || rollback=0
  fi

  # 직전 동일 short-title review session 의 CHECKPOINT Current Summary 첫 줄.
  # 각 SESSION.md 의 Branch Context short-title 을 파싱해 문자열 동등 비교한다.
  # (grep substring 매칭은 `api` 가 `api-v2` 세션까지 잡는 FR scoping 위반이라 금지 — diff review turn 002)
  local sess_root="${PROJECT_ROOT:-.}/rd-workflow-workspace/handoffs/review_pipeline"
  if [[ -d "$sess_root" ]]; then
    local latest="" sf d st
    # glob 은 정렬되어 전개 → 마지막 매치가 최신 (session-id 가 timestamp prefix)
    for sf in "$sess_root"/*/SESSION.md; do
      [[ -f "$sf" ]] || continue
      d="$(dirname "$sf")"
      [[ -n "$cur_session" && "$d" == *"$cur_session"* ]] && continue
      st="$(awk '/^## Branch Context/{f=1} f&&/^- short-title:/{sub(/^- short-title:[ \t]*/,"");sub(/[ \t]+$/,"");print;exit}' "$sf")"
      [[ "$st" == "$short_title" ]] || continue
      latest="$d"
    done
    if [[ -n "$latest" && -f "$latest/CHECKPOINT.md" ]]; then
      local summ
      summ="$(awk '/^## Current Summary/{f=1;next} f&&/^## /{exit} f&&NF{print;exit}' "$latest/CHECKPOINT.md")"
      [[ -n "$summ" ]] && prev_reason="$summ"
    fi
  fi

  # 주입할 게 전혀 없으면 빈 문자열
  if [[ "$reedit_block" == "없음" && "$rollback" -eq 0 && "$prev_reason" == "없음" ]]; then
    return 0
  fi

  printf '## Attempt History (autopilot)\n'
  printf -- '- 이전 review session 종결 사유: %s\n' "$prev_reason"
  printf -- '- 동일 파일 재수정 누적:\n%s\n' "$reedit_block"
  printf -- '- lifecycle: rollback %s회\n' "$rollback"
}

# 리뷰 프롬프트 생성
build_review_prompt() {
  local output_file="$1"
  local session_dir_rel="$2"
  local session_file_rel="$3"
  local checkpoint_file_rel="$4"
  local user_action_file_rel="$5"
  local latest_turn_file_rel="$6"
  local expected_turn_file_rel="$7"
  local review_type="$8"
  local review_target="$9"
  local review_goal="${10}"
  local turn_limit="${11}"
  local next_turn_number="${12}"

  # M2: autopilot 모드에서만 Attempt History prepend (Reviewer turn 002 Finding 2)
  local _attempt_history=""
  if [[ "${RD_AUTOPILOT:-}" == "1" ]]; then
    local _short_title=""
    # 정본: review 대상 SESSION.md ($3 = session_file_rel) Branch Context short-title
    if [[ -f "${PROJECT_ROOT:-.}/${session_file_rel}" ]]; then
      _short_title="$(awk '/^## Branch Context/{f=1} f&&/^- short-title:/{sub(/^- short-title:[ \t]*/,"");sub(/[ \t]+$/,"");print;exit}' "${PROJECT_ROOT:-.}/${session_file_rel}")"
    fi
    # fallback: CURRENT_TASK.md
    if [[ -z "$_short_title" || "$_short_title" == "unknown" || "$_short_title" == "-" ]]; then
      if [[ -f "${PROJECT_ROOT:-.}/CURRENT_TASK.md" ]]; then
        _short_title="$(awk '/^## Short Title/{f=1;next} f&&/^[^#]/{sub(/^[ \t]+/,"");sub(/[ \t]+$/,"");print;exit}' "${PROJECT_ROOT:-.}/CURRENT_TASK.md")"
      fi
    fi
    # 유효 slug 일 때만 주입. unknown/-/빈 값이면 섹션 생략 (legacy session 기존 동작 유지)
    if [[ -n "$_short_title" && "$_short_title" != "unknown" && "$_short_title" != "-" ]]; then
      _attempt_history="$(build_attempt_history "$_short_title" "$session_dir_rel" || true)"
    fi
  fi

  {
    if [[ -n "$_attempt_history" ]]; then
      printf '%s\n\n' "$_attempt_history"
    fi
    cat <<EOF
You are continuing an existing file-based review session.

Follow the rules in:
- rd-workflow/docs/flows/FILE_BASED_REVIEW_PIPELINE.md

Session execution contract:
- SESSION_DIR: ${session_dir_rel}
- SESSION_FILE: ${session_file_rel}
- CHECKPOINT_FILE: ${checkpoint_file_rel}
- USER_ACTION_FILE: ${user_action_file_rel}
- LATEST_TURN_FILE: ${latest_turn_file_rel}
- EXPECTED_TURN_FILE: ${expected_turn_file_rel}
- REVIEW_TYPE: ${review_type}
- TURN_LIMIT: ${turn_limit} total turns
- THIS_TURN_NUMBER: ${next_turn_number}

Review target:
${review_target}

Review goal:
${review_goal}

You must do all of the following:
1. Read SESSION.md, CHECKPOINT.md, USER_ACTION.md, and the latest turn file (LATEST_TURN_FILE). Then read the review target.
   - Previous turn files are available at ${session_dir_rel}/turns/ — only read specific ones if CHECKPOINT context is insufficient to understand an open issue or prior agreement.
   - Do NOT read all previous turns by default.
2. Create exactly one new turn file at EXPECTED_TURN_FILE.
3. Update CHECKPOINT_FILE.
4. Update SESSION_FILE so that Current Owner is no longer Reviewer.
   - Modify ONLY the "Status" and "Current Owner" sections.
   - Do NOT modify "Turn Limit", "Stop Rule", "Finalize Rule", "Tool History", "Branch Context", or any other section in SESSION.md. Those sections are managed by the harness.
5. If unresolved objections remain after your review, default to Status=awaiting-author and hand the session back to Author.
6. Only set Status=awaiting-user if one of these is true: you explicitly have no remaining objections, user input is required, or this turn reaches the ${turn_limit}-turn limit.
7. If you have no remaining objections, say that explicitly in Disagreement and Proposed Decision.

Constraints:
- Do not modify files outside the review session except to read the review target.
- Do not create a second turn file.
- Use EXPECTED_TURN_FILE exactly as given. Do not rename, renumber, or "fix" the turn file path.
- Do not leave Current Owner as Reviewer.
- The session may not exceed ${turn_limit} total turn files.
- If this is turn ${turn_limit}, you must stop the loop by setting Status=awaiting-user.
- Do not answer the human directly; the files are the source of truth.
- Do not implement code changes or create commits.

Required turn file sections:
- Summary
- Findings
- Agreement
- Disagreement
- Questions
- Proposed Decision
- Next Owner

If you cannot continue safely, record the blocker in CHECKPOINT_FILE and set Current Owner to User with Status awaiting-user.
At the end, print a short summary of what you changed.
EOF
  } > "$output_file"
}

# 턴 실행 후 출력 검증
validate_turn_output() {
  local session_file="$1"
  local expected_turn_file="$2"
  local next_turn_index="$3"
  local turn_limit="$4"
  local tool_name="$5"

  if [[ ! -f "$expected_turn_file" ]]; then
    echo "${tool_name} did not create the expected turn file: $expected_turn_file" >&2
    return 1
  fi

  local updated_status
  local updated_owner
  updated_status="$(extract_section "$session_file" "Status" | trim_blank_lines)"
  updated_owner="$(extract_section "$session_file" "Current Owner" | trim_blank_lines)"

  case "$updated_status" in
    awaiting-author|awaiting-claude|awaiting-user|closed)
      ;;
    *)
      echo "invalid session status after ${tool_name} run: $updated_status" >&2
      return 1
      ;;
  esac

  if ! validate_owner_output "$updated_owner"; then
    echo "invalid current owner after ${tool_name} run: $updated_owner" >&2
    return 1
  fi

  if [[ "$next_turn_index" -eq "$turn_limit" && "$updated_status" == "awaiting-author" ]]; then
    echo "turn limit reached but ${tool_name} handed the session back to Author" >&2
    return 1
  fi

  echo "$updated_status"
}

# === Task 8 — Branch Context schema ===

parse_branch_context() {
  local session_dir="$1"
  local file="$session_dir/SESSION.md"
  [[ -f "$file" ]] || return 2
  awk '
    /^## Branch Context/{flag=1; next}
    flag && /^## /{flag=0}
    flag && /^- /{print}
  ' "$file"
}

# 5필드 strict 검증 — 라벨 누락 / 값 누락 / enum 위반 / git 상태 불일치 모두 hard error
# Returns 0 on success or legacy session, 1 on validation failure
validate_branch_context() {
  local session_dir="$1"
  local lines fr_branch worktree_path short_title lifecycle_stage remote_mode
  lines="$(parse_branch_context "$session_dir")"

  if [[ -z "$lines" ]]; then
    printf '[branch-context] WARN — ## Branch Context 부재 (legacy session). 재진입 검증 skip.\n' >&2
    return 0
  fi

  fr_branch="$(printf '%s\n' "$lines" | awk -F': ' '/^- fr-branch:/{sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2; exit}')"
  worktree_path="$(printf '%s\n' "$lines" | awk -F': ' '/^- worktree-path:/{sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2; exit}')"
  short_title="$(printf '%s\n' "$lines" | awk -F': ' '/^- short-title:/{sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2; exit}')"
  lifecycle_stage="$(printf '%s\n' "$lines" | awk -F': ' '/^- lifecycle-stage:/{sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2; exit}')"
  remote_mode="$(printf '%s\n' "$lines" | awk -F': ' '/^- remote-mode:/{sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2; exit}')"

  for f in fr_branch worktree_path short_title lifecycle_stage remote_mode; do
    if [[ -z "${!f:-}" ]]; then
      printf '[branch-context] FAIL — 라벨/값 누락: %s\n' "$f" >&2
      return 1
    fi
  done

  case "$lifecycle_stage" in
    request-review|spec-review|plan-review|implementing|validating|archive-pending|archived) ;;
    *) printf '[branch-context] FAIL — lifecycle-stage enum 위반: [%s]\n' "$lifecycle_stage" >&2; return 1 ;;
  esac
  case "$remote_mode" in
    remote|local-only) ;;
    *) printf '[branch-context] FAIL — remote-mode enum 위반: [%s]\n' "$remote_mode" >&2; return 1 ;;
  esac

  if [[ "$fr_branch" != "null" && "$fr_branch" != "main" ]]; then
    if ! git rev-parse --verify "$fr_branch" >/dev/null 2>&1; then
      printf '[branch-context] FAIL — fr-branch [%s] 미존재. handoff 갱신 또는 git switch 필요\n' "$fr_branch" >&2
      return 1
    fi
  fi

  if [[ "$worktree_path" != "null" && "$worktree_path" != "main" ]]; then
    if [[ ! -d "$worktree_path" ]]; then
      printf '[branch-context] FAIL — worktree-path [%s] 디렉토리 부재\n' "$worktree_path" >&2
      return 1
    fi
  fi

  # short-title 비교 (informational — halt 안 함)
  local current_short=""
  if [[ -f CURRENT_TASK.md ]]; then
    current_short="$(awk '/^## Short Title/{flag=1; next} flag && /^[^#]/{sub(/^[ \t]+/,""); sub(/[ \t]+$/,""); print; exit}' CURRENT_TASK.md)"
  fi
  if [[ -n "$current_short" && "$current_short" != "$short_title" ]]; then
    printf '[branch-context] WARN — short-title [%s] ↔ CURRENT_TASK [%s] 불일치 (informational)\n' "$short_title" "$current_short" >&2
  fi

  # remote-mode 비교 (informational)
  local current_remote=""
  if command -v detect_remote_mode >/dev/null 2>&1; then
    current_remote="$(detect_remote_mode 2>/dev/null || echo "")"
  fi
  if [[ -n "$current_remote" && "$current_remote" != "$remote_mode" ]]; then
    printf '[branch-context] WARN — remote-mode [%s] ↔ 현재 [%s] 불일치 (informational)\n' "$remote_mode" "$current_remote" >&2
  fi

  return 0
}

# SESSION.md에 Tool History 행 추가 (idempotent — 같은 turn_number 행이 있으면 skip)
append_tool_history() {
  local session_file="$1"
  local turn_number="$2"
  local tool_name="$3"
  local mode="$4"

  # Tool History 섹션이 없으면 추가
  if ! grep -q "^## Tool History" "$session_file"; then
    printf '\n## Tool History\n| Turn | Tool | Mode |\n|------|------|------|\n' >> "$session_file"
  fi

  # LLM이 SESSION.md 갱신 시 자기 turn 행을 이미 추가했을 수 있음 → 중복 회피
  if grep -qE "^\| ${turn_number} \|" "$session_file"; then
    return 0
  fi

  printf '| %s | %s | %s |\n' "$turn_number" "$tool_name" "$mode" >> "$session_file"
}
