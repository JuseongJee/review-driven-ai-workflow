#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
fail() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$1" >&2; }
pass() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$1"; }
TMP="$(mktemp -d)" || { echo "test_session_launch.sh: 임시 디렉터리 생성 실패 (mktemp rc≠0, TMPDIR='${TMPDIR:-}')" >&2; exit 1; }
[[ -n "$TMP" && -d "$TMP" ]] || { echo "test_session_launch.sh: 임시 디렉터리 경로 검증 실패 (TMPDIR='${TMPDIR:-}')" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT
source "$SCRIPT_DIR/session_launch.sh"

# 1) herdr 밖이면 기동하지 않고 none 을 낸다
out="$(HERDR_ENV= RD_CHILD_SESSION= session_launch /tmp/wt alpha REQUEST.md 2>/dev/null)"
[[ "$out" == "none" ]] && pass "herdr 밖에서는 none" || fail "herdr 밖 판정: $out"

# 2) 자식 세션이면 herdr 환경이어도 기동하지 않고 none + 거부 사유
err="$(HERDR_ENV=1 RD_CHILD_SESSION=1 session_launch /tmp/wt alpha REQUEST.md 2>&1 >/dev/null)"
[[ "$err" == *"자식 세션"* ]] && pass "자식 세션은 기동을 거부한다" || fail "깊이 1 거부"

# 3) 수동 기동 명령에 worktree 경로가 들어간다
cmd="$(session_launch_command /tmp/wt alpha)"
[[ "$cmd" == *"/tmp/wt"* ]] && pass "수동 명령에 worktree 경로 포함" || fail "수동 명령"

# 4) 상태별 다음 행동이 비어 있지 않다 (ok 만 '없음')
[[ -n "$(session_launch_status_hint failed)" ]] \
  && [[ -n "$(session_launch_status_hint unknown)" ]] \
  && [[ -n "$(session_launch_status_hint none)" ]] \
  && pass "상태별 다음 행동이 있다" || fail "다음 행동"

# 5) CLI 대역(stub)으로 상태 분기를 검사한다 — PATH 앞에 가짜 herdr 를 둔다.
#    실제 herdr 화면 동작은 수동 확인이지만, 상태 분기까지 수동에 맡기지 않는다.
#    stub 은 받은 인자를 calls.log 에 남겨, cwd·env 전달 같은 호출 형태도 검사한다.
#    (실제 응답 스키마 — 이 머신에서 실측: `tab create` 는 `.result.root_pane.pane_id` 와
#     `.result.tab.tab_id` 를 함께 돌려준다.)
STUB="$TMP/bin"; mkdir -p "$STUB"
make_stub() {  # make_stub <tab-create-rc> <start-rc> <prompt-rc> [start-body]
  : > "$STUB/calls.log"
  local _start_body="${4:-}"
  cat > "$STUB/herdr" <<STUBEOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$STUB/calls.log"
case "\$1 \$2" in
  "tab create")
    [[ "$1" -ne 0 ]] && exit $1
    echo '{"result":{"root_pane":{"pane_id":"wX:p9","tab_id":"wX:t9"},"tab":{"tab_id":"wX:t9"}}}' ;;
  "agent start") printf '%s' '${_start_body}'; exit $2 ;;
  "agent prompt") exit $3 ;;
  "agent get") echo '{"result":{"agents":[]}}' ;;
  "tab close") exit 0 ;;
esac
STUBEOF
  chmod +x "$STUB/herdr"
}

make_stub 0 0 0
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_CHILD_SESSION= session_launch /tmp/wt alpha REQUEST.md 2>/dev/null)"
[[ "$out" == "ok" ]] && pass "start·prompt 모두 성공이면 ok" || fail "ok 판정: $out"

make_stub 0 0 1
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_CHILD_SESSION= session_launch /tmp/wt alpha REQUEST.md 2>/dev/null)"
[[ "$out" == "unknown" ]] \
  && pass "start 성공 + prompt 실패는 unknown (세션이 살아 있을 수 있다)" || fail "부분 성공: $out"

make_stub 0 1 0
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_CHILD_SESSION= session_launch /tmp/wt alpha REQUEST.md 2>/dev/null)"
[[ "$out" == "failed" ]] && pass "start 실패는 failed" || fail "failed 판정: $out"
grep -q '^tab close' "$STUB/calls.log" \
  && pass "agent start 실패 시 만들어진 tab 을 닫으려 시도한다" || fail "agent start 실패 후 tab close 미시도"

# 5-1) **`agent_not_ready` 는 failed 가 아니다.** 새 worktree 는 늘 처음 여는 경로라
#      claude 가 기동 직후 신뢰 확인 다이얼로그를 띄우고 blocked 로 들어가는데, 그때
#      agent start 가 이 코드로 rc≠0 을 낸다 — **에이전트는 떠 있다**(2026-09-16 실측).
#      failed 로 보고 tab 을 닫으면 사람이 승인하기 전에 방금 뜬 세션을 죽인다.
make_stub 0 1 0 '{"error":{"code":"agent_not_ready","message":"blocked during startup"}}'
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_CHILD_SESSION= session_launch /tmp/wt alpha REQUEST.md 2>/dev/null)"
[[ "$out" == "unknown" ]] \
  && pass "agent_not_ready(blocked)는 unknown 이다" || fail "agent_not_ready 판정: $out"
grep -q '^tab close' "$STUB/calls.log" \
  && fail "blocked 세션의 tab 을 닫았다(승인 전 세션 소실)" \
  || pass "blocked 세션의 tab 은 닫지 않는다"

