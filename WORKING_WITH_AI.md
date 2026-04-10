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
| 템플릿 업데이트 | "ai/docs/guides/sync_template.md 읽고 템플릿 업데이트 진행해줘" |

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

## 스킬 목록

### 직접 호출 (`/명령`)

| 명령 | 설명 | 예시 |
|------|------|------|
| `/fr add` | Future Request 등록 | `/fr add 리뷰 리포트 자동 요약` |
| `/fr list` | FR 목록 출력 | `/fr list` |
| `/fr pri` | FR 우선순위 검토 | `/fr pri` |
| `/review-config` | 리뷰 도구 현황 확인 | `/review-config` |
| `/review-config setup` | 리뷰 도구 대화형 설정 (priority, model) | `/review-config setup` |
| `/tpl update` | 최신 템플릿으로 업데이트 | `/tpl update` |
| `/comprehensive-audit` | 프로젝트 전방위 감사 | `/comprehensive-audit` |

### 자연어로 요청

| 요청 예시 | 동작 |
|----------|------|
| "이 요구사항으로 진행해줘" | REQUEST → review → spec/plan → 구현 |
| "small-task로 구현해줘" | 바로 구현 (review 최소화) |
| "autopilot으로 돌려줘" | FUTURE_REQUESTS에서 작업 꺼내 자동 실행 |
| "이 기획문서로 REQUEST 만들어줘" | 외부 문서 → REQUEST 변환 |

### 내부 전용 (AI가 자동 사용)

| 스킬 | 역할 |
|------|------|
| workflow-router | 다음 단계 스킬 추천 |
| implement-reviewed-plan | 리뷰된 plan으로 구현 |
| final-diff-review | 구현 후 최종 diff 리뷰 |
| gap-check | spec ↔ 구현 간 누락 점검 |

## 잘 안 될 때

| 상황 | 해결 |
|------|------|
| AI가 워크플로를 안 따를 때 | "CLAUDE.md 다시 읽고 워크플로대로 진행해" |
| skill이 원하는 출력을 안 낼 때 | `ai/docs/prompts/recovery/` 참조 |
| 자동 review가 안 될 때 | `ai/docs/prompts/manual/` 참조 |
| 검증 스크립트만 다시 채우고 싶을 때 | "프로젝트 파일 읽고 검증 스크립트 채워줘" |
