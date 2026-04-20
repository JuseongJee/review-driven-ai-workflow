#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../../.." && pwd)"

# stdin에서 JSON 읽기
input="$(cat)"

# command 추출 (jq 우선, bash 문자열 조작 폴백)
cmd=""
if command -v jq &>/dev/null; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
fi

if [[ -z "$cmd" ]]; then
  # bash 내장 파싱 폴백 (macOS/Linux 공통, grep 불사용)
  tmp="${input#*\"command\":\"}"
  if [[ "$tmp" != "$input" ]]; then
    cmd="${tmp%%\"*}"
  fi
fi

# command가 비어있으면 통과
if [[ -z "$cmd" ]]; then
  exit 0
fi

# git commit 패턴 감지 (bash [[ ]] 사용, grep 불사용)
# git 토큰 + commit 토큰이 모두 포함된 경우 매칭
# cd && git commit, /usr/bin/git commit, git -c ... commit 등 포함
# 설계 제약: bash -lc 'git commit' 같은 간접 호출은 감지하지 않음
if ! [[ "$cmd" == *git\ *commit* || "$cmd" == *git$'\t'*commit* || "$cmd" == git\ commit* ]]; then
  exit 0
fi

# git commit 감지됨 — staged 파일 분류 후 필요 시 검증 실행

# 문서 경로 패턴 정의
default_doc_patterns=('*.md' 'rd-workflow-workspace/*' 'docs/*' 'rd-workflow/docs/*')

if [[ "${PRE_COMMIT_DOC_PATHS+__SET__}" == "__SET__" ]]; then
  read -ra doc_patterns <<< "$PRE_COMMIT_DOC_PATHS"
else
  doc_patterns=("${default_doc_patterns[@]}")
fi

# 단일 경로가 문서 패턴 리스트와 매칭되면 return 0, 아니면 return 1.
is_doc_path() {
  local path="$1"
  local pat
  # 빈 배열 시 set -u 오류 방지: ${array[@]+"${array[@]}"} 패턴 사용
  for pat in "${doc_patterns[@]+"${doc_patterns[@]}"}"; do
    [[ "$path" == $pat ]] && return 0
  done
  return 1
}

# staged 파일 전체 분류.
# return 0 → 모두 문서 (검증 스킵)
# return 1 → 비문서 포함 (검증 실행)
# return 2 → unknown (검증 실행)
classify_staged() {
  local diff_output
  diff_output="$(git diff --cached --name-status -M --diff-filter=ACMRDT 2>/dev/null)" || {
    # git 실패 → unknown → 안전쪽으로 검증 실행
    return 2
  }

  # staged가 비어있으면 vacuous truth → 스킵
  if [[ -z "$diff_output" ]]; then
    return 0
  fi

  local line status src dst rest
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    status="${line%%$'\t'*}"
    case "$status" in
      A|C|M|D|T)
        src="${line#*$'\t'}"
        if ! is_doc_path "$src"; then
          return 1
        fi
        ;;
      R*)
        # R{score}\t<src>\t<dst> — source와 destination 양쪽 검사
        rest="${line#*$'\t'}"
        src="${rest%%$'\t'*}"
        dst="${rest#*$'\t'}"
        if ! is_doc_path "$src"; then
          return 1
        fi
        if ! is_doc_path "$dst"; then
          return 1
        fi
        ;;
      *)
        # 미인식 status — 안전쪽으로 unknown 처리
        return 2
        ;;
    esac
  done <<< "$diff_output"

  return 0
}

classification_result=0
classify_staged || classification_result=$?

# docs(0)이면 조용히 통과; code(1) 또는 unknown(2)이면 기존 검증 루프 실행
if [[ "$classification_result" -eq 0 ]]; then
  exit 0
fi

# TEMPLATE_STUB sentinel 확인 (bash 내장 사용, grep 불사용)
is_template_stub() {
  local file="$1"
  local line count=0
  while IFS= read -r line; do
    count=$((count + 1))
    [[ "$line" == *'# TEMPLATE_STUB'* ]] && return 0
    [[ "$count" -ge 5 ]] && break
  done < "$file" 2>/dev/null
  return 1
}

scripts_dir="${project_root}/rd-workflow/scripts"
verification_scripts=("test.sh" "lint.sh" "typecheck.sh")

for script_name in "${verification_scripts[@]}"; do
  script_path="${scripts_dir}/${script_name}"

  # 파일 없으면 skip
  if [[ ! -f "$script_path" ]]; then
    continue
  fi

  # TEMPLATE_STUB sentinel이 있으면 skip
  if is_template_stub "$script_path"; then
    continue
  fi

  # 실행
  if ! bash "$script_path"; then
    echo "[hooks] 커밋 전 ${script_name} 검증 실패" >&2
    exit 2
  fi
done

exit 0
