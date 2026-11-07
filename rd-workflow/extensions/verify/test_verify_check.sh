#!/usr/bin/env bash
# verify.sh --check 와 일반 실행의 설정 미완료 판정 회귀 테스트.
# 사용: bash test_verify_check.sh [케이스이름...]   (인자 없으면 전 케이스)
# 임시 디렉터리 안에서만 동작하고 끝나면 지웁니다. 실제 도구는 실행하지 않습니다(adapter 는 stub).
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 &>/dev/null; then
  echo "SKIP: python3 없음 — 테스트 설정 작성에 필요합니다"
  exit 0
fi

TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

PASS_N=0
FAIL_N=0
CUR=""

ok()   { PASS_N=$((PASS_N + 1)); }
bad()  { FAIL_N=$((FAIL_N + 1)); echo "FAIL ${CUR}: $1"; }

assert_rc() { # 기대 실제 이름
  if [[ "$1" == "$2" ]]; then ok; else bad "$3 (기대 rc=$1, 실제 rc=$2)"; fi
}
assert_has() { # 문자열 파일 이름
  if grep -qF -- "$1" "$2"; then ok; else bad "$3"; fi
}
assert_not() { # 문자열 파일 이름
  if grep -qF -- "$1" "$2"; then bad "$3"; else ok; fi
}
assert_file() { # 경로 이름
  if [[ -e "$1" ]]; then ok; else bad "$2"; fi
}
assert_nofile() { # 경로 이름
  if [[ -e "$1" ]]; then bad "$2"; else ok; fi
}
assert_eq() { # 기대 실제 이름
  if [[ "$1" == "$2" ]]; then ok; else bad "$3"; fi
}

PROVIDED_ADAPTERS="lighthouse axe playwright k6 schema-validate snapshot hyperfine"

# new_project <이름> — 임시 프로젝트를 만들고 경로를 PROJ 에 둡니다.
new_project() {
  PROJ="${TMPROOT}/$1"
  mkdir -p "${PROJ}/rd-workflow/extensions/verify" "${PROJ}/rd-workflow/config"
  cp -R "${script_dir}/." "${PROJ}/rd-workflow/extensions/verify/"
  local a
  for a in ${PROVIDED_ADAPTERS}; do
    printf '#!/usr/bin/env bash\necho "$1" >> "$3/../../.called-%s"\nexit 0\n' "${a}" \
      > "${PROJ}/rd-workflow/extensions/verify/verifiers/${a}.sh"
  done
}

use_preset() { # 프리셋...  — 설정 파일을 프리셋들의 verifiers 합집합으로 씁니다.
  local args=() p
  for p in "$@"; do args+=("${script_dir}/presets/${p}/verification.json"); done
  python3 -c '
import json, sys
out = {}
for path in sys.argv[2:]:
    with open(path) as f:
        out.update(json.load(f)["verifiers"])
with open(sys.argv[1], "w") as f:
    json.dump({"verifiers": out}, f, indent=2)
' "${PROJ}/rd-workflow/config/verification.json" "${args[@]}"
}

strip_requires_env() {
  python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
for v in d["verifiers"].values():
    v.pop("requires_env", None)
json.dump(d, open(p, "w"), indent=2)
' "${PROJ}/rd-workflow/config/verification.json"
}

make_stub() { # 경로 마커이름 — 호출되면 마커에 verifier 이름을 append 하는 stub
  mkdir -p "$(dirname "${PROJ}/$1")"
  printf '#!/usr/bin/env bash\necho "$1" >> "$3/../../.called-%s"\nexit 0\n' "$2" > "${PROJ}/$1"
}

add_spec() {
  mkdir -p "${PROJ}/tests"
  : > "${PROJ}/tests/a.spec.ts"
}

# run_v <출력파일> <환경...> -- <verify.sh 인자...> ; 결과 코드는 RC
run_v() {
  local out="$1"; shift
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  RC=0
  (cd "${PROJ}" && env -u URL -u K6_SCRIPT -u SCHEMA_VALIDATE_SCRIPT -u BENCHMARK_CMD \
    -u SNAPSHOT_TEST_SCRIPT -u OPTIONAL -u UNUSED -u VALUE ${envs[@]+"${envs[@]}"} \
    bash rd-workflow/extensions/verify/verify.sh "$@") > "${out}" 2>&1 || RC=$?
}

called_count() { # 마커이름
  if [[ -f "${PROJ}/.verification/.called-$1" ]]; then wc -l < "${PROJ}/.verification/.called-$1" | tr -d ' '; else echo 0; fi
}

