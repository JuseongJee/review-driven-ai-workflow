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

# ===========================================================================
# 캐싱 테스트 섹션 (케이스 C1–C10): 실제 git sandbox repo 사용
# git write-tree는 실제 index가 있는 repo에서만 유효 — mock git으로는 불가
# ===========================================================================

# ---------------------------------------------------------------------------
# 캐싱 fixture 생성 헬퍼: 실제 git repo + 검증 스크립트 + hook 포함
# $1: 비문서 파일 이름 (staged에 넣을 파일)
# Returns: fixture 경로 (내부에 실제 git repo 구성)
# ---------------------------------------------------------------------------
make_cache_fixture() {
  local staged_file="${1:-src/code.sh}"
  local fixture
  fixture="$(mktemp -d)"

  # 실제 git repo 초기화
  git -C "$fixture" init -q
  git -C "$fixture" config user.email "test@example.com"
  git -C "$fixture" config user.name "Test"

  # 디렉토리 구조
  mkdir -p "$fixture/rd-workflow/scripts/hooks"
  mkdir -p "$fixture/rd-workflow-workspace/.lifecycle"
  mkdir -p "$fixture/markers"

  # hook 복사 (BASH_SOURCE[0]이 hook 자신을 참조하므로 fixture 내부로 복사)
  cp "$HOOK_SOURCE" "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh"
  chmod +x "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh"

  # 검증 stub 스크립트 생성 (실행되면 marker 파일 생성)
  local s
  for s in test lint typecheck; do
    cat > "$fixture/rd-workflow/scripts/${s}.sh" <<STUB
#!/bin/bash
touch "$fixture/markers/${s}.done"
exit 0
STUB
    chmod +x "$fixture/rd-workflow/scripts/${s}.sh"
  done

  # staged 상태 구성: 비문서 파일을 실제로 add
  local staged_dir
  staged_dir="$(dirname "$staged_file")"
  [[ "$staged_dir" != "." ]] && mkdir -p "$fixture/$staged_dir"
  printf 'content-v1\n' > "$fixture/$staged_file"
  git -C "$fixture" add "$staged_file"

  printf '%s' "$fixture"
}

# 캐싱 fixture hook 실행 헬퍼 (실제 git repo 기반)
# CWD를 fixture로 변경해서 실행해야 git diff --cached 등이 fixture repo를 참조함
# stderr도 별도 변수에 캡처
_cache_hook_last_exit=0
_cache_hook_stderr=""
run_cache_hook() {
  local fixture="$1"
  _cache_hook_last_exit=0
  _cache_hook_stderr=""
  local stderr_tmp
  stderr_tmp="$(mktemp)"
  # CWD를 fixture로 변경: subshell로 cd + hook 실행 (hook PATH는 system PATH 그대로)
  printf '%s' '{"tool_input":{"command":"git commit -m test"}}' | \
    ( cd "$fixture" && bash "$fixture/rd-workflow/scripts/hooks/pre_commit_verify.sh" ) \
    2>"$stderr_tmp" || _cache_hook_last_exit=$?
  _cache_hook_stderr="$(cat "$stderr_tmp")"
  rm -f "$stderr_tmp"
}

# 마커 초기화 헬퍼
clear_markers() {
  local fixture="$1"
  rm -f "$fixture/markers/test.done" "$fixture/markers/lint.done" "$fixture/markers/typecheck.done"
}

# ---------------------------------------------------------------------------
# C1: 비문서 staged + 검증 성공 1회차 → 검증 실행됨 + verify-cache 생성
# ---------------------------------------------------------------------------
f_c1="$(make_cache_fixture 'src/code.sh')"
_current_fixture="$f_c1"

run_cache_hook "$f_c1"
label_c1="cache-C1: 1회차 성공 → 캐시 생성"
failed_c1=0

