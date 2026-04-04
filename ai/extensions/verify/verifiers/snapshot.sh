#!/usr/bin/env bash
set -euo pipefail

NAME="$1"
CONFIG="$2"
OUTPUT_DIR="$3"

# $SNAPSHOT_TEST_SCRIPT 환경 변수 확인
if [ -z "${SNAPSHOT_TEST_SCRIPT:-}" ]; then
  echo "SNAPSHOT_TEST_SCRIPT 환경 변수가 설정되지 않았습니다." >&2
  echo "스냅샷 테스트 스크립트 경로를 지정해주세요. 예: export SNAPSHOT_TEST_SCRIPT=./tests/snapshot.sh" >&2
  exit 1
fi

if [ ! -x "$SNAPSHOT_TEST_SCRIPT" ]; then
  echo "SNAPSHOT_TEST_SCRIPT($SNAPSHOT_TEST_SCRIPT)를 실행할 수 없습니다. 파일이 존재하고 실행 권한이 있는지 확인해주세요." >&2
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
LOG_FILE="$OUTPUT_DIR/snapshot.log"
EXIT_CODE=0
eval "$RUN_CMD" 2>&1 | tee "$LOG_FILE" || EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "snapshot 검증 실패 (exit $EXIT_CODE). 로그: $LOG_FILE" >&2
  exit 1
fi

echo "snapshot 검증 완료. 결과: $LOG_FILE"
