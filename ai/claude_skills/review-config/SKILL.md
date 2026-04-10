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

`ai/config/review-tools.json` 파일이 있으면 내용을 읽어서 출력한다.
없으면 "설정 파일 없음. `/review-config setup`으로 생성하세요."를 출력한다.

### 3. 출력 형식

```
리뷰 도구 상태:
  codex:  ✓ 설치됨
  gemini: ✗ 미설치
  claude: ✓ 설치됨

현재 설정 (ai/config/review-tools.json):
  priority: codex → claude
  codex:  bin=기본, model=없음
  claude: bin=기본, model=없음

설정을 변경하려면: /review-config setup
```

종료.

---

## 대화형 설정 {#setup}

아래 순서로 실행한다. AskUserQuestion 도구를 사용하여 대화형으로 진행한다.

### 1. 도구 감지

Bash로 codex, gemini, claude 설치 여부를 확인한다 (상태 출력과 동일).
설치된 도구 목록을 `detected_tools`로 저장한다.

### 2. 기존 설정 확인

`ai/config/review-tools.json` 파일이 있으면 읽어서 현재 설정을 파악한다.

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

### 6. config 파일 생성

수집한 정보로 `ai/config/review-tools.json`을 생성한다.

구조:
```json
{
  "default_priority": ["선택된 순서"],
  "tools": {
    "도구명": {
      "bin": null,
      "model": null 또는 "선택된 모델"
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

### 7. 결과 출력

생성된 config를 보여주고 완료 메시지를 출력한다:

```
✓ ai/config/review-tools.json 생성 완료

priority: codex → gemini → claude
  codex:  model=없음
  gemini: model=gemini-2.5-pro
  claude: model=기본값 (self-review fallback)

설정을 다시 바꾸려면: /review-config setup
```

종료.
