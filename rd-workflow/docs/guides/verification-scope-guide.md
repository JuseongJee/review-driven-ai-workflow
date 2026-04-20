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

## pre-commit hook의 staged 경로 기반 분기

기본 제공되는 `rd-workflow/scripts/hooks/pre_commit_verify.sh`는 staged 파일의 경로만 보고 검증 실행 여부를 결정한다. 전체 repo 재검증이 아니다.

### 동작

1. `git diff --cached --name-status -M --diff-filter=ACMRDT`로 staged 변경 레코드 수집.
2. 각 레코드의 경로(rename은 source + destination 양쪽)를 문서 패턴과 대조.
3. **모든** 경로가 문서 패턴에 매칭되면 → 검증 스킵하고 커밋 진행.
4. 하나라도 비문서 경로면, 또는 미인식 status/`git` 실패 등 `unknown`이면 → `test.sh`/`lint.sh`/`typecheck.sh` 실행.

### 기본 문서 패턴

아래 4개 패턴이 하드코딩되어 있으며, `[[ $path == $pattern ]]` Bash 매칭으로 평가된다 (`globstar` 미사용, Bash 3.2 호환).

- `*.md` — 모든 경로의 md 파일
- `rd-workflow-workspace/*` — 워크플로 산출물 디렉토리 하위 전체
- `docs/*` — 프로젝트 상위 문서 디렉토리 하위 전체
- `rd-workflow/docs/*` — rd-workflow 템플릿이 설치된 프로젝트 내부 문서 디렉토리

### Override: `PRE_COMMIT_DOC_PATHS` 환경변수

문서 패턴을 프로젝트별로 조정할 수 있다. 공백 구분 glob 리스트.

- **미설정 (unset)**: 위 기본값 4개 사용.
- **설정됨 (빈 문자열 포함 어떤 값이라도)**: env var 값으로 기본값을 **대체**(확장 아님). 빈 문자열이면 패턴 0개가 되어 모든 staged 파일이 비문서로 분류되고 검증이 실행된다 (기능 비활성화 경로).

판별 방식(hook 내부)은 `"${PRE_COMMIT_DOC_PATHS+__SET__}" == "__SET__"`로 Bash 3.2에서 안전하게 set/unset을 구분한다.

**중요**: `PRE_COMMIT_DOC_PATHS`는 대체(replacement) 시맨틱이다. override를 설정하면 기본값 4개는 자동 유지되지 않는다. 기본값을 지키면서 경로만 추가하려면 기본 4개 패턴을 override 값에 **직접 포함**해야 한다.

### 사용 예

기본 동작(대부분 OK):
```bash
git commit -m "docs: update README"  # *.md 매칭 → 검증 스킵
git commit -m "fix: bump version"    # src/ 포함 → 검증 실행
```

Override로 문서 경로 추가 (기본 4개를 보존하면서 `articles/`까지 포함):
```bash
export PRE_COMMIT_DOC_PATHS='*.md rd-workflow-workspace/* docs/* rd-workflow/docs/* articles/*'
```

기본값 4개를 좁히고 싶을 때 (예: `docs/*`만 허용):
```bash
export PRE_COMMIT_DOC_PATHS='docs/*'
# 주의: *.md와 rd-workflow-workspace/*, rd-workflow/docs/*도 비문서로 처리됨
```

기능 비활성화 (모든 커밋에서 검증 실행):
```bash
export PRE_COMMIT_DOC_PATHS=''
```

### 주의사항

- **너무 넓은 glob은 검증을 사실상 무력화**한다. 예: `PRE_COMMIT_DOC_PATHS='*'`는 모든 파일을 문서로 취급 → 어떤 커밋도 검증되지 않음. 대체 시맨틱이므로 기본값이 자동 유지되지 않는다.
- 경로 매칭은 문자열 기준. 심볼릭 링크는 resolve하지 않는다.
- `rename/delete/type-change` 포함 모든 staged 타입을 커버 — 코드 파일의 rename-only/delete-only/symlink↔file 타입 변경도 "코드 포함"으로 분류되어 검증 실행.

### 테스트

Hook의 분류 로직은 `rd-workflow/scripts/hooks/test_pre_commit_verify.sh`로 격리 검증 가능하다. 11개 시나리오(md-only, code 혼합, rename/delete/type-change, override 조합, git 실패 fallback 등)를 mock git + fixture로 실행한다.

```bash
/bin/bash rd-workflow/scripts/hooks/test_pre_commit_verify.sh
```
