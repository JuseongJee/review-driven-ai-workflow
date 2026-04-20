#!/bin/bash
# test_pre_commit_verify.sh — pre_commit_verify.sh staged 파일 분류 격리 검증
# macOS /bin/bash 3.2 호환 (globstar/extglob 불사용)
set -uo pipefail

HOOK_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pre_commit_verify.sh"
PASS=0
FAIL=0

# 현재 시나리오 fixture 경로 (cleanup용; EXIT trap은 등록하지 않음)
# 각 시나리오가 명시적으로 cleanup_fixture를 호출한다.
_current_fixture=""

cleanup_fixture() {
  if [[ -n "$_current_fixture" && -d "$_current_fixture" ]]; then
    rm -rf "$_current_fixture"
    _current_fixture=""
  fi
}

# 스크립트 전체 EXIT 시 마지막 fixture 정리 (중단 등 예외 상황 대비)
trap 'cleanup_fixture' EXIT INT TERM

# ---------------------------------------------------------------------------
# 헬퍼 함수
# ---------------------------------------------------------------------------

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "[FAIL] $label — expected='$expected' actual='$actual'" >&2
    return 1
  fi
  return 0
}

# markers 디렉토리가 비어있는지 확인 (스킵 시나리오)
assert_skipped() {
  local fixture="$1" label="$2"
  local marker_count=0
  [[ -f "$fixture/markers/test.done" ]] && marker_count=$((marker_count + 1))
  [[ -f "$fixture/markers/lint.done" ]] && marker_count=$((marker_count + 1))
  [[ -f "$fixture/markers/typecheck.done" ]] && marker_count=$((marker_count + 1))
  if [[ "$marker_count" -gt 0 ]]; then
    local found=""
    [[ -f "$fixture/markers/test.done" ]] && found="${found}test.done "
    [[ -f "$fixture/markers/lint.done" ]] && found="${found}lint.done "
    [[ -f "$fixture/markers/typecheck.done" ]] && found="${found}typecheck.done "
    echo "[FAIL] $label — expected skip but markers found: ${found}" >&2
    return 1
  fi
  return 0
}

