#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/slug.sh"

PASS=0; FAIL=0
assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [[ "$got" == "$want" ]]; then PASS=$((PASS+1)); echo "  PASS: $desc";
  else FAIL=$((FAIL+1)); echo "  FAIL: $desc — got=[$got] want=[$want]" >&2; fi
}
assert_err() {
  local input="$1" desc="$2"
  if normalize_slug "$input" >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "  FAIL: $desc — expected error but got success" >&2
  else PASS=$((PASS+1)); echo "  PASS: $desc"; fi
}

echo "== slug normalization =="
assert_eq "$(normalize_slug 'Foo Bar')" "foo-bar" "공백 + 대문자"
assert_eq "$(normalize_slug 'foo  bar')" "foo-bar" "다중 공백 압축"
assert_eq "$(normalize_slug 'foo_bar')" "foo-bar" "underscore 치환"
assert_eq "$(normalize_slug 'foo.bar')" "foo-bar" "dot 치환"
assert_eq "$(normalize_slug '--foo--')" "foo" "양끝 trim"
assert_eq "$(normalize_slug 'foo--bar')" "foo-bar" "연속 dash 압축"
assert_err "한글" "비-ASCII 거부"
assert_err "foo!bar" "특수문자 거부"
assert_err "" "빈 문자열 거부"
assert_err "   " "공백만 거부"
assert_err "$(printf 'x%.0s' {1..61})" "61자 거부"


# === Task 2: _lifecycle_common.sh fixtures ===
source "$SCRIPT_DIR/_lifecycle_common.sh"

echo "== git state helpers =="
assert_in_set() {
  local got="$1" set="$2" desc="$3"
  if [[ ",$set," == *",$got,"* ]]; then PASS=$((PASS+1)); echo "  PASS: $desc";
  else FAIL=$((FAIL+1)); echo "  FAIL: $desc — got=[$got]" >&2; fi
}

assert_in_set "$(detect_remote_mode)" "remote,local-only" "detect_remote_mode 반환값"
ensure_worktree_clean >/dev/null 2>&1 && rc=0 || rc=$?
assert_in_set "$rc" "0,1" "ensure_worktree_clean exit code"

echo "== metadata I/O =="
TMPDIR_TEST="$(mktemp -d)"
trap "rm -rf '$TMPDIR_TEST'" EXIT
# v2 2b: task-state 경로로 격리 (LIFECYCLE_METADATA_PATH 폐지 — TASK_STATE_PATH 사용)
TASK_STATE_PATH="$TMPDIR_TEST/task-state"
if metadata_exists; then FAIL=$((FAIL+1)); echo "  FAIL: empty metadata 인데 exists 반환" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: metadata 부재 (fr-branch=null 또는 파일 없음)"; fi
metadata_write "fr/foo" "foo" "/path"
if metadata_exists; then PASS=$((PASS+1)); echo "  PASS: write 후 exists (fr-branch=fr/foo)"; \
  else FAIL=$((FAIL+1)); echo "  FAIL: metadata write 실패 — fr-branch 값 없음" >&2; fi
assert_eq "$(metadata_read_field fr-branch)" "fr/foo" "metadata_read fr-branch"
assert_eq "$(metadata_read_field short-title)" "foo" "metadata_read short-title"
assert_eq "$(metadata_read_field worktree-path)" "/path" "metadata_read worktree-path"
# created-at 존재 확인 (write 후 생성)
if grep -q "^created-at=" "$TASK_STATE_PATH" 2>/dev/null; then PASS=$((PASS+1)); echo "  PASS: write 후 created-at 존재"; \
  else FAIL=$((FAIL+1)); echo "  FAIL: created-at 누락" >&2; fi
metadata_clear
# clear 후: fr-branch=null, worktree-path=null, created-at 제거
assert_eq "$(metadata_read_field fr-branch)" "null" "metadata_clear 후 fr-branch=null"
assert_eq "$(metadata_read_field worktree-path)" "null" "metadata_clear 후 worktree-path=null"
if grep -q "^created-at=" "$TASK_STATE_PATH" 2>/dev/null; then FAIL=$((FAIL+1)); echo "  FAIL: clear 후 created-at 잔존" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: clear 후 created-at 제거"; fi
if metadata_exists; then FAIL=$((FAIL+1)); echo "  FAIL: clear 후에도 metadata_exists true" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: metadata_exists false (fr-branch=null)"; fi

# --- legacy active-fr fallback (수정 2: metadata_read_field legacy fallback) ---
echo "== legacy active-fr fallback =="
LEGACY_AFR_DIR="$TMPDIR_TEST/legacy-root/rd-workflow-workspace/.lifecycle"
mkdir -p "$LEGACY_AFR_DIR"
printf 'fr-branch=fr/legacy-test\nshort-title=legacy-task\nworktree-path=/tmp/legacy\n' > "$LEGACY_AFR_DIR/active-fr"
# task-state 없는 상태 + project_root 격리
(
  set +e
  export project_root="$TMPDIR_TEST/legacy-root"
  export TASK_STATE_PATH="$TMPDIR_TEST/legacy-root/rd-workflow-workspace/.lifecycle/task-state"
  rm -f "$TASK_STATE_PATH"
  source "$SCRIPT_DIR/_lifecycle_common.sh"
  got="$(metadata_read_field fr-branch)"
  if [[ "$got" == "fr/legacy-test" ]]; then
    echo "  PASS: task-state 부재 + active-fr → fr-branch=fr/legacy-test"
    exit 0
  else
    echo "  FAIL: task-state 부재 legacy fallback — got=[$got] want=[fr/legacy-test]" >&2
    exit 1
  fi
) && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# task-state 존재 시 legacy active-fr 무시 확인
(
  set +e
  export project_root="$TMPDIR_TEST/legacy-root"
  export TASK_STATE_PATH="$TMPDIR_TEST/legacy-root/rd-workflow-workspace/.lifecycle/task-state2"
  mkdir -p "$(dirname "$TASK_STATE_PATH")"
  printf 'schema=1\nfr-branch=fr/real-state\nshort-title=real\nstatus=구현 중\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
  # active-fr도 존재 (무시 대상)
  printf 'fr-branch=fr/legacy-test\nshort-title=legacy-task\n' > "$LEGACY_AFR_DIR/active-fr"
  source "$SCRIPT_DIR/_lifecycle_common.sh"
  got="$(metadata_read_field fr-branch)"
  if [[ "$got" == "fr/real-state" ]]; then
    echo "  PASS: task-state 존재 시 active-fr 무시 → fr-branch=fr/real-state"
    exit 0
  else
    echo "  FAIL: task-state 존재 시 legacy 값이 노출됨 — got=[$got] want=[fr/real-state]" >&2
    exit 1
  fi
) && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# metadata_clear — legacy active-fr 삭제 확인 (수정 3)
(
  set +e
  export project_root="$TMPDIR_TEST/legacy-root"
  export TASK_STATE_PATH="$TMPDIR_TEST/legacy-root/rd-workflow-workspace/.lifecycle/task-state3"
  mkdir -p "$(dirname "$TASK_STATE_PATH")"
  printf 'schema=1\nfr-branch=fr/to-clear\nshort-title=clr\nstatus=구현 중\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
  printf 'fr-branch=fr/to-clear\nshort-title=clr\n' > "$LEGACY_AFR_DIR/active-fr"
  source "$SCRIPT_DIR/_lifecycle_common.sh"
  metadata_clear
  if [[ ! -f "$LEGACY_AFR_DIR/active-fr" ]]; then
    echo "  PASS: metadata_clear → legacy active-fr 삭제됨"
    exit 0
  else
    echo "  FAIL: metadata_clear 후 active-fr 잔존" >&2
    exit 1
  fi
) && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# metadata_exists — legacy fallback 회귀 테스트
# metadata_exists가 metadata_read_field 경유로 legacy fallback을 공유하는지 검증
echo "== metadata_exists legacy fallback =="
# Case 1: task-state 부재 + active-fr(fr-branch=fr/x) → metadata_exists return 0 (참)
(
  set +e
  export project_root="$TMPDIR_TEST/exists-legacy-root"
  export TASK_STATE_PATH="$TMPDIR_TEST/exists-legacy-root/rd-workflow-workspace/.lifecycle/task-state"
  local_afr="$TMPDIR_TEST/exists-legacy-root/rd-workflow-workspace/.lifecycle"
  mkdir -p "$local_afr"
  rm -f "$TASK_STATE_PATH"
  printf 'fr-branch=fr/x\nshort-title=legacy-x\n' > "$local_afr/active-fr"
  source "$SCRIPT_DIR/_lifecycle_common.sh"
  if metadata_exists; then
    echo "  PASS: task-state 부재 + active-fr(fr/x) → metadata_exists true"
    exit 0
  else
    echo "  FAIL: task-state 부재 + active-fr(fr/x) → metadata_exists false (legacy fallback 미적용)" >&2
    exit 1
  fi
) && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# Case 2: task-state 존재(fr-branch=null) + active-fr 잔존(fr-branch=fr/x) → metadata_exists return 1 (task-state 우선)
(
  set +e
  export project_root="$TMPDIR_TEST/exists-ts-root"
  export TASK_STATE_PATH="$TMPDIR_TEST/exists-ts-root/rd-workflow-workspace/.lifecycle/task-state"
  local_afr="$TMPDIR_TEST/exists-ts-root/rd-workflow-workspace/.lifecycle"
  mkdir -p "$local_afr"
  printf 'schema=1\nfr-branch=null\nshort-title=cleared\nstatus=대기 중\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
  printf 'fr-branch=fr/x\nshort-title=legacy-x\n' > "$local_afr/active-fr"
  source "$SCRIPT_DIR/_lifecycle_common.sh"
  if metadata_exists; then
    echo "  FAIL: task-state(fr-branch=null) + active-fr → metadata_exists true (legacy 값이 우선됨)" >&2
    exit 1
  else
    echo "  PASS: task-state(fr-branch=null) + active-fr → metadata_exists false (task-state 우선)"
    exit 0
  fi
) && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# Case 3: task-state 부재 + active-fr 부재 → metadata_exists return 1
(
  set +e
  export project_root="$TMPDIR_TEST/exists-empty-root"
  export TASK_STATE_PATH="$TMPDIR_TEST/exists-empty-root/rd-workflow-workspace/.lifecycle/task-state"
  mkdir -p "$(dirname "$TASK_STATE_PATH")"
  rm -f "$TASK_STATE_PATH" "$TMPDIR_TEST/exists-empty-root/rd-workflow-workspace/.lifecycle/active-fr"
  source "$SCRIPT_DIR/_lifecycle_common.sh"
  if metadata_exists; then
    echo "  FAIL: task-state 부재 + active-fr 부재 → metadata_exists true" >&2
    exit 1
  else
    echo "  PASS: task-state 부재 + active-fr 부재 → metadata_exists false"
    exit 0
  fi
) && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

