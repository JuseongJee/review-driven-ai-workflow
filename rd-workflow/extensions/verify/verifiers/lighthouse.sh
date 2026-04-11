#!/usr/bin/env bash
set -euo pipefail

NAME="$1"
CONFIG="$2"
OUTPUT_DIR="$3"

# ──────────────────────────────────────────────
# 환경 검사
# ──────────────────────────────────────────────
if ! command -v npx &>/dev/null; then
  echo "[${NAME}] npx가 설치되지 않았습니다. Node.js를 설치해주세요." >&2
  exit 1
fi

if [[ -z "${URL:-}" ]]; then
  echo "[${NAME}] 환경 변수 URL이 설정되지 않았습니다. (예: export URL=http://localhost:3000)" >&2
  exit 1
fi

# ──────────────────────────────────────────────
# 출력 디렉토리 준비
# ──────────────────────────────────────────────
mkdir -p "${OUTPUT_DIR}"

# ──────────────────────────────────────────────
# verification.json에서 run 필드 읽기 (jq 우선, python3 폴백)
# ──────────────────────────────────────────────
if command -v jq &>/dev/null; then
  run_cmd="$(jq -r --arg name "${NAME}" '.verifiers[$name].run // empty' "${CONFIG}")"
else
  run_cmd="$(python3 - <<PYEOF
import json, sys
with open('${CONFIG}') as f:
    data = json.load(f)
val = data.get('verifiers', {}).get('${NAME}', {}).get('run', '')
if val:
    print(val)
PYEOF
)"
fi

if [[ -z "${run_cmd}" ]]; then
  echo "[${NAME}] verification.json에 run 필드가 없습니다." >&2
  exit 1
fi

# ──────────────────────────────────────────────
# 환경 변수 치환 후 실행
# ──────────────────────────────────────────────
# $URL, $OUTPUT_DIR를 실제 값으로 치환
run_cmd="${run_cmd//\$URL/${URL}}"
run_cmd="${run_cmd//\$OUTPUT_DIR/${OUTPUT_DIR}}"

echo "[${NAME}] 실행: ${run_cmd}"

EXIT_CODE=0
eval "${run_cmd}" || EXIT_CODE=$?

exit "${EXIT_CODE}"
