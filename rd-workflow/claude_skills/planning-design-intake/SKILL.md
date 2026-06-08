---
name: planning-design-intake
description: Convert planning document text into REQUEST.md. Use when the user has external planning docs (from Notion, Confluence, etc.) to convert into a structured REQUEST. v1 requires pasted planning text; design references (Figma URLs, screenshots) are optional.
disable-model-invocation: true
---

# Planning Design Intake

기획서 텍스트를 REQUEST.md로 변환한다. (v1: 기획서 텍스트 필수, 디자인 레퍼런스는 선택)

Typical user requests:
- "기획서 붙여넣을게, REQUEST로 만들어줘"
- "이 기획서로 intake 진행해줘"
- "디자인이랑 기획서 있어, REQUEST 만들어줘"

Read these first (Always Read files are already loaded):
- `PROJECT_CONTEXT.md`의 `## Intake Settings` (있으면)

## v1 범위

- 입력: 사용자가 붙여넣은 기획서 텍스트만 처리
- URL/API/PDF 직접 호출 없음
- 디자인: 사용자가 직접 제공한 URL/스크린샷 참조만. Figma API 호출 없음

## 기존 REQUEST.md 처리 — overwrite-backup (implicit archive)

**실행 시점: 사용자 입력(기획서 텍스트)을 받은 후, short-title 부여 전에 실행한다.**
(skill 진입 직후가 아님 — 사용자가 입력을 주기 전에 기존 REQUEST 를 silent archive 하는 eager archive 방지)

### 분기 1a: REQUEST.md 존재 + `CURRENT_TASK.md ## Short Title` = non-`-` (정상 happy path)

- `CURRENT_TASK.md ## Short Title` 에서 `SHORT_TITLE` 변수를 read
- 기존 REQUEST.md 를 collision-safe 백업:
  ```bash
  # assert_no_symlink_in_path: POSIX dirname 반복으로 절대경로 component 단위 traverse
  # bash/sh/zsh/dash 호환 — local 미사용, IFS split 의존 안 함
  assert_no_symlink_in_path() {
    _aslnp_p="$1"
    case "$_aslnp_p" in
      /*) ;;
      *)  _aslnp_p="$PWD/$_aslnp_p" ;;
    esac
    _aslnp_d="$_aslnp_p"
    while [ "$_aslnp_d" != "/" ] && [ -n "$_aslnp_d" ]; do
      if [ -L "$_aslnp_d" ]; then
        echo "경고: path component ($_aslnp_d) 가 symlink 입니다. 보안상 중단합니다." >&2
        unset _aslnp_p _aslnp_d
        return 1
      fi
      _aslnp_d=$(dirname "$_aslnp_d")
    done
    unset _aslnp_p _aslnp_d
    return 0
  }

  # collision-safe: BASE immutable + DEST 매 iter 재계산
  # SHORT_TITLE 은 CURRENT_TASK.md ## Short Title 에서 read (canonical 검증된 값)
  BASE="rd-workflow-workspace/backlog/request-archive/{date-time}-${SHORT_TITLE}.md"
  DEST="$BASE"

  # 조상 경로 symlink escape 방어
  assert_no_symlink_in_path "$(dirname "$DEST")" || exit 1

  N=2
  while [ -e "$DEST" ] || [ -L "$DEST" ]; do
    DEST="${BASE%.md}-${N}.md"
    N=$((N+1))
  done
  # DEST 자체가 symlink 면 거부
  if [ -L "$DEST" ]; then
    echo "경고: archive 대상 ($DEST) 이 symlink 입니다. 보안상 중단합니다." >&2
    exit 1
  fi
  cp REQUEST.md "$DEST"
  ```
- 같은 short-title 의 `request`/`spec`/`plan` stage 캡처를 frontmatter exact match 로 `raw-captures/archive/` 로 이동:
  ```bash
  archive_dir="rd-workflow-workspace/raw-captures/archive"
  parent_dir="rd-workflow-workspace/raw-captures"

  # 조상 경로 symlink escape 방어
  assert_no_symlink_in_path "$archive_dir" || exit 1

  # 디렉토리 생성 + 권한 hardening (기존 0755 보정 포함)
  mkdir -p "$archive_dir"
  chmod 0700 "$parent_dir"
  chmod 0700 "$archive_dir"

  for STAGE in request spec plan; do
    find rd-workflow-workspace/raw-captures -maxdepth 1 -type f -name "*-${STAGE}-*.md" 2>/dev/null \
      | while IFS= read -r f; do
          if awk -v t="${SHORT_TITLE}" -v s="${STAGE}" '
              BEGIN{c=0; st=0; sg=0}
              /^---$/{c++; if(c==2)exit}
              c==1 && $0=="short-title: " t {st=1}
              c==1 && $0=="stage: " s {sg=1}
              END{exit !(st && sg)}
            ' "$f"; then
            mv "$f" "$archive_dir/"
          fi
        done
  done
  ```
