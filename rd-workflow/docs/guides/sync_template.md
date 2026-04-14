# 템플릿 변경사항을 프로젝트에 동기화

이 문서는 Claude가 읽고 실행하는 템플릿 동기화 가이드입니다.

사용자는 프로젝트 디렉토리에서 Claude Code를 열고 아래처럼 말하면 됩니다.

```text
템플릿 최신으로 업데이트해
```

배포 repo URL을 알고 있다면:

```text
이 템플릿으로 업데이트해: <배포 repo URL>
```

---

## Claude가 실행할 절차

### 1. 버전 확인 및 템플릿 소스 확보

먼저 버전 가드 스크립트를 실행합니다.

```bash
bash rd-workflow/scripts/sync_template.sh <배포 repo URL>
```

- 스크립트가 정상 종료(exit 0)하면 마지막 줄에 출력된 임시 clone 경로를 사용합니다.
- 스크립트가 다운그레이드 경고로 중단(exit 1)하면:
  - 사용자에게 "현재 프로젝트의 템플릿이 원격보다 최신입니다. 강제로 다운그레이드하시겠습니까?" 확인
  - 사용자가 동의하면 `--force`를 붙여 재실행
  - 사용자가 거부하면 동기화 중단

배포 repo URL을 모르면 사용자에게 물어봅니다.

동기화 대상은 현재 작업 디렉토리 (프로젝트 루트)입니다.

### 2. 파일 분류

양쪽 디렉토리의 파일 목록을 비교해서 아래 4가지로 분류합니다.

**동기화 대상** — 템플릿 소스에 있고, 프로젝트에도 있고, 내용이 다른 파일:
- `CLAUDE.md`, `WORKING_WITH_AI.md`
- `rd-workflow/claude_skills/`
- `rd-workflow/config/` (설정 예제 파일)
- `rd-workflow/docs/` (adr, flows, guides, prompts, backlog 구조 문서)
- `rd-workflow/scripts/` 중 review pipeline 관련 스크립트

**신규 추가** — 템플릿에 있지만 프로젝트에 없는 파일

**삭제 후보** — 프로젝트에 있지만 템플릿에 없는 파일 중, 프로젝트 작업물이 아닌 것

**보존** — 절대 덮어쓰거나 지우지 않는 파일:
- `PROJECT_CONTEXT.md`
- `REQUEST.md`, `CURRENT_TASK.md` (프로젝트 고유 내용이 있는 경우)
- `rd-workflow-workspace/backlog/FUTURE_REQUESTS.md` (항목이 있는 경우)
- `rd-workflow-workspace/backlog/request-archive/` 안의 아카이브 파일
- `rd-workflow-workspace/specs/`, `rd-workflow-workspace/plans/` 안의 작업 산출물 (README 제외)
- `rd-workflow/scripts/{build,test,lint,typecheck}.sh` (프로젝트별 명령이 들어 있음)
- `rd-workflow-workspace/handoffs/` 안의 작업 내용물
- `rd-workflow/config/review-tools.json` (프로젝트별 리뷰 도구 설정, `.example`은 동기화 대상)
- `rd-workflow/config/verification.json` (프로젝트별 검증 설정, `.example`은 동기화 대상)
- `rd-workflow/config/extensions.json` (설치된 extension 이력, `.example`은 동기화 대상)
- 프로젝트 고유 설정 파일 (`.gitignore`, `.swiftlint.yml`, `.claude/` 등)

### 3. 사용자 확인

분류 결과를 사용자에게 보여주고 확인을 받습니다.

보여줄 내용:
- 내용이 바뀌어서 덮어쓸 파일 목록
- 새로 추가할 파일 목록
- 삭제할 파일 목록 (있다면)
- 보존할 파일 요약

### 4. 구조 마이그레이션 감지

동기화 실행 전에, **clone된 템플릿의** 마이그레이션 목록을 읽고 프로젝트에 적용할 항목이 있는지 확인합니다.

> **중요**: 마이그레이션 목록은 반드시 **clone된 템플릿** 쪽에서 읽습니다. 프로젝트 자체 문서는 구버전일 수 있으므로 참조하지 않습니다.

