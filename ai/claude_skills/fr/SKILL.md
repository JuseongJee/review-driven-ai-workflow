---
name: fr
description: >
  Manage future requests — add, list, prioritize.
  Subcommands: /fr add, /fr list, /fr pri.
  Use when the user wants to manage backlog items.
user-invocable: true
disable-model-invocation: true
---

# FR — Future Request 관리

Typical user requests:
- "/fr add autopilot에서 review gate 자동화"
- "/fr list"
- "/fr pri"
- "이거 FR에 넣어줘" → `/fr add`로 라우팅
- "future request에 기록해줘" → `/fr add`로 라우팅
- "FR 목록 보여줘" → `/fr list`로 라우팅
- "FR 우선순위 검토해줘" → `/fr pri`로 라우팅

사용자가 `/fr <subcommand> [args]` 형식으로 호출하거나, 위의 자연어 요청으로 호출한다.

## 서브커맨드 라우팅

첫 번째 인자를 파싱한다:

- `add` → [/fr add](#fr-add) 섹션으로
- `list` → [/fr list](#fr-list) 섹션으로
- `pri` → [/fr pri](#fr-pri) 섹션으로
- 그 외 / 인자 없음 → 아래 사용법 출력 후 종료 (파일 수정 없음 보장)

**Legacy call 처리**: 첫 번째 단어가 `add`, `list`, `pri` 중 어느 것도 아니면 사용법 help를 출력한다. 파일을 절대 수정하지 않는다.

### 사용법 출력

```
/fr 사용법:
- `/fr add 내용` — FR 등록
- `/fr list` — 활성 항목 목록 출력
- `/fr pri` — 우선순위 검토

예: `/fr add autopilot에서 review gate 자동화`
```

---

## /fr add {#fr-add}

`add` 뒤의 텍스트를 입력으로 받아 Future Request를 등록한다.

### 절차

1. `ai/workspace/backlog/FUTURE_REQUESTS.md` 읽기 (인덱스 형식 확인 + 중복 체크).
2. 입력에서 다음을 추출한다:
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

### 규칙

- 같은 short-title이 인덱스에 이미 있거나 `items/` 에 같은 파일명이 존재하면 등록하지 않고 사용자에게 알린다. (done/dropped로 인덱스에서 삭제된 항목도 상세 파일이 남아있으므로 파일 존재 여부를 반드시 확인한다.)
- 입력이 너무 짧아서 summary를 만들 수 없으면 한 줄 질문으로 보충을 요청한다.
- FUTURE_REQUESTS.md의 기존 형식(테이블 구조, 상태 값)을 변경하지 않는다.
- 이 subcommand는 FR 등록만 한다. REQUEST.md 작성이나 구현은 하지 않는다.

---

## /fr list {#fr-list}

활성 FR 항목을 우선순위 순으로 출력한다. **읽기 전용 — 파일 수정 없음.**

### 절차

1. `ai/workspace/backlog/FUTURE_REQUESTS.md` 읽기.
2. 인덱스에서 status가 `idea` / `validated` / `ready-for-request` 인 항목만 추린다.
3. 인덱스의 우선순위 컬럼을 기준으로 정렬: P1 → P2 → P3 → unranked (`-`). 동순위는 날짜 오름차순.
4. 결과 테이블 출력:

```
| # | 우선순위 | 날짜 | 제목 | 요약 | 상태 |
```

활성 항목이 0개이면: `활성 항목이 없습니다` 출력.

---

## /fr pri {#fr-pri}

활성 FR 항목의 우선순위를 AI가 제안하고 사용자 확인 후 상세 파일에 반영한다.

### 절차

1. `ai/workspace/backlog/FUTURE_REQUESTS.md` 읽기.
2. 활성 항목(idea / validated / ready-for-request)의 인덱스 행에서 현재 우선순위를 확인하고, 상세 파일에서 `summary`, `why`, `related context`를 수집.
   - 상세 파일이 없으면 해당 항목을 건너뛰고 경고 출력.
3. `PROJECT_CONTEXT.md` 읽기 (맥락 기반 판단 기준으로 사용. REQUEST.md 사용 금지 — 이 backlog는 전역 기준).
4. 다음 기준으로 각 항목에 P1 / P2 / P3 부여 + 한 줄 근거 작성:
   - 프로젝트 목표와의 관련성
   - 사용자 경험 / 안정성 영향도
   - 노력 대비 가치
   - 다른 항목과의 의존 관계
5. 결과 테이블을 사용자에게 출력:

```
| 제목 | 이전 | 신규 | 근거 |
```

6. 사용자 확인 요청. **확인 전에는 파일을 절대 수정하지 않는다.**
7. 확인 후: `FUTURE_REQUESTS.md` 인덱스의 우선순위 컬럼을 업데이트한다.

활성 항목이 0개이면: `검토할 활성 항목이 없습니다` 출력.

---

## 전역 규칙

- `priority` 허용 값: `P1`, `P2`, `P3`, `-` 만 허용. 인덱스에서만 관리하고 상세 파일에는 넣지 않는다.
- `/fr pri`에서 사용자 확인 전에는 어떤 파일도 수정하지 않는다.
- `/fr add`는 FR 등록만 한다. REQUEST.md 작성, 구현 착수 금지.
- 서브커맨드가 없거나 알 수 없으면 사용법만 출력하고 종료한다. 파일 수정 없음.
