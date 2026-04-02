# Prompt Guide

이 폴더는 상시 입력창이 아니라 보조 도구 상자입니다.

프롬프트를 꺼내야 할지 판단할 때는 이 문서를 먼저 봅니다.

## 기본 원칙

- 평소에는 입력창에 짧은 자연어 요청을 먼저 넣습니다.
- skill이 있으면 skill 이름만 붙여도 원하는 단계까지 가는 경우가 많습니다.
- 프롬프트 파일은 예문, 보정, 수동 복구에만 씁니다.

짧은 요청 예:

```text
이 요구사항으로 request-to-reviewed-plan skill로 진행해줘.
```

```text
small-task로 보고 바로 구현해줘.
```

```text
future request에 기록해줘.
```

```text
future request 후보 보여줘.
```

## 폴더 역할

`guides/`
- 설정, 마이그레이션, 템플릿 동기화 등 실행 절차 문서

`examples/`
- 평상시 입력창에 바로 넣기 쉬운 짧은 프롬프트 예시

`recovery/`
- 모델이 형식이나 절차를 자꾸 놓칠 때 그대로 붙여 넣는 보정 프롬프트

`manual/`
- review pipeline이나 특정 절차를 수동으로 시작하거나 이어갈 때 그대로 붙여 넣는 프롬프트

## 추천 사용 순서

1. 자연어로 짧게 요청
2. 원하는 문장 형태가 바로 안 나오면 `examples/`
3. 설정/마이그레이션/동기화가 필요하면 `guides/`
4. 모델이 형식이나 절차를 반복해서 놓치면 `recovery/`
5. 스크립트나 자동화가 막히면 `manual/`

## 자주 쓰는 파일

- `guides/sync_template.md`
- `guides/record_future_request.md`
- `guides/setup_with_claude.md`
- `examples/make_request.md`
- `examples/start_large_or_existing_change.md`
- `examples/implement_small_task.md`
- `recovery/request_to_reviewed_plan_full.md`
- `manual/review_pipeline_continue_manual.md`
