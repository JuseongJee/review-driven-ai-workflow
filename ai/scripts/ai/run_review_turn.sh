#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../../.." && pwd)"
cd "${project_root}"

usage() {
  cat <<'EOF' >&2
사용법:
  bash ai/scripts/ai/run_review_turn.sh <tool> <session-path>

지원 tool:
  codex

예:
  bash ai/scripts/ai/run_review_turn.sh codex ai/workspace/handoffs/review_pipeline/20260313_120000_request-review
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

tool="$1"
session_path="$2"

case "$tool" in
  codex)
    exec "${script_dir}/run_review_turn_codex.sh" "$session_path"
    ;;
  *)
    echo "unsupported review tool: $tool" >&2
    usage
    exit 1
    ;;
esac
