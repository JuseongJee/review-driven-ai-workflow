이 자유 텍스트 요구사항으로 `REQUEST.md` 작성부터 spec / plan review 완료 직전까지 한 번에 진행해줘.

진행 규칙:
1. `PROJECT_CONTEXT.md`를 먼저 읽는다
2. `REQUEST.md`가 비어 있거나 현재 요구사항과 다르면 새로 쓴다
3. 범위를 넓히지 말고 꼭 필요한 정보만 질문한다
4. `Execution Path`를 판단한다
5. `small-task`면 이유만 남기고 멈춘다
6. 큰 작업이면 `REQUEST review -> spec/change spec -> plan -> spec/plan review` 순서로 진행한다
7. review는 `prepare_review_pipeline.sh`와 `run_review_turn.sh codex ...`를 사용한다
8. Superpowers를 쓸 수 있으면 그 workflow를 실행하고, 아니면 같은 위치에 같은 산출물을 만든다
9. 구현은 하지 않는다
10. `CURRENT_TASK.md`를 업데이트한다

마지막 출력:
- Execution Path
- REQUEST 상태
- spec 경로
- plan 경로
- request review session path
- spec / plan review session path
- 다음 추천 단계
- 남은 사용자 질문