마이그레이션 파일 위치 (clone 경로 기준):
- `<임시 clone 경로>/rd-workflow/MIGRATIONS.md` (현재 구조)
- `<임시 clone 경로>/ai/MIGRATIONS.md` (구버전 구조 — fallback)

파일이 없으면 마이그레이션이 불필요합니다. 파일이 있으면 각 항목의 **조건**을 프로젝트에 대해 확인하고, 해당하는 항목을 순서대로 실행합니다.

### 5. 동기화 실행

사용자 확인 후:
- 변경된 템플릿 파일을 프로젝트에 복사합니다
- 신규 파일을 추가합니다
- 확인받은 삭제 후보를 제거합니다

### 6. settings.json Hook 머지

`.claude/settings.json`은 보존 대상이므로 5단계에서 덮어쓰지 않습니다. 대신 이 단계에서 템플릿의 새 hook 엔트리를 프로젝트에 머지합니다.

**입력:**
- 템플릿: `<임시 clone 경로>/.claude/settings.json`
- 프로젝트: `.claude/settings.json`

**머지 규칙:**

1. 템플릿 settings.json이 없으면 건너뜁니다.
2. 프로젝트 settings.json이 없으면 템플릿 것을 그대로 복사합니다.
3. 양쪽 모두 있으면 `hooks` 객체를 이벤트별로 머지합니다:

| 이벤트 (SessionStart, PreToolUse 등) | 템플릿 | 프로젝트 | 동작 |
|---|---|---|---|
| 있음 | 있음 | matcher별로 hook command 합집합 (아래 참조) |
| 있음 | 없음 | 템플릿 엔트리 추가 |
| 없음 | 있음 | 프로젝트 엔트리 유지 |

**matcher별 hook command 합집합:**
- matcher가 없는 엔트리 (SessionStart 등): 양쪽의 hooks 배열에서 `command` 문자열이 같으면 중복, 다르면 추가
- matcher가 있는 엔트리 (PreToolUse 등): 같은 matcher 값끼리 hooks 배열의 `command` 합집합. 프로젝트에 없는 matcher는 통째로 추가

4. 머지 결과를 `.claude/settings.json`에 저장합니다.

**보고:**
- 추가된 hook이 있으면: "settings.json에 N개 hook 추가됨: [command 목록]"
- 변경 없으면: "settings.json hook 구성은 변경없음"

### 7. 검증 및 버전 갱신

동기화 후 임시 clone의 템플릿 파일과 프로젝트 파일이 일치하는지 확인합니다. (보존 대상 제외)

원격 템플릿의 VERSION을 프로젝트에 복사합니다 (이미 동기화 과정에서 복사되었다면 건너뜀):

```bash
# 구버전 배포 repo는 ai/VERSION일 수 있음
if [[ -f "<임시 clone 경로>/rd-workflow/VERSION" ]]; then
  cp <임시 clone 경로>/rd-workflow/VERSION rd-workflow/VERSION
elif [[ -f "<임시 clone 경로>/ai/VERSION" ]]; then
  cp <임시 clone 경로>/ai/VERSION rd-workflow/VERSION
fi
```

검증과 버전 갱신이 끝나면 1단계에서 받은 임시 clone 디렉토리를 정리합니다:
```bash
rm -rf <임시 clone 경로의 부모 디렉토리>
```

### 8. Skill 재설치

`rd-workflow/claude_skills/`가 동기화되었으므로 `.claude/skills/`에도 반영합니다.

```bash
bash rd-workflow/scripts/install_claude_skills.sh project
```

- link 모드로 설치된 기존 스킬: 파일 내용은 symlink으로 자동 반영되지만, **새로 추가된 스킬**은 symlink이 없으므로 재설치가 필요합니다.
- copy 모드로 설치된 기존 스킬: 모든 스킬의 재설치가 필요합니다.
- 스크립트가 이미 설치된 스킬은 자동으로 건너뛰므로 항상 실행해도 안전합니다.

