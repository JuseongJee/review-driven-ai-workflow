# Config Reference

`rd-workflow/config/` 아래 설정 파일의 필드 레퍼런스입니다.
설정하려면 `.example` 파일을 복사(`cp *.example *.json`)한 뒤 값을 수정하세요.

## review-tools.json

리뷰 파이프라인에서 사용할 외부 도구와 우선순위를 설정합니다. 리뷰어의 모델·effort 는 이 파일이 아니라 [models.json](#modelsjson) 에서 정합니다.

### 최상위

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `default_priority` | 리뷰 도구 시도 순서 | `["codex", "gemini", "claude"]` 등 도구 이름 배열 | 첫 번째 사용 가능한 도구 사용 |

### tools 객체

각 도구의 실행 바이너리와 도구별 정책을 지정합니다. 키는 도구 이름(`gemini`, `codex`, `claude`).

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `tools.{tool}.bin` | 도구 실행 바이너리 경로 | `"/usr/local/bin/gemini"`, `null` | `null`이면 PATH에서 자동 탐색 |
| `tools.gemini.model` | gemini에서 사용할 모델 | `"gemini-2.5-pro"`, `null` | `null`이면 도구 기본 모델 |
| `tools.claude.self_review_warning` | Claude self-review 시 경고 표시 여부 | `true`, `false` | `true` — 경고 표시 |
| `tools.claude.self_review_policy` | Claude self-review 정책 | `"block"`, `"warn"`, `"off"` | `block` — 차단 |

### overrides 객체

리뷰 타입별로 `default_priority`를 덮어씁니다. 키는 리뷰 타입(`request-review`, `spec-plan-review`, `diff-review`, `project-context-review`).

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `overrides.{type}.priority` | 해당 리뷰 타입의 도구 우선순위 | `["codex"]` 등 도구 이름 배열 | 미설정 시 `default_priority` 사용 |

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
- 고정 이름은 「고정됨, 낡을 수 있음」 경고를 냅니다. 계열 이름을 쓰면 새 모델이 나와도 고칠 필요가 없습니다.
- 파일이 JSON 객체 하나가 아니면 `⚠️  models.json 을 읽지 못했습니다(<경로>) — 이 파일을 무시하고 옛 설정으로 진행합니다.` 를 내고 파일 전체를 무시합니다.
- 다른 최상위 키(`review` 밖)는 읽지도 바꾸지도 않습니다.
- jq 가 없으면 `models.json`·`review-tools.json`·`RD_REVIEW_*` 를 모두 쓰지 않고 모델·effort 를 넘기지 않습니다.

### Codex 계열 해석

- 계열 이름은 `<Codex 홈>/models_cache.json` 에서 `visibility` 가 `list` 이고 이름이 `gpt-<버전>-<계열>` 인 모델 중 버전이 가장 높은 것으로 바꿉니다. Codex 홈은 `${CODEX_HOME:-$HOME/.codex}` 입니다.
- 버전은 `.` 로 나눈 정수로 비교합니다(`6.10` > `6.2` > `6`). 같은 버전이 둘이면 `priority` 가 작은 쪽을 고릅니다.
- 캐시가 없거나 그 계열이 없으면 경고하고 `-m` 없이 실행합니다. 실행 줄은 `모델 요청: none (source: unresolved · …) — CLI 기본값으로 실행` 입니다.

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
  - `<종류>` 가 `legacy` 면 `<경로>` 는 `review-tools.json` 의 `default_priority`·`tools.{tool}.bin`·`tools.claude.self_review_policy`·`tools.gemini.model`·`overrides.{type}.priority` 중 하나이고 `<값>` 은 JSON 값입니다. 예: `legacy default_priority ["codex","claude"]`.
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

## extensions.json

설치된 확장 기능의 메타데이터를 기록합니다. `extensions` 객체 아래 확장 이름별 하위 객체와, 최상위의 안내 이력 `seen_extensions`.

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `extensions.{name}.installed_at` | 설치 시각 | ISO 8601 (`"2026-04-09T12:00:00Z"`) | 필수 — 설치 시 자동 기록 |
| `extensions.verify.preset` | verify 프리셋 이름 | `"react-web"`, `"api"`, `"cli"`, `"ios"`, `"macos"` | 미설정 시 프리셋 없이 verify 실행 |
| `extensions.verify.seen_verifiers` | 이 프로젝트가 현재 프리셋에서 받은 적 있는 verifier 이름 (`/tpl update` 가 지운 verifier 를 다시 넣지 않는 데 씀) | 문자열 배열, 이름순 (`["axe", "lighthouse", "playwright"]`) | 직접 고치지 않음 — 프리셋 설치·변경과 `/tpl update` 가 기록. 없으면 다음 `/tpl update` 가 빠진 verifier 마다 묻고 만듦. 지운 verifier 를 다시 받으려면 그 이름만 빼고 `/tpl update` 실행 (`sync_template.md` 8.6) |
| `seen_extensions` | 설치 여부를 안내한 적 있는 extension 이름 — 설치·거절 모두 포함 (`/tpl update` 가 거절한 extension 을 다시 묻지 않는 데 씀) | 문자열 배열, 이름순 (`["design-review", "verify"]`) | 직접 고치지 않음 — setup 의 확장 안내와 `/tpl update` 가 기록. 목록에 없는 extension 만 묻습니다. manifest 는 있는데 이 키가 없으면 다음 `/tpl update` 가 묻지 않고 지금 있는 extension 으로 채웁니다. 거절한 extension 을 설치하려면 「<이름> extension 설치해줘」 로 요청하고, update 에서 다시 질문을 받으려면 그 이름만 빼고 `/tpl update` 실행 (`sync_template.md` 8.4·8.7) |
