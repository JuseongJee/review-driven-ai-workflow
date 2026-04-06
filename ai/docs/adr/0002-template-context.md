# ADR 0002: AI Dev Template Context

이 문서는 현재 저장소에 있는 AI 개발 템플릿을 왜 이렇게 구성했는지 설명하고,
Codex가 문서를 고치거나 검토할 때 따라야 할 설계 기준을 적어 둔 문서다.

이 문서의 목적은 다음이다.

- 템플릿 설계 의도를 읽고 파악한다
- 실제 폴더 구조와 문서를 읽고 맞는지 확인한다
- 문서 충돌과 설명 누락을 찾아 고친다
- 처음 읽는 사용자가 바로 따라갈 수 있게 문서를 마무리한다

## Background

이 템플릿은 Claude Code + Superpowers 기반 AI 코딩 워크플로를 안정적으로 운영하기 위해 만들어졌다.

대화 과정에서 다음 문제가 반복적으로 발견되었다.

### AI 코딩의 기본 문제

일반적인 AI 코딩은 다음 패턴으로 진행된다.

요구사항
-> 바로 코드 생성

이 방식은 다음 문제를 만듭니다.

- 설계 없이 코드 생성
- 변경 영향 분석 부족
- 테스트 전략 없음
- 기존 코드베이스 수정 시 혼란
- 코드 리뷰 부재

그래서 설계 -> 계획 -> 구현 순서를 강제하는 워크플로가 필요했다.

## Superpowers의 역할

Superpowers는 Claude Code의 워크플로를 구조화합니다.

특히 다음 흐름을 제공합니다.

brainstorming
-> writing-plans
-> implementation

즉

설계
-> 계획
-> 구현

순서를 강제합니다.

하지만 Superpowers는 Claude 중심 도구이기 때문에 다음 문제는 여전히 남는다.

- 요구사항 구조화 부족
- 리뷰 역할 분리 없음
- 긴 문서 분석 능력 제한
- 여러 AI 협업 구조 없음

## AI 역할 분리

이 문제를 해결하기 위해 AI 역할을 분리했다.

Claude = Builder
Codex = Critic
외부 AI(예: Gemini) = Compressor

이 구조는 opencode에서 사용되던 AI orchestration 패턴을 참고한 것이다.

### Claude (Builder)

Claude는 다음 작업에 강하다.

- 설계
- 코드 작성
- 리팩터링
- 테스트 작성

그래서 Builder 역할을 맡는다.

### Codex (Critic)

Codex는 다음 작업에 강하다.

- 설계 검토
- 코드 리뷰
- 변경 영향 분석

그래서 Critic 역할을 맡는다.

### 외부 AI — Compressor (예: Gemini)

긴 컨텍스트에 강한 외부 AI는 다음 작업에 강하다.

- 긴 PRD 요약
- API 문서 정리
- 로그 분석

그래서 입력 압축 역할을 맡는다.

## 템플릿 목표

이 템플릿의 목표는 다음이다.

- AI 코딩 시작 흐름을 명확히 한다
- 요구사항을 구조화한다
- 설계 -> 계획 -> 구현 순서를 강제한다
- AI 역할을 분리한다
- 리뷰 게이트를 만든다

## 문서 구조

프로젝트 루트에는 핵심 운영 문서만 둡니다.

CLAUDE.md
REQUEST.md
PROJECT_CONTEXT.md
CURRENT_TASK.md
WORKING_WITH_AI.md

이유

- Claude Code가 CLAUDE.md를 자동 로드한다
- REQUEST / CONTEXT는 작업 입력이다
- CURRENT_TASK는 상태 관리 문서다
- WORKING_WITH_AI는 일상 운영 안내 문서다

### ai 폴더

AI 운영 문서는 ai 폴더에 둡니다.

ai/docs

구성

- prompts (review/ 포함)
- flows
- guides
- adr

ai/workspace

구성

- specs (base / changes)
- plans
- backlog
- reports

## 핵심 워크플로

REQUEST
-> SPEC
-> PLAN
-> IMPLEMENT
-> VERIFY
-> REVIEW

## 새 기능

REQUEST
-> brainstorming
-> base spec
-> plan
-> 구현

## 기존 코드베이스 변경

REQUEST
-> brainstorming
-> change spec
-> plan
-> 구현

## 작은 작업

REQUEST
-> 바로 구현
-> 필요 시 plan

## spec 구조

base spec
-> 새 기능

change spec
-> 기존 코드 수정

위치

ai/workspace/specs/base
ai/workspace/specs/changes

## plan 구조

implementation plan

위치

ai/workspace/plans

## 추가 문서 역할

AI_DOC_MAP.md
-> 어떤 문서가 어디에 있는지 찾을 때 읽는다

AGENTS.md
-> AI 협업 규칙과 Git 정책을 읽는다

PR_TEMPLATE.md
-> PR 설명을 쓸 때 그대로 복사해 쓴다

7. 구현
8. 검증
9. PR 작성
10. Codex 리뷰