# ──────────────────────────────────────────────
# 케이스
# ──────────────────────────────────────────────
case_react_web_preset_incomplete() {
  new_project "$CUR"; use_preset react-web
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" -- --check
  assert_rc 2 "$RC" "--check 종료 코드 2"
  assert_has "lighthouse: 채점 기준에 TODO — performance" "$o" "lighthouse TODO 나열"
  assert_has "axe: 채점 기준에 TODO — accessibility" "$o" "axe TODO 나열"
  assert_has "playwright: 채점 기준에 TODO — responsive" "$o" "playwright TODO 나열"
  assert_has "lighthouse: 환경 변수 미설정 — URL" "$o" "lighthouse URL 미설정"
  assert_has "axe: 환경 변수 미설정 — URL" "$o" "axe URL 미설정"
  assert_has "playwright: 실행 대상 0개 — spec 파일 없음" "$o" "playwright 실행 대상 0개"
  assert_has "verify-check: status=incomplete incomplete=10 attention=0" "$o" "기계 판독 줄 incomplete=10"
}

case_react_web_url_and_spec() {
  new_project "$CUR"; use_preset react-web; add_spec
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" URL=http://localhost:1 -- --check
  assert_not "환경 변수 미설정" "$o" "환경 변수 미설정 없음"
  assert_not "실행 대상 0개" "$o" "실행 대상 0개 없음"
  assert_has "incomplete=7 " "$o" "TODO 7건만 남음"
}

case_api_cli_requires_env() {
  new_project "$CUR"; use_preset api cli
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" -- --check
  assert_has "k6: 환경 변수 미설정 — K6_SCRIPT" "$o" "K6_SCRIPT 환경 변수 미설정"
  assert_has "schema-validate: 환경 변수 미설정 — SCHEMA_VALIDATE_SCRIPT" "$o" "SCHEMA_VALIDATE_SCRIPT 환경 변수 미설정"
  assert_has "hyperfine: 환경 변수 미설정 — BENCHMARK_CMD" "$o" "BENCHMARK_CMD 환경 변수 미설정"
  assert_has "snapshot: 환경 변수 미설정 — SNAPSHOT_TEST_SCRIPT" "$o" "SNAPSHOT_TEST_SCRIPT 환경 변수 미설정"
}

case_api_cli_without_requires_env() {
  new_project "$CUR"; use_preset api cli; strip_requires_env
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" -- --check
  assert_has "snapshot: 환경 변수 미설정 — SNAPSHOT_TEST_SCRIPT" "$o" "SNAPSHOT_TEST_SCRIPT 환경 변수 미설정 (고정 표)"
  assert_not "k6: 환경 변수 미설정" "$o" "k6 는 미완료 아님"
  assert_not "hyperfine: 환경 변수 미설정" "$o" "hyperfine 은 미완료 아님"
  assert_has "k6: run 이 참조하는 환경 변수가 비어 있습니다 — K6_SCRIPT" "$o" "K6_SCRIPT 확인 필요 표시"
  assert_has "hyperfine: run 이 참조하는 환경 변수가 비어 있습니다 — BENCHMARK_CMD" "$o" "BENCHMARK_CMD 확인 필요 표시"
}

case_optional_refs_not_blocking() {
  new_project "$CUR"; make_stub scripts/custom.sh custom
  cat > "${PROJ}/rd-workflow/config/verification.json" <<'EOF'
{"verifiers":{
 "a":{"run":"test -z \"$OPTIONAL\"","adapter":"scripts/custom.sh"},
 "b":{"run":"printf '%s' \"${OPTIONAL:+$VALUE}\"","adapter":"scripts/custom.sh"},
 "c":{"run":"printf ok # $UNUSED","adapter":"scripts/custom.sh"}
}}
EOF
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" -- --check
  assert_rc 0 "$RC" "--check 종료 코드 0"
  run_v "$o" --
  assert_eq 3 "$(called_count custom)" "custom adapter 3회 호출"
}

case_same_name_user_adapter() {
  new_project "$CUR"; make_stub scripts/lighthouse.sh userlh
  cat > "${PROJ}/rd-workflow/config/verification.json" <<'EOF'
{"verifiers":{"lh":{"run":"echo $URL","adapter":"scripts/lighthouse.sh"}}}
EOF
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" -- --check
  assert_has "incomplete=0 " "$o" "미완료 아님"
  assert_not "환경 변수 미설정" "$o" "환경 변수 미설정 없음"
  run_v "$o" --
  assert_file "${PROJ}/.verification/.called-userlh" "사용자 adapter 호출됨"
}