echo "== Task 2 누적: PASS=$PASS FAIL=$FAIL =="

echo "== loop-state primitives =="
LOOP_STATE_PATH="$TMPDIR_TEST/loop-state"
rm -f "$LOOP_STATE_PATH"
assert_eq "$(loop_state_get 'verify-fail::test')" "0" "미존재 키 → 0"
loop_state_record "verify-fail::test" incr
loop_state_record "verify-fail::test" incr
assert_eq "$(loop_state_get 'verify-fail::test')" "2" "incr 2회 → 2"
loop_state_record "verify-fail::test" reset
assert_eq "$(loop_state_get 'verify-fail::test')" "0" "reset → 0"
loop_state_record "reedit::a/b.sh" incr
loop_state_record "rollback::foo" incr
loop_state_record "verify-fail::lint" incr
loop_state_clear_attempt
assert_eq "$(loop_state_get 'reedit::a/b.sh')" "0" "clear_attempt → reedit 제거"
assert_eq "$(loop_state_get 'verify-fail::lint')" "0" "clear_attempt → verify-fail 제거"
assert_eq "$(loop_state_get 'rollback::foo')" "1" "clear_attempt → rollback 보존"
loop_state_clear_all
if [[ -f "$LOOP_STATE_PATH" ]]; then FAIL=$((FAIL+1)); echo "  FAIL: clear_all 후 파일 잔존" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: clear_all"; fi
rc=0; loop_state_record "bad=key" incr 2>/dev/null || rc=$?
assert_eq "$rc" "1" "잘못된 키(=) 거부"
rc=0; loop_state_record "$(printf 'a\nb')" incr 2>/dev/null || rc=$?
assert_eq "$rc" "1" "잘못된 키(개행) 거부"

echo "== loop-guard check =="
LOOP_GUARD_CONFIG="$TMPDIR_TEST/loop-guard.json"
export LOOP_GUARD_CONFIG
rm -f "$LOOP_STATE_PATH" "$LOOP_GUARD_CONFIG"
SLUG_T="demo"
# config 미존재 → 기본 임계 3
assert_eq "$(loop_guard_threshold verify_fail)" "3" "config 미존재 → 기본 3"
# verify-fail 임계 도달 → halt (slug-scoped key)
loop_state_record "verify-fail::${SLUG_T}::test" incr
loop_state_record "verify-fail::${SLUG_T}::test" incr
loop_state_record "verify-fail::${SLUG_T}::test" incr
rc=0; out="$(loop_guard_check "$SLUG_T")" || rc=$?
assert_eq "$rc" "1" "verify-fail 3회 → halt(return 1)"
case "$out" in *"검증 연속 실패"*) PASS=$((PASS+1)); echo "  PASS: verify-fail 사유 출력";; *) FAIL=$((FAIL+1)); echo "  FAIL: 사유 누락 — [$out]" >&2;; esac
# FR scoping: 다른 slug 로 조회 → 현재 FR 키 무시 → halt 안 함
rc=0; loop_guard_check "other" >/dev/null || rc=$?
assert_eq "$rc" "0" "다른 slug → FR scoping (halt 안 함)"
# rollback 임계 도달 → halt
rm -f "$LOOP_STATE_PATH"
loop_state_record "rollback::${SLUG_T}" incr; loop_state_record "rollback::${SLUG_T}" incr; loop_state_record "rollback::${SLUG_T}" incr
rc=0; loop_guard_check "$SLUG_T" >/dev/null || rc=$?
assert_eq "$rc" "1" "rollback 3회 → halt"
# reedit 단독 → halt 안 함
rm -f "$LOOP_STATE_PATH"
loop_state_record "reedit::${SLUG_T}::a.sh" incr; loop_state_record "reedit::${SLUG_T}::a.sh" incr; loop_state_record "reedit::${SLUG_T}::a.sh" incr
rc=0; loop_guard_check "$SLUG_T" >/dev/null || rc=$?
assert_eq "$rc" "0" "reedit 단독 3회 → halt 안 함"
# reedit + verify-fail 결합(ceil(3/2)=2) → halt
loop_state_record "verify-fail::${SLUG_T}::lint" incr; loop_state_record "verify-fail::${SLUG_T}::lint" incr
rc=0; loop_guard_check "$SLUG_T" >/dev/null || rc=$?
assert_eq "$rc" "1" "reedit 3 + verify-fail 2 → halt"
# enabled=false → 항상 0 (jq 있을 때만 의미; 없으면 skip+PASS)
if command -v jq >/dev/null 2>&1; then
  printf '{"enabled":false,"thresholds":{"verify_fail":1}}' > "$LOOP_GUARD_CONFIG"
  rm -f "$LOOP_STATE_PATH"; loop_state_record "verify-fail::${SLUG_T}::test" incr
  rc=0; loop_guard_check "$SLUG_T" >/dev/null || rc=$?
  assert_eq "$rc" "0" "enabled=false → halt 안 함"
  rm -f "$LOOP_GUARD_CONFIG"
else
  PASS=$((PASS+1)); echo "  PASS: jq 미설치 → enabled=false skip (fallback 기본값 동작)"
fi
unset LOOP_GUARD_CONFIG

echo "== rollback persistence =="
rm -f "$LOOP_STATE_PATH"
# 시뮬레이션: rollback 시 rollback:: 증가 후 clear_attempt (slug-scoped within-attempt 키)
loop_state_record "verify-fail::mytask::test" incr
loop_state_record "reedit::mytask::x.sh" incr
loop_state_record "rollback::mytask" incr
loop_state_clear_attempt
assert_eq "$(loop_state_get 'verify-fail::mytask::test')" "0" "clear_attempt → verify-fail 제거"
assert_eq "$(loop_state_get 'rollback::mytask')" "1" "rollback 1회 기록 + attempt clear 후 보존"
loop_state_record "rollback::mytask" incr
loop_state_clear_attempt
assert_eq "$(loop_state_get 'rollback::mytask')" "2" "2회 rollback 누적 (cross-attempt 지속)"
loop_state_clear_all
assert_eq "$(loop_state_get 'rollback::mytask')" "0" "clear_all → rollback 제거"

echo "== M2 attempt history 주입 =="
( # 서브셸 — review_common.sh의 set -e / PROJECT_ROOT 격리. fixture PROJECT_ROOT 사용.
  FAKE_ROOT="$TMPDIR_TEST/m2root"
  prev_dir="$FAKE_ROOT/rd-workflow-workspace/handoffs/review_pipeline/20260101_000000_prev"
  mkdir -p "$prev_dir" "$FAKE_ROOT/cur"
  printf '## Branch Context\n- short-title: demo\n' > "$prev_dir/SESSION.md"
  printf '## Current Summary\n이전 시도 요약입니다.\n' > "$prev_dir/CHECKPOINT.md"
  printf '## Branch Context\n- short-title: demo\n' > "$FAKE_ROOT/cur/SESSION.md"
  PROJECT_ROOT="$FAKE_ROOT"; export PROJECT_ROOT
  LOOP_STATE_PATH="$TMPDIR_TEST/m2-loop-state"; export LOOP_STATE_PATH
  # fixture loop-state (slug-scoped). demo reedit 6개 → top-5 cap 검증 (bar.sh=2 가 rank6 으로 제외).
  # reedit::other:: 는 negative — 출력에 안 나와야 함.
  {
    printf 'reedit::demo::c1.sh=10\nreedit::demo::c2.sh=9\nreedit::demo::c3.sh=8\n'
    printf 'reedit::demo::c4.sh=7\nreedit::demo::foo.sh=4\nreedit::demo::bar.sh=2\n'
    printf 'rollback::demo=1\nreedit::other::zzz.sh=9\n'
  } > "$LOOP_STATE_PATH"
  source "$SCRIPT_DIR/../review_common.sh"
  out_file="$TMPDIR_TEST/prompt_auto.txt"
  # $3 = cur/SESSION.md (short-title 정본). cur_session=sdir 이라 prev 와 겹치지 않음.
  RD_AUTOPILOT=1 build_review_prompt "$out_file" sdir cur/SESSION.md cfile uafile ltfile etfile spec-plan-review target goal 20 003
  grep -q "Attempt History" "$out_file" || { echo "  FAIL: autopilot prepend 누락" >&2; exit 9; }
  grep -q "c1.sh=10" "$out_file" || { echo "  FAIL: reedit 최상위 누락" >&2; exit 9; }
  grep -q "foo.sh=4" "$out_file" || { echo "  FAIL: reedit rank5 누락" >&2; exit 9; }
  grep -q "rollback 1회" "$out_file" || { echo "  FAIL: rollback count 누락" >&2; exit 9; }
  grep -q "이전 시도 요약" "$out_file" || { echo "  FAIL: 이전 종결 사유 누락" >&2; exit 9; }
  if grep -q "bar.sh" "$out_file"; then echo "  FAIL: top-5 cap 미적용 (rank6 bar.sh 노출)" >&2; exit 9; fi
  if grep -q "zzz.sh" "$out_file"; then echo "  FAIL: 다른 slug(other) 키가 샘" >&2; exit 9; fi
  out_file2="$TMPDIR_TEST/prompt_manual.txt"
  # 수동 모드 — RD_AUTOPILOT 을 명시적으로 비워 외부 환경(autopilot 세션) 오염을 격리한다.
  RD_AUTOPILOT="" build_review_prompt "$out_file2" sdir cur/SESSION.md cfile uafile ltfile etfile spec-plan-review target goal 20 003
  if grep -q "Attempt History" "$out_file2"; then echo "  FAIL: 수동 모드인데 prepend 됨" >&2; exit 9; fi
  echo "  PASS: M2 (prepend/reedit-top5/rollback/prev/negative-slug/manual)"
) && PASS=$((PASS+7)) || { FAIL=$((FAIL+1)); echo "  FAIL: M2 블록 실패" >&2; }

