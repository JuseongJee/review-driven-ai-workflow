#!/usr/bin/env bash
set -euo pipefail

NAME="$1"
CONFIG="$2"
OUTPUT_DIR="$3"

# ── node 설치 확인 ────────────────────────────────
if ! command -v node &>/dev/null; then
  echo "[${NAME}] node가 설치되지 않았습니다." >&2
  echo "[${NAME}] 설치: https://nodejs.org/" >&2
  exit 1
fi

# ── verification.json에서 run 추출 ─────────────────
if command -v jq &>/dev/null; then
  run_cmd="$(jq -r --arg name "${NAME}" '.verifiers[$name].run // empty' "${CONFIG}")"
else
  run_cmd="$(python3 - <<PYEOF
import json
with open('${CONFIG}') as f:
    data = json.load(f)
val = data.get('verifiers', {}).get('${NAME}', {}).get('run', '')
print(val)
PYEOF
)"
fi

if [[ -z "${run_cmd}" ]]; then
  echo "[${NAME}] verification.json에 run 필드가 없습니다." >&2
  exit 1
fi

# ── 환경 변수 치환 후 실행 ─────────────────────────
export OUTPUT_DIR
eval "${run_cmd}"
