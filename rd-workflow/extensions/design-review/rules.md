# Design Review Extension 규칙

이 파일은 design-review extension 설치 시 `rd-workflow/claude_skills/design-review/`에 복사되어 자동으로 활성화된다.

## 적용 시점
- spec/plan review 통과 후, 구현 전
- UI 작업(화면, 컴포넌트, 레이아웃, 스타일 변경)으로 판단될 때

## 동작
- AI가 "UI 작업인 것 같은데 디자인 리뷰를 할까요?"로 추천
- 사용자가 수락하면 /design-review skill 실행
- 사용자가 거절하면 기본 흐름 그대로 진행

## spec 작성 규칙
- UI 작업인 경우 spec에 `## Design Reference` 섹션 권장
- 레퍼런스 형태 자유: 참고 URL, Figma 링크, 스크린샷, 텍스트, 프로토타입

## final-diff-review 시
- Design Reference가 있으면 구현 스크린샷과 비교 권장

## CURRENT_TASK.md
- `## Design Review` 필드 사용 (-, not-required, approved, revision-requested)
