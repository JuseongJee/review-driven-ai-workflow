# Config Reference

`rd-workflow/config/` 아래 설정 파일의 필드 레퍼런스입니다.
설정하려면 `.example` 파일을 복사(`cp *.example *.json`)한 뒤 값을 수정하세요.

## review-tools.json

리뷰 파이프라인에서 사용할 외부 도구와 우선순위를 설정합니다.

### 최상위

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `default_priority` | 리뷰 도구 시도 순서 | `["codex", "gemini", "claude"]` 등 도구 이름 배열 | 첫 번째 사용 가능한 도구 사용 |

### tools 객체

각 도구의 실행 바이너리와 모델을 지정합니다. 키는 도구 이름(`gemini`, `codex`, `claude`).

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `tools.{tool}.bin` | 도구 실행 바이너리 경로 | `"/usr/local/bin/gemini"`, `null` | `null`이면 PATH에서 자동 탐색 |
| `tools.gemini.model` | gemini에서 사용할 모델 | `"gemini-2.5-pro"`, `null` | `null`이면 도구 기본 모델 |
| `tools.claude.model` | claude에서 사용할 모델 | `"claude-sonnet-4-5-20250514"`, `null` | `null`이면 도구 기본 모델 |
| `tools.claude.self_review_warning` | Claude self-review 시 경고 표시 여부 | `true`, `false` | `true` — 경고 표시 |
| `tools.codex.reasoning_effort` | codex 추론 깊이 기본값 | `"medium"`, `"high"`, `"xhigh"`, `null` | `null`·키 부재면 **전달하지 않음** (전역 `~/.codex/config.toml` 을 따름) |
| `tools.codex.small_task_reasoning_effort` | small-task 리뷰에서 쓸 추론 깊이 | `"medium"` 이상, `null` | 키가 없으면 전달하지 않음 (자동 하향 없음) |

**codex 에는 `model` 필드가 없습니다.** 모델은 전역 `~/.codex/config.toml` 을 단일 진실 원천으로 두어
설정이 두 곳으로 갈라지는 drift 를 막습니다. `adapter_codex.sh` 는 `TOOL_MODEL` 을 받더라도 무시하며,
조절 가능한 것은 reasoning effort 뿐입니다.

### overrides 객체

리뷰 타입별로 `default_priority`와 도구 설정을 덮어씁니다. 키는 리뷰 타입(`request-review`, `spec-plan-review`, `diff-review`, `project-context-review`).

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `overrides.{type}.priority` | 해당 리뷰 타입의 도구 우선순위 | `["codex"]` 등 도구 이름 배열 | 미설정 시 `default_priority` 사용 |
| `overrides.{type}.tools.codex.reasoning_effort` | 해당 리뷰 타입의 codex 추론 깊이 | `"medium"`, `"high"`, `"xhigh"` | 미설정 시 `tools.codex.reasoning_effort` 사용 |

### reasoning effort 해석 우선순위

```
kill switch → small-task → review type override → tool 기본 → 미전달(전역 config)
```

| 환경변수 | 의미 | 허용값 | 동작 |
|------|------|--------------|----------|
| `RD_REVIEW_EFFORT_OVERRIDE` | effort override 전역 kill switch | 미설정 / `0` | 미설정이면 위 우선순위대로 적용, `0`이면 설정을 남긴 채 즉시 무력화. 그 외 값은 경고 후 미적용 |

- **키가 없으면 전달하지 않습니다.** 설정이 전혀 없을 때의 동작은 이 기능 도입 전과 완전히 동일합니다.
- **`medium` 이 허용 하한이며, 하한 검증은 `small_task_reasoning_effort` 에만 적용합니다.** `low`·`minimal` 이 오면
  경고를 내고 **값을 보정하지 않은 채 전달하지 않습니다**. small-task 는 REQUEST review·spec/plan review 를
  생략해 final diff review 가 유일한 게이트이고, 판정도 사용자 지정이지 실제 규모의 보증이 아니기 때문입니다.
  review 타입 override 와 tool 기본값은 사용자가 명시적으로 지정한 값이므로 하한을 강제하지 않습니다.
- 허용값 집합은 **모델에 따라 다릅니다** (예: `gpt-5.6-sol` = `low|medium|high|xhigh|max|ultra`,
  `gpt-5.5` = `low|medium|high|xhigh`). 지원하지 않는 값을 남긴 채 모델을 되돌리면 codex 가 설정을 거부하고
  **리뷰 턴이 즉시 실패합니다.** 자동 재시도는 하지 않습니다 — codex 의 stderr 는 설정 오류 전용 채널이 아니라
  진행 출력 전체이므로 "agent 가 시작되기 전에 실패했다"를 증명할 수 없고, 증명 없이 재시도하면 이미 시작된
  agent 뒤에 두 번째 agent 가 붙어 세션을 조용히 오염시킬 수 있습니다. 대신 실패 메시지가 전달한 값과
  복구 방법 두 가지(`RD_REVIEW_EFFORT_OVERRIDE=0` 설정 / 해당 effort 키 제거)를 함께 알려줍니다.
- 적용 상태는 두 번 표시됩니다. 어댑터 실행 **직전**에 stderr 로
  `리뷰 도구: <도구> / effort 시도: <값|none> (source: <근거>)`, 턴 완료 **후**에 stdout 으로
  `effort override: <상태>` 입니다. 상태는 아래 5종이 전부입니다.

  | 상태 | 의미 |
  |------|------|
  | `applied:<값> (source: <근거>)` | codex 에 전달했고 턴이 정상 완료 — codex 가 그 값을 수락 |
  | `none/global` | 설정 부재 — 전역 `~/.codex/config.toml` 을 따름 |
  | `disabled-by-kill-switch` | `RD_REVIEW_EFFORT_OVERRIDE` 가 `0` 또는 인식 불가 값 |
  | `rejected-below-floor:<값>` | `small_task_reasoning_effort` 가 하한 미만이라 거부 (설정은 존재) |
  | `not-applicable (tool=claude)` | claude fallback 이 선택됨 — effort 개념이 없음 |

  effort 가 거부되면 턴이 즉시 실패하므로 "전달했지만 무시됐다" 상태는 존재하지 않습니다.
- **되돌리는 방법**: ① 키 제거 ② `RD_REVIEW_EFFORT_OVERRIDE=0` ③ 값을 올림.
  **small-task diff review 에서 놓친 결함이 발견되면 `small_task_reasoning_effort` 를 제거하고 FR 로 기록하십시오.**
  effort 하락이 리뷰 품질에 주는 영향은 LLM 이 비결정적이라 고정 fixture 로 검증할 수 없으므로,
  실사용 관측과 되돌림 경로로 관리합니다.

## extensions.json

설치된 확장 기능의 메타데이터를 기록합니다. `extensions` 객체 아래 확장 이름별 하위 객체.

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `extensions.{name}.installed_at` | 설치 시각 | ISO 8601 (`"2026-04-09T12:00:00Z"`) | 필수 — 설치 시 자동 기록 |
| `extensions.verify.preset` | verify 프리셋 이름 | `"react-web"`, `"api"`, `"cli"`, `"ios"`, `"macos"` | 미설정 시 프리셋 없이 verify 실행 |
