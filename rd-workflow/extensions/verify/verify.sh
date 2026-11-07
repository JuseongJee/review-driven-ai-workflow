#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../../.." && pwd)"
cd "${project_root}"

# ──────────────────────────────────────────────
# 상수
# ──────────────────────────────────────────────
CONFIG_FILE="rd-workflow/config/verification.json"
RESULT_BASE=".verification"

# ──────────────────────────────────────────────
# 도움말
# ──────────────────────────────────────────────
usage() {
  cat <<'EOF' >&2
사용법:
  bash rd-workflow/extensions/verify/verify.sh [--verifier <name>] [--skip <name>[,name2]] [--all] [--check] [-h|--help]

옵션:
  --verifier <name>        특정 verifier만 실행
  --skip <name>[,name2]    지정한 verifier를 제외하고 실행
  --all                    모든 verifier 실행 (기본값)
  --check                  설정 점검만 수행 (adapter·run 미실행, 다른 옵션보다 우선)
  -h, --help               도움말 출력

종료 코드:
  0   항상 0 (실패는 manual 체크 항목으로 기록)
  --check 종료 코드:
  0   미완료 0건
  1   점검 불가 (jq·python3 부재, JSON 파싱 실패)
  2   미완료 1건 이상
  3   설정 없음 (verification.json 부재 또는 verifier 0개)
EOF
}

# ──────────────────────────────────────────────
# 인수 파싱
# ──────────────────────────────────────────────
target_verifier=""
skip_verifiers=""
run_all=true
check_mode=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verifier)
      shift
      target_verifier="${1:-}"
      run_all=false
      ;;
    --skip)
      shift
      skip_verifiers="${1:-}"
      ;;
    --all)
      run_all=true
      target_verifier=""
      ;;
    --check)
      check_mode=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[verify] 알 수 없는 옵션: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

# ──────────────────────────────────────────────
# 설정 파일 존재 확인
# ──────────────────────────────────────────────
if [[ ! -f "${project_root}/${CONFIG_FILE}" ]]; then
  if [[ "${check_mode}" == true ]]; then
    echo "[verify] 설정 없음 — ${CONFIG_FILE}"
    echo "verify-check: status=absent incomplete=0 attention=0"
    exit 3
  fi
  echo "[verify] ${CONFIG_FILE} 없음 — 검증을 건너뜁니다."
  exit 0
fi

config_path="${project_root}/${CONFIG_FILE}"

# ──────────────────────────────────────────────
# JSON 파서 탐지 (jq 우선, python3 폴백)
# ──────────────────────────────────────────────
use_jq=false
if command -v jq &>/dev/null; then
  use_jq=true
elif ! command -v python3 &>/dev/null; then
  echo "[verify] jq 또는 python3 중 하나가 필요합니다." >&2
  exit 1
fi

# ──────────────────────────────────────────────
# 전용 헬퍼 함수
# ──────────────────────────────────────────────

# get_verifier_names — JSON에서 verifier 이름 목록을 줄 단위로 반환
get_verifier_names() {
  if [[ "${use_jq}" == true ]]; then
    jq -r '.verifiers | keys_unsorted[]' "${config_path}"
  else
    python3 - <<PYEOF
import json, sys
with open('${config_path}') as f:
    data = json.load(f)
for name in data.get('verifiers', {}).keys():
    print(name)
PYEOF
  fi
}

# get_verifier_field <name> <field> — 특정 verifier의 필드 값을 반환
get_verifier_field() {
  local name="$1"
  local field="$2"

  if [[ "${use_jq}" == true ]]; then
    jq -r --arg name "${name}" --arg field "${field}" \
      '.verifiers[$name][$field] // empty' \
      "${config_path}"
  else
    python3 - <<PYEOF
import json, sys
with open('${config_path}') as f:
    data = json.load(f)
name = '${name}'
field = '${field}'
verifier = data.get('verifiers', {}).get(name, {})
val = verifier.get(field, '')
if val is not None:
    print(val)
PYEOF
  fi
}

