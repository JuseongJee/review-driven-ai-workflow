#!/usr/bin/env bash
set -euo pipefail

NAME="$1"
CONFIG="$2"
OUTPUT_DIR="$3"

echo "[$NAME] XCUITest macOS adapter — 프로젝트에 맞게 수정이 필요합니다." >&2
echo "  rd-workflow/extensions/verify/presets/macos/README.md를 참조하세요" >&2
echo "  PROJECT, SCHEME 환경변수를 설정하세요" >&2
exit 1
