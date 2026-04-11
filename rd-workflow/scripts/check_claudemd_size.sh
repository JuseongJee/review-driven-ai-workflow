#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../.." && pwd)"

claudemd="${project_root}/CLAUDE.md"
limit="${CLAUDEMD_LINE_LIMIT:-200}"

if [[ ! -f "$claudemd" ]]; then
  echo "[claudemd-guard] CLAUDE.md가 없습니다: $claudemd" >&2
  exit 0
fi

line_count="$(wc -l < "$claudemd" | tr -d '[:space:]')"

if [[ "$line_count" -gt "$limit" ]]; then
  echo "[claudemd-guard] 경고: CLAUDE.md가 ${line_count}줄입니다 (제한: ${limit}줄)" >&2
  echo "[claudemd-guard] 각 줄에 대해 '이 줄을 삭제해도 실수가 발생하는가?' 테스트를 적용하세요." >&2
  exit 1
fi

echo "[claudemd-guard] CLAUDE.md: ${line_count}줄 (제한: ${limit}줄 이내)"
exit 0
