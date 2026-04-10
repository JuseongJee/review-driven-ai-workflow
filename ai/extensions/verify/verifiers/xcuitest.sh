#!/usr/bin/env bash
set -euo pipefail

NAME="$1"
CONFIG="$2"
OUTPUT_DIR="$3"

echo "[$NAME] XCUITest adapter — 프로젝트에 맞게 수정이 필요합니다." >&2
echo "  ai/extensions/verify/presets/ios/README.md를 참조하세요" >&2
echo "  WORKSPACE, SCHEME, DESTINATION 환경변수를 설정하세요" >&2
exit 1