assert_eq "$label_c1 (exit)" "0" "$_cache_hook_last_exit" || failed_c1=1
assert_validated "$f_c1" "$label_c1" || failed_c1=1
if [[ ! -f "$f_c1/rd-workflow-workspace/.lifecycle/verify-cache" ]]; then
  echo "[FAIL] $label_c1 — verify-cache 파일이 생성되지 않았습니다" >&2
  failed_c1=1
fi

if [[ "$failed_c1" -eq 0 ]]; then
  echo "[PASS] $label_c1"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c1 — fixture: $f_c1" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C2: 동일 staged 2회차 → 검증 스킵 (marker 미생성) + stderr 고지
# ---------------------------------------------------------------------------
f_c2="$(make_cache_fixture 'src/code.sh')"
_current_fixture="$f_c2"

# 1회차 실행 → 캐시 생성
run_cache_hook "$f_c2"
# marker 초기화 후 2회차
clear_markers "$f_c2"
run_cache_hook "$f_c2"
label_c2="cache-C2: 동일 staged 2회차 → 스킵"
failed_c2=0

assert_eq "$label_c2 (exit)" "0" "$_cache_hook_last_exit" || failed_c2=1
assert_skipped "$f_c2" "$label_c2" || failed_c2=1
if [[ "$_cache_hook_stderr" != *"캐시 일치"* ]] && [[ "$_cache_hook_stderr" != *"검증 스킵"* ]]; then
  echo "[FAIL] $label_c2 — stderr에 스킵 고지 없음: '$_cache_hook_stderr'" >&2
  failed_c2=1
fi

if [[ "$failed_c2" -eq 0 ]]; then
  echo "[PASS] $label_c2"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c2 — fixture: $f_c2" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C3: staged 내용 변경 → 재실행 (캐시 불일치)
# ---------------------------------------------------------------------------
f_c3="$(make_cache_fixture 'src/code.sh')"
_current_fixture="$f_c3"

# 1회차 → 캐시 생성
run_cache_hook "$f_c3"
# staged 내용 변경 후 재 stage
printf 'content-v2-changed\n' > "$f_c3/src/code.sh"
git -C "$f_c3" add "src/code.sh"
clear_markers "$f_c3"
run_cache_hook "$f_c3"
label_c3="cache-C3: staged 내용 변경 → 재실행"
failed_c3=0

assert_eq "$label_c3 (exit)" "0" "$_cache_hook_last_exit" || failed_c3=1
assert_validated "$f_c3" "$label_c3" || failed_c3=1

if [[ "$failed_c3" -eq 0 ]]; then
  echo "[PASS] $label_c3"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c3 — fixture: $f_c3" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C4: 검증 스크립트(test.sh) 내용 변경 → 재실행
# ---------------------------------------------------------------------------
f_c4="$(make_cache_fixture 'src/code.sh')"
_current_fixture="$f_c4"

# 1회차
run_cache_hook "$f_c4"
# test.sh 내용 변경 (stub에 주석 추가)
printf '# changed\n' >> "$f_c4/rd-workflow/scripts/test.sh"
clear_markers "$f_c4"
run_cache_hook "$f_c4"
label_c4="cache-C4: 검증 스크립트 변경 → 재실행"
failed_c4=0

assert_eq "$label_c4 (exit)" "0" "$_cache_hook_last_exit" || failed_c4=1
assert_validated "$f_c4" "$label_c4" || failed_c4=1

if [[ "$failed_c4" -eq 0 ]]; then
  echo "[PASS] $label_c4"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c4 — fixture: $f_c4" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C5: verify-cache 손상(임의 문자열) → fail-closed = 전체 검증 실행
# ---------------------------------------------------------------------------
f_c5="$(make_cache_fixture 'src/code.sh')"
_current_fixture="$f_c5"

