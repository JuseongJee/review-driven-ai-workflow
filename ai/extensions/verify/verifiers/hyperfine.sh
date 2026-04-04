#!/usr/bin/env bash
set -euo pipefail

NAME="$1"
CONFIG="$2"
OUTPUT_DIR="$3"

# hyperfine 설치 확인
if ! command -v hyperfine &>/dev/null; then
  echo "hyperfine가 설치되지 않았습니다." >&2
  echo "설치 방법:" >&2
  echo "  macOS: brew install hyperfine" >&2
  echo "  Cargo: cargo install hyperfine" >&2
  exit 1
fi

# verification.json에서 run 명령 추출
if command -v jq &>/dev/null; then
  RUN_CMD=$(jq -r ".verifiers[\"$NAME\"].run" "$CONFIG")
else
  RUN_CMD=$(python3 -c "
import json, sys
with open('$CONFIG') as f:
    data = json.load(f)
print(data['verifiers']['$NAME']['run'])
")
fi

if [ -z "$RUN_CMD" ] || [ "$RUN_CMD" = "null" ]; then
  echo "verification.json에서 verifier '$NAME'의 run 명령을 찾을 수 없습니다." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# run 명령 실행 (환경 변수 치환 포함)
# --export-json 옵션은 verification.json의 run 필드에 포함되어 있으므로 여기서 추가하지 않는다
EXIT_CODE=0
eval "$RUN_CMD" 2>&1 || EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "hyperfine 벤치마크 실패 (exit $EXIT_CODE)." >&2
  exit 1
fi

echo "hyperfine 벤치마크 완료."