write_playwright_config() { # run 문자열
  cat > "${PROJ}/rd-workflow/config/verification.json" <<EOF
{"verifiers":{"playwright":{"run":"$1","adapter":"rd-workflow/extensions/verify/verifiers/playwright.sh"}}}
EOF
}

case_playwright_config_reexport() {
  new_project "$CUR"
  write_playwright_config 'npx playwright test --reporter=json'
  echo "export { default } from '../shared/playwright.config';" > "${PROJ}/playwright.config.ts"
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" -- --check
  assert_not "실행 대상 0개" "$o" "실행 대상 0개 없음"
  assert_has "spec 파일을 찾지 못했습니다" "$o" "확인 필요 표시"
  run_v "$o" --
  assert_file "${PROJ}/.verification/.called-playwright" "playwright 호출됨"
}

case_playwright_external_config_flag() {
  new_project "$CUR"
  write_playwright_config 'npx playwright test --config=../shared/playwright.config.ts'
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" -- --check
  assert_not "실행 대상 0개" "$o" "실행 대상 0개 없음"
  assert_has "spec 파일을 찾지 못했습니다" "$o" "확인 필요 표시"
  run_v "$o" --
  assert_file "${PROJ}/.verification/.called-playwright" "playwright 호출됨"
}

case_run_blocks_zero_specs() {
  new_project "$CUR"; use_preset react-web
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" URL=http://localhost:1 --
  assert_rc 0 "$RC" "일반 실행 종료 코드 0"
  assert_nofile "${PROJ}/.verification/.called-playwright" "playwright 표식 없음"
  assert_has "playwright (설정 미완료: 실행 대상 0개 — spec 파일 없음)" "$o" "MANUAL 에 설정 미완료"
  assert_file "${PROJ}/.verification/.called-lighthouse" "lighthouse 표식 있음"
  assert_file "${PROJ}/.verification/.called-axe" "axe 표식 있음"
}

case_check_no_execution() {
  new_project "$CUR"
  mkdir -p "${PROJ}/scripts"
  cat > "${PROJ}/scripts/evalrun.sh" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "$3/../../.called-evalrun"
eval "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["verifiers"][sys.argv[2]]["run"])' "$2" "$1")"
EOF
  cat > "${PROJ}/rd-workflow/config/verification.json" <<'EOF'
{"verifiers":{
 "lighthouse":{"run":"npx lighthouse $URL","adapter":"rd-workflow/extensions/verify/verifiers/lighthouse.sh"},
 "evalrun":{"run":"touch RUN_MARK","adapter":"scripts/evalrun.sh"}
}}
EOF
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" URL=http://localhost:1 -- --check
  assert_nofile "${PROJ}/.verification/.called-lighthouse" "제공 adapter 표식 없음"
  assert_nofile "${PROJ}/.verification/.called-evalrun" "사용자 adapter 표식 없음"
  assert_nofile "${PROJ}/RUN_MARK" "run 표식 없음"
  run_v "$o" URL=http://localhost:1 --
  assert_file "${PROJ}/.verification/.called-lighthouse" "일반 실행 뒤 제공 adapter 표식 있음"
  assert_file "${PROJ}/.verification/.called-evalrun" "일반 실행 뒤 사용자 adapter 표식 있음"
  assert_file "${PROJ}/RUN_MARK" "일반 실행 뒤 run 표식 있음"
}

case_run_blocks_missing_env() {
  new_project "$CUR"; use_preset react-web; add_spec
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" --
  assert_rc 0 "$RC" "일반 실행 종료 코드 0"
  assert_nofile "${PROJ}/.verification/.called-lighthouse" "lighthouse 표식 없음"
  assert_nofile "${PROJ}/.verification/.called-axe" "axe 표식 없음"
  assert_has "lighthouse (설정 미완료: 환경 변수 미설정 — URL)" "$o" "MANUAL 에 설정 미완료"
  assert_file "${PROJ}/.verification/.called-playwright" "playwright 표식 있음"
}

case_run_todo_only_warns() {
  new_project "$CUR"; use_preset react-web; add_spec
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" URL=http://localhost:1 --
  assert_has "설정 경고" "$o" "설정 경고 있음"
  assert_file "${PROJ}/.verification/.called-lighthouse" "lighthouse 표식 있음"
  assert_file "${PROJ}/.verification/.called-axe" "axe 표식 있음"
  assert_file "${PROJ}/.verification/.called-playwright" "playwright 표식 있음"
}

