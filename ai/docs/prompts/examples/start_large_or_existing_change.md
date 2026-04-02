REQUEST.md와 PROJECT_CONTEXT.md를 읽고 진행해줘.

이번 작업이 `existing-code-change` 또는 `new-feature-or-large-task`라면:
- 지금은 구현하지 않는다
- 가능한 경우 Superpowers `brainstorming`과 `writing-plans`를 실행한다
- 새 기능이면 `ai/workspace/specs/base/`에 spec을 저장한다
- 기존 코드 변경이면 `ai/workspace/specs/changes/`에 change spec을 저장한다
- plan은 `ai/workspace/plans/`에 저장한다
- reviewed plan이 준비된 시점까지만 만들고 멈춘다
- spec/plan이 준비되면 review를 실행한다 (`prepare_review_pipeline.sh spec-plan` 또는 수동으로 `ai/docs/prompts/manual/review_pipeline_start_manual.md`)
- `CURRENT_TASK.md`를 업데이트한다
