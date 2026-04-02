# Working With AI

모든 작업 규칙, 절차, skill 안내는 `CLAUDE.md`에 정의되어 있습니다.

이 문서는 사용자가 빠르게 참조할 수 있는 요약만 남깁니다.

## 짧은 요청 예시

```text
small-task로 보고 바로 구현해줘.
```

```text
이 요구사항으로 request-to-reviewed-plan skill로 진행해줘.
```

```text
future request에 기록해줘.
```

## Skill 라우팅

```
workflow-router ─── 판단 ──┬─ small-task-implement (사용자가 small 지정 시)
                           ├─ request-to-reviewed-plan (큰 작업 시작)
                           ├─ implement-reviewed-plan (reviewed plan 구현)
                           └─ final-diff-review (마무리)
```

## 잘 안 먹힐 때

| 상황 | 문서 |
|------|------|
| 프롬프트 전체 안내 | `ai/docs/prompts/README.md` |
| 평소 쓰는 예문 | `ai/docs/prompts/examples/` |
| skill이 원하는 출력을 안 낼 때 | `ai/docs/prompts/recovery/` |
| 자동 review가 안 될 때 | `ai/docs/prompts/manual/` |