# 5-2) **타임아웃(rc=124)도 failed 가 아니다** (F3). 시작 요청은 이미 보냈으므로 "만들어지지
#      않았다" 는 증거가 없다. tab 을 닫으면 응답만 늦은 살아 있는 세션을 죽인다.
make_stub 0 124 0
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_CHILD_SESSION= session_launch /tmp/wt alpha REQUEST.md 2>/dev/null)"
[[ "$out" == "unknown" ]] \
  && pass "agent start 타임아웃(124)은 unknown 이다" || fail "start 타임아웃 판정: $out"
grep -q '^tab close' "$STUB/calls.log" \
  && fail "타임아웃 뒤 tab 을 닫았다(살아 있을 수 있는 세션 소실)" \
  || pass "start 타임아웃에서는 tab 을 닫지 않는다"

# 5a) tab create 자체가 실패하면 ok 가 아니다 (agent start·prompt 는 아예 호출되지 않아야 한다)
make_stub 1 0 0
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_CHILD_SESSION= session_launch /tmp/wt alpha REQUEST.md 2>/dev/null)"
[[ "$out" == "failed" ]] && pass "tab create 실패는 failed(ok 아님)" || fail "tab create 실패 판정: $out"
if grep -q '^tab create' "$STUB/calls.log" && ! grep -q '^agent start' "$STUB/calls.log"; then
  pass "tab create 실패 시 agent start 를 호출하지 않는다"
else
  fail "tab create 실패 후에도 agent start 가 호출됨"
fi

# 5b) 기동 경로가 cwd·env·label 을 tab create 인자로 직접 전달한다 (send-text 로 타이핑해
#     넣지 않는다 — 그 방식은 셸 준비 시점과 경합한다). **label 에 slug 를 싣는 것이
#     식별의 근거다** — herdr agents 패널이 행마다 그 tab 의 label 을 보여준다(실측).
make_stub 0 0 0
: "$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_CHILD_SESSION= session_launch /tmp/wt alpha REQUEST.md 2>/dev/null)"
create_call="$(grep '^tab create' "$STUB/calls.log" || true)"
[[ "$create_call" == *"--cwd /tmp/wt"* && "$create_call" == *"--env RD_CHILD_SESSION=1"* ]] \
  && pass "tab create 인자에 --cwd·--env 가 담긴다" || fail "cwd·env 전달: $create_call"
[[ "$create_call" == *"--label alpha"* ]] \
  && pass "tab label 에 작업 slug 가 담긴다(목록 식별)" || fail "label 전달: $create_call"
grep -q 'send-text' "$STUB/calls.log" \
  && fail "send-text 경로가 남아 있다(경합 원인)" \
  || pass "send-text 를 호출하지 않는다"

# 5c) herdr 에이전트 이름은 1~32자다(실측). normalize_slug 는 60자까지 허용하므로 그 사이
#     구간을 줄이지 않으면 정상 착수가 기동 실패로 떨어진다. 전체 slug 는 label 이 지킨다.
make_stub 0 0 0
long_slug="aaaaaaaaaa-bbbbbbbbbb-cccccccccc-dddddddddd"   # 43자
: "$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_CHILD_SESSION= session_launch /tmp/wt "$long_slug" REQUEST.md 2>/dev/null)"
start_call="$(grep '^agent start' "$STUB/calls.log" || true)"
started_name="$(printf '%s' "$start_call" | awk '{print $3}')"
[[ -n "$started_name" && "${#started_name}" -le 32 ]] \
  && pass "긴 slug 의 에이전트 이름을 32자 이하로 줄인다" || fail "이름 길이: [${started_name}] ${#started_name}자"
create_call="$(grep '^tab create' "$STUB/calls.log" || true)"
[[ "$create_call" == *"--label $long_slug"* ]] \
  && pass "이름을 줄여도 tab label 에는 전체 slug 가 남는다" || fail "긴 slug label: $create_call"

# 6) 조회 실패는 unknown 이다 (세션 부재로 단정하지 않는다)
cat > "$STUB/herdr" <<'STUBEOF'
#!/usr/bin/env bash
[[ "$1 $2" == "agent get" ]] && exit 3
echo '{"result":{"pane":{"id":"wX:p9"}}}'
STUBEOF
chmod +x "$STUB/herdr"
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 session_probe alpha 2>/dev/null)"
[[ "$out" == "unknown" ]] && pass "조회 실패는 unknown" || fail "조회 실패 판정: $out"

# 7) 무응답은 유한 시간 안에 unknown 으로 끝난다 (이 머신에 timeout 명령이 없다)
cat > "$STUB/herdr" <<'STUBEOF'
#!/usr/bin/env bash
sleep 30
STUBEOF
chmod +x "$STUB/herdr"
start=$SECONDS
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 RD_LAUNCH_TIMEOUT=2 session_probe alpha 2>/dev/null)"
elapsed=$((SECONDS-start))
[[ "$out" == "unknown" && "$elapsed" -lt 10 ]] \
  && pass "무응답이 유한 시간 안에 unknown 으로 끝난다" || fail "타임아웃: $out/${elapsed}s"

# 8) 살아 있는 세션이 다른 작업을 맡고 있으면 대상 불일치로 본다
cat > "$STUB/herdr" <<'STUBEOF'
#!/usr/bin/env bash
[[ "$1 $2" == "agent get" ]] && { echo '{"result":{"agents":[{"cwd":"/other/wt"}]}}'; exit 0; }
STUBEOF
chmod +x "$STUB/herdr"
out="$(PATH="$STUB:$PATH" HERDR_ENV=1 session_probe alpha /tmp/wt 2>/dev/null)"
[[ "$out" != "alive" ]] && pass "대상 불일치 세션을 alive 로 보지 않는다" || fail "대상 불일치"

printf 'session_launch: PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
