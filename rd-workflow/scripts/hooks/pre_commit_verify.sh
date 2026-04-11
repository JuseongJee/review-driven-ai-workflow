#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../../.." && pwd)"

# stdin에서 JSON 읽기
input="$(cat)"

# command 추출 (jq 우선, bash 문자열 조작 폴백)
cmd=""
if command -v jq &>/dev/null; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
fi

if [[ -z "$cmd" ]]; then
  # bash 내장 파싱 폴백 (macOS/Linux 공통, grep 불사용)
  tmp="${input#*\"command\":\"}"
  if [[ "$tmp" != "$input" ]]; then
    cmd="${tmp%%\"*}"
  fi
fi

# command가 비어있으면 통과
if [[ -z "$cmd" ]]; then
  exit 0
fi

# git commit 패턴 감지 (bash [[ ]] 사용, grep 불사용)
# git 토큰 + commit 토큰이 모두 포함된 경우 매칭
# cd && git commit, /usr/bin/git commit, git -c ... commit 등 포함
# 설계 제약: bash -lc 'git commit' 같은 간접 호출은 감지하지 않음
if ! [[ "$cmd" == *git\ *commit* || "$cmd" == *git$'\t'*commit* || "$cmd" == git\ commit* ]]; then
  exit 0
fi

# git commit 감지됨 — 검증 스크립트 실행
is_template_stub() {
  local file="$1"
  head -5 "$file" 2>/dev/null | grep -q '# TEMPLATE_STUB' 2>/dev/null
}

scripts_dir="${project_root}/rd-workflow/scripts"
verification_scripts=("test.sh" "lint.sh" "typecheck.sh")

for script_name in "${verification_scripts[@]}"; do
  script_path="${scripts_dir}/${script_name}"

  # 파일 없으면 skip
  if [[ ! -f "$script_path" ]]; then
    continue
  fi

  # TEMPLATE_STUB sentinel이 있으면 skip
  if is_template_stub "$script_path"; then
    continue
  fi

  # 실행
  if ! bash "$script_path"; then
    echo "[hooks] 커밋 전 ${script_name} 검증 실패" >&2
    exit 2
  fi
done

exit 0
