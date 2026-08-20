#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../.." && pwd)"

limit="${CLAUDEMD_LINE_LIMIT:-200}"

# 검사 대상은 둘입니다.
#
#   REQUIRED  <root>/CLAUDE.md              — 이 프로젝트가 실제로 쓰는 파일
#   OPTIONAL  <root>/_ROOT_FILES/CLAUDE.md  — 배포될 템플릿 정본 (이 저장소에만 존재)
#
# **정본을 함께 재는 이유**: 이 검사기는 원래 `<root>/CLAUDE.md` 만 봤습니다. 그런데 이
# 저장소에서 배포되는 것은 `_ROOT_FILES/CLAUDE.md` 이므로, 정본이 제한을 넘겨도 dev
# self_test 는 통과하고 **소비 프로젝트에서만 터졌습니다.** 그 지점이 우회 밸브가 없는
# 아카이브 게이트라, 소비 프로젝트가 자기 작업을 마감할 수 없는 상태로 발행됐습니다.
# (실제 발생: self-test-runtime-reduction 이 199→204줄로 늘렸는데 이 저장소 full 은 전부 PASS)
#
# 미러(`rd-workflow/scripts/`)에서 실행되면 `project_root` 가 저장소 루트이므로 두 파일이
# 모두 잡힙니다. 정본 트리에서 직접 실행하면 `project_root` 가 `_ROOT_FILES` 이고 REQUIRED
# 가 곧 정본 파일이며 OPTIONAL 은 부재입니다. 소비 프로젝트에는 `_ROOT_FILES` 가 없으므로
# REQUIRED 하나만 잡힙니다 — 어느 형상에서도 "재야 할 파일을 빠뜨리지 않는" 배치입니다.
#
# **REQUIRED 는 부재 시 rc=1 입니다.** 예전에는 부재를 안내만 하고 `exit 0` 이었는데, 그것은
# 이름만 필수이고 동작은 fail-open 이라 "검사했다" 는 신호를 거짓으로 만듭니다.
# (lite 산출물은 `rules.conf` 의 `[lite-exclude]` 로 이 스크립트 자체가 빠지므로 영향 없음)

rc=0
reasons=""

_add_reason() {
  if [[ -n "$reasons" ]]; then reasons="${reasons}
  - $1"; else reasons="  - $1"; fi
}

_measure() {
  local kind="$1" path="$2" label="$3" line_count
  if [[ ! -f "$path" ]]; then
    if [[ "$kind" == "REQUIRED" ]]; then
      echo "[claudemd-guard] ${label}: 파일 없음 — ${path}" >&2
      _add_reason "${label} 부재 (REQUIRED): ${path}"
      rc=1
    else
      echo "[claudemd-guard] ${label}: 없음 (선택 대상 — 이 형상에서는 정상)"
    fi
    return 0
  fi
  line_count="$(wc -l < "$path" | tr -d '[:space:]')"
  if [[ "$line_count" -gt "$limit" ]]; then
    echo "[claudemd-guard] ${label}: ${line_count}줄 — 초과 (제한 ${limit}줄)" >&2
    _add_reason "${label} ${line_count}줄 > 제한 ${limit}줄: ${path}"
    rc=1
  else
    echo "[claudemd-guard] ${label}: ${line_count}줄 (제한 ${limit}줄 이내)"
  fi
  return 0
}

_measure REQUIRED "${project_root}/CLAUDE.md"               "프로젝트 CLAUDE.md"
_measure OPTIONAL "${project_root}/_ROOT_FILES/CLAUDE.md"   "배포 정본 CLAUDE.md"

if [[ "$rc" -ne 0 ]]; then
  echo "[claudemd-guard] 실패 이유:" >&2
  echo "$reasons" >&2
  echo "[claudemd-guard] 각 줄에 대해 '이 줄을 삭제해도 실수가 발생하는가?' 테스트를 적용하세요." >&2
  exit 1
fi

exit 0
