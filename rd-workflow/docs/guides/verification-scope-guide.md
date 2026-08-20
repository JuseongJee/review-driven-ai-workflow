# 검증 범위 가이드

AI가 검증 스크립트를 설정하거나 추천할 때 참고하는 단계별 범위 가이드.

## 단계별 권장 범위

| 단계 | 타이밍 | 권장 검증 | 금지 |
|------|--------|-----------|------|
| **pre-commit** | 커밋 직전 | syntax check, lint, format | UI test, integration test, 네트워크 호출 |
| **구현 후 (local)** | `bash rd-workflow/scripts/test.sh` 등 | unit test, lint, typecheck | 무거운 E2E, 외부 서비스 의존 테스트 |
| **CI** | push/PR 트리거 | full test, integration, E2E | - (제한 없음) |
| **verify extension** | final-diff-review 전 | 런타임 품질 검증 (Lighthouse, k6 등) | - (프리셋에 따름) |

## 핵심 원칙

1. **pre-commit은 빨라야 한다** — 5초 이내 목표. 느린 검증은 커밋 습관을 망친다.
2. **무거운 테스트는 CI로** — UI test, integration test, E2E는 로컬이 아닌 CI에서 돌린다.
3. **구현 후 검증은 균형** — unit test + lint + typecheck로 기본 품질을 확인하되, 전체 suite를 돌리지 않는다.
4. **verify extension은 선택** — 설치된 경우에만, AI가 추천하면 사용자가 결정.
5. **pre-commit은 "이 커밋의 변경"을 검증한다** — repo 전체 상태를 매번 재검증하지 않는다. 무관한 레거시 부채가 md/문서 커밋을 막으면 안 된다.

## AI가 검증을 설정할 때

- pre-commit hook에 `test` 명령을 넣지 않는다
- pre-commit에는 `lint`, `format`, `build --check` 수준만
- `PROJECT_CONTEXT.md`의 Test/Lint/Typecheck 명령을 참고하여 구현 후 검증에 사용
- 프로젝트에 CI가 없으면 구현 후 검증 범위를 넓힌다 (full test 포함 가능)

## 템플릿이 제공하는 pre-commit hook은 없습니다

이전 판에는 staged 경로를 보고 검증을 실행하던 `rd-workflow/scripts/hooks/pre_commit_verify.sh` 가 있었지만, 값어치를 증명하지 못해 제거했습니다 (게이트 정리, 2026-08-20). 위 표의 pre-commit 행은 **프로젝트가 스스로 두는 hook** 에 대한 권장 범위이며, 템플릿이 무언가를 자동으로 실행한다는 뜻이 아닙니다.