- `CURRENT_TASK.md ## Short Title` 을 default `-` 로 reset
- 사용자에게 한 줄 알림: "기존 REQUEST `{old-title}` 을 archive 했습니다 — 캡처 N 건 이동, short-title reset"
- 이후 새 REQUEST 작성 단계 진행 — `## Short Title` 이 `-` 이므로 baseline 분기로 새 short-title 부여

### 분기 1b: REQUEST.md 존재 + `## Short Title` = `-` 또는 부재 (drift 상태)

archive key 가 없으므로 캡처 매칭 불가:
- REQUEST.md 백업은 collision-safe 로 정상 진행:
  ```bash
  # collision-safe: BASE immutable + DEST 매 iter 재계산
  # orphan 은 path-safe 고정 문자열
  BASE="rd-workflow-workspace/backlog/request-archive/{date-time}-orphan.md"
  DEST="$BASE"

  # 조상 경로 symlink escape 방어
  assert_no_symlink_in_path "$(dirname "$DEST")" || exit 1

  N=2
  while [ -e "$DEST" ] || [ -L "$DEST" ]; do
    DEST="${BASE%.md}-${N}.md"
    N=$((N+1))
  done
  # DEST 자체가 symlink 면 거부
  if [ -L "$DEST" ]; then
    echo "경고: archive 대상 ($DEST) 이 symlink 입니다. 보안상 중단합니다." >&2
    exit 1
  fi
  cp REQUEST.md "$DEST"
  ```
- **캡처 archive 는 skip** (short-title 모름)
- 사용자에게 명시적 경고:
  > 경고: `CURRENT_TASK.md ## Short Title` 이 비어 있어 raw capture archive 매칭을 skip 했습니다.
  > `rd-workflow-workspace/raw-captures/` 디렉토리에서 미archive 된 이전 작업 캡처를 수동으로 정리하세요.
- `## Short Title` 은 이미 `-`/부재이므로 reset 불필요
- baseline 분기 진행

## 실행 흐름

### 1. 기획서 텍스트 요청

사용자가 기획서 텍스트를 이미 붙여넣었으면 바로 2단계로 간다.
아직 없으면 요청한다:

> "기획서 텍스트를 붙여넣어 주세요. (v1은 텍스트 붙여넣기만 지원합니다)"

**사용자 입력(기획서 텍스트)을 받은 직후** → overwrite-backup (분기 1a / 1b) 수행 후 2단계로 진행.

### 2. short-title 부여 (equality-aware 3-way)

사용자 입력 / REQUEST 후보 제목에서 short-title 후보 추론 → `CANDIDATE`

canonical 정규화: `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$` (영문 kebab-case, 영숫자 시작·끝, 사이만 `-` 허용)

추가 거절 케이스: `-` 단독, empty, hyphen-only (`---` 등) — reserved sentinel 충돌이므로 보정 요청.

위반 시 1줄 보정 요청:
> "short-title 후보: `{CANDIDATE}`. 이대로 진행할까요? (`^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`, `-` 단독 금지)"

확정 후 현재 `## Short Title` 값 read → `CURRENT_TITLE` 변수

- **legacy 케이스 (`## Short Title` 섹션 자체가 부재):** `## Task` 다음에 `## Short Title\n{CANDIDATE}\n` 섹션을 자동 추가 + 사용자 알림 ("legacy 템플릿이므로 `## Short Title` 섹션을 추가했습니다 — sync_template 마이그레이션 권장") → 그 후 baseline 분기 (a) 와 동일하게 진행. (`/fr add` 와 다름 — `planning-design-intake` 는 명시적 새 작업 시작 진입점이라 자동 추가 안전)

**3-way 분기 (섹션이 있는 경우):**

- **(a) `CURRENT_TITLE = -` → `CANDIDATE` 를 `CURRENT_TASK.md ## Short Title` 에 기록 (baseline)**
- **(b) `CURRENT_TITLE = CANDIDATE` (equal) → read-only continue.** `CURRENT_TASK` 변경 없음 (이미 같은 값)
- **(c) `CURRENT_TITLE ≠ CANDIDATE` AND ≠ `-` → Status-aware guard.** `CURRENT_TASK.md`의 `## Status` 값 read → `CURRENT_STATUS` (`## Status` heading 다음부터 다음 `## ` heading 직전까지에서 첫 비어있지 않은 줄. 다음 `## ` heading을 먼저 만나거나 그 범위가 공백뿐이면 값 없음 = 파싱 불가).
  - **(c-1) `## Status` 섹션 부재 또는 위 read 규칙으로 값 없음(파싱 불가) → 보수적 차단:**
    > `CURRENT_TASK.md ## Status` 가 없거나 파싱할 수 없습니다. 유효한 Status 를 설정하거나 `sync_template` 마이그레이션 후 다시 진입하세요. (active-task guard 는 상태를 확정할 수 없어 보수적으로 차단합니다.)
  - **(c-2) `CURRENT_STATUS = 대기 중` → stale Short Title:** 차단하지 않는다. `CANDIDATE` 를 `CURRENT_TASK.md ## Short Title` 에 기록(baseline)하고 다음 알림 후 진행:
    > 이전 Short Title (`${CURRENT_TITLE}`) 이 `Status = 대기 중` 인 stale 값이라 새 작업 (`${CANDIDATE}`) 으로 교체하고 진행합니다.
  - **(c-3) `CURRENT_STATUS` 가 읽혔고 `대기 중` 이 아님 (`완료` 포함) → active-task guard.** 명시 경고 + skill 진행 차단:
    > 다른 작업 (`${CURRENT_TITLE}`) 이 진행 중입니다. 새 작업 (`${CANDIDATE}`) 을 시작하려면 현재 작업을 archive 한 뒤 다시 진입하세요.