case_clean_config() {
  new_project "$CUR"
  cat > "${PROJ}/rd-workflow/config/verification.json" <<'EOF'
{"verifiers":{"lighthouse":{"run":"npx lighthouse $URL",
 "criteria":[{"name":"performance","description":"점수가 기준 이상인가","weight":"high"}],
 "requires_env":["URL"],
 "adapter":"rd-workflow/extensions/verify/verifiers/lighthouse.sh"}}}
EOF
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" URL=http://localhost:1 -- --check
  assert_rc 0 "$RC" "--check 종료 코드 0"
  assert_has "verify-check: status=complete incomplete=0 attention=0" "$o" "기계 판독 줄 complete"
  run_v "$o" URL=http://localhost:1 --
  assert_not "설정 경고" "$o" "설정 경고 없음"
}

case_exit_codes() {
  new_project "$CUR"
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" -- --check
  assert_rc 3 "$RC" "설정 파일 없음 rc=3"
  assert_has "status=absent" "$o" "설정 없음 status=absent"
  echo '{"verifiers":{}}' > "${PROJ}/rd-workflow/config/verification.json"
  run_v "$o" -- --check
  assert_rc 3 "$RC" "verifier 0개 rc=3"
  echo '{bad' > "${PROJ}/rd-workflow/config/verification.json"
  run_v "$o" -- --check
  assert_rc 1 "$RC" "깨진 JSON rc=1"
  assert_not "verify-check:" "$o" "verify-check 줄 없음"
  echo '{"verifiers":{"a":"str"}}' > "${PROJ}/rd-workflow/config/verification.json"
  run_v "$o" -- --check
  assert_rc 1 "$RC" "비객체 verifier rc=1"
  assert_not "status=complete" "$o" "비객체 verifier 를 설정 완료로 보지 않음"
  echo '{"verifiers":{"a":null}}' > "${PROJ}/rd-workflow/config/verification.json"
  run_v "$o" -- --check
  assert_rc 1 "$RC" "null verifier rc=1"
  assert_not "status=complete" "$o" "null verifier 를 설정 완료로 보지 않음"
}

case_mixed_case_refs() {
  new_project "$CUR"
  cat > "${PROJ}/rd-workflow/config/verification.json" <<'EOF'
{"verifiers":{"a":{"run":"tool $review_lc ${review_lc2} $ApiKey","adapter":"scripts/custom.sh"}}}
EOF
  local o="${TMPROOT}/$CUR.out"
  run_v "$o" ApiKey=set -- --check
  assert_rc 0 "$RC" "--check 종료 코드 0 (확인 필요만)"
  assert_has "환경 변수가 비어 있습니다 — review_lc " "$o" "소문자 \$이름 확인 필요"
  assert_has "환경 변수가 비어 있습니다 — review_lc2 " "$o" "소문자 \${이름} 확인 필요"
  assert_not "— ApiKey " "$o" "설정된 혼합 이름은 알리지 않음"
  assert_not "— A " "$o" "혼합 이름의 접두사를 별도 변수로 보지 않음"
}

case_check_preserves_latest() {
  new_project "$CUR"; use_preset react-web
  mkdir -p "${PROJ}/.verification/old"
  echo keep > "${PROJ}/.verification/old/x"
  ln -s old "${PROJ}/.verification/latest"
  local before_list before_sum before_link
  before_list="$(cd "${PROJ}" && find .verification | sort)"
  before_sum="$(cksum < "${PROJ}/.verification/old/x")"
  before_link="$(readlink "${PROJ}/.verification/latest")"
  run_v "${TMPROOT}/$CUR.out" -- --check
  assert_eq "$before_list" "$(cd "${PROJ}" && find .verification | sort)" "파일 목록 동일"
  assert_eq "$before_sum" "$(cksum < "${PROJ}/.verification/old/x")" "x 내용 동일"
  assert_eq "$before_link" "$(readlink "${PROJ}/.verification/latest")" "latest 대상 동일"
}

# make_nojq_bin <디렉터리> — jq 만 뺀 PATH 디렉터리를 만든다 (python3 경로 검증용)
make_nojq_bin() {
  local bin="$1" c p
  mkdir -p "${bin}"
  for c in bash python3 dirname find grep sed tr printenv head cat env sort date mkdir ln rm; do
    p="$(command -v "$c" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "${bin}/$c"
  done
}

