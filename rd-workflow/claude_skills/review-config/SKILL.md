---
name: review-config
description: >
  Configure review tools (priority, model, binary path).
  Use when the user says "/review-config", "리뷰 도구 설정", "review tool 설정", or wants to change review pipeline tool configuration.
user-invocable: true
disable-model-invocation: true
---

# review-config — 리뷰 도구 설정

Typical user requests:
- "/review-config" → 현재 상태 출력 + setup 안내
- "/review-config setup" → 대화형 설정
- "리뷰 도구 설정해줘" → setup 실행
- "리뷰에 gemini 추가해줘" → setup 실행
- "리뷰 모델 바꿔줘" → setup 실행

## 서브커맨드 라우팅

첫 번째 인자를 파싱한다:

- `setup` → [대화형 설정](#setup) 섹션으로
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

아래 순서로 실행한다:

### 1. 설치된 도구 감지

Bash로 각 도구의 설치 여부를 확인한다:

```bash
command -v codex &>/dev/null && echo "codex: ✓" || echo "codex: ✗"
command -v gemini &>/dev/null && echo "gemini: ✓" || echo "gemini: ✗"
command -v claude &>/dev/null && echo "claude: ✓" || echo "claude: ✗"
```

### 2. 현재 설정 출력

`rd-workflow/config/review-tools.json` 파일이 있으면 내용을 읽어서 출력한다.
없으면 "설정 파일 없음. `/review-config setup`으로 생성하세요."를 출력한다.

### 3. 출력 형식

```
리뷰 도구 상태:
  codex:  ✓ 설치됨
  gemini: ✗ 미설치
  claude: ✓ 설치됨

현재 설정 (rd-workflow/config/review-tools.json):
  priority: codex → claude
  codex:  bin=기본, reasoning_effort=없음(전역 따름), small_task=medium
  claude: bin=기본, model=없음

codex reasoning effort:
  기본값:       없음 (전역 ~/.codex/config.toml 을 따름)
  small-task:   medium
  리뷰 타입별:  request-review=medium
  kill switch:  RD_REVIEW_EFFORT_OVERRIDE=미설정 (적용 중)

설정을 변경하려면: /review-config setup
```

effort 표시 규칙:

- `tools.codex.reasoning_effort` / `tools.codex.small_task_reasoning_effort` /
  `overrides.{타입}.tools.codex.reasoning_effort` 를 각각 읽어 표시한다.
  **키가 없으면 "없음(전역 따름)"으로 표시한다** — 임의의 기본값을 지어내지 않는다.
- `RD_REVIEW_EFFORT_OVERRIDE` 환경변수를 확인해 `0`이면 "무력화됨", 그 외 값이면 "인식 불가 값(미적용)",
  미설정이면 "적용 중"으로 표시한다.
- codex 에는 `model` 항목을 표시하지 않는다 (모델은 전역 설정이 단일 진실 원천).

종료.

---

## 대화형 설정 {#setup}

아래 순서로 실행한다. AskUserQuestion 도구를 사용하여 대화형으로 진행한다.

### 1. 도구 감지

Bash로 codex, gemini, claude 설치 여부를 확인한다 (상태 출력과 동일).
설치된 도구 목록을 `detected_tools`로 저장한다.

### 2. 기존 설정 확인

`rd-workflow/config/review-tools.json` 파일이 있으면 읽어서 현재 설정을 파악한다.

### 3. 사용할 도구 선택

AskUserQuestion으로 사용할 도구를 물어본다 (multiSelect):
- 설치된 도구는 선택지로 표시 (설치됨 표기)
- 미설치 도구도 선택지에 포함 (미설치 경고 표기, 나중에 설치할 수 있으므로)

### 4. 우선순위 설정

선택된 도구가 2개 이상이면 AskUserQuestion으로 우선순위를 물어본다.
선택지는 자주 쓰는 조합을 미리 구성한다:

예시 (codex, gemini, claude 모두 선택 시):
- `codex → gemini → claude` (Recommended) — codex 우선, gemini 독립 리뷰, claude fallback
- `gemini → codex → claude` — gemini 우선
- `codex → claude` — gemini 건너뜀

도구가 1개면 이 단계를 건너뛴다.

### 5. 모델 설정

model을 지원하는 도구(gemini, claude)에 대해 AskUserQuestion으로 모델을 물어본다.
각 도구마다 하나씩 질문한다.

claude 선택지 예시:
- `기본값 (model 미지정)` (Recommended)
- `claude-sonnet-4-20250514`
- `claude-opus-4-20250514`

gemini 선택지 예시:
- `기본값 (model 미지정)` (Recommended)
- `gemini-2.5-pro`
- `gemini-2.5-flash`

사용자가 "Other"를 선택하면 입력값을 그대로 model로 사용한다.

### 5b. codex reasoning effort 설정

codex가 선택된 경우에만 AskUserQuestion으로 추론 깊이를 물어본다.
**codex의 모델은 묻지 않는다** — 모델은 전역 `~/.codex/config.toml`이 단일 진실 원천이다.

선택지:
- `기본값 (전역 설정을 따름)` (Recommended) — 키를 쓰지 않음. 현행 동작과 완전히 동일
- `medium`
- `high`
- `xhigh`

허용값 집합은 **모델에 따라 다르다**(예: `gpt-5.5`는 `max`·`ultra` 미지원). 사용자가 "Other"로
직접 입력하면 그 값을 그대로 쓰되, "이 값을 지원하지 않는 모델로 되돌리면 codex가 설정을 거부한다"고 알린다.

이어서 small-task 리뷰용 값을 물어본다:
- `medium` (Recommended) — small-task 리뷰의 추론 깊이를 낮춰 지연을 줄임
- `기본값 (키를 쓰지 않음)` — small-task에서도 위 설정을 그대로 따름

**`low`·`minimal`은 선택지로 제시하지 않는다.** small-task는 REQUEST review·spec/plan review를 생략해
final diff review가 유일한 게이트이므로 `medium`이 허용 하한이다. 사용자가 "Other"로 `low` 이하를 입력하면
"파이프라인이 경고 후 값을 전달하지 않는다(보정하지 않음)"고 알리고 그대로 기록하지 않는다.

### 6. config 파일 생성

수집한 정보로 `rd-workflow/config/review-tools.json`을 생성한다.

구조:
```json
{
  "default_priority": ["선택된 순서"],
  "tools": {
    "도구명": {
      "bin": null,
      "model": null 또는 "선택된 모델"
    },
    "codex": {
      "bin": null,
      "reasoning_effort": null 또는 "선택된 값",
      "small_task_reasoning_effort": "medium" 또는 키 생략
    }
  },
  "overrides": {
    "diff-review": {
      "priority": ["codex"]
    }
  }
}
```

규칙:
- `bin`은 항상 `null` (사용자가 커스텀 경로를 원하면 직접 편집)
- `model`은 "기본값"을 선택했으면 `null`, 아니면 선택된 값
- claude 도구에는 `"self_review_warning": true` 항상 포함
- `overrides`의 `diff-review`는 항상 `["codex"]` 유지
- codex에는 `model` 필드를 포함하지 않음
- codex effort는 "기본값"을 선택했으면 `null`(= 전달하지 않음), 아니면 선택된 값
- **JSON은 주석을 지원하지 않으므로 파일 안에 설명을 넣지 않는다.** 근거는 `config_reference.md`에 있다
- 생성 후 `jq empty rd-workflow/config/review-tools.json` 으로 유효성을 확인한다

### 7. 결과 출력

생성된 config를 보여주고 완료 메시지를 출력한다:

```
✓ rd-workflow/config/review-tools.json 생성 완료

priority: codex → gemini → claude
  codex:  reasoning_effort=없음(전역 따름), small_task=medium
  gemini: model=gemini-2.5-pro
  claude: model=기본값 (self-review fallback)

effort를 즉시 무력화하려면: RD_REVIEW_EFFORT_OVERRIDE=0
설정을 다시 바꾸려면: /review-config setup
```

종료.
