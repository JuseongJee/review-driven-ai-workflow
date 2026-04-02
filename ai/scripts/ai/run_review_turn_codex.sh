#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../../.." && pwd)"
cd "${project_root}"

turn_limit="${REVIEW_TURN_LIMIT:-20}"

usage() {
  cat <<'EOF' >&2
사용법:
  bash ai/scripts/ai/run_review_turn_codex.sh <session-path>

예:
  bash ai/scripts/ai/run_review_turn_codex.sh ai/workspace/handoffs/review_pipeline/20260313_120000_request-review
EOF
}

resolve_path() {
  local input="$1"

  if [[ "$input" = /* ]]; then
    printf '%s\n' "$input"
  else
    printf '%s\n' "${project_root}/${input}"
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

validate_owner_transition() {
  local owner="$1"

  case "$owner" in
    Claude|User)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
esac

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

session_dir="$(resolve_path "$1")"

if [[ ! -d "$session_dir" ]]; then
  echo "session directory not found: $session_dir" >&2
  exit 1
fi

session_file="${session_dir}/SESSION.md"
checkpoint_file="${session_dir}/CHECKPOINT.md"
user_action_file="${session_dir}/USER_ACTION.md"
turns_dir="${session_dir}/turns"

for required_file in "$session_file" "$checkpoint_file" "$user_action_file"; do
  if [[ ! -f "$required_file" ]]; then
    echo "required file not found: $required_file" >&2
    exit 1
  fi
done

if [[ ! -d "$turns_dir" ]]; then
  echo "turns directory not found: $turns_dir" >&2
  exit 1
fi

status="$(extract_section "$session_file" "Status" | trim_blank_lines)"
current_owner="$(extract_section "$session_file" "Current Owner" | trim_blank_lines)"
review_type="$(extract_section "$session_file" "Review Type" | trim_blank_lines)"
review_target="$(extract_section "$session_file" "Review Target" | trim_blank_lines)"
review_goal="$(extract_section "$session_file" "Review Goal" | trim_blank_lines)"

if [[ "$status" != "awaiting-codex" ]]; then
  echo "session is not awaiting Codex: status=$status" >&2
  exit 1
fi

if [[ "$current_owner" != "Codex" ]]; then
  echo "current owner is not Codex: owner=$current_owner" >&2
  exit 1
fi

latest_turn_file="$(find "$turns_dir" -maxdepth 1 -type f -name '*.md' | sort | tail -n 1)"

if [[ -z "$latest_turn_file" ]]; then
  echo "session has no prior turns; Claude should write the first turn before Codex runs" >&2
  exit 1
fi

latest_turn_base="$(basename "$latest_turn_file")"
latest_turn_number="${latest_turn_base%%_*}"
latest_turn_agent="${latest_turn_base#*_}"
latest_turn_agent="${latest_turn_agent%.md}"
existing_turn_count="$(find "$turns_dir" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d '[:space:]')"

if [[ "$latest_turn_agent" == "codex" ]]; then
  echo "latest turn already belongs to Codex; refusing to run due to session state conflict" >&2
  exit 1
fi

next_turn_number="$(printf '%03d' "$((10#${latest_turn_number} + 1))")"
next_turn_index="$((10#${next_turn_number}))"
expected_turn_file="${turns_dir}/${next_turn_number}_codex.md"

relative_session_dir="${session_dir#${project_root}/}"
relative_session_file="${session_file#${project_root}/}"
relative_checkpoint_file="${checkpoint_file#${project_root}/}"
relative_user_action_file="${user_action_file#${project_root}/}"
relative_expected_turn_file="${expected_turn_file#${project_root}/}"
relative_latest_turn_file="${latest_turn_file#${project_root}/}"

if [[ "$existing_turn_count" -ge "$turn_limit" || "$next_turn_index" -gt "$turn_limit" ]]; then
  echo "session already reached the turn limit (${turn_limit}): $relative_session_dir" >&2
  exit 1
fi

last_message_file="$(mktemp)"
prompt_file="$(mktemp)"
codex_bin="${REVIEW_TOOL_CODEX_BIN:-codex}"

cleanup() {
  rm -f "$last_message_file" "$prompt_file"
}
trap cleanup EXIT

cat <<EOF > "$prompt_file"
You are continuing an existing file-based review session.

Follow the rules in:
- ai/docs/flows/FILE_BASED_REVIEW_PIPELINE.md

Session execution contract:
- SESSION_DIR: ${relative_session_dir}
- SESSION_FILE: ${relative_session_file}
- CHECKPOINT_FILE: ${relative_checkpoint_file}
- USER_ACTION_FILE: ${relative_user_action_file}
- LATEST_TURN_FILE: ${relative_latest_turn_file}
- EXPECTED_TURN_FILE: ${relative_expected_turn_file}
- REVIEW_TYPE: ${review_type}
- TURN_LIMIT: ${turn_limit} total turns
- THIS_TURN_NUMBER: ${next_turn_number}

Review target:
${review_target}

Review goal:
${review_goal}

You must do all of the following:
1. Read SESSION.md, CHECKPOINT.md, USER_ACTION.md, the latest turn files, and the review target.
2. Create exactly one new turn file at EXPECTED_TURN_FILE.
3. Update CHECKPOINT_FILE.
4. Update SESSION_FILE so that Current Owner is no longer Codex.
5. If unresolved objections remain after your review, default to Status=awaiting-claude and hand the session back to Claude.
6. Only set Status=awaiting-user if one of these is true: you explicitly have no remaining objections, user input is required, or this turn reaches the ${turn_limit}-turn limit.
7. If you have no remaining objections, say that explicitly in Disagreement and Proposed Decision.

Constraints:
- Do not modify files outside the review session except to read the review target.
- Do not create a second turn file.
- Do not leave Current Owner as Codex.
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

if ! command -v "$codex_bin" &>/dev/null; then
  echo "Codex CLI를 찾을 수 없습니다: $codex_bin" >&2
  echo "설치: npm install -g @openai/codex (또는 해당 설치 방법)" >&2
  echo "또는 REVIEW_TOOL_CODEX_BIN 환경변수로 바이너리 경로를 지정하세요." >&2
  exit 1
fi

"$codex_bin" --ask-for-approval never exec \
  --cd "$project_root" \
  --sandbox workspace-write \
  --skip-git-repo-check \
  --output-last-message "$last_message_file" \
  - < "$prompt_file"

if [[ ! -f "$expected_turn_file" ]]; then
  echo "Codex did not create the expected turn file: $relative_expected_turn_file" >&2
  if [[ -s "$last_message_file" ]]; then
    echo "--- codex last message ---" >&2
    cat "$last_message_file" >&2
  fi
  exit 1
fi

updated_status="$(extract_section "$session_file" "Status" | trim_blank_lines)"
updated_owner="$(extract_section "$session_file" "Current Owner" | trim_blank_lines)"

case "$updated_status" in
  awaiting-claude|awaiting-user|closed)
    ;;
  *)
    echo "invalid session status after Codex run: $updated_status" >&2
    exit 1
    ;;
esac

if ! validate_owner_transition "$updated_owner"; then
  echo "invalid current owner after Codex run: $updated_owner" >&2
  exit 1
fi

if [[ "$next_turn_index" -eq "$turn_limit" && "$updated_status" == "awaiting-claude" ]]; then
  echo "turn limit reached but Codex handed the session back to Claude: $relative_session_dir" >&2
  exit 1
fi

echo "codex review turn completed"
echo "session: ${relative_session_dir}"
echo "turn: ${relative_expected_turn_file}"
echo "status: ${updated_status}"
echo "owner: ${updated_owner}"