# markers 디렉토리에 3개 done 파일이 있는지 확인 (검증 실행 시나리오)
assert_validated() {
  local fixture="$1" label="$2"
  local ok=1
  [[ -f "$fixture/markers/test.done" ]] || ok=0
  [[ -f "$fixture/markers/lint.done" ]] || ok=0
  [[ -f "$fixture/markers/typecheck.done" ]] || ok=0
  if [[ "$ok" -eq 0 ]]; then
    local found=""
    [[ -f "$fixture/markers/test.done" ]] && found="${found}test.done "
    [[ -f "$fixture/markers/lint.done" ]] && found="${found}lint.done "
    [[ -f "$fixture/markers/typecheck.done" ]] && found="${found}typecheck.done "
    echo "[FAIL] $label — expected test/lint/typecheck markers, found: '${found}'" >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Fixture 생성 헬퍼
# ---------------------------------------------------------------------------

# 기본 fixture 구조 생성
# $1: mock git diff 출력 (printf '%b' 포맷 — \t, \n 사용 가능)
# Returns: fixture 경로를 stdout에 출력
make_fixture() {
  local mock_diff_output="$1"
  local fixture
  fixture="$(mktemp -d)"

  # 디렉토리 구조 생성
  mkdir -p "$fixture/rd-workflow/scripts/hooks"
  mkdir -p "$fixture/bin"
  mkdir -p "$fixture/markers"

  # hook 복사
  cp "$HOOK_SOURCE" "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh"
  chmod +x "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh"

  # stub 스크립트 생성 (실행되면 marker 파일 생성)
  local s
  for s in test lint typecheck; do
    cat > "$fixture/rd-workflow/scripts/${s}.sh" <<STUB
#!/bin/bash
touch "$fixture/markers/${s}.done"
exit 0
STUB
    chmod +x "$fixture/rd-workflow/scripts/${s}.sh"
  done

  # mock git 실행파일 생성
  # diff --cached 호출 시 고정 출력 반환, 그 외 인수는 무시하고 exit 0
  cat > "$fixture/bin/git" <<MOCKGIT
#!/bin/bash
if [[ "\$1" == "diff" ]]; then
  printf '%b' '$mock_diff_output'
  exit 0
fi
exit 0
MOCKGIT
  chmod +x "$fixture/bin/git"

  printf '%s' "$fixture"
}

# mock git이 exit 1로 실패하는 fixture (시나리오 9용)
make_fixture_git_fail() {
  local fixture
  fixture="$(mktemp -d)"

  mkdir -p "$fixture/rd-workflow/scripts/hooks"
  mkdir -p "$fixture/bin"
  mkdir -p "$fixture/markers"

  cp "$HOOK_SOURCE" "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh"
  chmod +x "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh"

  local s
  for s in test lint typecheck; do
    cat > "$fixture/rd-workflow/scripts/${s}.sh" <<STUB
#!/bin/bash
touch "$fixture/markers/${s}.done"
exit 0
STUB
    chmod +x "$fixture/rd-workflow/scripts/${s}.sh"
  done

  # mock git: diff 호출 시 exit 1 (실패 시뮬레이션)
  cat > "$fixture/bin/git" <<MOCKGIT
#!/bin/bash
if [[ "\$1" == "diff" ]]; then
  exit 1
fi
exit 0
MOCKGIT
  chmod +x "$fixture/bin/git"

  printf '%s' "$fixture"
}

# ---------------------------------------------------------------------------
# hook 실행 헬퍼
# 결과를 전역 변수 _hook_last_exit에 저장 (서브쉘 방식 사용하지 않음)
# $1: fixture 경로
# $2 (optional): PRE_COMMIT_DOC_PATHS 값 — "__UNSET__" 이면 설정하지 않음
# ---------------------------------------------------------------------------
_hook_last_exit=0
run_hook() {
  local fixture="$1"
  # ${2-__UNSET__}: 인수 unset이면 __UNSET__, 빈 문자열("")이면 빈 문자열 그대로 사용
  local doc_paths_arg="${2-__UNSET__}"

  _hook_last_exit=0
  if [[ "$doc_paths_arg" == "__UNSET__" ]]; then
    printf '%s' '{"tool_input":{"command":"git commit -m test"}}' | \
      PATH="$fixture/bin:$PATH" \
      bash "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh" \
      2>/dev/null || _hook_last_exit=$?
  else
    printf '%s' '{"tool_input":{"command":"git commit -m test"}}' | \
      PATH="$fixture/bin:$PATH" \
      PRE_COMMIT_DOC_PATHS="$doc_paths_arg" \
      bash "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh" \
      2>/dev/null || _hook_last_exit=$?
  fi
}

# ---------------------------------------------------------------------------
# 시나리오 실행 헬퍼
# ---------------------------------------------------------------------------
run_scenario() {
  local num="$1"
  local name="$2"
  local fixture="$3"
  local expected_exit="$4"
  local expect_validated="$5"  # "yes" or "no"
  # ${6-__UNSET__}: 인수 unset이면 __UNSET__, 빈 문자열("")이면 빈 문자열 그대로 사용
  local doc_paths_arg="${6-__UNSET__}"

  _current_fixture="$fixture"

  # hook을 직접 실행 (서브쉘 방식 금지 — EXIT trap이 fixture를 지우는 문제 방지)
  run_hook "$fixture" "$doc_paths_arg"
  local hook_exit="$_hook_last_exit"

  local label="scenario ${num}: ${name}"
  local failed=0

  assert_eq "$label (exit code)" "$expected_exit" "$hook_exit" || failed=1

  if [[ "$expect_validated" == "yes" ]]; then
    assert_validated "$fixture" "$label" || failed=1
  else
    assert_skipped "$fixture" "$label" || failed=1
  fi

  if [[ "$failed" -eq 0 ]]; then
    echo "[PASS] $label"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $label — fixture: $fixture" >&2
    FAIL=$((FAIL + 1))
  fi

  cleanup_fixture
}

# ---------------------------------------------------------------------------
# 시나리오 1: md-only (A) — skip
# ---------------------------------------------------------------------------
f="$(make_fixture 'A\tREADME.md')"
run_scenario 1 "md-only (A)" "$f" 0 "no"

# ---------------------------------------------------------------------------
# 시나리오 2: code + docs 혼합 — validate
# ---------------------------------------------------------------------------
f="$(make_fixture 'A\tsrc/foo.swift\nA\tdocs/a.md')"
run_scenario 2 "code + docs 혼합" "$f" 0 "yes"

# ---------------------------------------------------------------------------
# 시나리오 3: rename code→docs (R) — validate (source가 비문서)
# ---------------------------------------------------------------------------
f="$(make_fixture 'R080\tsrc/foo.swift\tdocs/foo.swift')"
run_scenario 3 "rename code→docs (R)" "$f" 0 "yes"

# ---------------------------------------------------------------------------
# 시나리오 4: rename docs↔docs (R) — skip (양쪽 모두 문서)
# ---------------------------------------------------------------------------
f="$(make_fixture 'R100\tdocs/a.md\tdocs/b.md')"
run_scenario 4 "rename docs↔docs (R)" "$f" 0 "no"

# ---------------------------------------------------------------------------
# 시나리오 5: delete code (D) — validate
# ---------------------------------------------------------------------------
f="$(make_fixture 'D\tsrc/foo.swift')"
run_scenario 5 "delete code (D)" "$f" 0 "yes"

# ---------------------------------------------------------------------------
# 시나리오 6: delete docs (D) — skip
# ---------------------------------------------------------------------------
f="$(make_fixture 'D\tdocs/a.md')"
run_scenario 6 "delete docs (D)" "$f" 0 "no"

# ---------------------------------------------------------------------------
# 시나리오 7: PRE_COMMIT_DOC_PATHS="" + md-only — validate (패턴 0개)
# ---------------------------------------------------------------------------
f="$(make_fixture 'A\tREADME.md')"
run_scenario 7 "PRE_COMMIT_DOC_PATHS=empty + md-only" "$f" 0 "yes" ""

# ---------------------------------------------------------------------------
# 시나리오 8: PRE_COMMIT_DOC_PATHS="*.md" + docs/a.txt — validate
# docs/a.txt는 *.md 패턴과 매칭 안 됨 (기본 docs/* 패턴이 대체로 제거된 상태)
# ---------------------------------------------------------------------------
f="$(make_fixture 'A\tdocs/a.txt')"
run_scenario 8 "PRE_COMMIT_DOC_PATHS=*.md + docs/a.txt" "$f" 0 "yes" "*.md"

# ---------------------------------------------------------------------------
# 시나리오 9: git diff 실패 (unknown fallback) — validate
# ---------------------------------------------------------------------------
f="$(make_fixture_git_fail)"
_current_fixture="$f"

run_hook "$f"
hook_exit_9="$_hook_last_exit"

label_9="scenario 9: git 실패 (unknown fallback)"
failed_9=0

assert_eq "$label_9 (exit code)" "0" "$hook_exit_9" || failed_9=1
assert_validated "$f" "$label_9" || failed_9=1

if [[ "$failed_9" -eq 0 ]]; then
  echo "[PASS] $label_9"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_9 — fixture: $f" >&2
  FAIL=$((FAIL + 1))
fi

cleanup_fixture

# ---------------------------------------------------------------------------
# 시나리오 10: type change (T) — validate (src/symlink은 비문서)
# ---------------------------------------------------------------------------
f="$(make_fixture 'T\tsrc/symlink')"
run_scenario 10 "type change (T)" "$f" 0 "yes"

# ---------------------------------------------------------------------------
# 시나리오 11: non-md docs-only (기본 패턴 4개 전부 커버)
# docs/*, rd-workflow-workspace/*, rd-workflow/docs/* 3개 디렉토리 패턴 동시 검증
# ---------------------------------------------------------------------------
f="$(make_fixture 'A\trd-workflow-workspace/items/foo.txt\nA\tdocs/guides/bar.txt\nA\trd-workflow/docs/guides/asset.txt')"
run_scenario 11 "non-md docs-only (docs/* + rd-workflow-workspace/* + rd-workflow/docs/*)" "$f" 0 "no"

# ---------------------------------------------------------------------------
# 결과 요약
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
