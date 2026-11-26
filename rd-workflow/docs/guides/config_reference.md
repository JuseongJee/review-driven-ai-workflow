# Config Reference

`rd-workflow/config/` 아래 설정 파일의 필드 레퍼런스입니다.
설정하려면 `.example` 파일을 복사(`cp *.example *.json`)한 뒤 값을 수정하세요.

## review-tools.json

리뷰 파이프라인에서 사용할 외부 도구와 우선순위를 설정합니다. 리뷰어의 모델·effort 는 이 파일이 아니라 [models.json](#modelsjson) 에서 정합니다.

### 최상위

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `default_priority` | 리뷰 도구 시도 순서 | `["codex", "claude"]` 등 도구 이름 배열 | 첫 번째 사용 가능한 도구 사용. `rd-workflow/scripts/adapter_{tool}.sh` 가 없는 도구는 「어댑터 없음, 건너뜀」 을 출력하고 건너뜀 |

### tools 객체

각 도구의 실행 바이너리와 도구별 정책을 지정합니다. 키는 도구 이름(`codex`, `claude`).

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `tools.{tool}.bin` | 도구 실행 바이너리 경로 | `"/usr/local/bin/codex"`, `null` | `null`이면 PATH에서 자동 탐색 |
| `tools.claude.self_review_warning` | Claude self-review 시 경고 표시 여부 | `true`, `false` | `true` — 경고 표시 |
| `tools.claude.self_review_policy` | Claude self-review 정책 | `"block"`, `"warn"`, `"off"` | `block` — 차단 |

### overrides 객체

리뷰 타입별로 `default_priority`를 덮어씁니다. 키는 리뷰 타입(`request-review`, `spec-plan-review`, `diff-review`, `project-context-review`).

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `overrides.{type}.priority` | 해당 리뷰 타입의 도구 우선순위 | `["codex"]` 등 도구 이름 배열, `null` | 미설정·`null` 이면 `default_priority` 사용 |

### 옛 모델·effort 키

아래 키는 `models.json` 으로 옮겼습니다. 리뷰 턴은 `models.json` 의 같은 칸이 비어 있을 때만 옛 키를 읽고, 읽을 때마다 `ℹ️  옛 설정 … 을 썼습니다 — … 으로 옮기십시오.` 를 냅니다. 옛 키를 새로 쓰지 마십시오. `/review-config setup` 도 옛 키를 쓰거나 지우지 않습니다.

| 옛 키 | 옮긴 칸 |
|------|--------|
| `tools.claude.model` | `review.claude.model` |
| `tools.codex.reasoning_effort` | `review.codex.effort` |
| `tools.codex.small_task_reasoning_effort` | `review.codex.small_task_effort` |
| `overrides.{type}.tools.codex.reasoning_effort` | `review.codex.review_types.{type}.effort` |

옛 키 값은 형식을 판정하거나 변환하지 않고 그대로 넘깁니다.

## models.json

리뷰 턴의 Claude·Codex 리뷰어가 쓸 모델과 추론 깊이(effort)를 정합니다. `rd-workflow/config/models.json.example` 을 `rd-workflow/config/models.json` 으로 복사해 만듭니다. 경로는 `RD_MODELS_CONFIG` 환경 변수로 바꿀 수 있습니다.

| 경로 | 의미 | 허용값 | 비어 있을 때 |
|------|------|--------|-------------|
| `version` | 형식 버전 | `1` | - |
| `review.codex.model` | Codex 모델 | 계열 이름(`^[a-z]+$`, 예: `sol`), 고정 이름(`gpt-6.2-sol`), `default` | `~/.codex/config.toml` 의 모델 (`-m` 을 넘기지 않음) |
| `review.codex.effort` | Codex effort 기본값 | effort 값 | 옛 키 `tools.codex.reasoning_effort`, 그다음 미전달 |
| `review.codex.small_task_effort` | `standard` 등급 리뷰(세션 `execution-path: small-task`)의 Codex effort | effort 값 (`medium` 이상) | 옛 키 `tools.codex.small_task_reasoning_effort`, 그다음 아래 단계 |
| `review.codex.review_types.{type}.effort` | 리뷰 종류별 Codex effort | effort 값 | 옛 키 `overrides.{type}.tools.codex.reasoning_effort`, 그다음 아래 단계 |
| `review.claude.model` | Claude 모델 | 별칭(`opus`·`sonnet`·`haiku`·`fable`), 고정 이름(`claude-…`·`fable-…`), `default` | 옛 키 `tools.claude.model`, 그다음 CLI 기본값 |
| `review.claude.effort` | Claude effort (`--effort`) | effort 값 | CLI 기본값 |

- effort 값은 단계 이름(`low`·`medium`·`high`·`xhigh`·`max`·`ultra`), 상대어(`lowest`·`highest`), `default` 입니다.
- `null` 이나 칸 없음은 「비어 있음」 입니다. 다음 단계로 넘어갑니다.
- `default` 는 「이 칸에서 넘기지 않음」 입니다. 아래 단계나 옛 키로 내려가지 않습니다.
- 허용값 밖의 값(숫자·빈 문자열·`Opus` 처럼 대문자가 섞인 이름 등)은 경고하고 비어 있는 것으로 봅니다.
- Claude 고정 이름은 리뷰 턴마다 「고정됨, 낡을 수 있음」 경고를 냅니다. Codex 고정 이름은 계열 최신이 아니면 리뷰 세션을 만들 때 한 번 알립니다(아래 「낡은 Codex 모델 알림」). 계열 이름을 쓰면 새 모델이 나와도 고칠 필요가 없습니다.
- 파일이 JSON 객체 하나가 아니면 `⚠️  models.json 을 읽지 못했습니다(<경로>) — 이 파일을 무시하고 옛 설정으로 진행합니다.` 를 내고 파일 전체를 무시합니다.
- 리뷰 턴은 `review` 밖의 최상위 키를 읽지 않습니다. 작업 세션 칸 `session` 은 아래 「작업 세션 칸」 절에서 설명합니다.
- jq 가 없으면 `models.json`·`review-tools.json`·`RD_REVIEW_*` 를 모두 쓰지 않고 모델·effort 를 넘기지 않습니다.

### Codex 계열 해석

- 계열 이름은 `<Codex 홈>/models_cache.json` 에서 `visibility` 가 `list` 이고 이름이 `gpt-<버전>-<계열>` 인 모델 중 버전이 가장 높은 것으로 바꿉니다. Codex 홈은 `${CODEX_HOME:-$HOME/.codex}` 입니다.
- 버전은 `.` 로 나눈 정수로 비교합니다(`6.10` > `6.2` > `6`). 같은 버전이 둘이면 `priority` 가 작은 쪽을 고릅니다.
- 캐시가 없거나 그 계열이 없으면 경고하고 `-m` 없이 실행합니다. 실행 줄은 `모델 요청: none (source: unresolved · …) — CLI 기본값으로 실행` 입니다.

### 낡은 Codex 모델 알림

리뷰 세션을 만들 때, 이번 리뷰를 Codex 가 맡고 Codex 모델이 계열 최신이 아니면 한 번 알립니다. 리뷰 턴마다 알리지 않습니다.

리뷰 도구 판정: 리뷰 턴과 같은 규칙으로 첫 실행 가능 도구를 정합니다. `review-tools.json` 의 `overrides.<리뷰 종류>.priority`(없으면 `default_priority`, 둘 다 없으면 `codex claude`) 순서로 어댑터 파일과 실행 파일이 있는 첫 도구입니다. 그 도구가 Codex 가 아니면 알리지 않습니다.

판정 대상은 Codex 가 이번 리뷰에서 쓸 모델입니다.

| 모델을 정하는 곳 | 판정 대상 | 알림 |
| --- | --- | --- |
| 환경 변수 `RD_REVIEW_CODEX_MODEL` 또는 `models.json` 의 `review.codex.model` 이 고정 이름 | 그 고정 이름 | 계열 최신보다 낮으면 알림 |
| 두 곳이 비어 있음·`default`·계열 이름을 모델 목록에서 찾지 못함(`-m` 을 넘기지 않음) | `<Codex 홈>/config.toml` 의 `model` | 계열 최신보다 낮으면 알림 |
| 두 곳이 계열 이름이고 최신 모델로 해석됨 | 판정 안 함 | 없음(계열 이름은 항상 최신으로 바뀜) |

판정하지 않는 경우입니다.

- 모델 값이 계열 이름이고 최신 모델로 해석됩니다.
- `<Codex 홈>/config.toml` 에 `model` 이 없습니다.
- 모델을 `config.toml` 에서 읽는 경우, 프로젝트 `.codex/config.toml` 이 `model` 이나 `profile` 을 정합니다. 프로젝트 폴더부터 `.git` 이 있는 가장 가까운 폴더(없으면 프로젝트 폴더 하나)까지 올라가며 봅니다. Codex 가 그 값을 홈 설정보다 앞세우기 때문입니다.
- 모델을 `config.toml` 에서 읽는 경우, 홈 `config.toml` 에 `profile` 이 있습니다.
- 모델을 `config.toml` 에서 읽는 경우, 모델 목록 캐시(`<Codex 홈>/models_cache.json`)가 없거나 읽지 못하거나 그 계열이 없으면 아무것도 알리지 않습니다.
- 환경 변수·`models.json` 의 고정 이름은 같은 캐시 문제로 최신 여부를 확인하지 못하면, 확인하지 못했다는 「고정됨, 낡을 수 있음」 한 줄만 냅니다.
- jq 가 없습니다.

알림은 두 선택지를 보입니다.

- 선택 1: 이번만 옛 모델로 진행합니다. 다음 리뷰 세션에서 다시 알립니다.
- 선택 2: 옛 모델을 계속 쓰기로 기록합니다. 아래 명령을 씁니다.

```
bash rd-workflow/scripts/model_select.sh keep-codex-model <현재 모델> <새 모델>
```

- 두 값은 같은 계열의 서로 다른 고정 이름(`gpt-<버전>-<계열>`)이어야 합니다. 아니면 기록하지 않고 exit 1 입니다.
- 기록 파일은 `<상태 폴더>/rd-workflow/codex-model-keep.tsv` 입니다. 상태 폴더는 `XDG_STATE_HOME` 이 `/` 로 시작하면 그 값이고, 아니면 `$HOME/.local/state` 입니다. 한 줄이 `<현재 모델>\t<새 모델>` 입니다. 사용자 단위 파일이라 프로젝트마다 다시 기록하지 않아도 됩니다.
- 기록한 `<새 모델>` 은 다시 알리지 않습니다. 같은 계열에 더 새 모델이 나오면 다시 알립니다.
- 기록해도 리뷰에 쓰는 모델은 바뀌지 않습니다. 알림만 멈춥니다.
- 다시 알림을 받으려면 그 줄을 지우거나 모델 설정값을 바꿉니다.
- 기록 명령은 쓰는 동안 `<기록 파일>.lock` 폴더를 만들었다가 지웁니다. 두 기록이 겹쳐도 같은 조합은 한 줄만 남습니다. 강제 종료로 이 폴더가 남으면 다음 기록 명령이 잠금을 30번 다시 시도한 뒤(몇 초) 그 경로를 안내하고 exit 1 로 끝납니다. 그 폴더를 지운 뒤 다시 실행합니다. 기록 파일이 있는 폴더에 쓸 수 없을 때도 같은 안내가 나옵니다. 이때는 남은 잠금 폴더가 없으므로 그 폴더의 쓰기 권한을 확인합니다.

### 우선순위

```
Codex effort : kill switch → RD_REVIEW_CODEX_EFFORT → small-task → 리뷰 종류별 → 도구 기본 → 미전달
Codex 모델   : RD_REVIEW_CODEX_MODEL → review.codex.model → 미전달(~/.codex/config.toml)
Claude effort: RD_REVIEW_CLAUDE_EFFORT → review.claude.effort → 미전달
Claude 모델  : RD_REVIEW_CLAUDE_MODEL → review.claude.model → 옛 tools.claude.model → 미전달(CLI 기본값)
```

- 각 단계는 `models.json` 칸을 먼저 보고, 비어 있으면 같은 단계의 옛 키를 봅니다.
- 어느 단계에서 값을 찾으면 그 단계에서 멈춥니다.
- small-task 단계는 세션 `execution-path` 가 `small-task` 일 때만 봅니다.

| 환경 변수 | 의미 | 허용값 | 동작 |
|------|------|--------------|----------|
| `RD_REVIEW_EFFORT_OVERRIDE` | Codex effort 전역 kill switch | 미설정 / `0` | 설정돼 있으면 값과 상관없이 Codex effort 를 넘기지 않음. `0` 이 아닌 값은 인식 불가 경고를 함께 냄 |
| `RD_REVIEW_CODEX_MODEL` · `RD_REVIEW_CLAUDE_MODEL` | 이번 실행의 모델 | `models.json` 의 같은 칸과 같음 | `models.json` 을 이김. `default` 면 넘기지 않음 |
| `RD_REVIEW_CODEX_EFFORT` · `RD_REVIEW_CLAUDE_EFFORT` | 이번 실행의 effort | effort 값 | `models.json` 을 이김. `default` 면 넘기지 않음 |
| `RD_MODELS_CONFIG` | `models.json` 경로 | 파일 경로 | 미설정이면 `rd-workflow/config/models.json` |

### effort 변환

- 변환은 `models.json`·환경 변수의 값에만 합니다. 옛 키 값은 그대로 넘깁니다.
- Codex 는 고른 모델(없으면 `~/.codex/config.toml` 의 최상위 `model`)이 지원하는 단계를 `models_cache.json` 에서 읽습니다. 지원하지 않는 단계는 고정 순서 `low < medium < high < xhigh < max < ultra` 에서 바로 아래의 지원 단계로 낮추고 경고합니다. 그 아래에도 없으면 지원 단계 중 가장 낮은 것을 씁니다.
- `lowest`·`highest` 는 그 모델이 지원하는 가장 낮은·높은 단계입니다. 모델 정보를 얻지 못하면 단계 이름은 그대로 넘기고 상대어는 넘기지 않습니다.
- Claude 는 고정 단계표 `low`·`medium`·`high`·`xhigh`·`max` 를 씁니다. `ultra` 는 `max` 로 낮추고 경고합니다.
- **`medium` 이 허용 하한이며, 하한 검증은 small-task 단계에만 적용합니다.** 변환 결과가 `low`·`minimal` 이면 경고를 내고 **값을 보정하지 않은 채 넘기지 않습니다**(`below-floor`). `standard` 등급(REQUEST `## Risk Tier` 최종 등급 `standard` → 세션 `execution-path: small-task`) 은 REQUEST review·spec/plan review 를 생략해 final diff review 가 유일한 게이트이기 때문입니다. `## Risk Tier` 가 없는 옛 REQUEST 는 `Execution Path=small-task` 로 fallback 하고, 섹션이 있는데 판독이 안 되면 경고 후 하향을 적용하지 않습니다.
  리뷰 종류별 칸과 도구 기본 칸은 사용자가 명시적으로 지정한 값이므로 하한을 강제하지 않습니다.

### 조회와 저장

- `bash rd-workflow/scripts/model_select.sh show review [<리뷰 종류>]` 는 칸마다 `값 — 출처`(`models.json` / `review-tools.json (옛 키)` / `미설정`) 를 보이고, 마지막 줄에 kill switch 상태를 보입니다. 환경 변수 덮어쓰기는 보이지 않습니다(리뷰 턴의 실행 줄이 보입니다).
- `bash rd-workflow/scripts/model_select.sh set <칸> <값|null>` 은 `models.json` 의 그 칸만 바꿉니다. `null` 은 칸 비우기입니다. 파일이 없으면 `{"version":1}` 에서 시작합니다(예시 파일을 복사하지 않음).
- `bash rd-workflow/scripts/model_select.sh apply <저장 목록 파일>` 은 목록의 줄을 순서대로 저장하고 첫 실패에서 멈춥니다. 한 줄은 `<종류> <경로> <값>` 입니다.
  - `<종류>` 가 `models` 면 `<경로>` 는 `models.json` 칸이고 `<값>` 은 `set` 의 값입니다. 예: `models review.claude.model sonnet`.
  - `<종류>` 가 `legacy` 면 `<경로>` 는 `review-tools.json` 의 `default_priority`·`tools.{tool}.bin`·`tools.claude.self_review_policy`·`overrides.{type}.priority` 중 하나이고 `<값>` 은 JSON 값입니다. 예: `legacy default_priority ["codex","claude"]`.
  - `<값>` 은 둘째 칸 뒤의 나머지 전부입니다. 따옴표를 해석하지 않으므로 JSON 문자열은 `"g"` 처럼 그대로 적습니다.
  - 결과는 `반영됨:`·`실패:`·`미적용:` 줄로 보입니다. 실패하면 마지막 줄 `다시 실행: …` 을 그대로 붙여 넣어 남은 저장을 이어 갑니다.
- 저장은 `<파일>.lock` 폴더로 잠그고, 임시 파일에 쓴 뒤 한 번에 옮깁니다. 실패하면 원본을 바꾸지 않습니다. 원본 권한은 유지하고, 새 파일은 `0644` 로 만듭니다.

### 표시

- 어댑터 실행 **직전**에 stderr 로 도구마다 실행 줄을 냅니다.
  `리뷰 도구: <도구> / 모델 요청: <값|none> (source: <단계> · <위치>) / effort 시도: <값|none> (source: <단계> · <위치>)`
  - 모델 단계: `env`·`models.json`·`review-tools.json`·`unresolved`(계열 해석 실패)·`cli-default`.
  - effort 단계: `env`·`small-task`·`review-type`·`tool-default`·`kill-switch`·`below-floor`·`global`.
  - 위치: `env:<변수>` / `file:<경로>#<칸>` / `cli-default`. 값을 찾았지만 넘기지 않았으면 `= <값>` 을 붙입니다(예: `#review.codex.effort = default`).
  - 계열을 해석했으면 `sol→gpt-6.2-sol` 처럼 적습니다.
- 턴 완료 **후**에 stderr 로 `turn time: <초> (status: <상태>) / 실제 모델: <관측값> / 실제 effort: <관측값>` 을 냅니다. 관측값의 뜻은 `rd-workflow/docs/flows/FILE_BASED_REVIEW_PIPELINE.md` 「턴 계측」 절에 있습니다.
- 성공한 턴은 stdout 으로 `effort override: <상태>` 를 냅니다. Claude·Codex 모두 같은 규칙입니다. 상태는 아래 4종이 전부입니다.

  | 상태 | 의미 |
  |------|------|
  | `applied:<값> (source: <단계>)` | 도구에 넘겼고 턴이 정상 완료 — 도구가 그 값을 수락 |
  | `none/global` | 넘기지 않음 — 도구 자체 설정을 따름 |
  | `disabled-by-kill-switch` | `RD_REVIEW_EFFORT_OVERRIDE` 가 설정됨 |
  | `rejected-below-floor:<값>` | small-task 값이 하한 미만이라 넘기지 않음 (설정은 존재) |

### 거부되면

- 허용값 집합은 **모델에 따라 다릅니다.** 도구가 모델이나 effort 를 거부하면 **리뷰 턴이 즉시 실패합니다.** 자동 재시도는 하지 않습니다 — codex 의 stderr 는 설정 오류 전용 채널이 아니라 진행 출력 전체이므로 "agent 가 시작되기 전에 실패했다"를 증명할 수 없고, 증명 없이 재시도하면 이미 시작된 agent 뒤에 두 번째 agent 가 붙어 세션을 조용히 오염시킬 수 있습니다.
- 실패 메시지는 칸(모델·effort)마다 이번 호출에 넘긴 값과 그 출처를 알리고 고치는 방법을 안내합니다.
  - 넘긴 값의 출처가 파일이면 그 파일 경로와 칸을 고치거나, `RD_REVIEW_<도구>_<MODEL|EFFORT>=<유효 값>` 또는 `=default` 로 이번 호출만 덮어씁니다.
  - 넘긴 값의 출처가 환경 변수면 그 변수에 유효한 값이나 `default` 를 주거나 지우고 다시 실행합니다.
  - 넘기지 않았으면(CLI 기본값) 도구 자체 설정(Codex: `~/.codex/config.toml` 의 `model`·`model_reasoning_effort`)을 확인하거나 `RD_REVIEW_<도구>_<MODEL|EFFORT>=<유효 값>` 으로 이번 호출만 덮어씁니다.
  - Codex effort 는 `RD_REVIEW_EFFORT_OVERRIDE=0` 으로 이번 호출만 무력화할 수도 있습니다.
- **되돌리는 방법**: 1. 칸을 `null` 로 비움 2. `RD_REVIEW_EFFORT_OVERRIDE=0` 3. 값을 올림.
  **`standard` diff review 에서 놓친 결함이 발견되면 `review.codex.small_task_effort` 를 비우고 FR 로 기록하십시오.**
  effort 하락이 리뷰 품질에 주는 영향은 LLM 이 비결정적이라 고정 fixture 로 검증할 수 없으므로,
  실사용 관측과 되돌림 경로로 관리합니다.

### 리뷰 종류별 effort 의 근거

spec-plan-review 의 codex effort override(high)는 2026-09-30 실측 재평가 후 원복했습니다. override 이후 spec-plan 의 리뷰어 턴 중앙값이 2→4로 늘어 대조 리뷰 종류(request 2→3)보다 컸고, diff review 이월 결함 비교(2/10 vs 2/10)로는 비열등을 입증하지 못했습니다. 다시 적용하려면 `models.json` 에 `review.codex.review_types.spec-plan-review.effort` 를 추가합니다(전체 해제는 `RD_REVIEW_EFFORT_OVERRIDE=0`). 근거: `rd-workflow-workspace/reports/2026-09-30-review-effort-and-turn-cap-analysis.md`

### 작업 세션 칸 (`session.claude`)

promote 가 작업 탭(herdr·herdr app·Orca)에 띄우는 Claude 작업 세션의 모델과 effort 를 정합니다. 리뷰 턴의 `review` 칸과는 따로 읽습니다.

| 경로 | 의미 | 허용값 | 비어 있을 때 |
|------|------|--------|-------------|
| `session.claude.model` | 작업 세션 모델 (`--model`) | 별칭(`opus`·`sonnet`·`haiku`·`fable`), 고정 이름(`claude-…`·`fable-…`), `default` | 옛 키 `model-strategy.json` 의 `session_model`, 그다음 부모 세션(promote 를 부른 세션)의 모델 |
| `session.claude.effort` | 작업 세션 effort (`--effort`) | effort 값 | 부모 세션의 effort |

칸마다 아래 순서에서 처음 값이 있는 것을 씁니다.

1. 환경 변수 `RD_SESSION_MODEL`·`RD_SESSION_EFFORT`. promote 를 부르는 쪽이 이번 기동에만 줍니다. 대화형 `/fr do` 는 줄기마다 정한 값을 이 변수로 넘깁니다(`claude_skills/fr/do.md` 「1. 고르기와 착수 보고 표」 7단계).
2. `models.json` 의 `session.claude.<칸>`.
3. 모델만: 옛 키 `model-strategy.json` 의 `session_model`. 읽을 때마다 `models.json` 으로 옮기라는 안내를 냅니다.
4. 부모 세션의 값. promote 를 부른 Claude 세션의 transcript 에서 마지막으로 기록된 모델·effort 를 읽습니다.
5. 아무것도 없으면 넘기지 않습니다(CLI 기본값).

- `default` 는 「CLI 기본값으로 띄움」 입니다. `--model`·`--effort` 를 넘기지 않고, 아래 단계(옛 키·부모 세션)로 내려가지 않습니다.
- 허용값 밖의 값은 경고하고 그 칸을 CLI 기본값으로 둡니다. 부모 세션으로 내려가지 않습니다.
- 템플릿은 두 칸을 비워 배포합니다. 비워 두면 작업 세션이 부모 세션을 따라갑니다.
- `model_select.sh set` 은 이 칸을 바꾸지 않습니다. `models.json` 을 직접 고칩니다.
- promote 는 기동 전에 `promote: 다음 기동에 사용할 모델 — <값> (출처: <출처>) · effort — <값> (출처: <출처>)` 를 냅니다. 출처는 `RD_SESSION_MODEL`·`RD_SESSION_EFFORT`·`models.json`·`model-strategy.json(옛 키)`·`현재 세션 상속`·`default 지정 — CLI 기본값`·`미지정 — CLI 기본값` 중 하나입니다.
- Claude CLI 가 `--effort` 를 받지 않으면 effort 를 빼고 띄우며, effort 칸을 `CLI 기본값 (CLI 미지원으로 뺌, <출처>)` 로 보입니다.

### 구현 subagent 칸 (`subagent.claude`)

implement-reviewed-plan·autopilot 이 구현 subagent(구현자·task reviewer)를 띄울 때 Agent 도구에 넘기는 모델과 effort 를 정합니다. 리뷰 턴의 `review` 칸, 작업 세션의 `session` 칸과는 따로 읽습니다.

| 경로 | 의미 | 허용값 | 비어 있을 때 |
|------|------|--------|-------------|
| `subagent.claude.model` | Agent 도구 `model` 인자 | 별칭(`opus`·`sonnet`·`haiku`·`fable`), `default` | 옛 키 `model-strategy.json` 의 `subagent`, 그것도 없으면 `sonnet` |
| `subagent.claude.effort` | Agent 도구 `effort` 인자 | `low`·`medium`·`high`·`xhigh`·`max`, `default` | 넘기지 않음 |

모델 칸은 위에서부터 처음 맞는 것을 씁니다.

1. `models.json` 을 해석할 수 없음(최상위 객체 하나가 아님, `subagent`·`subagent.claude` 가 객체가 아님, jq·python3 모두 없음): 경고하고 `sonnet`. 옛 키로 내려가지 않습니다.
2. 별칭: 그 값.
3. `default`: 모델을 넘기지 않습니다(Agent 도구 기본값 — 부모 세션 모델 또는 agent 정의의 모델).
4. 고정 이름(`claude-…`·`fable-…`): Agent 도구는 별칭만 받으므로 경고하고 `sonnet`.
5. 그 밖의 값: 허용값을 알리는 경고 뒤 `sonnet`.
6. 칸이 없거나 `null`: 옛 키 `model-strategy.json` 의 `subagent` 를 읽습니다. 별칭이면 그 값을 쓰고 `models.json` 으로 옮기라고 안내합니다. 별칭이 아니면 경고 뒤 `sonnet`. 옛 키도 없으면 `sonnet` 입니다.

effort 칸은 단계 이름이면 그 값을 넘깁니다(`ultra` 는 경고 뒤 `max`, `lowest`·`highest` 는 `low`·`max`). `default`·칸 없음·`null` 은 넘기지 않습니다. 그 밖의 값이나 파일 해석 실패는 경고하고 넘기지 않습니다.

- 지금 값과 출처는 `bash rd-workflow/scripts/model_select.sh subagent` 로 확인합니다. 출력은 네 줄입니다: `model=<넘길 값>`, `effort=<넘길 값>`, `설정 파일: <models.json 경로>`, `subagent 모델: <값> (<출처>) · effort: <값> (<출처>)`. 넘길 값이 없으면 `=` 뒤가 빕니다. 경고·안내는 stderr 로 나오고 종료 코드는 늘 0 입니다. jq 가 없어도 python3 로 읽습니다.
- Status 가 `구현 중` 일 때 Agent 호출마다 hook(`subagent_dispatch_display.sh`)이 넘긴 값과 이 설정·출처·경고를 화면에 한 줄로 보입니다. 넘긴 값이 설정과 다르면 「설정과 다름」 을 붙입니다. 호출은 막지 않습니다.
- 무인 실행(`claude -p`, `/fr do --headless`)에서는 같은 줄이 transcript 에 `hook_system_message` 항목으로 남습니다. 작업 이름과 실행 시각으로 찾는 명령은 `rd-workflow/claude_skills/fr/do.md` 「4. 무인」 7단계에 있습니다.
- 바꾸려면 `bash rd-workflow/scripts/model_select.sh set subagent.claude.model <값>` 과 `set subagent.claude.effort <값>` 을 쓰거나 `/model-strategy` 를 실행합니다. `null` 은 칸을 비웁니다. `set` 은 고정 모델 이름을 거부하고 jq 가 있어야 쓸 수 있습니다.
- 이 체크아웃의 `rd-workflow/config/models.json`(`RD_MODELS_CONFIG` 가 있으면 그 파일)만 읽습니다. 같은 체크아웃에서 저장한 값은 커밋하지 않아도 다음 조회부터 적용됩니다. 다른 체크아웃(기본 체크아웃·다른 작업 worktree)에서 커밋하지 않고 바꾼 설정은 이 체크아웃에 닿지 않습니다.
- 템플릿은 두 칸을 비워 배포합니다. 설정하지 않으면 모델 `sonnet`, effort 미전달로 동작합니다.
- Agent 도구의 `model`·`effort` 허용값은 2026-11-23, Claude Code 2.1.330 에서 확인했습니다.

## extensions.json

설치된 확장 기능의 메타데이터를 기록합니다. `extensions` 객체 아래 확장 이름별 하위 객체와, 최상위의 안내 이력 `seen_extensions`.

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `extensions.{name}.installed_at` | 설치 시각 | ISO 8601 (`"2026-04-09T12:00:00Z"`) | 필수 — 설치 시 자동 기록 |
| `extensions.verify.preset` | verify 프리셋 이름 | `"react-web"`, `"api"`, `"cli"`, `"ios"`, `"macos"` | 미설정 시 프리셋 없이 verify 실행 |
| `extensions.verify.seen_verifiers` | 이 프로젝트가 현재 프리셋에서 받은 적 있는 verifier 이름 (`/tpl update` 가 지운 verifier 를 다시 넣지 않는 데 씀) | 문자열 배열, 이름순 (`["axe", "lighthouse", "playwright"]`) | 직접 고치지 않음 — 프리셋 설치·변경과 `/tpl update` 가 기록. 없으면 다음 `/tpl update` 가 빠진 verifier 마다 묻고 만듦. 지운 verifier 를 다시 받으려면 그 이름만 빼고 `/tpl update` 실행 (`sync_template.md` 8.6) |
| `seen_extensions` | 설치 여부를 안내한 적 있는 extension 이름 — 설치·거절 모두 포함 (`/tpl update` 가 거절한 extension 을 다시 묻지 않는 데 씀) | 문자열 배열, 이름순 (`["design-review", "verify"]`) | 직접 고치지 않음 — setup 의 확장 안내와 `/tpl update` 가 기록. 목록에 없는 extension 만 묻습니다. manifest 는 있는데 이 키가 없으면 다음 `/tpl update` 가 묻지 않고 지금 있는 extension 으로 채웁니다. 거절한 extension 을 설치하려면 「<이름> extension 설치해줘」 로 요청하고, update 에서 다시 질문을 받으려면 그 이름만 빼고 `/tpl update` 실행 (`sync_template.md` 8.4·8.7) |