echo "== M2 prev-session exact slug match (api vs api-v2) =="
( # prefix slug 가 다른 FR 세션을 오인하지 않는지 — diff review turn 002 회귀
  FR="$TMPDIR_TEST/m2exact"
  api_dir="$FR/rd-workflow-workspace/handoffs/review_pipeline/20260101_000000_api"
  apiv2_dir="$FR/rd-workflow-workspace/handoffs/review_pipeline/20260102_000000_apiv2"
  mkdir -p "$api_dir" "$apiv2_dir"
  printf '## Branch Context\n- short-title: api\n' > "$api_dir/SESSION.md"
  printf '## Current Summary\nAPI 세션 요약.\n' > "$api_dir/CHECKPOINT.md"
  printf '## Branch Context\n- short-title: api-v2\n' > "$apiv2_dir/SESSION.md"
  printf '## Current Summary\nAPIV2 세션 요약.\n' > "$apiv2_dir/CHECKPOINT.md"
  PROJECT_ROOT="$FR"; export PROJECT_ROOT
  LOOP_STATE_PATH="$TMPDIR_TEST/m2exact-loop"; export LOOP_STATE_PATH
  : > "$LOOP_STATE_PATH"
  source "$SCRIPT_DIR/../review_common.sh"
  out="$(build_attempt_history api "")"
  printf '%s' "$out" | grep -q "API 세션 요약" || { echo "  FAIL: api 세션 요약 누락" >&2; exit 9; }
  if printf '%s' "$out" | grep -q "APIV2"; then echo "  FAIL: api-v2 세션이 api 로 오인 주입됨" >&2; exit 9; fi
  echo "  PASS: prev-session exact slug match (api ≠ api-v2)"
) && PASS=$((PASS+2)) || { FAIL=$((FAIL+1)); echo "  FAIL: M2 exact-match 블록 실패" >&2; }

