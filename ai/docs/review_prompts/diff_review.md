최신 변경 diff를 리뷰해줘.

검토 기준
- 논리 버그
- 회귀 위험
- 성능 문제
- 보안 문제
- 유지보수성 저하
- 불필요한 복잡성
- CLAUDE.md 비대화: 변경이 CLAUDE.md를 수정했다면 "이 줄을 삭제해도 실수가 발생하는가?" 원칙을 적용. 200줄 이하 유지 권장
- UI 작업이고 current task spec에 `## Design Reference`가 있는 경우 디자인 fidelity:
  - 스크린샷이 디자인 프로토타입과 일치하는가
  - spec의 Design Reference에 명시된 시각적 방향과 부합하는가
  - PROJECT_CONTEXT.md에 플랫폼별 요구사항이 있으면 해당 기준 충족 여부
  - 여러 target surface/state가 요구되면 각 surface별 스크린샷 증적이 있는지
  - current task에 spec이 없거나 Design Reference가 없으면 디자인 fidelity 항목을 skip

출력
- 잠재적 버그
- 위험한 변경
- 개선 제안
- 머지 가능 여부
