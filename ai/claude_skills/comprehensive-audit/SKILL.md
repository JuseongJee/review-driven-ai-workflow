---
name: comprehensive-audit
description: >
  프로젝트 코드베이스를 전방위로 감사 — 카테고리별 findings를 출력하고 FR 등록 제안.
  Use when the user wants a broad codebase review, find improvements, or audit the codebase.
user-invocable: true
disable-model-invocation: true
---

# Comprehensive Audit

프로젝트 코드베이스를 전방위로 감사한다. 카테고리별 체크리스트로 구조화된 점검을 수행하고, 발견 항목을 FR로 등록할 수 있다.

Typical user requests:
- "/audit"
- "/audit ui,perf"
- "전방위 검토 해줘"
- "개선사항 찾아줘"
- "코드 감사 해줘"
- "프로젝트 전체 점검"

## 입력 파싱

- 카테고리 인자가 있으면 (예: `/audit ui,perf,code`) 해당 카테고리만 실행
- 카테고리 인자가 없으면 전체 카테고리 대상 (자동 필터링 적용)
- 유효한 약어: ui, flow, layout, convenience, perf, code, error, security
- 잘못된 약어가 포함되면 해당 약어를 무시하고 유효한 약어만 실행. 유효한 약어가 하나도 없으면 에러 안내

## Phase 1 — 구조 스캔

1. `PROJECT_CONTEXT.md`를 읽는다
2. `Tech Stack` 섹션에서 키워드를 추출한다
3. 아래 자동 필터링 로직으로 적용 가능한 카테고리를 결정한다
4. `Tech Stack` + `Architecture Rules`에서 스캔 대상 경로를 추론한다
5. 경로 추론 실패 시 glob으로 일반적 경로를 탐색한다: `src/`, `app/`, `lib/`, `pages/`, `components/`, `Sources/`, `ios/`, `macos/`, `android/`, `Packages/`
6. 항상 제외: `node_modules/`, `dist/`, `.next/`, `build/`, `vendor/`, `.git/`, `Pods/`, `.build/`, `DerivedData/`, `.gradle/`, `*.generated.*`
7. fallback glob 결과가 0건이면 사용자에게 주요 소스 경로를 질문한다

**PROJECT_CONTEXT.md가 없거나 Tech Stack이 비어있는 경우:**
- 사용자에게 tech stack과 주요 소스 경로를 질문한다
- 답변을 받은 후 카테고리 필터링과 경로 추론을 수행한다

## 카테고리 정의

| # | 카테고리 | 약어 | 적용 조건 | 체크포인트 |
|---|---------|------|----------|-----------|
| 1 | UI/UX | ui | UI 프레임워크 있음 | 인터랙션 일관성, 접근성(a11y), 로딩/에러 상태, 폼 UX |
| 2 | Flow | flow | 라우터/페이지/화면 구조 있음 | 사용자 동선, 불필요한 단계, dead end, 네비게이션 일관성 |
| 3 | Layout | layout | UI 프레임워크 있음 | 시각적 위계, 간격 일관성, 정렬, 반응형/적응형 대응 |
| 4 | 편의 기능 | convenience | 항상 적용 | 기본값, 에러 복구, 단축키/제스처, 자동 저장, undo |
| 5 | 성능 | perf | 항상 적용 | 불필요한 연산, N+1 쿼리, 캐싱, 지연 로딩, 메모리 누수 |
| 6 | 코드 품질 | code | 항상 적용 | 패턴 일관성, 중복 코드, 과도한 추상화, 네이밍, dead code |
| 7 | 에러 처리 | error | 항상 적용 | 미처리 예외, 피드백 부재, 엣지 케이스, 유효성 검증, 재시도 |
| 8 | 보안 | security | 항상 적용 | 인젝션, 인증/인가 누락, 민감 데이터 노출, 의존성 취약점 |

## 자동 필터링 로직

Tech Stack 키워드 매칭:

| 키워드 | 활성화 카테고리 |
|--------|---------------|
| React, Vue, Svelte, Angular, Solid, Flutter, SwiftUI | ui, layout |
| Next.js, Nuxt, Remix, React Router, SvelteKit 또는 위 UI 프레임워크 중 하나라도 있으면 | flow |