# 손상된 캐시 파일 주입
mkdir -p "$f_c5/rd-workflow-workspace/.lifecycle"
printf 'CORRUPTED_NOT_A_HASH\n' > "$f_c5/rd-workflow-workspace/.lifecycle/verify-cache"
run_cache_hook "$f_c5"
label_c5="cache-C5: 캐시 손상 → fail-closed 전체 검증"
failed_c5=0

assert_eq "$label_c5 (exit)" "0" "$_cache_hook_last_exit" || failed_c5=1
assert_validated "$f_c5" "$label_c5" || failed_c5=1

if [[ "$failed_c5" -eq 0 ]]; then
  echo "[PASS] $label_c5"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c5 — fixture: $f_c5" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C6: 검증 실패 시 → verify-cache 미기록
# ---------------------------------------------------------------------------
f_c6="$(make_cache_fixture 'src/code.sh')"
_current_fixture="$f_c6"

# test.sh을 실패(exit 1)하는 버전으로 교체
cat > "$f_c6/rd-workflow/scripts/test.sh" <<'FAILSTUB'
#!/bin/bash
exit 1
FAILSTUB
chmod +x "$f_c6/rd-workflow/scripts/test.sh"
run_cache_hook "$f_c6"
label_c6="cache-C6: 검증 실패 → 캐시 미기록"
failed_c6=0

# exit 2 예상 (검증 실패)
assert_eq "$label_c6 (exit)" "2" "$_cache_hook_last_exit" || failed_c6=1
if [[ -f "$f_c6/rd-workflow-workspace/.lifecycle/verify-cache" ]]; then
  echo "[FAIL] $label_c6 — 검증 실패인데 verify-cache가 생성되었습니다" >&2
  failed_c6=1
fi

if [[ "$failed_c6" -eq 0 ]]; then
  echo "[PASS] $label_c6"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c6 — fixture: $f_c6" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C7: 기존 회귀 — doc-only 스킵·TEMPLATE_STUB 스킵 동작 불변 (캐싱 테스트 기반)
# doc-only staged → classify_staged가 0 반환 → 캐싱 로직 자체에 도달하지 않음
# ---------------------------------------------------------------------------
f_c7="$(make_cache_fixture 'README.md')"
_current_fixture="$f_c7"

# README.md 자체는 이미 add됨. 캐시 없는 상태에서 실행
run_cache_hook "$f_c7"
label_c7="cache-C7: 기존 doc-only 스킵 회귀 (캐싱 전 단계 스킵 불변)"
failed_c7=0

assert_eq "$label_c7 (exit)" "0" "$_cache_hook_last_exit" || failed_c7=1
assert_skipped "$f_c7" "$label_c7" || failed_c7=1
# doc-only는 캐시도 생성하지 않아야 함 (classify 단계에서 조기 exit 0)
if [[ -f "$f_c7/rd-workflow-workspace/.lifecycle/verify-cache" ]]; then
  echo "[FAIL] $label_c7 — doc-only인데 verify-cache가 생성되었습니다" >&2
  failed_c7=1
fi

if [[ "$failed_c7" -eq 0 ]]; then
  echo "[PASS] $label_c7"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c7 — fixture: $f_c7" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C8: binary staged 변경 → 키가 달라져 재실행 (write-tree 기반 증명)
# ---------------------------------------------------------------------------
f_c8="$(make_cache_fixture 'src/binary.bin')"
_current_fixture="$f_c8"

# 1회차 (binary 파일 v1)
run_cache_hook "$f_c8"
# binary 파일 내용 변경 (barely-different: 마지막 바이트만 다름)
printf '\x00\x01\x02\x03\x04' > "$f_c8/src/binary.bin"
git -C "$f_c8" add "src/binary.bin"
clear_markers "$f_c8"
run_cache_hook "$f_c8"
label_c8="cache-C8: binary staged 변경 → 재실행"
failed_c8=0

assert_eq "$label_c8 (exit)" "0" "$_cache_hook_last_exit" || failed_c8=1
assert_validated "$f_c8" "$label_c8" || failed_c8=1

