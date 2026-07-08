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

# --- staged hash 캐시 (spec §2 결정 4): 성공만 기록, 불일치/손상/도구부재 → 전체 검증 ---
VERIFY_CACHE="${project_root}/rd-workflow-workspace/.lifecycle/verify-cache"

# hash 도구 선택 (shasum 우선, sha256sum 폴백, 부재 시 캐싱 비활성)
_hash_cmd() {
  if command -v shasum &>/dev/null; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum &>/dev/null; then
    sha256sum | awk '{print $1}'
  else
    return 1
  fi
}

# record-framed 파일 항목: 경로|존재여부|mode|내용hash
# 경계·존재·권한 변경이 키에 반영되도록 프레이밍 (spec §2 결정 4)
_file_record() {
  local f="$1" h
  if [[ -f "$f" ]]; then
    h="$(_hash_cmd < "$f")" || return 1
    printf '%s|present|%s|%s\n' "$f" "$(ls -l "$f" | awk '{print $1}')" "$h"
  else
    printf '%s|missing||\n' "$f"
  fi
}

# 캐시 키 계산: staged index tree oid + 검증 스크립트 3종 + hook 자체 record-framed 항목
# git diff --cached concat은 binary 안전성·레코드 경계가 불충분하므로 금지
compute_verify_key() {
  local tree
  tree="$(git write-tree 2>/dev/null)" || return 1
  {
    printf 'tree|%s\n' "$tree"
    local s
    for s in "${verification_scripts[@]}"; do
      _file_record "${scripts_dir}/${s}" || return 1
    done
    _file_record "${BASH_SOURCE[0]}" || return 1
  } | _hash_cmd
}

verify_key="$(compute_verify_key 2>/dev/null || true)"
if [[ -n "$verify_key" && -f "$VERIFY_CACHE" ]]; then
  cached="$(head -1 "$VERIFY_CACHE" 2>/dev/null || true)"
  if [[ "$cached" == "$verify_key" && "$verify_key" =~ ^[0-9a-f]{64}$ ]]; then
    echo "[hooks] staged 내용·검증 스크립트 무변경 (캐시 일치) — 검증 스킵" >&2
    exit 0
  fi
fi

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

# 검증 3종 전부 성공 시에만 캐시 기록 (실패 경로에서는 기록 없음)
[[ -n "$verify_key" ]] && {
  mkdir -p "$(dirname "$VERIFY_CACHE")"
  printf '%s\n' "$verify_key" > "$VERIFY_CACHE"
}

exit 0
