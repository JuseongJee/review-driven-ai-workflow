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

### overrides 객체

리뷰 타입별로 `default_priority`를 덮어씁니다. 키는 리뷰 타입(`request`, `spec-plan`, `diff-review` 등).

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `overrides.{type}.priority` | 해당 리뷰 타입의 도구 우선순위 | `["codex"]` 등 도구 이름 배열 | 미설정 시 `default_priority` 사용 |

## extensions.json

설치된 확장 기능의 메타데이터를 기록합니다. `extensions` 객체 아래 확장 이름별 하위 객체.

| 경로 | 의미 | 허용값 / 예시 | 기본 동작 |
|------|------|--------------|----------|
| `extensions.{name}.installed_at` | 설치 시각 | ISO 8601 (`"2026-04-09T12:00:00Z"`) | 필수 — 설치 시 자동 기록 |
| `extensions.verify.preset` | verify 프리셋 이름 | `"react-web"`, `"api"`, `"cli"`, `"ios"`, `"macos"` | 미설정 시 프리셋 없이 verify 실행 |
