# Working With AI

일상적으로 AI에게 말하는 방법을 정리한 치트시트입니다.
상세 워크플로는 `ai/docs/flows/WORKFLOW.md`, 전체 규칙은 `CLAUDE.md`를 참조하세요.

## 상황별 프롬프트

| 하고 싶은 것 | 이렇게 말하면 됩니다 |
|-------------|---------------------|
| 프로젝트 초기 설정 | "프로젝트 분석해서 PROJECT_CONTEXT.md 채워줘" |
| 큰 작업 시작 | "이 요구사항으로 진행해줘: ..." |
| 작은 작업 바로 구현 | "small-task로 바로 구현해줘: ..." |
| 아이디어 기록 | "future request에 기록해줘" |
| 기록된 아이디어 조회 | "future request 목록 보여줘" |
| 아이디어를 작업으로 승격 | "이거 REQUEST로 올려서 진행해줘" |
| 템플릿 업데이트 | "템플릿 최신으로 업데이트해" |

## 각 단계에서 할 일

| 단계 | 사용자 | AI |
|------|--------|-----|
| REQUEST 작성 | 목표와 제약을 전달 | REQUEST.md 정리 |
| REQUEST review | 피드백 확인, 보완 판단 | 모호함·리스크 짚어줌 |
| spec / plan | 설계안 리뷰, 승인 | spec·plan 작성 |
| spec/plan review | 리뷰 결과 확인 | 교차 리뷰 수행 |
| 구현 | 진행 상황 확인 | 코드 작성 |
| 검증 | 결과 확인 | 테스트·린트·타입체크 실행 |
| diff review | 최종 승인 | 변경사항 리뷰 |

## 잘 안 될 때

| 상황 | 해결 |
|------|------|
| AI가 워크플로를 안 따를 때 | "CLAUDE.md 다시 읽고 워크플로대로 진행해" |
| 프롬프트 예문이 필요할 때 | `ai/docs/prompts/examples/` 참조 |
| skill이 원하는 출력을 안 낼 때 | `ai/docs/prompts/recovery/` 참조 |
| 자동 review가 안 될 때 | `ai/docs/prompts/manual/` 참조 |