**이 단계를 완료한 뒤 반드시 9단계로 진행합니다.**

### 9. Extension 자동 재설치 및 신규 안내

동기화 후 extension 설치 이력(`rd-workflow/config/extensions.json`)을 기반으로 자동 재설치하고, 새 extension만 사용자에게 안내합니다.

#### 9.1 매니페스트 읽기

`rd-workflow/config/extensions.json`을 읽고 파싱합니다.

- 파일 없음 → `manifest = null`
- JSON 파싱 실패 → `manifest = null` (손상된 매니페스트는 부재와 동일하게 처리)

#### 9.1.1 Legacy presets 마이그레이션

manifest에 `extensions.presets`가 있으면 1회 이전을 수행합니다:

**Case A: `extensions.presets.preset` 값이 있고 `extensions.verify`도 있음**
→ `extensions.verify.preset`으로 값 복사 후 `extensions.presets` 키 삭제

**Case B: `extensions.presets.preset` 값이 있지만 `extensions.verify`가 없음 (orphan)**
→ verify가 실제 설치되어 있으면(`rd-workflow/claude_skills/verify/SKILL.md` 존재) `extensions.verify` object를 생성(`installed_at: now`)하고 preset을 이전 후 `extensions.presets` 키 삭제
→ verify가 미설치면 `extensions.presets` 키를 삭제하고 `new_extensions`로 내려 사용자에게 verify + preset 설치를 질문

**Case C: `extensions.presets`는 있지만 `preset` 값이 없음**
→ `extensions.presets` 키를 삭제. preset 선택은 질문하지 않음

**Invalid preset validation:**
모든 Case에서 preset 값이 허용 목록(`react-web`, `api`, `cli`, `ios`, `macos`) 밖이면 해당 키를 삭제하고 사용자에게 preset 선택을 질문합니다.

**파일시스템 마이그레이션:**
프로젝트에 `rd-workflow/extensions/presets/`가 남아 있으면 `rd-workflow/extensions/verify/presets/`로 통합된 구버전 잔재이므로 삭제합니다. 삭제 전 별도 질문 없이 진행하되, 완료 보고에 "presets → verify/presets 통합으로 구 폴더 삭제됨"을 포함합니다.

이전 결과는 메모리에 보관 (9.8에서 저장)

#### 9.2 파일시스템 상태 스캔

`rd-workflow/extensions/` 내 각 extension 디렉토리에 대해 설치 여부를 확인합니다.

설치 판정 기준 (extension별로 다름):
- **verify, design-review**: `rd-workflow/claude_skills/{name}/SKILL.md`가 존재하면 설치됨. 디렉토리만 있고 SKILL.md가 없으면 미설치.

두 집합을 구성합니다:
- `fs_installed`: 위 판정 기준에 따라 설치된 것으로 확인된 extension
- `fs_available`: `rd-workflow/extensions/` 내 모든 extension 디렉토리

#### 9.3 매니페스트-파일시스템 조정

`manifest != null`일 때만 실행합니다.

**파일시스템 판정 가능 extension (verify, design-review):**

| manifest | filesystem | 동작 |
|----------|-----------|------|
| 있음 | 설치됨 | 유지 (자동 재설치 대상) |
| 있음 | 미설치 | manifest에서 제거 (삭제/손상된 것으로 판단) |
| 없음 | 설치됨 | manifest에 추가 (`installed_at: now`) |

조정 결과는 메모리에 보관합니다 (파일 저장은 9.8에서 한 번만).

#### 9.4 분류

- `manifest != null`: `auto_reinstall` = manifest에 있는 extension, `new_extensions` = `fs_available` 중 manifest에도 `fs_installed`에도 없는 것
- `manifest == null`: `fs_installed`에 있는 extension은 `auto_reinstall`로, 나머지는 `new_extensions`로 분류합니다. 매니페스트가 없어도 이미 설치된 extension에 대해서는 불필요한 질문을 하지 않습니다.

#### 9.5 자동 재설치

`auto_reinstall`에 속한 extension을 **묻지 않고** 재설치합니다.