if [[ "$failed_c8" -eq 0 ]]; then
  echo "[PASS] $label_c8"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c8 — fixture: $f_c8" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C9: 검증 스크립트 삭제(missing 전이) → 키 변경으로 재실행
# test.sh 삭제 시 hook 실행 루프에서 파일 없으면 skip하므로 lint.done+typecheck.done만 생성됨.
# 핵심 확인: 캐시 일치 스킵이 아니라 검증 루프에 도달했음을 lint/typecheck marker로 증명.
# ---------------------------------------------------------------------------
f_c9="$(make_cache_fixture 'src/code.sh')"
_current_fixture="$f_c9"

# 1회차 → 캐시 생성
run_cache_hook "$f_c9"
# test.sh 삭제 (missing 전이) → 키가 달라짐
rm -f "$f_c9/rd-workflow/scripts/test.sh"
clear_markers "$f_c9"
run_cache_hook "$f_c9"
label_c9="cache-C9: 검증 스크립트 삭제(missing 전이) → 재실행"
failed_c9=0

assert_eq "$label_c9 (exit)" "0" "$_cache_hook_last_exit" || failed_c9=1
# test.sh가 없으므로 test.done은 생성 안 됨. lint.done + typecheck.done이 생성됐으면 검증 루프에 진입한 것.
if [[ ! -f "$f_c9/markers/lint.done" ]] || [[ ! -f "$f_c9/markers/typecheck.done" ]]; then
  echo "[FAIL] $label_c9 — lint/typecheck 검증 루프에 진입하지 않았습니다" >&2
  failed_c9=1
fi
# 캐시 스킵이 발생하지 않았는지 stderr로 확인 (스킵 고지 문자열 부재 = 정상 재실행)
if [[ "$_cache_hook_stderr" == *"캐시 일치"* ]] || [[ "$_cache_hook_stderr" == *"검증 스킵"* ]]; then
  echo "[FAIL] $label_c9 — 캐시 스킵이 발생했습니다: '$_cache_hook_stderr'" >&2
  failed_c9=1
fi

if [[ "$failed_c9" -eq 0 ]]; then
  echo "[PASS] $label_c9"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c9 — fixture: $f_c9" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# C10: git write-tree 실패(비정상 index) → 캐싱 비활성 = 전체 검증 실행
# macOS에는 /usr/bin/shasum이 기본 제공되므로 PATH 조작으로 hash 도구 부재를
# 만들 수 없습니다. write-tree 실패로 verify_key가 비어있게 되는 동등한 경로를 검증합니다.
# ---------------------------------------------------------------------------
f_c10="$(make_cache_fixture 'src/code.sh')"
_current_fixture="$f_c10"

# .git/index 손상 → git write-tree 실패 유도 (비정상 index)
printf 'CORRUPTED_INDEX\n' > "$f_c10/.git/index"
run_cache_hook "$f_c10"
label_c10="cache-C10: write-tree 실패(비정상 index) → 캐싱 비활성, 전체 검증 실행"
failed_c10=0

assert_eq "$label_c10 (exit)" "0" "$_cache_hook_last_exit" || failed_c10=1
assert_validated "$f_c10" "$label_c10" || failed_c10=1
# write-tree 실패 시 verify_key가 비어 캐시 파일은 생성되지 않아야 함
if [[ -f "$f_c10/rd-workflow-workspace/.lifecycle/verify-cache" ]]; then
  echo "[FAIL] $label_c10 — write-tree 실패인데 verify-cache가 생성되었습니다" >&2
  failed_c10=1
fi

if [[ "$failed_c10" -eq 0 ]]; then
  echo "[PASS] $label_c10"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $label_c10 — fixture: $f_c10" >&2
  FAIL=$((FAIL + 1))
fi
cleanup_fixture

# ---------------------------------------------------------------------------
# 결과 요약
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