echo "== build_ac_enforcement_notice =="
( # 서브셸 — review_common.sh의 set -e / PROJECT_ROOT 격리
  set +e
  source "$SCRIPT_DIR/../review_common.sh"
  acn_tmp="$(mktemp -d)"; trap "rm -rf '$acn_tmp'" EXIT

  mk_req() { # $1=AC 본문, $2=bypass 본문 → REQUEST.md 생성, 경로 echo
    local f="$acn_tmp/REQUEST_$RANDOM.md"
    printf '# Change Request\n\n## Acceptance Criteria\n%s\n\n## AC Bypass Reason\n%s\n\n## Source FR\n-\n' "$1" "$2" > "$f"
    printf '%s' "$f"
  }

  # 1) AC 채워짐 → 무주입 (빈 문자열)
  out="$(build_ac_enforcement_notice "$(mk_req '- 통과 조건 X' '-')")"
  [[ -z "$out" ]] || { echo "  FAIL: AC 채워짐인데 notice 발생 — [$out]" >&2; exit 9; }
  echo "  PASS: AC 채워짐 → 무주입"

  # 2) AC 비어있음(-) + bypass 없음 → 주입
  out="$(build_ac_enforcement_notice "$(mk_req '-' '-')")"
  printf '%s' "$out" | grep -q "완료 기준이 정의되지 않" || { echo "  FAIL: 누락 주입 메시지 없음" >&2; exit 9; }
  echo "  PASS: AC 비어있음 + 면제 없음 → 주입"

  # 3) AC 비어있음 + bypass=small-task → 면제 인정 (주입 메시지 미포함)
  out="$(build_ac_enforcement_notice "$(mk_req '-' 'small-task')")"
  printf '%s' "$out" | grep -q "면제 사유: small-task" || { echo "  FAIL: 면제 주석 없음" >&2; exit 9; }
  if printf '%s' "$out" | grep -q "완료 기준이 정의되지 않"; then echo "  FAIL: 면제인데 주입 메시지 포함" >&2; exit 9; fi
  echo "  PASS: bypass=small-task → 면제 인정"

  # 4) AC 비어있음 + bypass=오타 → 주입 + 경고
  out="$(build_ac_enforcement_notice "$(mk_req '-' 'typo')")"
  printf '%s' "$out" | grep -q "완료 기준이 정의되지 않" || { echo "  FAIL: 허용 외 값인데 주입 안 됨" >&2; exit 9; }
  printf '%s' "$out" | grep -q "인식할 수 없는 AC_BYPASS_REASON 값: typo" || { echo "  FAIL: 경고 누락" >&2; exit 9; }
  echo "  PASS: bypass=허용 외 값 → 주입 + 경고"

  # 5) AC가 HTML comment + '-' 만 → 비어있음 판정 → 주입 (Finding 1)
  out="$(build_ac_enforcement_notice "$(mk_req '<!-- 완료 기준을 적으세요 -->
-' '-')")"
  printf '%s' "$out" | grep -q "완료 기준이 정의되지 않" || { echo "  FAIL: comment+- 인데 채워짐으로 오판" >&2; exit 9; }
  echo "  PASS: AC=comment+'-' → 비어있음 → 주입"

  # 6) AC가 '-' 여러 줄(복수 placeholder) → 비어있음 → 주입 (Finding 1)
  out="$(build_ac_enforcement_notice "$(mk_req '-
-' '-')")"
  printf '%s' "$out" | grep -q "완료 기준이 정의되지 않" || { echo "  FAIL: 복수 '-' 인데 채워짐으로 오판" >&2; exit 9; }
  echo "  PASS: AC='-' 여러 줄 → 비어있음 → 주입"

  # 7) REQUEST.md 부재 → 빈 출력 + 성공 종료 (Finding 2)
  out="$(build_ac_enforcement_notice "$acn_tmp/NO_SUCH_REQUEST.md")" || { echo "  FAIL: 부재 경로에서 비정상 종료" >&2; exit 9; }
  [[ -z "$out" ]] || { echo "  FAIL: REQUEST 부재인데 notice 발생 — [$out]" >&2; exit 9; }
  echo "  PASS: REQUEST.md 부재 → 빈 출력 + 성공"

  # 8) AC가 multi-line HTML comment 블록 + '-' 만 → 비어있음 판정 → 주입 (diff-review Finding 1)
  out="$(build_ac_enforcement_notice "$(mk_req '<!--
완료 기준을 여기에 적으세요
placeholder 줄
-->
-' '-')")"
  printf '%s' "$out" | grep -q "완료 기준이 정의되지 않" || { echo "  FAIL: multi-line comment 블록 내부를 의미있는 줄로 오판" >&2; exit 9; }
  echo "  PASS: AC=multi-line comment 블록+'-' → 비어있음 → 주입"

  echo "  (build_ac_enforcement_notice OK)"
) || { FAIL=$((FAIL+1)); echo "FAIL: build_ac_enforcement_notice 단위 테스트" >&2; }
PASS=$((PASS+1))

echo "== build_review_prompt: AC enforcement 주입 =="
( set +e
  source "$SCRIPT_DIR/../review_common.sh"
  bp_tmp="$(mktemp -d)"; trap "rm -rf '$bp_tmp'" EXIT
  export PROJECT_ROOT="$bp_tmp"
  # AC 비어있는 REQUEST.md
  printf '# Change Request\n\n## Acceptance Criteria\n-\n\n## AC Bypass Reason\n-\n' > "$bp_tmp/REQUEST.md"
  # 첫 reviewer 턴 세션 (turns/ 에 reviewer 파일 없음)
  mkdir -p "$bp_tmp/sess/turns"; printf '# Turn 001 — Author\n' > "$bp_tmp/sess/turns/001_author.md"

  out_f="$bp_tmp/p1.txt"
  build_review_prompt "$out_f" sess sess/SESSION.md c u sess/turns/001_author.md sess/turns/002_reviewer.md request-review target goal 20 002
  grep -q "완료 기준이 정의되지 않" "$out_f" || { echo "  FAIL: request-review 첫 턴 주입 누락" >&2; exit 9; }
  echo "  PASS: request-review 첫 reviewer 턴 주입"

  out_f="$bp_tmp/p2.txt"
  build_review_prompt "$out_f" sess sess/SESSION.md c u sess/turns/001_author.md sess/turns/002_reviewer.md diff-review target goal 20 002
  grep -q "완료 기준이 정의되지 않" "$out_f" || { echo "  FAIL: diff-review 첫 턴 주입 누락" >&2; exit 9; }
  echo "  PASS: diff-review 첫 reviewer 턴 주입"

  # 둘째 reviewer 턴: turns/ 에 reviewer 파일 존재 → 미주입
  printf '# Turn 002 — Reviewer\n' > "$bp_tmp/sess/turns/002_reviewer.md"
  out_f="$bp_tmp/p3.txt"
  build_review_prompt "$out_f" sess sess/SESSION.md c u sess/turns/002_reviewer.md sess/turns/004_reviewer.md request-review target goal 20 004
  if grep -q "완료 기준이 정의되지 않" "$out_f"; then echo "  FAIL: 둘째 reviewer 턴인데 주입됨" >&2; exit 9; fi
  echo "  PASS: 둘째 reviewer 턴 → 미주입"

  # legacy *_codex.md 턴도 reviewer 턴으로 취급 → 둘째 턴 미주입 (diff-review Finding 2)
  rm -f "$bp_tmp/sess/turns/002_reviewer.md"
  printf '# Turn 002 — Reviewer (codex)\n' > "$bp_tmp/sess/turns/002_codex.md"
  out_f="$bp_tmp/p_legacy.txt"
  build_review_prompt "$out_f" sess sess/SESSION.md c u sess/turns/002_codex.md sess/turns/004_reviewer.md request-review target goal 20 004
  if grep -q "완료 기준이 정의되지 않" "$out_f"; then echo "  FAIL: legacy codex 턴 있는데 재주입됨" >&2; exit 9; fi
  echo "  PASS: legacy *_codex.md 턴 → reviewer 인식 → 미주입"
  rm -f "$bp_tmp/sess/turns/002_codex.md"

  # spec-plan-review: 대상 아님 → 미주입 (첫 턴이어도)
  rm -f "$bp_tmp/sess/turns/002_reviewer.md"
  out_f="$bp_tmp/p4.txt"
  build_review_prompt "$out_f" sess sess/SESSION.md c u sess/turns/001_author.md sess/turns/002_reviewer.md spec-plan-review target goal 20 002
  if grep -q "완료 기준이 정의되지 않" "$out_f"; then echo "  FAIL: spec-plan-review에 주입됨" >&2; exit 9; fi
  echo "  PASS: spec-plan-review → 미주입"
) || { FAIL=$((FAIL+1)); echo "FAIL: build_review_prompt AC 주입 테스트" >&2; }
PASS=$((PASS+1))

echo "== build_review_prompt: autopilot 공존 (AC notice + attempt history) =="
( set +e
  source "$SCRIPT_DIR/../review_common.sh"
  ar_tmp="$(mktemp -d)"; trap "rm -rf '$ar_tmp'" EXIT
  export PROJECT_ROOT="$ar_tmp"
  printf '# Change Request\n\n## Acceptance Criteria\n-\n\n## AC Bypass Reason\n-\n' > "$ar_tmp/REQUEST.md"
  mkdir -p "$ar_tmp/cur/turns"
  printf '## Branch Context\n- short-title: demo\n' > "$ar_tmp/cur/SESSION.md"
  printf '# Turn 001 — Author\n' > "$ar_tmp/cur/turns/001_author.md"
  prev="$ar_tmp/rd-workflow-workspace/handoffs/review_pipeline/20260101_000000_prev"
  mkdir -p "$prev"
  printf '## Branch Context\n- short-title: demo\n' > "$prev/SESSION.md"
  printf '## Current Summary\n이전 시도 요약입니다.\n' > "$prev/CHECKPOINT.md"
  export LOOP_STATE_PATH="$ar_tmp/loop-state"
  printf 'reedit::demo::c1.sh=10\nrollback::demo=1\n' > "$LOOP_STATE_PATH"

  out_f="$ar_tmp/auto.txt"
  RD_AUTOPILOT=1 build_review_prompt "$out_f" cur cur/SESSION.md c u cur/turns/001_author.md cur/turns/002_reviewer.md request-review target goal 20 002
  grep -q "완료 기준이 정의되지 않" "$out_f" || { echo "  FAIL: autopilot에서 AC notice 누락" >&2; exit 9; }
  grep -q "Attempt History" "$out_f" || { echo "  FAIL: autopilot attempt history 누락" >&2; exit 9; }
  ac_line="$(grep -n "완료 기준이 정의되지 않" "$out_f" | head -1 | cut -d: -f1)"
  ah_line="$(grep -n "Attempt History" "$out_f" | head -1 | cut -d: -f1)"
  [[ "$ac_line" -lt "$ah_line" ]] || { echo "  FAIL: AC notice 가 attempt history 보다 먼저가 아님 (ac=$ac_line ah=$ah_line)" >&2; exit 9; }
  echo "  PASS: autopilot 공존 — AC notice 먼저 + 두 블록 존재"
) || { FAIL=$((FAIL+1)); echo "FAIL: autopilot 공존 테스트" >&2; }
PASS=$((PASS+1))

echo "== parse_turn_limit_line / read_session_turn_limit (turn-limit-parser-anchored) =="
tl_tmp="$(mktemp -d)"

# (a) 정본 형식 추출 — 백틱 포함 리터럴
got="$( source "$SCRIPT_DIR/../review_common.sh"; parse_turn_limit_line '50 total turns in `turns/*.md`' 2>/dev/null )"
assert_eq "$got" "50" "parse: 정본 형식 → 50"

# (b) Stop Rule류 다른 줄 비추출 (exit 1 기대)
if ( source "$SCRIPT_DIR/../review_common.sh"; parse_turn_limit_line '총 턴 수가 20에 도달하면 더 이상 다음 턴을 만들지 않고' ) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); echo "  FAIL: 비정본 줄에서 추출됨" >&2
else
  PASS=$((PASS+1)); echo "  PASS: 비정본 줄 비추출"
fi

# (b2) 앵커 위반(뒤에 추가 텍스트) 비추출
if ( source "$SCRIPT_DIR/../review_common.sh"; parse_turn_limit_line '50 total turns in `turns/*.md` (note)' ) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); echo "  FAIL: 추가 텍스트 줄에서 추출됨" >&2
else
  PASS=$((PASS+1)); echo "  PASS: 앵커 위반 줄 비추출"
fi

# (f) read_session_turn_limit 정본 회귀
printf '## Turn Limit\n50 total turns in `turns/*.md`\n\n## Stop Rule\n- x\n' > "$tl_tmp/SESSION.md"
got="$( source "$SCRIPT_DIR/../review_common.sh"; REVIEW_TURN_LIMIT='' read_session_turn_limit "$tl_tmp/SESSION.md" 2>/dev/null )"
assert_eq "$got" "50" "read: 정본 → 50 (회귀)"

# (c) malformed-present → default 20 + stderr 경고
printf '## Turn Limit\nfifty turns\n\n## Stop Rule\n- x\n' > "$tl_tmp/SESSION.md"
got="$( source "$SCRIPT_DIR/../review_common.sh"; REVIEW_TURN_LIMIT='' read_session_turn_limit "$tl_tmp/SESSION.md" 2>/dev/null )"
assert_eq "$got" "20" "read: malformed-present → default 20"
warn="$( source "$SCRIPT_DIR/../review_common.sh"; REVIEW_TURN_LIMIT='' read_session_turn_limit "$tl_tmp/SESSION.md" 2>&1 >/dev/null )"
if printf '%s' "$warn" | grep -q "형식 미인식"; then
  PASS=$((PASS+1)); echo "  PASS: malformed-present stderr 경고"
else
  FAIL=$((FAIL+1)); echo "  FAIL: malformed-present 경고 누락" >&2
fi

# (d) section 부재 → fallback, 경고 없음
printf '## Stop Rule\n- x\n' > "$tl_tmp/SESSION.md"
got="$( source "$SCRIPT_DIR/../review_common.sh"; REVIEW_TURN_LIMIT='' read_session_turn_limit "$tl_tmp/SESSION.md" 2>/dev/null )"
assert_eq "$got" "20" "read: section 부재 → default 20"
warn="$( source "$SCRIPT_DIR/../review_common.sh"; REVIEW_TURN_LIMIT='' read_session_turn_limit "$tl_tmp/SESSION.md" 2>&1 >/dev/null )"
if [ -z "$warn" ]; then
  PASS=$((PASS+1)); echo "  PASS: section 부재 시 경고 없음"
else
  FAIL=$((FAIL+1)); echo "  FAIL: section 부재인데 경고 출력" >&2
fi

# (e) env fallback
printf '## Stop Rule\n- x\n' > "$tl_tmp/SESSION.md"
got="$( source "$SCRIPT_DIR/../review_common.sh"; REVIEW_TURN_LIMIT='33' read_session_turn_limit "$tl_tmp/SESSION.md" 2>/dev/null )"
assert_eq "$got" "33" "read: section 없음 + env 33 → 33"
rm -rf "$tl_tmp"

echo "== review-gate 헬퍼 (safeguard-review-completion-checks) =="
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
GUARD_ROOT="$(mktemp -d)"
mkdir -p "$GUARD_ROOT/rd-workflow-workspace/handoffs/review_pipeline"
mkdir -p "$GUARD_ROOT/rd-workflow-workspace/.lifecycle"
printf '# Current Task\n\n## Short Title\nmytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"

# mk_session <dirname> <status> <open_issues_line> <short_title>
mk_session() {
  local d="$GUARD_ROOT/rd-workflow-workspace/handoffs/review_pipeline/$1"
  mkdir -p "$d"
  printf '## Status\n%s\n\n## Branch Context\n- short-title: %s\n' "$2" "$4" > "$d/SESSION.md"
  printf '## Open Issues\n%s\n' "$3" > "$d/CHECKPOINT.md"
}

project_root="$GUARD_ROOT"
# v2 2b: task-state 격리 — metadata I/O 테스트의 잔여 상태가 오염되지 않도록 TASK_STATE_PATH 재설정
TASK_STATE_PATH="$GUARD_ROOT/rd-workflow-workspace/.lifecycle/task-state"
# task-state 초기값: 대기 중 (get_current_short_title이 task-state에서 short-title을 읽음)
printf 'schema=1\nshort-title=mytask\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
source "$REPO_ROOT/rd-workflow/scripts/hooks/_guard_common.sh"

assert_eq "$(get_current_short_title)" "mytask" "get_current_short_title — CURRENT_TASK"

# fr-scope: mytask 세션만 반환, 다른 fr 세션 제외
mk_session "20260101_000000_final-diff-review" "closed" "- 없음" "otherfr"
mk_session "20260102_000000_final-diff-review" "closed" "- 없음" "mytask"
assert_eq "$(basename "$(get_latest_diff_review_dir)")" "20260102_000000_final-diff-review" "fr-scope — mytask 세션만"

RP="$GUARD_ROOT/rd-workflow-workspace/handoffs/review_pipeline"
# (a) closed + 없음 → 종결(0)
mk_session "20260103_000000_final-diff-review" "closed" "- 없음" "mytask"
is_review_session_resolved "$RP/20260103_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "0" "resolved — closed + 없음"
# (b) awaiting-user + 없음 → 종결(0)  ※ 운영상 정상 종료 패턴(75%)
mk_session "20260104_000000_final-diff-review" "awaiting-user" "- 없음" "mytask"
is_review_session_resolved "$RP/20260104_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "0" "resolved — awaiting-user + 없음 (정상 종료)"
# (c) awaiting-reviewer (루프 진행 중) → 미종결(1)
mk_session "20260105_000000_final-diff-review" "awaiting-reviewer" "- 없음" "mytask"
is_review_session_resolved "$RP/20260105_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "unresolved — awaiting-reviewer (루프 진행 중)"
# (d) awaiting-user + 실제 이슈 → 미종결(1)
mk_session "20260106_000000_final-diff-review" "awaiting-user" "- 미해결 쟁점" "mytask"
is_review_session_resolved "$RP/20260106_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "unresolved — awaiting-user + 실제 이슈"
# (e) closed (후행 공백) → trim 후 종결(0)
mk_session "20260107_000000_final-diff-review" "closed " "- 없음" "mytask"
is_review_session_resolved "$RP/20260107_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "0" "resolved — 'closed ' trim"
# (f) malformed: CHECKPOINT.md 없음 → fail-closed(1)
mkdir -p "$RP/20260108_000000_final-diff-review"
printf '## Status\nclosed\n\n## Branch Context\n- short-title: mytask\n' > "$RP/20260108_000000_final-diff-review/SESSION.md"
is_review_session_resolved "$RP/20260108_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "fail-closed — CHECKPOINT.md 부재"
# (g) malformed: Open Issues 섹션 없음 → fail-closed(1)
mkdir -p "$RP/20260109_000000_final-diff-review"
printf '## Status\nclosed\n\n## Branch Context\n- short-title: mytask\n' > "$RP/20260109_000000_final-diff-review/SESSION.md"
printf '# Review Checkpoint\n\n## Current Summary\n-\n' > "$RP/20260109_000000_final-diff-review/CHECKPOINT.md"
is_review_session_resolved "$RP/20260109_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "fail-closed — Open Issues 섹션 부재"

# (h)~(q) canonical 마커 계약 (precheck-open-issues-marker) — 별도 short-title(markertask)로
# 격리해 아래 get_latest_diff_review_dir(mytask 최신=20260109) assert에 간섭하지 않는다.
# (h) closed + None (영어 canonical 마커) → 종결(0)
mk_session "20260301_000000_final-diff-review" "closed" "- None" "markertask"
is_review_session_resolved "$RP/20260301_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "0" "resolved — closed + None (영어 마커)"
# (i) closed + None. (후행 마침표 — 실제 관측된 거짓 양성 사례) → 종결(0)
mk_session "20260302_000000_final-diff-review" "closed" "- None." "markertask"
is_review_session_resolved "$RP/20260302_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "0" "resolved — closed + None. (후행 마침표)"
# (j) closed + 없음. (한국어 + 후행 마침표) → 종결(0)
mk_session "20260303_000000_final-diff-review" "closed" "- 없음." "markertask"
is_review_session_resolved "$RP/20260303_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "0" "resolved — closed + 없음. (후행 마침표)"
# (k) closed + 비마커 산문 → 미종결(1) (fail-closed)
mk_session "20260304_000000_final-diff-review" "closed" "- no issues" "markertask"
is_review_session_resolved "$RP/20260304_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "unresolved — 비마커 산문 (no issues)"
# (l) closed + 마커 뒤 후행 텍스트 → 미종결(1) (라인 전체 매칭, fail-closed 강화)
mk_session "20260305_000000_final-diff-review" "closed" "- 없음 (단, 후속 확인 필요)" "markertask"
is_review_session_resolved "$RP/20260305_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "unresolved — 마커 뒤 후행 텍스트"
# (m) closed + 빈 섹션 (내용 라인 없음) → 미종결(1) (마커 존재 요구)
mk_session "20260306_000000_final-diff-review" "closed" "" "markertask"
is_review_session_resolved "$RP/20260306_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "unresolved — 빈 Open Issues 섹션 (마커 부재)"
# (n) closed + HTML 주석만 → 미종결(1) (주석은 무시, 마커 부재)
mk_session "20260307_000000_final-diff-review" "closed" "<!-- 규약 주석 -->" "markertask"
is_review_session_resolved "$RP/20260307_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "unresolved — 주석만 있는 섹션 (마커 부재)"
# (o) closed + 비-bullet 산문 (dash 없는 None) → 미종결(1)
mk_session "20260308_000000_final-diff-review" "closed" "None" "markertask"
is_review_session_resolved "$RP/20260308_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "unresolved — 비-bullet 산문 (None)"
# (p) closed + 마커와 실제 이슈 혼재 → 미종결(1)
mk_session "20260309_000000_final-diff-review" "closed" "$(printf -- '- 없음\n- 실제 이슈')" "markertask"
is_review_session_resolved "$RP/20260309_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "1" "unresolved — 마커와 실제 이슈 혼재"
# (q) closed + 규약 주석 + 마커 (신규 템플릿 정상 종결 형태) → 종결(0)
mk_session "20260310_000000_final-diff-review" "closed" "$(printf -- '<!-- 규약 주석 -->\n- 없음')" "markertask"
is_review_session_resolved "$RP/20260310_000000_final-diff-review" && rc=0 || rc=1
assert_eq "$rc" "0" "resolved — 규약 주석 + 마커 (신규 템플릿 형태)"

# fr 세션 부재 시 빈 값 (다른 fr만 존재)
printf '# Current Task\n\n## Short Title\nlonelytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"
# v2 2b: task-state도 함께 업데이트 (get_current_short_title이 task-state에서 읽음)
printf 'schema=1\nshort-title=lonelytask\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
assert_eq "$(get_latest_diff_review_dir)" "" "fr-scope — 현재 fr 세션 없으면 빈 값"
printf '# Current Task\n\n## Short Title\nmytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"
printf 'schema=1\nshort-title=mytask\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"

# malformed 세션은 short-title 미상 → fr-scope 후보 제외 (legacy/unscoped 통과, 3d 오발화 방지)
mkdir -p "$RP/20260110_000000_final-diff-review"
mkdir -p "$RP/20260111_000000_final-diff-review"
printf '## Status\nclosed\n' > "$RP/20260111_000000_final-diff-review/SESSION.md"
assert_eq "$(basename "$(get_latest_diff_review_dir)")" "20260109_000000_final-diff-review" "malformed 제외 — short-title 매칭 세션만 반환"
printf '# Current Task\n\n## Short Title\nzzz\n' > "$GUARD_ROOT/CURRENT_TASK.md"
printf 'schema=1\nshort-title=zzz\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
assert_eq "$(get_latest_diff_review_dir)" "" "malformed-only → 빈 값 (unscoped 통과, 오발화 방지)"
printf '# Current Task\n\n## Short Title\nmytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"
printf 'schema=1\nshort-title=mytask\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"

# archive_review_precheck (3c)
PRECHECK_AUDIT="$GUARD_ROOT/rd-workflow-workspace/.lifecycle/review-skip-audit.log"
rm -f "$PRECHECK_AUDIT"
printf '# Current Task\n\n## Short Title\nlonelytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"
printf 'schema=1\nshort-title=lonelytask\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
archive_review_precheck "0" "" "lonelytask" "$PRECHECK_AUDIT" 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "1" "precheck — 미종결 + force-skip 아님 → 차단"
archive_review_precheck "1" "" "lonelytask" "$PRECHECK_AUDIT" 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "1" "precheck — force-skip + 사유 누락 → 차단"
archive_review_precheck "1" "긴급 핫픽스" "lonelytask" "$PRECHECK_AUDIT" 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "precheck — force-skip + 사유 → 통과"
assert_eq "$(awk -F' \\| ' 'END{print $2}' "$PRECHECK_AUDIT")" "lonelytask" "precheck — audit slug 기록"
assert_eq "$(awk -F' \\| ' 'END{print $3}' "$PRECHECK_AUDIT")" "긴급 핫픽스" "precheck — audit 사유 기록"
printf '# Current Task\n\n## Short Title\nmytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"
printf 'schema=1\nshort-title=mytask\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
mk_session "20260120_000000_final-diff-review" "closed" "- 없음" "mytask"   # 최신 종결 mytask 세션
archive_review_precheck "0" "" "mytask" "$PRECHECK_AUDIT" 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "precheck — 종결 세션 존재 → 통과"

# === archive precheck fr-branch tip 가시성 (archive-precheck-premerge-session-visibility) ===
echo "== archive precheck fr-branch tip 가시성 =="
FT_REPO="$(mktemp -d)"
git -C "$FT_REPO" init -q -b main
git -C "$FT_REPO" config user.email t@t && git -C "$FT_REPO" config user.name t
mkdir -p "$FT_REPO/rd-workflow-workspace/handoffs/review_pipeline" "$FT_REPO/rd-workflow-workspace/.lifecycle"
# 실제 archive 시점 재현: main 의 CURRENT_TASK ## Short Title 은 baseline(-),
# short-title 은 task-state metadata fallback 으로 해소된다(get_current_short_title).
printf '# Current Task\n\n## Short Title\n-\n' > "$FT_REPO/CURRENT_TASK.md"
# v2 2b: active-fr → task-state 전환 (schema=1, fr-branch=fr/fttask)
printf 'schema=1\nshort-title=fttask\nstatus=구현 중\nfr-branch=fr/fttask\nworktree-path=null\nsource-fr=-\ncreated-at=2026-07-05-0000\n' > "$FT_REPO/rd-workflow-workspace/.lifecycle/task-state"
git -C "$FT_REPO" add -A && git -C "$FT_REPO" commit -q -m seed
# fr branch 에 종결 diff-review 세션 commit
git -C "$FT_REPO" branch fr/fttask
git -C "$FT_REPO" switch -q fr/fttask
FTS="$FT_REPO/rd-workflow-workspace/handoffs/review_pipeline/20260301_000000_final-diff-review"
mkdir -p "$FTS"
printf '## Status\nclosed\n\n## Branch Context\n- fr-branch: fr/fttask\n- short-title: fttask\n' > "$FTS/SESSION.md"
printf '## Open Issues\n- 없음\n' > "$FTS/CHECKPOINT.md"
git -C "$FT_REPO" add -A && git -C "$FT_REPO" commit -q -m "diff-review session on fr"
git -C "$FT_REPO" switch -q main
FT_AUDIT="$FT_REPO/rd-workflow-workspace/.lifecycle/review-skip-audit.log"
# sanity 1: short-title 은 task-state fallback 으로 해소 (CURRENT_TASK Short Title=-)
# v2 2b: TASK_STATE_PATH를 명시적으로 FT_REPO 기반으로 설정 (서브셸에서 재설정 필요)
assert_eq "$( ( project_root="$FT_REPO"; TASK_STATE_PATH="$FT_REPO/rd-workflow-workspace/.lifecycle/task-state"; get_current_short_title ) )" "fttask" "fr-tip — metadata fallback 으로 short-title 해소(Short Title=-)"
# sanity 2: 세션은 fr branch tip 에만 있고 main 워킹트리엔 없음
assert_eq "$( ( project_root="$FT_REPO"; TASK_STATE_PATH="$FT_REPO/rd-workflow-workspace/.lifecycle/task-state"; get_latest_diff_review_dir ) )" "" "fr-tip — main 워킹트리에 세션 없음(sanity)"
# Case A (핵심 회귀): main Short Title=- + metadata fallback + fr_ref 지정 → fr tip 종결 세션 인식 → 통과(0)
( project_root="$FT_REPO"; TASK_STATE_PATH="$FT_REPO/rd-workflow-workspace/.lifecycle/task-state"; archive_review_precheck "0" "" "fttask" "$FT_AUDIT" "fr/fttask" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "fr-tip — 종결 세션을 fr branch tip 에서 검증 → 통과 (metadata fallback 결합)"
# Case B (안전 회귀): fr tip 세션을 미종결로 변경 → 차단(1)
git -C "$FT_REPO" switch -q fr/fttask
printf '## Status\nawaiting-reviewer\n\n## Branch Context\n- fr-branch: fr/fttask\n- short-title: fttask\n' > "$FTS/SESSION.md"
git -C "$FT_REPO" add -A && git -C "$FT_REPO" commit -q -m "session unterminated"
git -C "$FT_REPO" switch -q main
( project_root="$FT_REPO"; TASK_STATE_PATH="$FT_REPO/rd-workflow-workspace/.lifecycle/task-state"; archive_review_precheck "0" "" "fttask" "$FT_AUDIT" "fr/fttask" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "1" "fr-tip — 미종결(awaiting-reviewer) 세션 → 차단 (안전 속성 보존)"
# Case C (audit 정규화): 미종결 fr 세션(위 Case B 상태) + force-skip + 사유 → 통과(0)
#   + audit 의 세션참조 필드가 temp 절대경로가 아닌 repo-상대 경로여야 한다.
FT_AUDIT2="$FT_REPO/rd-workflow-workspace/.lifecycle/audit2.log"
( project_root="$FT_REPO"; TASK_STATE_PATH="$FT_REPO/rd-workflow-workspace/.lifecycle/task-state"; archive_review_precheck "1" "긴급 사유" "fttask" "$FT_AUDIT2" "fr/fttask" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "fr-tip — force-skip + 사유 → 통과"
assert_eq "$(awk -F' \\| ' 'END{print $4}' "$FT_AUDIT2")" "rd-workflow-workspace/handoffs/review_pipeline/20260301_000000_final-diff-review" "fr-tip — audit 세션참조 repo-상대 경로(temp 절대경로 금지)"
rm -rf "$FT_REPO"

# === Case D~G (archive-precheck-fr-ref-short-title-fallback): fr-branch identity 매칭 ===
# active metadata 없이 archive.sh --fr-branch 호출 시, fr tip SESSION.md 의 Branch Context
# fr-branch == fr_ref 로 후보를 고정해 종결 세션을 인식한다(main 워킹트리 의존 제거).
echo "== archive precheck fr_ref — fr-branch identity 매칭 =="
FT2="$(mktemp -d)"
git -C "$FT2" init -q -b main
git -C "$FT2" config user.email t@t && git -C "$FT2" config user.name t
mkdir -p "$FT2/rd-workflow-workspace/handoffs/review_pipeline" "$FT2/rd-workflow-workspace/.lifecycle"
# main: baseline Short Title=- + task-state 부재 → get_current_short_title "-" 반환(fr-scope 미해소)
# v2 2b: active-fr 폐지 → task-state도 없는 상태로 테스트 (legacy fallback: CURRENT_TASK.md Short Title=-)
printf '# Current Task\n\n## Short Title\n-\n' > "$FT2/CURRENT_TASK.md"
git -C "$FT2" add -A && git -C "$FT2" commit -q -m seed
FT2_AUDIT="$FT2/rd-workflow-workspace/.lifecycle/review-skip-audit.log"
# task-state 없음 → legacy CURRENT_TASK.md Short Title=- 반환 (TASK_STATE_PATH 격리)
assert_eq "$( ( project_root="$FT2"; TASK_STATE_PATH="$FT2/rd-workflow-workspace/.lifecycle/task-state"; get_current_short_title ) )" "-" "metadata 부재 — short-title 빈 값(회귀 전제)"

# Case D (AC1 — metadata 부재 핵심 회귀): fr/d1 tip 종결 세션(fr-branch=fr/d1) → 통과(0)
git -C "$FT2" branch fr/d1
git -C "$FT2" switch -q fr/d1
D1S="$FT2/rd-workflow-workspace/handoffs/review_pipeline/20260401_000000_final-diff-review"
mkdir -p "$D1S"
printf '## Status\nclosed\n\n## Branch Context\n- fr-branch: fr/d1\n- short-title: d1\n' > "$D1S/SESSION.md"
printf '## Open Issues\n- 없음\n' > "$D1S/CHECKPOINT.md"
git -C "$FT2" add -A && git -C "$FT2" commit -q -m "diff-review on fr/d1"
git -C "$FT2" switch -q main
( project_root="$FT2"; archive_review_precheck "0" "" "d1" "$FT2_AUDIT" "fr/d1" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "AC1 — metadata 부재 + fr tip 종결 세션 → 통과 (fr-branch identity)"

# Case E (AC2 — suffix slug): fr/e1-2 tip, 세션 fr-branch=fr/e1-2, slug 인자=e1-2 → 통과(0)
git -C "$FT2" branch fr/e1-2
git -C "$FT2" switch -q fr/e1-2
E1S="$FT2/rd-workflow-workspace/handoffs/review_pipeline/20260402_000000_final-diff-review"
mkdir -p "$E1S"
printf '## Status\nclosed\n\n## Branch Context\n- fr-branch: fr/e1-2\n- short-title: e1\n' > "$E1S/SESSION.md"
printf '## Open Issues\n- 없음\n' > "$E1S/CHECKPOINT.md"
git -C "$FT2" add -A && git -C "$FT2" commit -q -m "diff-review on fr/e1-2"
git -C "$FT2" switch -q main
( project_root="$FT2"; archive_review_precheck "0" "" "e1-2" "$FT2_AUDIT" "fr/e1-2" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "AC2 — suffix branch fr/e1-2 (fr-branch identity) → 통과 (slug≠short-title)"

# Case F (fail-closed — legacy): fr/f1 tip 세션에 Branch Context 부재 → 매칭 실패 → 차단(1)
git -C "$FT2" branch fr/f1
git -C "$FT2" switch -q fr/f1
F1S="$FT2/rd-workflow-workspace/handoffs/review_pipeline/20260403_000000_final-diff-review"
mkdir -p "$F1S"
printf '## Status\nclosed\n' > "$F1S/SESSION.md"
printf '## Open Issues\n- 없음\n' > "$F1S/CHECKPOINT.md"
git -C "$FT2" add -A && git -C "$FT2" commit -q -m "legacy diff-review on fr/f1"
git -C "$FT2" switch -q main
( project_root="$FT2"; archive_review_precheck "0" "" "f1" "$FT2_AUDIT" "fr/f1" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "1" "fail-closed — fr tip 세션 Branch Context 부재 → 차단"

# Case G (AC8 — stale/unrelated false-positive 차단): fr/g1 tip 최신 세션이 fr-branch=fr/other(종결)
#   이고 fr/g1 매칭 세션 없음 → 차단(1). short-title 역산 설계였다면 통과했을 false-positive 를 차단.
git -C "$FT2" branch fr/g1
git -C "$FT2" switch -q fr/g1
G1S="$FT2/rd-workflow-workspace/handoffs/review_pipeline/20260404_000000_final-diff-review"
mkdir -p "$G1S"
printf '## Status\nclosed\n\n## Branch Context\n- fr-branch: fr/other\n- short-title: other\n' > "$G1S/SESSION.md"
printf '## Open Issues\n- 없음\n' > "$G1S/CHECKPOINT.md"
git -C "$FT2" add -A && git -C "$FT2" commit -q -m "unrelated closed session on fr/g1"
git -C "$FT2" switch -q main
( project_root="$FT2"; archive_review_precheck "0" "" "g1" "$FT2_AUDIT" "fr/g1" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "1" "AC8 — stale/unrelated(fr/other) closed 세션만 최신 → 차단 (false-positive 방지)"
rm -rf "$FT2"

# commit_has_archive_signal (review-gate-iteration-commit)
echo "== commit_has_archive_signal =="
SIG_REPO="$(mktemp -d)"
git -C "$SIG_REPO" init -q
git -C "$SIG_REPO" config user.email t@t && git -C "$SIG_REPO" config user.name t
mkdir -p "$SIG_REPO/rd-workflow-workspace/backlog/request-archive" "$SIG_REPO/rd-workflow-workspace/.lifecycle"
printf '# Current Task\n\n## Status\n구현 중\n\n## Short Title\nsigtask\n' > "$SIG_REPO/CURRENT_TASK.md"
# v2 2b: task-state 격리 — TASK_STATE_PATH를 SIG_REPO 기반으로 재설정
TASK_STATE_PATH="$SIG_REPO/rd-workflow-workspace/.lifecycle/task-state"
# task-state 초기값: 구현 중, short-title=sigtask (비-baseline)
printf 'schema=1\nshort-title=sigtask\nstatus=구현 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
ARCH="rd-workflow-workspace/backlog/request-archive/2026-05-24-0000-sigtask.md"
# 신호 없음: 비-baseline + staged archive 없음 → 1(허용)
( project_root="$SIG_REPO"; TASK_STATE_PATH="$SIG_REPO/rd-workflow-workspace/.lifecycle/task-state"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "1" "archive_signal — 신호 없음 → 1(허용)"
# AS1 경계: untracked stale archive 파일(add 안 함) → 1(허용, false-positive 방지)
printf 'x\n' > "$SIG_REPO/$ARCH"
( project_root="$SIG_REPO"; TASK_STATE_PATH="$SIG_REPO/rd-workflow-workspace/.lifecycle/task-state"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "1" "archive_signal — AS1 untracked stale archive → 1(허용)"
# AS1: staged 추가 → 0(차단)
git -C "$SIG_REPO" add "$ARCH"
( project_root="$SIG_REPO"; TASK_STATE_PATH="$SIG_REPO/rd-workflow-workspace/.lifecycle/task-state"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "0" "archive_signal — AS1 staged request-archive 추가 → 0(차단)"
# AS1 경계: 기존 archive 파일 삭제(staged D) → 1(허용, 추가 아님)
git -C "$SIG_REPO" commit -q -m seed
git -C "$SIG_REPO" rm -q "$ARCH"
( project_root="$SIG_REPO"; TASK_STATE_PATH="$SIG_REPO/rd-workflow-workspace/.lifecycle/task-state"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "1" "archive_signal — request-archive 삭제(staged D) → 1(허용)"
# AS2: task-state baseline(status=대기 중, short-title=-) → 0(차단)
# v2 2b: task-state가 권위 소스 — CURRENT_TASK.md 변경과 함께 task-state도 베이스라인으로 설정
printf '# Current Task\n\n## Status\n대기 중\n\n## Short Title\n-\n' > "$SIG_REPO/CURRENT_TASK.md"
printf 'schema=1\nshort-title=-\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' > "$TASK_STATE_PATH"
( project_root="$SIG_REPO"; TASK_STATE_PATH="$SIG_REPO/rd-workflow-workspace/.lifecycle/task-state"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "0" "archive_signal — AS2 task-state baseline → 0(차단)"
rm -rf "$SIG_REPO"

echo "== review_gate hook exit code (iteration-commit 허용) =="
HOOK_REPO="$(mktemp -d)"
mkdir -p "$HOOK_REPO/rd-workflow/scripts/hooks"
mkdir -p "$HOOK_REPO/rd-workflow/scripts"
mkdir -p "$HOOK_REPO/rd-workflow-workspace/handoffs/review_pipeline"
mkdir -p "$HOOK_REPO/rd-workflow-workspace/backlog/request-archive"
mkdir -p "$HOOK_REPO/rd-workflow-workspace/.lifecycle"
cp "$REPO_ROOT/rd-workflow/scripts/hooks/_guard_common.sh" "$HOOK_REPO/rd-workflow/scripts/hooks/"
cp "$REPO_ROOT/rd-workflow/scripts/hooks/pre_commit_review_gate.sh" "$HOOK_REPO/rd-workflow/scripts/hooks/"
# _guard_common.sh가 상위 디렉토리의 _state_common.sh를 source하므로 함께 복사 (v2 2b)
cp "$REPO_ROOT/rd-workflow/scripts/_state_common.sh" "$HOOK_REPO/rd-workflow/scripts/"
git -C "$HOOK_REPO" init -q
git -C "$HOOK_REPO" config user.email t@t && git -C "$HOOK_REPO" config user.name t
printf '# Current Task\n\n## Status\ndiff review 대기\n\n## Short Title\nhooktask\n' > "$HOOK_REPO/CURRENT_TASK.md"
hook_mk_session() {
  local d="$HOOK_REPO/rd-workflow-workspace/handoffs/review_pipeline/$1"
  mkdir -p "$d"
  printf '## Status\n%s\n\n## Branch Context\n- short-title: %s\n' "$2" "$4" > "$d/SESSION.md"
  printf '## Open Issues\n%s\n' "$3" > "$d/CHECKPOINT.md"
}
run_review_gate() {
  printf '%s' '{"tool_input":{"command":"git commit -m x"}}' \
    | bash "$HOOK_REPO/rd-workflow/scripts/hooks/pre_commit_review_gate.sh" >/dev/null 2>&1; echo $?
}
HARCH="rd-workflow-workspace/backlog/request-archive/2026-05-24-0000-hooktask.md"
# 세션 없음 → 통과
assert_eq "$(run_review_gate)" "0" "review_gate — 세션 없음 → 통과 (exit 0)"
# 종결(awaiting-user+없음) → 통과
hook_mk_session "20260201_000000_final-diff-review" "awaiting-user" "- 없음" "hooktask"
assert_eq "$(run_review_gate)" "0" "review_gate — awaiting-user+없음(종결) → 통과"
# A1: 미종결 + iteration(staged archive 없음) → 허용 (신 동작)
hook_mk_session "20260202_000000_final-diff-review" "awaiting-reviewer" "- 없음" "hooktask"
assert_eq "$(run_review_gate)" "0" "review_gate — A1 미종결 + iteration commit → 허용 (exit 0)"
# A1-edge: 미종결 + untracked stale archive(add 안 함) → 허용 (false-positive 방지)
printf 'x\n' > "$HOOK_REPO/$HARCH"
assert_eq "$(run_review_gate)" "0" "review_gate — A1 미종결 + untracked stale archive → 허용"
# B1-AS1: 미종결 + staged request-archive 추가 → 차단
git -C "$HOOK_REPO" add "$HARCH"
assert_eq "$(run_review_gate)" "2" "review_gate — B1(AS1) 미종결 + staged archive 추가 → 차단 (exit 2)"
git -C "$HOOK_REPO" reset -q; rm -f "$HOOK_REPO/$HARCH"
# B1-AS2: 미종결 + task-state baseline(status=대기 중, short-title=-) → 차단 (v2: task-state 우선)
printf 'schema=1\nshort-title=-\nstatus=대기 중\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' \
  > "$HOOK_REPO/rd-workflow-workspace/.lifecycle/task-state"
printf '# Current Task\n\n## Status\n대기 중\n\n## Short Title\n-\n' > "$HOOK_REPO/CURRENT_TASK.md"
assert_eq "$(run_review_gate)" "2" "review_gate — B1(AS2) 미종결 + task-state baseline → 차단 (exit 2)"
printf '# Current Task\n\n## Status\ndiff review 대기\n\n## Short Title\nhooktask\n' > "$HOOK_REPO/CURRENT_TASK.md"
printf 'schema=1\nshort-title=hooktask\nstatus=diff review 대기\nfr-branch=null\nworktree-path=null\nsource-fr=-\n' \
  > "$HOOK_REPO/rd-workflow-workspace/.lifecycle/task-state"
# autopilot 활성 + 미종결 + iteration → 허용 (3a 우회 제거 후에도 iteration 은 신호 아님)
touch "$HOOK_REPO/.autopilot_active"
assert_eq "$(run_review_gate)" "0" "review_gate — autopilot + 미종결 + iteration → 허용"
rm -f "$HOOK_REPO/.autopilot_active"
# malformed(Open Issues 섹션 부재) = 미종결 + iteration → 허용 (archive 신호일 때만 fail-closed)
mkdir -p "$HOOK_REPO/rd-workflow-workspace/handoffs/review_pipeline/20260203_000000_final-diff-review"
printf '## Status\nclosed\n\n## Branch Context\n- short-title: hooktask\n' > "$HOOK_REPO/rd-workflow-workspace/handoffs/review_pipeline/20260203_000000_final-diff-review/SESSION.md"
printf '# Review Checkpoint\n\n## Current Summary\n-\n' > "$HOOK_REPO/rd-workflow-workspace/handoffs/review_pipeline/20260203_000000_final-diff-review/CHECKPOINT.md"
assert_eq "$(run_review_gate)" "0" "review_gate — malformed + iteration → 허용"
# malformed + staged archive 추가 → 차단 (archive 경로 fail-closed 유지)
printf 'x\n' > "$HOOK_REPO/$HARCH"
git -C "$HOOK_REPO" add "$HARCH"
assert_eq "$(run_review_gate)" "2" "review_gate — malformed + staged archive → 차단 (fail-closed)"
git -C "$HOOK_REPO" reset -q
rm -rf "$HOOK_REPO"

echo "== archive_gate hook exit code =="
AG_REPO="$(mktemp -d)"
mkdir -p "$AG_REPO/rd-workflow/scripts/hooks" "$AG_REPO/rd-workflow/scripts" "$AG_REPO/rd-workflow-workspace/handoffs/review_pipeline" "$AG_REPO/rd-workflow-workspace/backlog/items"
cp "$REPO_ROOT/rd-workflow/scripts/hooks/_guard_common.sh" "$AG_REPO/rd-workflow/scripts/hooks/"
cp "$REPO_ROOT/rd-workflow/scripts/hooks/pre_commit_archive_gate.sh" "$AG_REPO/rd-workflow/scripts/hooks/"
# _guard_common.sh가 상위 디렉토리의 _state_common.sh를 source하므로 함께 복사 (v2 2b)
cp "$REPO_ROOT/rd-workflow/scripts/_state_common.sh" "$AG_REPO/rd-workflow/scripts/"
printf '# Current Task\n\n## Short Title\nagtask\n' > "$AG_REPO/CURRENT_TASK.md"
printf '# Change Request\n\n## Source FR\n2026-05-15-agtask\n' > "$AG_REPO/REQUEST.md"
printf '# agtask\n- status: idea\n' > "$AG_REPO/rd-workflow-workspace/backlog/items/2026-05-15-agtask.md"
ag_mk_session() {
  local d="$AG_REPO/rd-workflow-workspace/handoffs/review_pipeline/$1"; mkdir -p "$d"
  printf '## Status\n%s\n\n## Branch Context\n- short-title: %s\n' "$2" "$4" > "$d/SESSION.md"
  printf '## Open Issues\n%s\n' "$3" > "$d/CHECKPOINT.md"
}
run_ag() {
  printf '%s' '{"tool_input":{"command":"git commit -m x"}}' \
    | bash "$AG_REPO/rd-workflow/scripts/hooks/pre_commit_archive_gate.sh" >/dev/null 2>&1; echo $?
}
ag_mk_session "20260301_000000_final-diff-review" "closed" "- 없음" "agtask"
touch "$AG_REPO/.autopilot_active"
assert_eq "$(run_ag)" "2" "archive_gate — autopilot active + 종결 + FR not done → 차단"
rm -f "$AG_REPO/.autopilot_active"
printf '# agtask\n- status: done\n' > "$AG_REPO/rd-workflow-workspace/backlog/items/2026-05-15-agtask.md"
assert_eq "$(run_ag)" "0" "archive_gate — FR done → 통과"
rm -rf "$AG_REPO"

echo "== archive.sh dry-run 비파괴성 (precheck 배치) =="
# review precheck(audit write 가능)는 dry-run exit 뒤에 있어야 dry-run --force-skip-review-check 가 audit log를 오염시키지 않는다.
ARCHIVE_SH="$REPO_ROOT/rd-workflow/scripts/lifecycle/archive.sh"
dry_ln="$(grep -n 'DRY_RUN.*-eq 1' "$ARCHIVE_SH" | head -1 | cut -d: -f1)"
pc_ln="$(grep -n 'archive_review_precheck "' "$ARCHIVE_SH" | head -1 | cut -d: -f1)"
if [[ -n "$dry_ln" && -n "$pc_ln" && "$pc_ln" -gt "$dry_ln" ]]; then
  PASS=$((PASS+1)); echo "  PASS: archive_review_precheck($pc_ln) 가 dry-run exit($dry_ln) 뒤 — dry-run 비파괴"
else
  FAIL=$((FAIL+1)); echo "  FAIL: precheck($pc_ln) 가 dry-run($dry_ln) 앞 — dry-run audit 오염 위험" >&2
fi
# fr_ref 배선 회귀 (archive-precheck-premerge-session-visibility): precheck 호출이 $FR_BRANCH 를 5번째 인자로 전달하는지
pc_wire="$(grep -E 'archive_review_precheck "' "$ARCHIVE_SH" | head -1)"
if printf '%s' "$pc_wire" | grep -q '"\$AUDIT_LOG" "\$FR_BRANCH"'; then
  PASS=$((PASS+1)); echo "  PASS: archive.sh precheck 호출이 \$FR_BRANCH 를 5번째 인자로 전달"
else
  FAIL=$((FAIL+1)); echo "  FAIL: archive.sh precheck 호출에 \$FR_BRANCH(5번째 인자) 누락 — [$pc_wire]" >&2
fi

rm -rf "$GUARD_ROOT"

# === safeguard-self-review-block: self-review 게이트 ===
source "$SCRIPT_DIR/../review_common.sh"

echo "== resolve_self_review_policy =="
assert_eq "$(resolve_self_review_policy block "")" "block" "policy=block 그대로"
assert_eq "$(resolve_self_review_policy warn "")"  "warn"  "policy=warn 그대로"
assert_eq "$(resolve_self_review_policy off "")"   "off"   "policy=off 그대로"
assert_eq "$(resolve_self_review_policy "" false)" "off"   "미설정(빈값)+warning=false → off"
assert_eq "$(resolve_self_review_policy "" true)"  "block" "미설정(빈값)+warning=true → block"
assert_eq "$(resolve_self_review_policy "" "")"    "block" "미설정(빈값)+warning 미설정 → block"
assert_eq "$(resolve_self_review_policy bogus "")" "block" "미인식 policy + warning 빈값 → block (fail-safe)"
assert_eq "$(resolve_self_review_policy bogus false)" "block" "미인식 policy + warning=false → block (finding1 회귀방지)"

echo "== evaluate_self_review_gate =="
assert_eq "$(evaluate_self_review_gate off "" "")"   "proceed-silent"    "off → silent"
assert_eq "$(evaluate_self_review_gate warn "" "")"  "proceed-warn"      "warn → warn"
assert_eq "$(evaluate_self_review_gate block 1 "")"  "proceed-autopilot" "block+autopilot → autopilot"
assert_eq "$(evaluate_self_review_gate block "" 1)"  "proceed-warn"      "block+approve → warn"
assert_eq "$(evaluate_self_review_gate block "" "")" "block"             "block+일반 → block"
assert_eq "$(evaluate_self_review_gate block 1 1)"   "proceed-autopilot" "block+autopilot이 approve보다 우선"

echo "== record_self_review_block =="
SR_UA="$(mktemp)"
# 기본 USER_ACTION 템플릿(차단 안내가 지워져야 하는 문구 포함)
printf '# User Action\n\n## Current Recommendation\n-\n\n## Why\n- \n\n## Question For User\n아직 사용자 확인이 필요한 단계가 아닙니다.\n' > "$SR_UA"
record_self_review_block "$SR_UA"
if grep -q "RD_SELF_REVIEW_APPROVE=1" "$SR_UA"; then PASS=$((PASS+1)); echo "  PASS: 승인 재실행 안내 포함"; \
  else FAIL=$((FAIL+1)); echo "  FAIL: 승인 안내 누락" >&2; fi
if grep -q "아직 사용자 확인이 필요한 단계가 아닙니다" "$SR_UA"; then \
  FAIL=$((FAIL+1)); echo "  FAIL: 기본 no-action 문구가 남아 모순(finding3)" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: no-action 문구 제거됨"; fi
sr_snap1="$(cat "$SR_UA")"
record_self_review_block "$SR_UA"
sr_snap2="$(cat "$SR_UA")"
assert_eq "$sr_snap1" "$sr_snap2" "멱등 — 재호출 시 내용 동일"
rm -f "$SR_UA"

echo "== run_review_turn.sh self-review 차단 (script-level 통합) =="
SR_INT="$(mktemp -d)"
mkdir -p "$SR_INT/bin" "$SR_INT/session/turns"
# fake claude: 게이트가 block이면 호출되지 않아야 함 (호출되면 흔적 파일 생성)
cat > "$SR_INT/bin/claude" <<FAKE
#!/bin/sh
touch "$SR_INT/CLAUDE_WAS_CALLED"
exit 99
FAKE
chmod +x "$SR_INT/bin/claude"
# 임시 config: claude만 우선, policy=block
cat > "$SR_INT/review-tools.json" <<'CFG'
{ "default_priority": ["claude"], "tools": { "claude": { "self_review_policy": "block" } } }
CFG
# 최소 세션 fixture (Branch Context 생략 → validate_branch_context가 legacy로 skip)
cat > "$SR_INT/session/SESSION.md" <<'SES'
# Review Session
## Status
awaiting-reviewer
## Current Owner
Reviewer
## Review Type
spec-plan-review
## Review Target
target
## Review Goal
goal
## Turn Limit
20 total turns in `turns/*.md`
SES
printf '# Checkpoint\n## Current Summary\n-\n' > "$SR_INT/session/CHECKPOINT.md"
printf '# User Action\n\n## Current Recommendation\n-\n\n## Why\n- \n\n## Question For User\n아직 사용자 확인이 필요한 단계가 아닙니다.\n' > "$SR_INT/session/USER_ACTION.md"
printf '# Turn 001 Author\n' > "$SR_INT/session/turns/001_author.md"
# 일반 모드 실행 (RD_AUTOPILOT / RD_SELF_REVIEW_APPROVE 미설정)
sr_rc=0
PATH="$SR_INT/bin:$PATH" REVIEW_TOOLS_CONFIG="$SR_INT/review-tools.json" \
  RD_AUTOPILOT="" RD_SELF_REVIEW_APPROVE="" \
  bash "$SCRIPT_DIR/../run_review_turn.sh" "$SR_INT/session" >/dev/null 2>&1 || sr_rc=$?
assert_eq "$sr_rc" "3" "차단 exit code 3"
if [ ! -f "$SR_INT/session/turns/002_reviewer.md" ]; then PASS=$((PASS+1)); echo "  PASS: reviewer turn 미생성"; \
  else FAIL=$((FAIL+1)); echo "  FAIL: reviewer turn 생성됨" >&2; fi
if grep -q "RD_SELF_REVIEW_APPROVE=1" "$SR_INT/session/USER_ACTION.md"; then PASS=$((PASS+1)); echo "  PASS: USER_ACTION 차단 안내 기록"; \
  else FAIL=$((FAIL+1)); echo "  FAIL: USER_ACTION 차단 안내 누락" >&2; fi
assert_eq "$(awk '/^## Status/{getline; gsub(/[ \t]/,"",$0); print; exit}' "$SR_INT/session/SESSION.md")" "awaiting-reviewer" "SESSION Status awaiting-reviewer 유지"
if [ ! -f "$SR_INT/CLAUDE_WAS_CALLED" ]; then PASS=$((PASS+1)); echo "  PASS: fake claude 미호출(게이트가 adapter 전 차단)"; \
  else FAIL=$((FAIL+1)); echo "  FAIL: claude adapter 실행됨" >&2; fi
rm -rf "$SR_INT"

# === get_default_branch resolver (lifecycle-default-branch-generalize) ===
echo "== get_default_branch resolver =="
GDB_TMP="$(mktemp -d)"
make_gdb_repo() {  # <dir> <initial-branch>
  local d="$1" b="$2"
  mkdir -p "$d"
  ( cd "$d" && { git init -q -b "$b" 2>/dev/null || { git init -q; git checkout -q -b "$b"; }; } \
    && git config user.email t@example.com && git config user.name t \
    && git commit -q --allow-empty -m init )
}
gdb_in() { ( cd "$1" && unset project_root && get_default_branch 2>/dev/null ); }

# case 1: config 최우선 (브랜치 실존 여부와 무관하게 config 값 채택)
R="$GDB_TMP/c1"; make_gdb_repo "$R" main
mkdir -p "$R/rd-workflow/config"
printf '{\n  "default_branch": "trunk"\n}\n' > "$R/rd-workflow/config/workflow.json"
assert_eq "$(gdb_in "$R")" "trunk" "config default_branch 최우선"

# case 2: 빈 config 값("")은 미설정 — 다음 체인 진행 (master 유일 매치)
R="$GDB_TMP/c2"; make_gdb_repo "$R" master
mkdir -p "$R/rd-workflow/config"
printf '{\n  "default_branch": ""\n}\n' > "$R/rd-workflow/config/workflow.json"
assert_eq "$(gdb_in "$R")" "master" "빈 config 값 → 자동 검출 fallthrough"

# case 3: origin/HEAD 검출
R="$GDB_TMP/c3"; make_gdb_repo "$R" main
( cd "$R" && git update-ref refs/remotes/origin/devel HEAD \
  && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/devel )
assert_eq "$(gdb_in "$R")" "devel" "origin/HEAD 검출"

# case 4: 로컬 유일 매치 (master만 존재)
R="$GDB_TMP/c4"; make_gdb_repo "$R" master
assert_eq "$(gdb_in "$R")" "master" "main/master 유일 매치"

# case 5: 모호 (main+master 동시 존재) → 에러
R="$GDB_TMP/c5"; make_gdb_repo "$R" main
( cd "$R" && git branch master )
if gdb_in "$R" >/dev/null; then FAIL=$((FAIL+1)); echo "  FAIL: 모호 케이스에서 성공 반환" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: main/master 동시 존재 시 에러"; fi

# case 6: 후보 전무 → 에러
R="$GDB_TMP/c6"; make_gdb_repo "$R" work
if gdb_in "$R" >/dev/null; then FAIL=$((FAIL+1)); echo "  FAIL: 후보 전무에서 성공 반환" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: 후보 전무 시 에러"; fi

# get_main_worktree_path 일반화: master 유일 repo에서 해당 worktree path 반환
R="$GDB_TMP/c7"; make_gdb_repo "$R" master
assert_eq "$( cd "$R" && get_main_worktree_path )" "$( cd "$R" && pwd -P )" "get_main_worktree_path master 일반화"

rm -rf "$GDB_TMP"

echo "== 결과: PASS=$PASS FAIL=$FAIL =="
[[ $FAIL -eq 0 ]]
