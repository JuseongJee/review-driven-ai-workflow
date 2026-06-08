#!/usr/bin/env bash
# 워크플로 인프라(rd-workflow) self-test entrypoint.
# 본 프로젝트와 generated project 공통으로 rd-workflow 인프라가 정상인지 검증한다.
# 제품 코드 테스트(test.sh/lint.sh/typecheck.sh)와는 책임이 다르다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAIL=0
run_step() {
  local desc="$1"; shift
  echo ""
  echo "== ${desc} =="
  if "$@"; then
    echo "  -> PASS: ${desc}"
  else
    echo "  -> FAIL: ${desc}" >&2
    FAIL=1
  fi
}

syntax_check() {
  local rc=0 f
  while IFS= read -r f; do
    if ! bash -n "$f" 2>/dev/null; then
      echo "  구문 오류: $f" >&2
      rc=1
    fi
  done < <(find "${SCRIPT_DIR}" -type f -name "*.sh")
  return $rc
}

autopilot_skill_lifecycle_check() {
  local rc=0 skill
  for skill in \
    "${SCRIPT_DIR}/../claude_skills/autopilot/SKILL.md" \
    "${SCRIPT_DIR}/../../_ROOT_FILES/rd-workflow/claude_skills/autopilot/SKILL.md" \
    "${SCRIPT_DIR}/../../_ROOT_FILES_LITE/rd-workflow/claude_skills/autopilot/SKILL.md"; do
    [[ -f "$skill" ]] || continue
    grep -q 'promote.sh --short-title' "$skill" || { echo "  $skill: promote.sh --short-title 미참조" >&2; rc=1; }
    grep -q 'promote_rollback.sh' "$skill" || { echo "  $skill: promote_rollback.sh 미참조" >&2; rc=1; }
    if grep -q 'checkout -b autopilot' "$skill"; then echo "  $skill: autopilot/* 직접 생성 잔존" >&2; rc=1; fi
    if grep -q 'autopilot/<' "$skill"; then echo "  $skill: autopilot/<...> 표기 잔존" >&2; rc=1; fi
    if grep -q 'checkout master' "$skill"; then echo "  $skill: master 표기 잔존" >&2; rc=1; fi
    if grep -q 'branch -D autopilot' "$skill"; then echo "  $skill: branch -D autopilot 잔존" >&2; rc=1; fi
  done
  return $rc
}

run_step "lifecycle 단위 테스트 (test_lifecycle.sh)" bash "${SCRIPT_DIR}/lifecycle/test_lifecycle.sh"
run_step "lifecycle 통합 테스트 (test_integration.sh)" bash "${SCRIPT_DIR}/lifecycle/test_integration.sh"
run_step "스크립트 구문 검사 (bash -n)" syntax_check
run_step "autopilot SKILL lifecycle 정합 (promote/rollback 일원화)" autopilot_skill_lifecycle_check
run_step "템플릿 동기화 검증 (test_template_sync.sh)" bash "${SCRIPT_DIR}/test_template_sync.sh"
run_step "CLAUDE.md 크기 제한 (check_claudemd_size.sh)" bash "${SCRIPT_DIR}/check_claudemd_size.sh"

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "== self_test 결과: PASS =="
  exit 0
else
  echo "== self_test 결과: FAIL ==" >&2
  exit 1
fi
