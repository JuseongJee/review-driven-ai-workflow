# ADR-0003: FUTURE_REQUESTS 네이밍 유지

## 상태
승인

## 맥락
폴더명은 `rd-workflow-workspace/backlog/`인데 파일명은 `FUTURE_REQUESTS.md`로, 용어가 불일치하는 것처럼 보인다. "backlog"로 통일하는 것이 더 보편적이지 않은가 하는 질문이 제기됨.

## 결정
FUTURE_REQUESTS 네이밍을 유지한다.

## 근거
- "backlog"는 "정리되어 바로 작업할 수 있는 항목"이라는 뉘앙스가 있음
- FUTURE_REQUESTS는 "아직 REQUEST로 승격되지 않은 후보"라는 이 프로젝트 고유의 의미를 정확히 전달
- 상태 흐름(idea → validated → ready-for-request → done)이 일반 backlog와 다름
- `backlog/`는 상위 카테고리(아카이브, parked 포함), `FUTURE_REQUESTS.md`는 그 안의 활성 후보 목록
- 바꾸면 파일명, 문서 참조, skill, 대화 용어 등 영향 범위가 넓은 데 비해 실익이 없음

## 결과
- FUTURE_REQUESTS.md, FUTURE_REQUESTS_PARKED.md 네이밍 유지
- /fr skill 이름 유지
- 폴더 `backlog/`는 상위 카테고리로 유지
