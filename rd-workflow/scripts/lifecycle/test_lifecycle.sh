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
LIFECYCLE_METADATA_PATH="$TMPDIR_TEST/active-fr"
if metadata_exists; then FAIL=$((FAIL+1)); echo "  FAIL: empty metadata 인데 exists 반환" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: metadata 부재"; fi
metadata_write "fr/foo" "foo" "/path"
if metadata_exists; then PASS=$((PASS+1)); echo "  PASS: write 후 exists"; \
  else FAIL=$((FAIL+1)); echo "  FAIL: metadata write 실패" >&2; fi
assert_eq "$(metadata_read_field fr-branch)" "fr/foo" "metadata_read fr-branch"
assert_eq "$(metadata_read_field short-title)" "foo" "metadata_read short-title"
metadata_clear
if metadata_exists; then FAIL=$((FAIL+1)); echo "  FAIL: clear 후에도 exists" >&2; \
  else PASS=$((PASS+1)); echo "  PASS: metadata clear"; fi

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
  build_review_prompt "$out_file2" sdir cur/SESSION.md cfile uafile ltfile etfile spec-plan-review target goal 20 003
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

# fr 세션 부재 시 빈 값 (다른 fr만 존재)
printf '# Current Task\n\n## Short Title\nlonelytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"
assert_eq "$(get_latest_diff_review_dir)" "" "fr-scope — 현재 fr 세션 없으면 빈 값"
printf '# Current Task\n\n## Short Title\nmytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"

# malformed 세션은 short-title 미상 → fr-scope 후보 제외 (legacy/unscoped 통과, 3d 오발화 방지)
mkdir -p "$RP/20260110_000000_final-diff-review"
mkdir -p "$RP/20260111_000000_final-diff-review"
printf '## Status\nclosed\n' > "$RP/20260111_000000_final-diff-review/SESSION.md"
assert_eq "$(basename "$(get_latest_diff_review_dir)")" "20260109_000000_final-diff-review" "malformed 제외 — short-title 매칭 세션만 반환"
printf '# Current Task\n\n## Short Title\nzzz\n' > "$GUARD_ROOT/CURRENT_TASK.md"
assert_eq "$(get_latest_diff_review_dir)" "" "malformed-only → 빈 값 (unscoped 통과, 오발화 방지)"
printf '# Current Task\n\n## Short Title\nmytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"

