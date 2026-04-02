#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../../../.." && pwd)"

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

exit 0
