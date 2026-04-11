---
name: model-strategy
description: Configure model strategy per workflow stage — interactive wizard to set recommended models for each stage (brainstorming, spec, plan, review, subagent, archive) and save to ai/config/model-strategy.json
---

# Model Strategy Setup

워크플로 단계별 모델 전략을 설정하는 대화형 위저드.

## 사용 시점

- 프로젝트 초기 설정 시
- 비용 최적화를 위해 모델 전략을 조정할 때
- `ai/config/model-strategy.json`을 생성/수정할 때

## 워크플로 단계 개요 (advisory 안내용)

아래는 각 단계의 추천 모델과 제어 방식을 정리한 참고 테이블이다. **실제 config에 저장되는 것은 `subagent`만**이다.

| 키 | 단계 | 제어 | 설명 |
|----|------|------|------|
| `orchestration` | 오케스트레이션 | advisory | 메인 세션 — 워크플로 전체 진행 |
| `brainstorming` | 브레인스토밍 | advisory | 설계 탐색, 대안 제시 |
| `spec` | spec 작성 | advisory | 설계 구조화 |
| `plan` | plan 작성 | advisory | spec → task 분해 |
| `review_author` | review author 턴 | advisory | Reviewer 피드백 반영 |
| `subagent` | subagent 구현 | **direct** | plan task 실행 (Agent dispatch) — config로 제어 |
| `archive` | 아카이브/보고 | advisory | 기계적 정리 작업 |

**direct**: Agent tool `model` 파라미터로 직접 제어. 설정이 자동 적용됨.
**advisory**: 메인 세션 모델에 의존. 사용자가 세션 시작 시 직접 선택해야 함.

## 설정 파일 형식

`ai/config/model-strategy.json`:
```json
{
  "version": 1,
  "subagent": "sonnet"
}
```

허용 모델 값: `"opus"`, `"sonnet"`, `"haiku"` — Claude Code Agent 도구의 model 파라미터와 동일.

## 위저드 흐름

### 1. 현재 설정 표시

`ai/config/model-strategy.json`을 읽는다. 파일이 없으면 "설정 없음 — subagent는 세션 모델 상속" 표시.

### 2. 추천 프리셋 제시

아래 테이블을 사용자에게 보여준다:

| 단계 | 추천 모델 | 근거 | 제어 방식 | 위험 포인트 |
|------|----------|------|-----------|------------|
| orchestration | opus | 워크플로 판단, 규칙 준수 | advisory | - |
| brainstorming | opus | 창의적 설계 판단 필요 | advisory | Sonnet은 얕은 대안 |
| spec | sonnet | 설계 완료 후 구조화 | advisory | brainstorming 품질 의존 |
| plan | sonnet | spec → task 분해 | advisory | task 경계 품질 차이 가능 |
| review_author | sonnet | 피드백 반영/수정 | advisory | Reviewer 잘못된 지적 무비판 수용 가능 |
| subagent | sonnet | plan 기반 구현 | **direct** | plan에 없는 예외 대처 약함 |
| archive | haiku | 기계적 아카이브/보고 | advisory | 복잡한 보고서 품질 저하 |

### 3. subagent 모델 선택

AskUserQuestion으로 묻는다:

> subagent 구현에 사용할 모델을 선택하세요 (추천: sonnet):
> - **opus** — 높은 품질, 높은 비용
> - **sonnet** (추천) — 충분한 품질, 비용 절감
> - **haiku** — 최저 비용, 단순 작업만

### 4. 설정 저장

`ai/config/model-strategy.json`에 기록:

```json
{
  "version": 1,
  "subagent": "<선택값>"
}
```

### 5. 요약 출력

설정 결과 + 아래 안내:

> **설정 완료:** subagent 구현 시 `<선택값>` 모델이 자동 적용됩니다.
>
> **참고:** orchestration, brainstorming, spec, plan, review_author, archive 단계는 메인 세션 모델에 의존합니다. 이 단계들의 모델을 변경하려면 Claude Code 세션을 해당 모델로 시작하세요.

## 오류 처리

- 기존 설정 파일의 JSON 파싱 실패 → 경고 출력, 새로 생성할지 확인
- 허용되지 않은 모델 값 → 경고 출력, 기본값(파라미터 생략)으로 대체
