#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../../.." && pwd)"
source "${script_dir}/_guard_common.sh"

task_file="${project_root}/CURRENT_TASK.md"

extract_section() {
  local file="$1"
  local section="$2"
  awk -v target="## ${section}" '
    $0 == target { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if (NF) print }
  ' "$file"
}

if [[ ! -f "$task_file" ]]; then
  echo "[hooks] CURRENT_TASK.md가 없습니다. 작업 추적이 불가합니다." >&2
  exit 0
fi

task="$(extract_section "$task_file" "Task")"
status="$(extract_section "$task_file" "Status")"
next_step="$(extract_section "$task_file" "Next Step")"

[[ "$task" == "-" || -z "$task" ]] && task="(설정되지 않음)"
[[ "$status" == "-" || -z "$status" ]] && status="(설정되지 않음)"
[[ "$next_step" == "-" || -z "$next_step" ]] && next_step="(설정되지 않음)"

echo "[hooks] 현재 작업 상태:"
echo "  Task: ${task}"
echo "  Status: ${status}"
echo "  Next Step: ${next_step}"

# --- diff-review 누락 경고 (Layer 2) ---

if ! is_autopilot_active; then
  review_dir="$(get_latest_diff_review_dir)"

  if [[ -n "$review_dir" ]]; then
    checkpoint="${review_dir}/CHECKPOINT.md"
    if [[ -f "$checkpoint" ]]; then
      has_real_issues="$(awk '
        /^## Open Issues/ { in_section = 1; next }
        in_section && /^## / { exit }
        in_section && /^- / && !/^- 없음/ { found = 1; exit }
        END { print (found ? "yes" : "no") }
      ' "$checkpoint")"

      if [[ "$has_real_issues" == "yes" ]]; then
        echo "[guard] 최신 diff-review에 미해결 이슈가 있습니다." >&2
      fi
    fi
  else
    head_epoch="$(git -C "$project_root" log -1 --format=%ct 2>/dev/null || echo 0)"
    if [[ "$head_epoch" -gt 0 ]]; then
      echo "[guard] diff-review 세션이 없습니다. 새 프로젝트라면 무시해도 됩니다." >&2
    fi
  fi
fi

exit 0
