REQUEST.md, PROJECT_CONTEXT.md, 최신 spec 문서를 읽고 구현 plan을 작성해줘.

출력:
- 구현 단계 목록
- 수정 파일 후보
- task별 파일 목록 (Create/Modify) — phase 비중첩 판정 근거
- phase 그룹핑 (같은 phase의 task는 파일 비중첩·의존 없음)
- task별 review flag (mechanical | needs-review)
- 테스트 필요 항목
- 위험한 변경
- 롤백 또는 단계적 적용이 필요한 지점

규칙:
- plan은 `rd-workflow-workspace/plans/`에 저장한다
- 파일명은 `YYYY-MM-DD-HHMM-작업명-plan.md` 형식을 따른다
- phase·파일 목록·review flag 규약은 `rd-workflow/docs/guides/plan-parallel-phases.md`를 따른다. phase 미표현 시 순차 실행으로 degrade한다
- 구현 파일은 건드리지 않는다
- `CURRENT_TASK.md`에 plan 경로와 다음 단계를 적는다
