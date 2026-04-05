#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../../.." && pwd)"
cd "${project_root}"

# ──────────────────────────────────────────────
# 상수
# ──────────────────────────────────────────────
CONFIG_FILE="ai/config/verification.json"
RESULT_BASE=".verification"

# ──────────────────────────────────────────────
# 도움말
# ──────────────────────────────────────────────
usage() {
  cat <<'EOF' >&2
사용법:
  bash ai/extensions/verify/verify.sh [--verifier <name>] [--skip <name>[,name2]] [--all] [-h|--help]

옵션:
  --verifier <name>        특정 verifier만 실행
  --skip <name>[,name2]    지정한 verifier를 제외하고 실행
  --all                    모든 verifier 실행 (기본값)
  -h, --help               도움말 출력

종료 코드:
  0   항상 0 (실패는 manual 체크 항목으로 기록)
EOF
}

# ──────────────────────────────────────────────
# 인수 파싱
# ──────────────────────────────────────────────
target_verifier=""
skip_verifiers=""
run_all=true

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
    jq -r '.verifiers | keys[]' "${config_path}"
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
  echo "[verify] verification.json에 verifier가 없습니다."
  exit 0
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
