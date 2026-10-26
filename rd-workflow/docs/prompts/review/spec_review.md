rd-workflow-workspace/specs/와 rd-workflow-workspace/plans/의 최신 문서를 검토해줘.

검토 기준
- 과도한 설계 여부
- 빠진 엣지 케이스
- 더 단순한 대안
- 테스트 전략 누락
- 플랫폼별 리스크(web / macOS / iOS)
- 변이 명세: plan 이 테스트의 필수 대상 단언(부정 명제·회귀)을 새로 만들거나 바꾸면(기존 테스트에 단언을 더하는 경우 포함) 그 단언마다 FAIL 을 유발할 `변이:` 줄이 있는가. 누락되거나 그 변이로 단언이 실패하지 않을 것으로 보이면 이의 (`rd-workflow/docs/guides/mutation-check.md`)

출력
- 문제점
- 개선 제안
- 꼭 수정해야 할 항목