- **verify, design-review**: `rd-workflow/extensions/{name}/SKILL.md`와 `rules.md`를 `rd-workflow/claude_skills/{name}/`에 복사 (덮어쓰기)
- **verify의 preset 머지**: manifest에 `verify.preset` 값이 있고 허용 목록 내이면 8.6 머지 알고리즘 실행. 값이 허용 목록 밖이면 키를 삭제하고 사용자에게 질문. 값이 없으면 머지를 건너뛰고 조용히 유지 (preset 없는 verify는 정상 상태이므로 질문하지 않음)

자동 재설치 실패 시: 해당 extension을 manifest에서 제거하고 `new_extensions`로 이동하여 8.7에서 사용자에게 질문합니다.

각 성공한 extension의 `installed_at`을 현재 시각으로 갱신합니다 (메모리).

#### 9.6 Verify Preset AI 자동 머지

manifest의 `verify.preset` 값이 기록되어 있을 때 실행합니다.

**입력:**
- template preset: `rd-workflow/extensions/verify/presets/{manifest.verify.preset}/verification.json`
- project current: `rd-workflow/config/verification.json`

**머지 규칙 (2-way):**

각 verifier를 name 기준으로 비교합니다:

| template | project | 결과 |
|----------|---------|------|
| 있음 | 있음 | **구조적 머지** (아래 참조) |
| 있음 | 없음 | template에서 추가 |
| 없음 | 있음 | **프로젝트 고유 항목 — 유지** |

**구조적 머지 (양쪽 모두 있는 verifier):**
- `run`: template 값 사용 (CLI 플래그, 버그 수정 반영)
- `adapter`: template 값 사용 (경로 변경 반영)
- `evaluate`: project 값 유지 (사용자 커스텀 보존)
- `criteria`: name 기준 머지
  - project에 있고 template에도 있는 name → project 값 유지 (커스텀 weight/description 보존)
  - template에만 있는 name → 추가
  - project에만 있는 name → template에서 삭제된 것으로 판단, 제거

머지 결과를 `rd-workflow/config/verification.json`에 저장합니다.

**머지 요약을 기록합니다** (10단계 완료 보고에 포함):
- 추가된 verifier
- 보존된 프로젝트 고유 verifier
- 구조 업데이트된 verifier (run/adapter 변경)
- 추가/제거된 criteria

#### 9.7 새 Extension 질문

`new_extensions`가 있을 때만 실행합니다.

프로젝트에 아직 설치되지 않은 extension을 사용자에게 안내합니다:

```
새로운 확장 기능이 감지되었습니다:
1. {name} — {설명}
...

설치할 확장을 선택하세요 (예: 1,2 또는 건너뛰기):
```

사용자가 선택하면 해당 extension의 `rd-workflow/extensions/{name}/install.md`를 읽고 안내에 따라 설치합니다.
`depends`가 있으면 먼저 설치할지 물어봅니다.

설치 성공한 extension을 manifest에 추가합니다 (메모리). 거절한 extension은 추가하지 않습니다 (다음 sync에서 다시 질문).

#### 9.8 매니페스트 저장

최종 manifest를 `rd-workflow/config/extensions.json`에 저장합니다.

- manifest가 null이었고 사용자가 모든 extension을 건너뛰어도, `fs_installed` 기준으로 manifest를 생성합니다 (다음 sync에서 다시 묻지 않도록)
- 이 시점에서 1회만 파일에 기록합니다 (중간 저장 없음)

### 10. 완료 보고

- 복사/추가/삭제된 파일 수
- 마이그레이션 실행 여부와 결과
- 보존된 파일 요약
- settings.json Hook 머지 결과 (추가된 hook 수, 또는 변경없음)
- Skill 재설치 결과 (설치/건너뛴 수)
- Extension 자동 재설치 결과 (자동 재설치/신규 설치/건너뛴 수)
- Verify Preset 머지 결과 요약 (추가/보존/업데이트된 verifier, 변경된 criteria) — verify preset이 자동 재설치된 경우에만
