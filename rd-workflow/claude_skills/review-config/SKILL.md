---
name: review-config
description: >
  Configure review tools (priority, binary path) and reviewer model·effort (models.json).
  Use when the user says "/review-config", "리뷰 도구 설정", "review tool 설정", or wants to change review pipeline tool configuration.
user-invocable: true
---

# review-config — 리뷰 도구 설정

Typical user requests:
- "/review-config" → 현재 상태 출력 + setup 안내
- "/review-config setup" → 대화형 설정
- "리뷰 도구 설정해줘" → setup 실행
- "리뷰 도구 우선순위 바꿔줘" → setup 실행
- "리뷰 모델 바꿔줘" → setup 실행
- "codex effort high 로 바꿔줘" → [한 칸만 바꾸기](#set)

## rd-workflow 버전 대조

이 skill 은 아래 `RD_SKILL_BASE` 보다 나중에 배포된 rd-workflow 를 전제한다. 첫 작업 단계보다 먼저, 프로젝트 루트에서 아래 명령을 이 호출에서 한 번 실행한다.

- 출력이 없으면 그대로 진행한다.
- 출력이 있으면 출력 전문을 사용자에게 알리고, 템플릿을 sync 할지 그대로 계속할지 묻고 멈춘다. 사용자가 계속을 지시하면 진행한다.
- autopilot·무인 실행처럼 물을 사람이 없으면 계속하지 않고 그 출력을 중단 사유로 보고한다.

```bash
bash -s <<'RD_SKILL_COMPAT'
RD_SKILL_BASE=2026-11-21-001711 RD_SKILL_NAME=review-config
vf="rd-workflow/VERSION"
if [ ! -f "$vf" ] && [ -f "_ROOT_FILES/rd-workflow/VERSION" ]; then exit 0; fi
v=""; [ -f "$vf" ] && v="$(cat "$vf")"; v="${v#lite-}"
if [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ ]] && [[ "$v" > "$RD_SKILL_BASE" ]]; then exit 0; fi
echo "rd-workflow 버전 불일치 — skill '$RD_SKILL_NAME' 은 $RD_SKILL_BASE 보다 나중에 배포된 rd-workflow 가 필요합니다."
echo "프로젝트: $PWD"
echo "프로젝트 VERSION: ${v:-없음} (파일: $vf)"
echo "이 상태로 진행하면 skill 이 가리키는 문서 절·스크립트·인자가 없어 중간에 실패할 수 있습니다."
echo "해결: 템플릿을 sync 하십시오 (/tpl update 또는 rd-workflow/docs/guides/sync_template.md 절차)."
RD_SKILL_COMPAT
```

## 서브커맨드 라우팅

첫 번째 인자를 파싱한다:

- `setup` → [대화형 설정](#setup) 섹션으로
- 사용자가 모델·effort 칸 하나와 값을 함께 말함 → [모델·effort 한 칸만 바꾸기](#set) 섹션으로
- 인자 없음 또는 그 외 → [상태 출력](#status) 섹션으로

### 사용법 출력

인자가 `help`이면 아래를 출력하고 종료:

```
/review-config 사용법:
- `/review-config` — 현재 설정 + 설치된 도구 확인
- `/review-config setup` — 대화형 설정

예: `/review-config setup`
```

---

## 상태 출력 {#status}

설정은 두 파일로 나뉜다.

- `rd-workflow/config/review-tools.json`: 도구 우선순위, `bin`, Claude self-review 정책, 리뷰 종류별 priority.
- `rd-workflow/config/models.json`: Claude·Codex 리뷰어의 모델·effort. 이 skill 은 모델·effort 를 `model_select.sh show review` 출력 한 곳에서만 보인다.

아래 순서로 실행한다:

### 1. 설치된 도구 감지

리뷰 도구는 이 설치에 어댑터(`rd-workflow/scripts/adapter_<도구>.sh`)가 있는 도구다. 배포 기본은 codex·claude 이고, `docs/guides/adapter-interface.md` 절차로 직접 추가한 어댑터도 포함한다. Bash로 도구 목록과 각 도구의 설치 여부를 확인한다. 설치 여부는 리뷰 실행기와 같이 `tools.<도구>.bin` 이 있으면 그 경로로, 없으면 도구 이름으로 판정한다:

```bash
cfg="${REVIEW_TOOLS_CONFIG:-rd-workflow/config/review-tools.json}"
for t in $(ls rd-workflow/scripts/adapter_*.sh 2>/dev/null | sed 's#.*/adapter_##; s#\.sh$##'); do
  b="$(jq -r --arg t "$t" '.tools[$t].bin // empty' "$cfg" 2>/dev/null)"
  command -v "${b:-$t}" &>/dev/null && echo "$t: ✓" || echo "$t: ✗"
done
```

### 2. review-tools.json 출력

리뷰 실행기와 같은 파일을 읽는다. 환경 변수 `REVIEW_TOOLS_CONFIG` 가 있으면 그 경로, 없으면 `rd-workflow/config/review-tools.json` 이다. 프로젝트 루트에서 아래로 경로를 정하고, 출력 첫 줄에 그 경로를 보인다.

```bash
echo "${REVIEW_TOOLS_CONFIG:-rd-workflow/config/review-tools.json}"
```

그 파일이 있으면 읽어서 이 파일이 맡는 항목만 출력한다: `default_priority`, `tools.<도구>.bin`, `tools.claude.self_review_policy`·`self_review_warning`, `overrides.<종류>.priority`. `overrides.<종류>.priority` 가 `null` 이면 리뷰 실행기가 기본 우선순위를 쓰므로 「<종류> priority: 기본 우선순위 사용」 으로 출력한다.
없으면 "review-tools.json 없음(<경로>). `/review-config setup`으로 생성하세요."를 출력한다.

옛 모델·effort 키(`tools.claude.model`, `tools.codex.reasoning_effort`, `tools.codex.small_task_reasoning_effort`, `overrides.<종류>.tools.codex.reasoning_effort`)는 이 절에 보이지 않는다. 그 값은 3단계 표에 `review-tools.json (옛 키)` 출처로 나온다.

`default_priority` 와 `overrides.<종류>.priority` 의 도구마다 1단계 도구 목록(어댑터가 있는 도구)에 있는지 본다. 없는 도구(예: 예전 예시의 `gemini`)는 우선순위 줄 아래에 도구마다 한 줄로 경고한다: 「⚠️ <도구>: 이 설치에 리뷰 어댑터가 없어 리뷰 턴이 건너뜁니다. 리뷰 도구는 <1단계 도구 목록> 입니다. 우선순위에서 빼려면 /review-config setup」.

### 3. 모델·effort 출력

프로젝트 루트에서 아래를 실행하고 출력을 그대로 보인다. 칸마다 `값 — 출처`(`models.json` / `review-tools.json (옛 키)` / `미설정`)가 나오고, 마지막 줄이 kill switch 상태다.

```bash
bash rd-workflow/scripts/model_select.sh show review
```

`미설정` 칸은 리뷰 턴이 값을 넘기지 않는다는 뜻이다(Codex: `~/.codex/config.toml`, Claude: CLI 기본값). 환경 변수 `RD_REVIEW_*_MODEL`·`RD_REVIEW_*_EFFORT` 덮어쓰기는 이 표에 보이지 않고 리뷰 턴의 실행 줄에 보인다.

### 4. 출력 형식

```
리뷰 도구 상태:
  codex:  ✓ 설치됨
  claude: ✓ 설치됨

review-tools.json (rd-workflow/config/review-tools.json):
  priority: codex → claude
  codex:  bin=기본
  claude: bin=기본, self_review_policy=block
  diff-review priority: codex

모델·effort (model_select.sh show review):
  <show review 출력 그대로>

설정을 변경하려면: /review-config setup
```

종료.

---

## 모델·effort 한 칸만 바꾸기 {#set}

사용자가 칸 하나만 바꾸라고 하면(예: "codex effort high 로 바꿔줘") setup 을 거치지 않고 `model_select.sh set <칸> <값>` 으로 `models.json` 에 쓴다. 옛 `review-tools.json` 키를 새로 쓰지 않는다.

- 칸: `review.codex.model`·`review.codex.effort`·`review.codex.small_task_effort`·`review.codex.review_types.<종류>.effort`·`review.claude.model`·`review.claude.effort`
- 값: `null` 은 칸 비우기(옛 설정을 따름), `default` 는 넘기지 않음(CLI 기본값). 그 밖의 값은 아래 setup 의 선택지 값이다.

예 (Codex effort 기본값을 `high` 로):

```bash
# rd:review-config-write
bash rd-workflow/scripts/model_select.sh set review.codex.effort high
```

rc 가 0 이 아니면 출력의 경고를 그대로 보이고 멈춘다. 성공하면 상태 출력의 3단계 명령으로 결과를 보인다.

---

## 대화형 설정 {#setup}

아래 순서로 실행한다. AskUserQuestion 도구를 사용하여 대화형으로 진행한다. 답은 모두 저장 목록에 모았다가 마지막에 한 번에 저장한다.

### 1. 도구 감지

상태 출력의 1단계를 실행해 도구 목록(어댑터가 있는 도구)과 설치 여부를 구한다.
설치된 도구 목록을 `detected_tools`로 저장한다.

### 2. 기존 설정 확인

상태 출력의 2·3단계를 실행해 현재 값을 파악한다. 질문마다 현재 값을 함께 보인다.

2단계가 어댑터 없는 도구를 경고했으면 그 경고를 다시 보이고, 이번 저장에서 그 도구를 우선순위에서 뺀다고 알린다.

- 기본 우선순위는 4단계에서 새로 저장하므로 빠진다. 어댑터가 있는 도구는 3단계 선택지에 남으므로 사용자가 유지·제거를 고른다.
- `overrides.<종류>.priority` 에 있으면 그 도구를 뺀 목록을 `legacy overrides.<종류>.priority [...]` 줄로 저장 목록에 더한다. 빼고 남는 도구가 없으면 `legacy overrides.<종류>.priority null` 을 더한다. `null` 인 칸은 리뷰 실행기가 기본 우선순위를 따르므로 나중에 기본 우선순위를 바꿔도 함께 바뀐다. 같은 종류의 다른 칸은 그대로 남는다.
- `tools.<도구>.bin`·`tools.<도구>.model` 같은 남은 칸은 읽는 곳이 없으므로 건드리지 않는다.

### 3. 사용할 도구 선택

AskUserQuestion으로 사용할 도구를 물어본다 (multiSelect). 선택지는 1단계 도구 목록이다:
- 설치된 도구는 선택지로 표시 (설치됨 표기)
- 미설치 도구도 선택지에 포함 (미설치 경고 표기, 나중에 설치할 수 있으므로)
- 지금 `default_priority` 에 있는 도구는 「현재 사용 중」 을 함께 표기한다

### 4. 우선순위 설정

선택된 도구가 2개 이상이면 AskUserQuestion으로 우선순위를 물어본다.
선택지는 자주 쓰는 조합을 미리 구성한다:

예시 (codex, claude 모두 선택 시):
- `codex → claude` (Recommended) — codex 독립 리뷰, claude fallback(self-review 정책 적용)
- `claude → codex` — claude 우선

직접 추가한 어댑터를 함께 고르면 같은 방식으로 조합을 만든다. 도구가 1개면 묻지 않고 그 도구 하나를 우선순위로 쓴다.

정한 순서는 도구 수와 상관없이 늘 저장 목록에 `legacy default_priority [...]` 한 줄로 쓴다(예: Claude 만 고르면 `legacy default_priority ["claude"]`). 이 줄을 빼면 리뷰 실행기는 `review-tools.json` 의 기존 값이나 기본값 `codex → claude` 를 쓴다.

### 5. 모델·effort 질문

선택한 도구마다 아래 칸을 하나씩 묻는다. Claude·Codex 칸에는 항상 아래 두 선택지를 둔다.

| 선택지 | 저장 값 | 뜻 |
|---|---|---|
| `CLI 기본값 (넘기지 않음)` | `default` | 이 칸에서 값을 넘기지 않는다. 옛 `review-tools.json` 키로 내려가지 않는다 |
| `옛 설정을 따름(이 칸 비우기)` | `null` | `models.json` 칸을 비운다. 옛 `review-tools.json` 키가 있으면 그 값을, 없으면 CLI 기본값을 쓴다 |

질문과 그 밖의 선택지:

- Claude 모델 (`review.claude.model`): `opus`·`sonnet`·`haiku`·`fable`. 별칭을 권한다. "Other"로 `claude-…` 고정 이름을 받으면 그대로 쓰되 「고정 이름은 낡을 수 있음」 을 알린다.
- Claude effort (`review.claude.effort`): `low`·`medium`·`high`·`xhigh`·`max`.
- Codex 모델 (`review.codex.model`): 계열 이름(예: `sol`). `~/.codex/models_cache.json` 에서 그 계열의 최신 모델을 고른다. "Other"로 `gpt-6.2-sol` 같은 고정 이름도 받는다.
- Codex effort 기본값 (`review.codex.effort`): `medium`·`high`·`xhigh`·`max`·`ultra`·`highest`. 모델이 지원하지 않는 단계는 리뷰 턴이 바로 아래 지원 단계로 낮추고 경고한다.
- Codex small-task effort (`review.codex.small_task_effort`, `standard` 등급 리뷰 — 세션 `execution-path: small-task`): `medium` (Recommended)·`high`.
  **`low`·`minimal`·`lowest` 는 선택지로 제시하지 않는다.** `standard` 는 REQUEST review·spec/plan review 를 생략해 final diff review 가 유일한 게이트이므로 `medium` 이 허용 하한이다. 사용자가 "Other"로 `low` 이하를 입력하면 "파이프라인이 경고 후 값을 전달하지 않는다(보정하지 않음)"고 알리고 그대로 기록하지 않는다.
- Codex 리뷰 종류별 effort (`review.codex.review_types.<종류>.effort`): 사용자가 원할 때만 종류(`request-review`·`spec-plan-review`·`diff-review`·`project-context-review`)를 골라 Codex effort 기본값과 같은 선택지로 묻는다.

### 6. 저장 목록 만들기

답마다 저장 목록 파일에 한 줄을 더한다. 한 줄 형식은 `<종류> <경로> <값>` 이다.

- `<종류>` 가 `models` 면 `<경로>` 는 위의 `models.json` 칸이고 `<값>` 은 저장 값(`default`·`null`·`sonnet` 등) 그대로다.
- `<종류>` 가 `legacy` 면 `<경로>` 는 `review-tools.json` 의 `default_priority`·`tools.<도구>.bin`·`tools.claude.self_review_policy`·`overrides.<종류>.priority` 중 하나이고 `<값>` 은 JSON 값이다.
- `<값>` 은 둘째 칸 뒤의 나머지 전부다. 따옴표를 해석하지 않으므로 JSON 문자열은 `"warn"` 처럼, 배열은 `["codex","claude"]` 처럼 그대로 적는다. 셸 인용(`'…'`)을 넣지 않는다.
- 옛 모델·effort 키는 목록에 넣지 않는다(쓰지도 지우지도 않는다). `apply` 도 그 경로를 거부한다.

목록 줄의 예:

```text
legacy default_priority ["codex","claude"]
legacy overrides.diff-review.priority ["codex"]
models review.claude.model sonnet
models review.codex.small_task_effort medium
```

Claude 모델 질문에서 「CLI 기본값 (넘기지 않음)」 과 「옛 설정을 따름(이 칸 비우기)」 을 골랐을 때는 아래 블록의 표지 다음 줄 가운데 하나만 목록에 쓴다. 한 칸에는 한 줄만 쓴다. 다른 칸도 같은 방식으로 `default`·`null` 을 쓴다.

```text
# rd:review-config-default-choice
models review.claude.model default
# rd:review-config-legacy-choice
models review.claude.model null
```

`# rd:` 로 시작하는 줄은 문서 표지이며 목록 파일에 쓰지 않는다. `apply` 는 이 줄을 받으면 그 자리에서 멈춘다.

목록 파일은 `mktemp` 로 만들고 그 경로를 `list` 변수에 둔다.

### 7. 한 번에 저장

프로젝트 루트에서 아래를 실행한다. `apply` 는 줄을 순서대로 쓰고 첫 실패에서 멈춘다. 완료 메시지는 rc 0 일 때만 나온다.

```bash
# rd:review-config-apply
bash rd-workflow/scripts/model_select.sh apply "$list" && echo "✓ 리뷰 설정 저장 완료"
```

- `review-tools.json` 이 없으면 `{"default_priority":["codex","claude"]}` 에서 시작해 목록의 칸만 넣는다. 있으면 목록의 칸만 바꾸고 나머지는 그대로 둔다.
- `models.json` 이 없으면 `{"version":1}` 에서 시작한다. 예시 파일을 복사하지 않는다.
- 실패하면 출력의 `반영됨:`·`실패:`·`미적용:` 줄과 마지막 `다시 실행: …` 줄을 그대로 보인다. 사용자는 원인을 고친 뒤 그 줄을 붙여 넣어 남은 저장을 이어 간다. 완료라고 말하지 않는다.

### 8. 결과 출력

저장이 끝나면 상태 출력의 2·3단계를 다시 실행해 결과를 보인다. `overrides.<종류>.priority` 가 배열인 종류마다 「<종류> 리뷰는 이 우선순위 대신 <그 값> 을 씁니다」 를 한 줄로 알린다. `null` 인 종류는 알리지 않는다(기본 우선순위를 쓴다). 그다음 아래를 덧붙인다:

```
Codex effort 를 즉시 무력화하려면: RD_REVIEW_EFFORT_OVERRIDE=0
이번 실행만 바꾸려면: RD_REVIEW_CODEX_MODEL·RD_REVIEW_CODEX_EFFORT·RD_REVIEW_CLAUDE_MODEL·RD_REVIEW_CLAUDE_EFFORT
설정을 다시 바꾸려면: /review-config setup
```

종료.