비고: REQUEST.md 가 있는 overwrite-backup 케이스는 분기 1 에서 implicit archive 후 `## Short Title = -` 이 되므로 (c) 도달 안 함.

### 3. REQUEST.md 신규 생성 직전 raw capture

- 경로: `rd-workflow-workspace/raw-captures/{date}-request-{short-title}.md`
- 디렉토리 0700 보장 + umask 077 subshell 로 캡처 파일 0600 보장:
  ```bash
  if ! assert_no_symlink_in_path "rd-workflow-workspace/raw-captures"; then
    echo "경고: raw-captures 경로에 symlink 가 있어 캡처를 건너뜁니다." >&2
  else
    mkdir -p rd-workflow-workspace/raw-captures
    chmod 0700 rd-workflow-workspace/raw-captures
    ( umask 077 && cat > "$capture_path" <<EOF
  ---
  date: YYYY-MM-DD HH:MM
  stage: request
  short-title: {short-title}
  source: direct | routed
  ---

  ## 원본 입력
  {사용자 입력 원문}
  EOF
    )
  fi
  ```
- frontmatter 4 필드: `date`, `stage`, `short-title`, `source` (`direct` | `routed`)
- 본문: `## 원본 입력` 섹션 + 사용자 입력 원문 (byte-level 동일, 가공 금지)
- 충돌 시 `-2`, `-3` suffix
- 캡처 실패 시 경고만 (REQUEST 작성 차단 안 함)
- 원문 접근 불가 (routed) 시 캡처 생략 + 경고

### 4. REQUEST.md 필드 매핑

기획서 텍스트를 분석하여 REQUEST.md 필드를 채운다:

| REQUEST 필드 | 기획서에서 추출 |
|---|---|
| Task Type | new feature / existing-code-change (추론) |
| Execution Path | Task Type 기반 자동 설정 |
| User Goal | 기획서의 목적/배경 |
| Change Description | 기능 요구사항 목록 |
| Constraints | 제약 조건, 비기능 요구사항 |
| Acceptance Criteria | 완료 조건, QA 기준 |
| Risks | 리스크, 의존성 |
| Affected Area | 영향 범위 (추론) |
| Platform | PROJECT_CONTEXT.md 참조 |

### 5. 빈 필드 알림 + 신뢰도 판단

한 번에 변환한 뒤, 못 채운 필드를 목록으로 제시한다:

> "다음 필드를 기획서에서 찾지 못했습니다:
> - Constraints
> - Risks
>
> 보충해주시거나, '그대로 진행'이라고 하시면 빈 채로 REQUEST를 생성합니다."

6개 필드(User Goal, Change Description, Constraints, Acceptance Criteria, Risks, Affected Area) 중 3개 이상 비어있으면 `low-confidence` 경고:

> "⚠ 기획서 정보가 부족합니다 (6개 필드 중 N개 미채움). 추가 입력을 권장합니다. 그대로 진행하시겠습니까?"

### 6. 디자인 레퍼런스

기획서 변환 후 디자인 레퍼런스를 묻는다:

> "디자인 레퍼런스(피그마 URL, 스크린샷 등)가 있으면 공유해주세요. 없으면 '없음'이라고 해주세요."

디자인이 있으면 REQUEST.md 하단에 `## Design Reference Memo` 섹션을 추가한다:

```markdown
## Design Reference Memo

> spec 작성 시 `## Design Reference` 섹션으로 옮길 참고 자료

- [피그마 URL / 스크린샷 경로 / 설명]
```

### 7. REQUEST.md 저장

REQUEST.md를 저장하고 안내한다:

> "REQUEST.md 생성 완료. 다음: `/request-to-reviewed-plan`으로 REQUEST review부터 시작하세요."

## 규칙

- 기획서 원본을 직접 수정하지 않는다
- REQUEST.md 범위를 기획서 이상으로 넓히지 않는다
- Platform은 PROJECT_CONTEXT.md에서 가져온다. 없으면 빈 필드 목록에 포함
- `## Design Reference` 형식은 기존 design-review extension 계약을 따른다 (`rd-workflow/extensions/design-review/rules.md` 참조)
- `## Design Reference Memo`가 있으면 안내에 포함: "spec 작성 시 이 메모를 `## Design Reference` 섹션으로 옮겨주세요"
