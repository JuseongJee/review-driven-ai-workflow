# 리뷰 어댑터 인터페이스

review pipeline(`run_review_turn.sh`)이 리뷰 도구를 실행할 때 사용하는 어댑터의 공통 인터페이스.

## 파일 위치

`ai/scripts/adapter_{도구명}.sh`

## 입력 환경변수

| 변수 | 설명 | 필수 |
|------|------|------|
| `SESSION_PATH` | 리뷰 세션 디렉토리 절대 경로 | Y |
| `PROMPT_FILE` | 리뷰 프롬프트가 담긴 임시 파일 경로 | Y |
| `EXPECTED_TURN_FILE` | 어댑터가 생성해야 할 턴 파일 경로 | Y |
| `TOOL_BIN` | 도구 바이너리 경로 (빈 문자열이면 도구명을 기본값으로 사용) | Y |
| `PROJECT_ROOT` | 프로젝트 루트 절대 경로 | Y |
| `TOOL_MODEL` | 모델 식별자 (빈 문자열이면 도구 기본값 사용) | N |
| `SELF_REVIEW_WARNING` | self-review 경고 표시 여부 (`true`/`false`) | N |

## Exit Code

| Code | 의미 | run_review_turn.sh 동작 |
|------|------|------------------------|
| 0 | 턴 정상 완료 | 후처리 진행 |
| 1 | 실행 실패 | 즉시 중단 (다음 도구로 fallback 하지 않음) |

바이너리 미설치(`command -v` 실패)는 어댑터가 아닌 `run_review_turn.sh`에서 먼저 감지하여 건너뜀.

## 산출물

어댑터 실행 후 반드시 존재해야 하는 파일:
- `EXPECTED_TURN_FILE`: 리뷰 턴 마크다운 파일
- `SESSION.md`의 Current Owner가 Reviewer가 아닌 값으로 변경

선택적 산출물:
- `.turn_ready` 마커 (`adapter_codex.sh`만 해당, 디버깅용)

## 공통 함수

어댑터는 `review_common.sh`를 source하여 아래 함수를 사용할 수 있다:
- `extract_section <file> <heading>`: 마크다운 섹션 추출
- `trim_blank_lines`: 앞뒤 공백 줄 제거

## 새 어댑터 추가 절차

1. `ai/scripts/adapter_{도구명}.sh` 생성
2. 위 환경변수를 읽고, 도구를 실행하고, exit code 계약을 지킨다
3. `ai/config/review-tools.json`의 `tools`에 도구 엔트리 추가
4. `default_priority`에 원하는 위치에 도구명 추가