- "항상 적용" 카테고리(convenience, code, error, security, perf)는 필터링하지 않는다
- 사용자가 카테고리를 명시하면 자동 필터링을 무시한다

## Phase 2 — 심층 스캔

필터링된 카테고리별로 subagent를 **병렬** 실행한다.

각 subagent 호출:
- **Agent tool** 사용, `subagent_type: "Explore"`
- **프롬프트에 포함할 정보:**
  - 카테고리 이름과 체크포인트 목록
  - 스캔 대상 경로
  - severity 기준 (아래 참조)
  - 반환 형식: `severity | 항목 | 파일:라인 | 설명`
  - "코드를 수정하지 말 것, 읽기만 할 것"
  - "발견이 없으면 빈 목록을 반환할 것"

**병렬 실행:** 독립적인 카테고리이므로 모든 subagent를 하나의 메시지에서 동시에 호출한다.

**부분 실패 처리:** subagent가 에러를 반환하거나 타임아웃되면 해당 카테고리를 "스캔 실패 — [에러 요약]"으로 표기하고, 나머지 카테고리 결과는 정상 출력한다. 전체 중단하지 않는다.

## Severity 기준

- **important**: 사용자 경험, 안정성, 보안에 직접 영향. 수정하지 않으면 문제가 됨
- **nice-to-have**: 개선하면 좋지만 현재 동작에 문제는 없음

## 결과량 제어

- 카테고리당 최대 **10건** 출력 (화면 테이블 기준)
- important를 먼저 정렬, 그 다음 nice-to-have
- 10건 초과 시 "외 N건 — audit report 파일 참조"로 요약
- 파일 저장본에는 상한 없이 전체 findings 기록

## 출력

### 1. 화면 테이블

subagent 결과를 카테고리별로 종합하여 출력한다:

```
## Audit 결과

### [카테고리명] (N건)
| Severity | 항목 | 위치 | 설명 |
|----------|------|------|------|
| important | ... | file:line | ... |
| nice-to-have | ... | file:line | ... |

### [다음 카테고리] (N건)
| ... |

---
총 N건 (important: X / nice-to-have: Y)
스캔 제외 카테고리: [카테고리명] ([이유])
```

### 2. 파일 저장

경로: `ai/workspace/reports/audits/YYYY-MM-DD-HHmmss-audit.md`

내용: 화면 테이블과 동일 + 메타데이터 헤더:

```
# Audit Report

- 일시: YYYY-MM-DD HH:MM:SS
- 적용 카테고리: [목록]
- 제외 카테고리: [목록 + 이유]
- 스캔 경로: [목록]

[findings 테이블]
```

### 3. FR 등록 제안

findings가 1건 이상이면 아래를 출력한다:

```
위 항목 중 FR로 등록할 것을 번호로 선택하세요 (예: 1,3,5 / "all" / "all important" / "all nice-to-have"):
1. [카테고리] [severity] 항목명
2. [카테고리] [severity] 항목명
...
```

- severity에 관계없이 모든 findings를 선택지에 포함한다. AI가 임의로 nice-to-have를 제외하지 않는다.
- 사용자가 번호를 선택하면 해당 항목을 `/fr add` 서브커맨드로 순차 호출한다.
- 한 finding이 하나의 FR
- `/fr add` 서브커맨드 호출만 허용 — 직접 backlog 파일 수정 불가

## 규칙

- 코드를 수정하지 않는다 — 읽기 전용 감사만 수행
- findings가 0건이고 스캔 실패 카테고리도 없으면 "발견 항목 없음"을 출력하고 종료. 스캔 실패 카테고리가 있으면 실패 표기와 report 저장을 수행한 후 종료
- 같은 날 재실행 시 기존 audit 파일을 덮어쓰지 않음 (초 단위 타임스탬프로 구분)
- 이 스킬은 구현된 코드를 감사한다 (gap-check은 spec 레벨)
- `ai/workspace/reports/audits/` 디렉토리가 없으면 생성한다
