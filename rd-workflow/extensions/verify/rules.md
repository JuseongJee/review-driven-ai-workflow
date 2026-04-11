# Verify Extension 규칙

이 파일은 verify extension 설치 시 `rd-workflow/claude_skills/verify/`에 복사되어 자동으로 활성화된다.

## 적용 시점
- 구현·검증(test/lint/typecheck) 완료 후, final-diff-review 전
- `rd-workflow/config/verification.json`이 존재할 때

## 동작
- AI가 "verification.json이 있네요. 런타임 검증을 돌릴까요?"로 추천
- 사용자가 수락하면 /verify skill 실행
- 사용자가 거절하면 기본 흐름 그대로 진행
- 검증 실행: `bash rd-workflow/extensions/verify/verify.sh` (extension 디렉토리에서 직접 실행)

## spec 작성 규칙
- spec에 `## Verification Criteria` 섹션 권장
- REQUEST AC = "무엇이 되어야 하는가", Spec VC = "어떻게 검증하는가"
- 포맷: | ID | 대상 | 기준 | 검증 방법 | 도구 | 통과 조건 |

## review 시
- spec review: VC 품질 점검 권장
- diff review: VC 기반 판단 권장

## CURRENT_TASK.md
- `## Verify` 필드 사용 (-, not-required, passed, in-progress)

## 검증 루프
- verify.sh가 도구 실행 → AI 평가(criteria 기반) → 코드 수정 → 반복
- init_review_pipeline.sh를 직접 호출하여 review 세션 생성
- 기존 review pipeline의 Author↔Reviewer 구조 재활용

## 플랫폼 범위
- ios/macos preset은 manual starter template. 자동 verify 실행 대상이 아님.
- 스켈레톤 adapter가 exit 1 + 설정 안내를 출력. 사용자가 프로젝트에 맞게 수정해야 자동 실행 가능.
- ios/macos preset은 모든 호스트에서 `(macOS 전용)` 라벨과 함께 표시하되, non-macOS 호스트에서 선택 시 즉시 차단 + 경고한다.
- ios와 macos preset은 동일한 XCUITest 스켈레톤 adapter를 공유한다. verification.json의 tool 참조만 다르고, adapter 동작(exit 1 + 안내)은 동일하다.
