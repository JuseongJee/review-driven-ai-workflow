붙어 있는 메타데이터(`session slug`, `review type`, `review target`, `review goal`)와 `rd-workflow/docs/flows/FILE_BASED_REVIEW_PIPELINE.md`를 읽고 review 세션을 수동으로 시작해줘.

이 프롬프트는 `prepare_review_pipeline.sh`를 쓸 수 없을 때만 사용합니다.

절차:
1. `bash rd-workflow/scripts/init_review_pipeline.sh "<session-slug>" "<review-type>" "<review-target>" "<review-goal>"`로 세션을 만듭니다. 안 되면 같은 구조를 직접 만듭니다
2. `SESSION.md`, `CHECKPOINT.md`, `USER_ACTION.md`를 채웁니다
3. `turns/001_claude.md`를 작성합니다
4. `CHECKPOINT.md`에 열린 쟁점과 Codex에게 넘길 질문을 정리합니다
5. `SESSION.md`를 `awaiting-reviewer`로 바꾸고 멈춥니다

규칙:
- 메타데이터를 추측하지 말 것
- 총 턴 수는 20개를 넘기지 말 것