# archive_review_precheck (3c)
PRECHECK_AUDIT="$GUARD_ROOT/rd-workflow-workspace/.lifecycle/review-skip-audit.log"
rm -f "$PRECHECK_AUDIT"
printf '# Current Task\n\n## Short Title\nlonelytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"
archive_review_precheck "0" "" "lonelytask" "$PRECHECK_AUDIT" 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "1" "precheck — 미종결 + force-skip 아님 → 차단"
archive_review_precheck "1" "" "lonelytask" "$PRECHECK_AUDIT" 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "1" "precheck — force-skip + 사유 누락 → 차단"
archive_review_precheck "1" "긴급 핫픽스" "lonelytask" "$PRECHECK_AUDIT" 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "precheck — force-skip + 사유 → 통과"
assert_eq "$(awk -F' \\| ' 'END{print $2}' "$PRECHECK_AUDIT")" "lonelytask" "precheck — audit slug 기록"
assert_eq "$(awk -F' \\| ' 'END{print $3}' "$PRECHECK_AUDIT")" "긴급 핫픽스" "precheck — audit 사유 기록"
printf '# Current Task\n\n## Short Title\nmytask\n' > "$GUARD_ROOT/CURRENT_TASK.md"
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
# short-title 은 .lifecycle/active-fr metadata fallback 으로 해소된다(get_current_short_title).
printf '# Current Task\n\n## Short Title\n-\n' > "$FT_REPO/CURRENT_TASK.md"
printf 'fr-branch=fr/fttask\nshort-title=fttask\nworktree-path=null\nstatus=active\n' > "$FT_REPO/rd-workflow-workspace/.lifecycle/active-fr"
git -C "$FT_REPO" add -A && git -C "$FT_REPO" commit -q -m seed
# fr branch 에 종결 diff-review 세션 commit
git -C "$FT_REPO" branch fr/fttask
git -C "$FT_REPO" switch -q fr/fttask
FTS="$FT_REPO/rd-workflow-workspace/handoffs/review_pipeline/20260301_000000_final-diff-review"
mkdir -p "$FTS"
printf '## Status\nclosed\n\n## Branch Context\n- short-title: fttask\n' > "$FTS/SESSION.md"
printf '## Open Issues\n- 없음\n' > "$FTS/CHECKPOINT.md"
git -C "$FT_REPO" add -A && git -C "$FT_REPO" commit -q -m "diff-review session on fr"
git -C "$FT_REPO" switch -q main
FT_AUDIT="$FT_REPO/rd-workflow-workspace/.lifecycle/review-skip-audit.log"
# sanity 1: short-title 은 metadata fallback 으로 해소 (CURRENT_TASK Short Title=-)
assert_eq "$( ( project_root="$FT_REPO"; get_current_short_title ) )" "fttask" "fr-tip — metadata fallback 으로 short-title 해소(Short Title=-)"
# sanity 2: 세션은 fr branch tip 에만 있고 main 워킹트리엔 없음
assert_eq "$( ( project_root="$FT_REPO"; get_latest_diff_review_dir ) )" "" "fr-tip — main 워킹트리에 세션 없음(sanity)"
# Case A (핵심 회귀): main Short Title=- + metadata fallback + fr_ref 지정 → fr tip 종결 세션 인식 → 통과(0)
( project_root="$FT_REPO"; archive_review_precheck "0" "" "fttask" "$FT_AUDIT" "fr/fttask" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "fr-tip — 종결 세션을 fr branch tip 에서 검증 → 통과 (metadata fallback 결합)"
# Case B (안전 회귀): fr tip 세션을 미종결로 변경 → 차단(1)
git -C "$FT_REPO" switch -q fr/fttask
printf '## Status\nawaiting-reviewer\n\n## Branch Context\n- short-title: fttask\n' > "$FTS/SESSION.md"
git -C "$FT_REPO" add -A && git -C "$FT_REPO" commit -q -m "session unterminated"
git -C "$FT_REPO" switch -q main
( project_root="$FT_REPO"; archive_review_precheck "0" "" "fttask" "$FT_AUDIT" "fr/fttask" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "1" "fr-tip — 미종결(awaiting-reviewer) 세션 → 차단 (안전 속성 보존)"
# Case C (audit 정규화): 미종결 fr 세션(위 Case B 상태) + force-skip + 사유 → 통과(0)
#   + audit 의 세션참조 필드가 temp 절대경로가 아닌 repo-상대 경로여야 한다.
FT_AUDIT2="$FT_REPO/rd-workflow-workspace/.lifecycle/audit2.log"
( project_root="$FT_REPO"; archive_review_precheck "1" "긴급 사유" "fttask" "$FT_AUDIT2" "fr/fttask" ) 2>/dev/null && rc=0 || rc=1
assert_eq "$rc" "0" "fr-tip — force-skip + 사유 → 통과"
assert_eq "$(awk -F' \\| ' 'END{print $4}' "$FT_AUDIT2")" "rd-workflow-workspace/handoffs/review_pipeline/20260301_000000_final-diff-review" "fr-tip — audit 세션참조 repo-상대 경로(temp 절대경로 금지)"
rm -rf "$FT_REPO"

# commit_has_archive_signal (review-gate-iteration-commit)
echo "== commit_has_archive_signal =="
SIG_REPO="$(mktemp -d)"
git -C "$SIG_REPO" init -q
git -C "$SIG_REPO" config user.email t@t && git -C "$SIG_REPO" config user.name t
mkdir -p "$SIG_REPO/rd-workflow-workspace/backlog/request-archive"
printf '# Current Task\n\n## Status\n구현 중\n\n## Short Title\nsigtask\n' > "$SIG_REPO/CURRENT_TASK.md"
ARCH="rd-workflow-workspace/backlog/request-archive/2026-05-24-0000-sigtask.md"
# 신호 없음: 비-baseline + staged archive 없음 → 1(허용)
( project_root="$SIG_REPO"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "1" "archive_signal — 신호 없음 → 1(허용)"
# AS1 경계: untracked stale archive 파일(add 안 함) → 1(허용, false-positive 방지)
printf 'x\n' > "$SIG_REPO/$ARCH"
( project_root="$SIG_REPO"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "1" "archive_signal — AS1 untracked stale archive → 1(허용)"
# AS1: staged 추가 → 0(차단)
git -C "$SIG_REPO" add "$ARCH"
( project_root="$SIG_REPO"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "0" "archive_signal — AS1 staged request-archive 추가 → 0(차단)"
# AS1 경계: 기존 archive 파일 삭제(staged D) → 1(허용, 추가 아님)
git -C "$SIG_REPO" commit -q -m seed
git -C "$SIG_REPO" rm -q "$ARCH"
( project_root="$SIG_REPO"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "1" "archive_signal — request-archive 삭제(staged D) → 1(허용)"
# AS2: CURRENT_TASK baseline → 0(차단)  (staged archive 추가 없이도)
printf '# Current Task\n\n## Status\n대기 중\n\n## Short Title\n-\n' > "$SIG_REPO/CURRENT_TASK.md"
( project_root="$SIG_REPO"; commit_has_archive_signal ) && rc=0 || rc=1
assert_eq "$rc" "0" "archive_signal — AS2 CURRENT_TASK baseline → 0(차단)"
rm -rf "$SIG_REPO"

echo "== review_gate hook exit code (iteration-commit 허용) =="
HOOK_REPO="$(mktemp -d)"
mkdir -p "$HOOK_REPO/rd-workflow/scripts/hooks"
mkdir -p "$HOOK_REPO/rd-workflow-workspace/handoffs/review_pipeline"
mkdir -p "$HOOK_REPO/rd-workflow-workspace/backlog/request-archive"
mkdir -p "$HOOK_REPO/rd-workflow-workspace/.lifecycle"
cp "$REPO_ROOT/rd-workflow/scripts/hooks/_guard_common.sh" "$HOOK_REPO/rd-workflow/scripts/hooks/"
cp "$REPO_ROOT/rd-workflow/scripts/hooks/pre_commit_review_gate.sh" "$HOOK_REPO/rd-workflow/scripts/hooks/"
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
# B1-AS2: 미종결 + CURRENT_TASK baseline (metadata fallback 로 세션 매칭) → 차단
printf 'short-title=hooktask\n' > "$HOOK_REPO/rd-workflow-workspace/.lifecycle/active-fr"
printf '# Current Task\n\n## Status\n대기 중\n\n## Short Title\n-\n' > "$HOOK_REPO/CURRENT_TASK.md"
assert_eq "$(run_review_gate)" "2" "review_gate — B1(AS2) 미종결 + CURRENT_TASK baseline → 차단 (exit 2)"
printf '# Current Task\n\n## Status\ndiff review 대기\n\n## Short Title\nhooktask\n' > "$HOOK_REPO/CURRENT_TASK.md"
rm -f "$HOOK_REPO/rd-workflow-workspace/.lifecycle/active-fr"
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
mkdir -p "$AG_REPO/rd-workflow/scripts/hooks" "$AG_REPO/rd-workflow-workspace/handoffs/review_pipeline" "$AG_REPO/rd-workflow-workspace/backlog/items"
cp "$REPO_ROOT/rd-workflow/scripts/hooks/_guard_common.sh" "$AG_REPO/rd-workflow/scripts/hooks/"
cp "$REPO_ROOT/rd-workflow/scripts/hooks/pre_commit_archive_gate.sh" "$AG_REPO/rd-workflow/scripts/hooks/"
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

echo "== 결과: PASS=$PASS FAIL=$FAIL =="
[[ $FAIL -eq 0 ]]