# emit_config_rows — 설정을 탭 구분 행으로 출력 (jq·python3 두 경로가 같은 출력을 냄)
#   V 이름 adapter run / C 이름 criteria명 TODO여부 / R 이름 변수 / B 이름
emit_config_rows() {
  if [[ "${use_jq}" == true ]]; then
    jq -r '
      def clean: gsub("[\t\n\r]"; " ");
      def s: (. // "") | tostring | clean;
      (.verifiers // {}) | keys[] as $k | .[$k] as $v |
      if ($v | type) != "object" then error("verifier 값이 객체가 아님: \($k)") else . end |
      (["V", ($k|clean), ($v.adapter|s), ($v.run|s)] | join("\t")),
      (($v.criteria // [])[]? | select(type == "object") |
        ((.name // "") | tostring) as $n | ((.description // "") | tostring) as $d |
        ["C", ($k|clean), ($n|clean), (if ($n|contains("TODO")) or ($d|contains("TODO")) then "1" else "0" end)] | join("\t")),
      (if ($v | has("requires_env")) then
         (if ($v.requires_env | type) == "array"
          then ($v.requires_env[] | select(type == "string") | ["R", ($k|clean), clean] | join("\t"))
          else (["B", ($k|clean)] | join("\t")) end)
       else empty end)
    ' "${config_path}"
  else
    python3 - "${config_path}" <<'PYEOF'
import json, re, sys

def clean(x):
    if x is None:
        x = ''
    return re.sub(r'[\t\n\r]', ' ', str(x))

with open(sys.argv[1]) as f:
    data = json.load(f)
verifiers = data.get('verifiers') or {}
for k in sorted(verifiers):
    v = verifiers[k]
    if not isinstance(v, dict):
        sys.exit('verifier 값이 객체가 아님: ' + str(k))
    print('\t'.join(['V', clean(k), clean(v.get('adapter') or ''), clean(v.get('run') or '')]))
    crit = v.get('criteria') or []
    if isinstance(crit, list):
        for c in crit:
            if not isinstance(c, dict):
                continue
            n = str(c.get('name') or '')
            d = str(c.get('description') or '')
            todo = '1' if ('TODO' in n or 'TODO' in d) else '0'
            print('\t'.join(['C', clean(k), clean(n), todo]))
    if 'requires_env' in v:
        r = v['requires_env']
        if isinstance(r, list):
            for e in r:
                if isinstance(e, str):
                    print('\t'.join(['R', clean(k), clean(e)]))
        else:
            print('\t'.join(['B', clean(k)]))
PYEOF
  fi
}

PW_ADAPTER="rd-workflow/extensions/verify/verifiers/playwright.sh"
INCOMPLETE=()
ATTENTION=()
BLOCKED=()

# list_has <개행 구분 목록> <이름>
list_has() {
  case $'\n'"$1"$'\n' in
    *$'\n'"$2"$'\n'*) return 0 ;;
  esac
  return 1
}

# flush_verifier — 모아 둔 verifier 한 개를 판정해 INCOMPLETE·ATTENTION·BLOCKED 에 더함
flush_verifier() {
  [[ -n "${cv_name}" ]] || return 0
  local v="${cv_name}" parts="" x fixed="" envs="" refs="" ref

  # 1. TODO
  while IFS= read -r x; do
    [[ -n "${x}" ]] || continue
    INCOMPLETE+=("${v}: 채점 기준에 TODO — ${x}")
  done <<< "${cv_todos}"

  # 2. 필수 변수 집합 = adapter 고정 표 ∪ requires_env
  case "${cv_adapter}" in
    rd-workflow/extensions/verify/verifiers/lighthouse.sh|rd-workflow/extensions/verify/verifiers/axe.sh)
      envs="URL" ;;
    rd-workflow/extensions/verify/verifiers/snapshot.sh)
      envs="SNAPSHOT_TEST_SCRIPT" ;;
  esac
  while IFS= read -r x; do
    [[ -n "${x}" ]] || continue
    list_has "${envs}" "${x}" || envs="${envs:+${envs}$'\n'}${x}"
  done <<< "${cv_envs}"
  while IFS= read -r x; do
    [[ -n "${x}" ]] || continue
    if [[ -z "$(printenv "${x}" 2>/dev/null || true)" ]]; then
      INCOMPLETE+=("${v}: 환경 변수 미설정 — ${x}")
      parts="${parts:+${parts}; }환경 변수 미설정 — ${x}"
    fi
  done <<< "${envs}"

  # 3. requires_env 형식 오류
  if [[ "${cv_b}" == 1 ]]; then
    ATTENTION+=("${v}: requires_env 가 문자열 배열이 아닙니다")
  fi

  # 4. run 참조 (확정하지 않고 확인 필요로만 알림)
  refs="$(printf '%s\n' "${cv_run}" | grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*' | sed 's/[${}]//g' || true)"
  local seen=""
  while IFS= read -r ref; do
    [[ -n "${ref}" ]] || continue
    [[ "${ref}" == "OUTPUT_DIR" ]] && continue
    list_has "${envs}" "${ref}" && continue
    list_has "${seen}" "${ref}" && continue
    seen="${seen:+${seen}$'\n'}${ref}"
    if [[ -z "$(printenv "${ref}" 2>/dev/null || true)" ]]; then
      ATTENTION+=("${v}: run 이 참조하는 환경 변수가 비어 있습니다 — ${ref} (필수 여부를 확정하지 않음, 필수면 requires_env 에 선언)")
    fi
  done <<< "${refs}"

  # 5. Playwright 실행 대상
  if [[ "${cv_adapter}" == "${PW_ADAPTER}" ]]; then
    local found
    found="$(find "${project_root}" \( -name node_modules -o -name .git -o -name .verification \) -type d -prune -o \
      -type f \( -name '*.spec.ts' -o -name '*.spec.tsx' -o -name '*.spec.js' -o -name '*.spec.jsx' -o -name '*.spec.mjs' -o -name '*.spec.cjs' \
      -o -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.test.js' -o -name '*.test.jsx' -o -name '*.test.mjs' -o -name '*.test.cjs' \) \
      -print 2>/dev/null | head -n 1 || true)"
    if [[ -z "${found}" ]]; then
      local is_default=true toks=() i t
      read -ra toks <<< "${cv_run}"
      if [[ ${#toks[@]} -lt 3 || "${toks[0]}" != "npx" || "${toks[1]}" != "playwright" || "${toks[2]}" != "test" ]]; then
        is_default=false
      else
        for ((i = 3; i < ${#toks[@]}; i++)); do
          t="${toks[$i]}"
          case "${t}" in
            --reporter=*|--output=*|--workers=*|--retries=*|--quiet) ;;
            *) is_default=false ;;
          esac
        done
      fi
      local has_config=false ext
      for ext in ts js mjs cjs; do
        [[ -f "${project_root}/playwright.config.${ext}" ]] && has_config=true
      done
      if [[ "${is_default}" == true && "${has_config}" == false ]]; then
        INCOMPLETE+=("${v}: 실행 대상 0개 — spec 파일 없음")
        parts="${parts:+${parts}; }실행 대상 0개 — spec 파일 없음"
      else
        ATTENTION+=("${v}: spec 파일을 찾지 못했습니다 (설정 파일 또는 사용자 명령이 검색 위치를 바꿀 수 있어 확정하지 않음)")
      fi
    fi
  fi

  if [[ -n "${parts}" ]]; then
    BLOCKED+=("${v}"$'\t'"${parts}")
  fi
}

# analyze_config — emit_config_rows 를 읽어 INCOMPLETE·ATTENTION·BLOCKED 를 채움
analyze_config() {
  INCOMPLETE=()
  ATTENTION=()
  BLOCKED=()
  cv_name=""; cv_adapter=""; cv_run=""; cv_todos=""; cv_envs=""; cv_b=0
  local kind a b c rows
  # 행을 먼저 받아 파서 실패(예: verifier 값이 객체가 아님)를 검사한다.
  # 프로세스 치환으로 바로 읽으면 실패가 묻혀 「설정 완료」 로 끝난다.
  rows="$(emit_config_rows)" || return 1
  while IFS=$'\037' read -r kind a b c; do
    case "${kind}" in
      V)
        flush_verifier
        cv_name="${a}"; cv_adapter="${b}"; cv_run="${c}"; cv_todos=""; cv_envs=""; cv_b=0
        ;;
      C) [[ "${c}" == "1" ]] && cv_todos="${cv_todos:+${cv_todos}$'\n'}${b}" ;;
      R) cv_envs="${cv_envs:+${cv_envs}$'\n'}${b}" ;;
      B) cv_b=1 ;;
    esac
  done < <(printf '%s\n' "${rows}" | tr '\t' '\037')
  flush_verifier
}

# blocked_reason <verifier> — 건너뛸 verifier 면 사유를 출력하고 0, 아니면 1
blocked_reason() {
  local i entry
  for ((i = 0; i < ${#BLOCKED[@]}; i++)); do
    entry="${BLOCKED[$i]}"
    if [[ "${entry%%$'\t'*}" == "$1" ]]; then
      printf '%s\n' "${entry#*$'\t'}"
      return 0
    fi
  done
  return 1
}

print_findings() {
  local i
  echo "[verify] 미완료 ${#INCOMPLETE[@]}건"
  for ((i = 0; i < ${#INCOMPLETE[@]}; i++)); do echo "  - ${INCOMPLETE[$i]}"; done
  echo "[verify] 확인 필요 ${#ATTENTION[@]}건"
  for ((i = 0; i < ${#ATTENTION[@]}; i++)); do echo "  - ${ATTENTION[$i]}"; done
}

# ──────────────────────────────────────────────
# verifier 목록 결정
# ──────────────────────────────────────────────
set +e
raw_names="$(get_verifier_names 2>/dev/null)"
get_status=$?
set -e

# JSON 파싱 실패 확인 (get_verifier_names가 에러 반환)
if [[ ${get_status} -ne 0 ]]; then
  echo "[verify] verification.json을 파싱할 수 없습니다 — JSON 형식이 잘못되었습니다." >&2
  exit 1
fi

# 파싱은 성공했지만 verifier가 없는 경우
all_names=()
while IFS= read -r name; do
  [[ -n "${name}" ]] && all_names+=("${name}")
done <<< "${raw_names}"

if [[ ${#all_names[@]} -eq 0 ]]; then
  if [[ "${check_mode}" == true ]]; then
    echo "[verify] 설정 없음 — verifier 0개"
    echo "verify-check: status=absent incomplete=0 attention=0"
    exit 3
  fi
  echo "[verify] verification.json에 verifier가 없습니다."
  exit 0
fi

# ──────────────────────────────────────────────
# 설정 점검 (--check: 결과 디렉토리 생성 전에 끝냄 / 일반 실행: 경고 출력)
# ──────────────────────────────────────────────
if ! analyze_config 2>/dev/null; then
  INCOMPLETE=(); ATTENTION=(); BLOCKED=()
  if [[ "${check_mode}" == true ]]; then
    echo "[verify] verification.json 을 해석할 수 없습니다 — verifier 값이 객체가 아닌 항목이 있습니다." >&2
    exit 1
  fi
  echo "[verify] 설정 경고: verification.json 을 해석할 수 없어 설정 점검을 건너뜁니다."
fi

if [[ "${check_mode}" == true ]]; then
  echo "[verify] 설정 점검: ${CONFIG_FILE}"
  print_findings
  echo "[verify] 참고: 「설정 완료」 는 도구 설치와 adapter 구현까지 보장하지 않습니다. xcuitest·xcuitest-macos adapter 는 프로젝트에 맞게 구현해야 합니다."
  if [[ ${#INCOMPLETE[@]} -gt 0 ]]; then
    echo "verify-check: status=incomplete incomplete=${#INCOMPLETE[@]} attention=${#ATTENTION[@]}"
    exit 2
  fi
  echo "verify-check: status=complete incomplete=0 attention=${#ATTENTION[@]}"
  exit 0
fi

if [[ $(( ${#INCOMPLETE[@]} + ${#ATTENTION[@]} )) -gt 0 ]]; then
  echo "[verify] 설정 경고"
  print_findings
fi

# ──────────────────────────────────────────────
# per-run 결과 디렉토리 생성
# ──────────────────────────────────────────────
run_id="$(date +%Y%m%d_%H%M%S)_$$"
result_base="${project_root}/${RESULT_BASE}/${run_id}"
mkdir -p "${result_base}"

# latest 심볼릭 링크 갱신 (기존 디렉토리가 있으면 제거 후 생성)
rm -rf "${project_root}/${RESULT_BASE}/latest"
ln -sfn "${run_id}" "${project_root}/${RESULT_BASE}/latest"

echo "[verify] 결과 디렉토리: ${RESULT_BASE}/${run_id}"

if [[ "${run_all}" == false ]]; then
  # 지정된 verifier가 목록에 있는지 확인
  found=false
  for n in "${all_names[@]}"; do
    if [[ "${n}" == "${target_verifier}" ]]; then
      found=true
      break
    fi
  done
  if [[ "${found}" == false ]]; then
    echo "[verify] verifier '${target_verifier}'를 찾을 수 없습니다." >&2
    exit 1
  fi
  run_names=("${target_verifier}")
else
  # --skip 적용
  if [[ -n "${skip_verifiers}" ]]; then
    IFS=',' read -ra skip_arr <<< "${skip_verifiers}"
    run_names=()
    for n in "${all_names[@]}"; do
      skipped=false
      for s in "${skip_arr[@]}"; do
        if [[ "${n}" == "${s}" ]]; then
          skipped=true
          echo "[verify] [${n}] skip"
          break
        fi
      done
      if [[ "${skipped}" == false ]]; then
        run_names+=("${n}")
      fi
    done
  else
    run_names=("${all_names[@]}")
  fi
fi

# ──────────────────────────────────────────────
# 실행 및 결과 수집
# ──────────────────────────────────────────────
PASSED=()
MANUAL=()

for name in "${run_names[@]}"; do
  adapter="$(get_verifier_field "${name}" "adapter")"

  if [[ -z "${adapter}" ]]; then
    echo "[verify] [${name}] adapter 필드가 없습니다 — manual로 기록합니다."
    MANUAL+=("${name} (adapter 미정의)")
    continue
  fi

  adapter_path="${project_root}/${adapter}"

  if [[ ! -f "${adapter_path}" ]]; then
    echo "[verify] [${name}] adapter 파일 없음: ${adapter} — manual로 기록합니다."
    MANUAL+=("${name} (adapter 없음: ${adapter})")
    continue
  fi

  if blocked_msg="$(blocked_reason "${name}")"; then
    echo "[verify] [${name}] 설정 미완료 — 실행하지 않습니다: ${blocked_msg}"
    MANUAL+=("${name} (설정 미완료: ${blocked_msg})")
    continue
  fi

  result_dir="${result_base}/${name}"
  mkdir -p "${result_dir}"

  echo "[verify] [${name}] 실행 중..."

  set +e
  bash "${adapter_path}" "${name}" "${config_path}" "${result_dir}"
  exit_code=$?
  set -e

  if [[ ${exit_code} -eq 0 ]]; then
    echo "[verify] [${name}] PASSED"
    PASSED+=("${name}")
  else
    echo "[verify] [${name}] FAILED (exit ${exit_code}) — manual 확인 필요"
    MANUAL+=("${name} (exit ${exit_code})")
  fi
done

# ──────────────────────────────────────────────
# 요약 출력
# ──────────────────────────────────────────────
echo ""
echo "══════════════════════════════════"
echo "  검증 요약"
echo "══════════════════════════════════"
echo "  PASSED : ${#PASSED[@]}"
echo "  MANUAL : ${#MANUAL[@]}"

if [[ ${#PASSED[@]} -gt 0 ]]; then
  echo ""
  echo "[ PASSED ]"
  for item in "${PASSED[@]}"; do
    echo "  - ${item}"
  done
fi

if [[ ${#MANUAL[@]} -gt 0 ]]; then
  echo ""
  echo "[ MANUAL 확인 필요 ]"
  for item in "${MANUAL[@]}"; do
    echo "  - ${item}"
  done
fi

echo "══════════════════════════════════"

# 항상 0으로 종료 (실패는 manual 체크 항목)
exit 0
