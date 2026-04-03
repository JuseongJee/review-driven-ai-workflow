# Workflow

이 문서는 전체 작업 흐름을 한 페이지에 모아 둔 문서입니다.

평소에는 `WORKING_WITH_AI.md`를 먼저 읽고,
큰 작업과 작은 작업의 분기가 헷갈릴 때 이 문서를 읽습니다.

## 큰 작업 vs 작은 작업 판단 기준

이 판단이 전체 흐름의 핵심 분기입니다.

**작은 작업은 사용자가 직접 지정합니다.** AI가 자체적으로 작은 작업이라고 판단하지 않습니다.
사용자가 "small-task로 처리해줘", "이건 small이야" 등 명시적으로 말한 경우에만 작은 작업 흐름을 탑니다.

작은 작업의 일반적 특징 (참고용):
- 변경 파일이 2~3개 이하
- 새 API/인터페이스를 만들지 않음
- 기존 테스트로 검증이 충분하거나 테스트 추가가 간단함
- 다른 모듈에 파급 영향이 거의 없음
- 예: 버그 수정, 문구 변경, 설정값 조정, 단순 유틸 추가

**큰 작업**으로 봐야 하는 경우:
- 여러 파일/모듈이 함께 바뀜
- 새 API, 데이터 모델, UI 흐름이 추가됨
- 기존 동작이 달라지거나 마이그레이션이 필요함
- 테스트 전략을 새로 잡아야 함
- 예: 새 기능 추가, 아키텍처 변경, 대규모 리팩터링

사용자가 small로 지정하지 않은 모든 작업은 큰 작업으로 취급합니다.

## UI 작업 판단 기준

UI 작업 여부에 따라 디자인 리뷰 단계를 추가한다.

**UI 작업 기준:**
- 화면, 컴포넌트, 레이아웃, 스타일, 프론트엔드 뷰 변경이 포함되면 UI 작업
- API만 바뀌고 화면은 그대로인 경우 비UI
- 판단이 애매하면 사용자에게 질문

**UI 작업 시 추가 단계:**
- spec 작성 시 `## Design Reference` 섹션에 참고 앱/화면 명시
- spec/plan review 통과 후 디자인 AI 프로토타입 생성 + 디자인 리뷰 gate (`/design-review`)
- final diff review 시 스크린샷 첨부하여 디자인 프로토타입과 비교

**비UI 작업:** `/design-review`를 한 번 통과하지만 즉시 `not-required`로 종료. 실질적 영향 없음.

## 기본 분기

### 작은 작업

`REQUEST 정리 -> 구현 -> 검증 -> 필요 시 final diff review -> REQUEST 아카이브`

### 큰 작업 / 기존 코드베이스의 중간 이상 변경

`REQUEST 정리 -> REQUEST review -> spec/change spec -> plan -> spec/plan review -> /design-review -> 구현 -> 검증 -> final diff review -> REQUEST 아카이브`

## REQUEST 아카이브

작업이 완료되면 현재 `REQUEST.md`를 `ai/workspace/backlog/request-archive/`에 보관합니다.

- 파일명: `YYYY-MM-DD-HHMM-작업명.md`
- 새 REQUEST로 덮어쓰기 전에 먼저 아카이브합니다
- 아카이브 후 `REQUEST.md`는 빈 템플릿으로 되돌립니다

## 기본 원칙

- skill이 있으면 skill부터 호출합니다
- skill이 없거나 원하는 출력이 안 나오면 `ai/docs/prompts/`에서 맞는 프롬프트를 꺼냅니다
- 큰 작업은 reviewed spec / plan 파일을 만든 뒤에만 구현합니다
- 범위를 벗어난 아이디어는 `ai/workspace/backlog/FUTURE_REQUESTS.md`에 적습니다

## 권장 skill 순서

- 다음 단계를 고르기 어렵다면 `workflow-router`
- 큰 작업 시작은 `request-to-reviewed-plan`
- 작은 작업 구현은 `small-task-implement`
- reviewed plan 구현은 `implement-reviewed-plan`
- UI 작업의 디자인 리뷰는 `design-review`
- 마무리는 `final-diff-review`

## 프로젝트 초기 설정

1. `PROJECT_CONTEXT.md`를 만듭니다
2. `ai/scripts/ai/{build,test,lint,typecheck}.sh`를 프로젝트 명령으로 채웁니다
3. 빈칸이나 불명확한 제약이 남아 있으면 `PROJECT_CONTEXT` review를 돌립니다

초기 설정에 쓰는 문서는 `ai/docs/prompts/examples/`에 있습니다.

## Review Pipeline

- review는 기본적으로 `prepare_review_pipeline.sh`로 세션을 만들고 `run_review_turn.sh`로 턴을 이어갑니다
- 사용자는 보통 검토 시작만 말하고, 세션 파일 작성과 턴 전환은 AI가 처리합니다
- 세부 규칙은 `ai/docs/flows/FILE_BASED_REVIEW_PIPELINE.md`에 적혀 있습니다

## Prompt 사용 위치

- 예문: `ai/docs/prompts/examples/`
- 보정: `ai/docs/prompts/recovery/`
- 수동 복구: `ai/docs/prompts/manual/`
