# PR Template

<!-- final diff review 에서는 이 본문을 Author 턴의 `## PR 본문` 절에 싣는다. 완료 보고와 발행 승인 질문이 이 본문을 옮겨 쓴다. -->

## Summary
- 무엇을: 이번 변경이 무엇인지 한 문장
- 왜: 이 변경이 필요한 이유 한 문장

## User-visible Changes
<!-- 사용자·운영자·소비 프로젝트 입장으로 쓴다. 체감할 변화가 없으면 세 항목 대신 `없음 — <이유>` 한 줄. -->
- 무엇이 달라졌나:
- 어떻게 확인하나: (명령·화면·경로)
- 아직 확인되지 않은 것: (실사용에서만 드러나는 것. 없으면 `없음`)

## Technical Changes
구현 관점의 주요 변경 사항

## 되돌리기와 영향 범위
- 되돌리기: `되돌릴 수 있음` 또는 `되돌리기 어려움 — <이유>` (`REQUEST.md ## Risk Tier` 의 근거 신호를 옮겨 적음)
- 영향 범위: 영역(module·API·UI·database·infra 중 해당하는 것)과 영향받는 사용자·데이터·외부 시스템, 그 규모

## Risks
예상 리스크와 주의할 점

## Verification
- 검증 증거 (`bash rd-workflow/scripts/verify_record.sh -- <검증 명령>` 이 남긴 `rd-workflow-workspace/.lifecycle/review-seals/verify-evidence` 의 값): 명령 · exit code · 트리 해시
- 돌린 범위가 고친 영역에 충분한 이유 한 줄 (리뷰어가 판단합니다)
- lint / typecheck 결과
- 수동 확인한 항목

## Notes
리뷰어가 알아야 할 추가 정보
