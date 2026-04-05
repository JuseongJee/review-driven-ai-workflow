# FUTURE_REQUESTS

현재 작업 범위 밖이지만 나중에 별도 task로 다룰 후보 목록.

## 상태 값

- `idea`: 아직 검증 안 됨
- `validated`: 필요성 확인, 우선순위 아님
- `ready-for-request`: REQUEST.md로 바로 올릴 수 있음
- `done` / `dropped`: 상세 파일에서 상태만 변경 (별도 이동 불필요)

## 기록 원칙

- 이 파일은 **인덱스**만 관리한다. 항목 상세는 `items/YYYY-MM-DD-제목.md`에 작성한다.
- 인덱스 행에는 반드시 **요약** 컬럼을 포함한다. 상세 파일을 열지 않아도 내용을 파악할 수 있어야 한다.
- "왜 필요한지"와 "왜 지금 안 하는지"를 상세 파일에 같이 적는다.
- 하나의 항목은 독립된 REQUEST.md로 승격 가능한 단위로 쓴다.

## 항목 템플릿

상세 파일 형식: `items/YYYY-MM-DD-short-title.md`

```md
# YYYY-MM-DD short-title
- status: idea
- kind: feature | bug | refactor | tech-debt | tooling | research | test
- summary: 한두 문장 요약
- why: 왜 필요한지
- related context: 어디서 발견했는지
- related files: file/path/a, file/path/b
- not now because: 왜 지금 안 하는지
- request seed: REQUEST로 만들 때 쓸 초안
```

상세 가이드: `ai/docs/prompts/guides/record_future_request.md`

---

## 인덱스

| 날짜 | 제목 | 요약 | 상태 | 상세 |
|------|------|------|------|------|
