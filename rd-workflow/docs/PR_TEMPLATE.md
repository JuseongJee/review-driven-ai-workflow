# PR Template

## Summary
이번 변경이 무엇인지 한두 문장으로 요약

## User-visible Changes
사용자가 실제로 보게 되는 변화

## Technical Changes
구현 관점의 주요 변경 사항

## Affected Areas
- module
- API
- UI
- database
- infra

## Risks
예상 리스크와 주의할 점

## Verification
- 검증 증거 (`bash rd-workflow/scripts/verify_record.sh -- <검증 명령>` 이 남긴 `rd-workflow-workspace/.lifecycle/review-seals/verify-evidence` 의 값): 명령 · exit code · 트리 해시
- 돌린 범위가 고친 영역에 충분한 이유 한 줄 (리뷰어가 판단합니다)
- lint / typecheck 결과
- 수동 확인한 항목

## Notes
리뷰어가 알아야 할 추가 정보
