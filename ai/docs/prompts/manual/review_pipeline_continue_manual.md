붙어 있는 세션 경로(예: `handoffs/review_pipeline/YYYYMMDD_HHMMSS_세션명`)와 `ai/docs/flows/FILE_BASED_REVIEW_PIPELINE.md`를 읽고 파일 기반 review를 이어줘.

절차:
1. `SESSION.md`, `CHECKPOINT.md`, 최신 턴 파일, 검토 대상을 읽는다
2. 자기 차례가 아니면 상태만 짧게 알린다
3. 자기 차례면 `turns/NNN_<agent>.md` 한 파일만 추가한다
4. `CHECKPOINT.md`와 `SESSION.md`를 갱신한다
5. 최신 Codex 턴이 `이의 없음`을 명시할 때까지 반복한다
6. 사람 결정이 필요하거나 총 턴 수가 20에 도달하면 `awaiting-user`로 바꾸고 멈춘다