case_parser_parity() {
  if ! command -v jq &>/dev/null; then echo "SKIP parser_parity: jq 없음"; return 0; fi
  new_project "$CUR"; use_preset react-web
  local jq_out="${TMPROOT}/$CUR.jq.out" py_out="${TMPROOT}/$CUR.py.out"
  run_v "${jq_out}" -- --check
  local bin="${TMPROOT}/$CUR.bin"
  make_nojq_bin "${bin}"
  local bash_path envp
  bash_path="$(command -v bash)"; envp="$(command -v env)"
  (cd "${PROJ}" && "${envp}" -u URL PATH="${bin}" "${bash_path}" rd-workflow/extensions/verify/verify.sh --check) > "${py_out}" 2>&1
  assert_eq "$(cat "${jq_out}")" "$(cat "${py_out}")" "출력 동일 (jq 경로 = python3 경로)"
  # 합성 설정: requires_env 비배열(B 행), 탭·줄바꿈이 든 run, description 에만 있는 TODO
  printf '%s\n' '{"verifiers":{"zz":{"run":"tool\t$ALPHA\n--x","criteria":[{"name":"c1","description":"설명 TODO"}],"requires_env":"URL","adapter":"scripts/zz.sh"}}}' \
    > "${PROJ}/rd-workflow/config/verification.json"
  run_v "${jq_out}" -- --check
  (cd "${PROJ}" && "${envp}" -u URL -u ALPHA PATH="${bin}" "${bash_path}" rd-workflow/extensions/verify/verify.sh --check) > "${py_out}" 2>&1
  assert_has "zz: requires_env 가 문자열 배열이 아닙니다" "${jq_out}" "B 행 확인 필요 표시"
  assert_has "zz: 채점 기준에 TODO — c1" "${jq_out}" "description 의 TODO 집계"
  assert_has "환경 변수가 비어 있습니다 — ALPHA" "${jq_out}" "탭·줄바꿈 run 의 참조 추출"
  assert_eq "$(cat "${jq_out}")" "$(cat "${py_out}")" "합성 설정 출력 동일 (jq 경로 = python3 경로)"
}

case_run_order_follows_config() {
  new_project "$CUR"; use_preset react-web
  printf '%s\n' '{"verifiers":{"zz":{"run":"true"},"aa":{"run":"true"},"mm":{"run":"true"}}}' \
    > "${PROJ}/rd-workflow/config/verification.json"
  local out="${TMPROOT}/$CUR.out" extract
  extract() { grep -o '^\[verify\] \[[a-z]*\] adapter 필드가 없습니다' "$1" | sed 's/^\[verify\] \[\([a-z]*\)\].*/\1/' | tr '\n' ' '; }
  if command -v jq &>/dev/null; then
    run_v "${out}" --
    assert_eq "zz aa mm " "$(extract "${out}")" "jq 경로 실행 순서 = 설정 파일 순서"
  else
    echo "SKIP run_order_follows_config(jq 경로): jq 없음"
  fi
  local bin="${TMPROOT}/$CUR.bin" bash_path envp
  make_nojq_bin "${bin}"
  bash_path="$(command -v bash)"; envp="$(command -v env)"
  (cd "${PROJ}" && "${envp}" -u URL PATH="${bin}" "${bash_path}" rd-workflow/extensions/verify/verify.sh) > "${out}" 2>&1 || true
  assert_eq "zz aa mm " "$(extract "${out}")" "python3 경로 실행 순서 = 설정 파일 순서"
}

ALL_CASES="react_web_preset_incomplete react_web_url_and_spec api_cli_requires_env api_cli_without_requires_env optional_refs_not_blocking same_name_user_adapter playwright_config_reexport playwright_external_config_flag run_blocks_zero_specs check_no_execution run_blocks_missing_env run_todo_only_warns clean_config exit_codes mixed_case_refs check_preserves_latest parser_parity run_order_follows_config"

if [[ $# -gt 0 ]]; then
  selected="$*"
else
  selected="${ALL_CASES}"
fi

for CUR in ${selected}; do
  if [[ " ${ALL_CASES} " != *" ${CUR} "* ]]; then
    bad "알 수 없는 케이스"
    continue
  fi
  "case_${CUR}"
done

if [[ ${FAIL_N} -gt 0 ]]; then
  echo "FAIL: ${FAIL_N}"
  exit 1
fi
echo "PASS: ${PASS_N}"
