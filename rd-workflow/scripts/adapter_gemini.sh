#!/usr/bin/env bash
# adapter_gemini.sh — Gemini CLI 어댑터 (독립 리뷰어)
# 환경변수: SESSION_PATH, PROMPT_FILE, EXPECTED_TURN_FILE,
#           TOOL_BIN, PROJECT_ROOT, TOOL_MODEL
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/review_common.sh"

gemini_bin="${TOOL_BIN:-gemini}"

if ! command -v "$gemini_bin" &>/dev/null; then
  echo "Gemini CLI를 찾을 수 없습니다: $gemini_bin" >&2
  exit 1
fi

# --model 옵션 (TOOL_MODEL이 있을 때만)
model_args=()
if [[ -n "${TOOL_MODEL:-}" ]]; then
  model_args=(--model "$TOOL_MODEL")
fi

# Gemini CLI 실행 (동기, stdin으로 프롬프트 전달)
if ! "$gemini_bin" "${model_args[@]}" \
  < "$PROMPT_FILE"; then
  echo "Gemini CLI가 비정상 종료했습니다" >&2
  exit 1
fi

# 턴 파일 생성 확인
if [[ ! -f "$EXPECTED_TURN_FILE" ]]; then
  echo "Gemini did not create the expected turn file: $EXPECTED_TURN_FILE" >&2
  exit 1
fi

exit 0
