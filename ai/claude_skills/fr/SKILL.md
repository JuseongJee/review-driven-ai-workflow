---
name: fr
description: Register a future request to FUTURE_REQUESTS.md index and items/ detail file in one step. Use when the user wants to log an idea, feature request, or backlog item for later.
user-invocable: true
disable-model-invocation: true
---

# FR — Future Request 등록

사용자가 `/fr 설명` 으로 future request를 한번에 등록한다.

Typical user requests:
- "/fr autopilot에서 review gate 자동화"
- "/fr 템플릿 영어 버전"
- "이거 FR에 넣어줘"
- "future request에 기록해줘"

## 절차

1. Read `ai/workspace/backlog/FUTURE_REQUESTS.md` (인덱스 형식 확인 + 중복 체크).
2. 사용자 입력에서 다음을 추출한다:
   - **short-title**: 영문 kebab-case, 간결하게 (예: `autopilot-review-gate`)
   - **summary**: 한국어 한두 문장 요약
   - **kind**: feature | bug | refactor | tech-debt | tooling | research | test (맥락에서 추론, 불확실하면 feature)
3. 상세 파일 생성: `ai/workspace/backlog/items/YYYY-MM-DD-{short-title}.md`

```md
# YYYY-MM-DD {short-title}
- status: idea
- kind: {kind}
- summary: {summary}
- why: {사용자 입력에서 추론, 없으면 "-"}
- related context: {대화 맥락에서 추론, 없으면 "-"}
- related files: {관련 파일, 없으면 "-"}
- not now because: {왜 지금 안 하는지, 없으면 "별도 작업으로 진행 예정"}
- revisit when: -
- request seed: {REQUEST로 만들 때 쓸 초안, 없으면 summary 반복}
```

4. `FUTURE_REQUESTS.md`의 `## 인덱스` 테이블 끝에 행 추가:

```
| {날짜} | {short-title} | {summary} | idea | [상세](items/YYYY-MM-DD-{short-title}.md) |
```

5. 완료 메시지 출력:

> FR 등록: **{short-title}** — {summary}

## 규칙

- 같은 short-title이 인덱스에 이미 있거나 `items/` 에 같은 파일명이 존재하면 등록하지 않고 사용자에게 알린다. (done/dropped로 인덱스에서 삭제된 항목도 상세 파일이 남아있으므로 파일 존재 여부를 반드시 확인한다.)
- 사용자 입력이 너무 짧아서 summary를 만들 수 없으면 한 줄 질문으로 보충을 요청한다.
- FUTURE_REQUESTS.md의 기존 형식(테이블 구조, 상태 값)을 변경하지 않는다.
- 이 skill은 FR 등록만 한다. REQUEST.md 작성이나 구현은 하지 않는다.
