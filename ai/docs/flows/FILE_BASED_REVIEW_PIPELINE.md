# File-based Review Pipeline

이 문서는 review 세션을 어떻게 만들고 어떻게 끝내는지 적어 둔 규칙 문서입니다.

평소 사용 흐름:

- 사용자는 검토 시작만 말합니다
- Claude가 세션 파일과 검토 대상을 읽고 자기 턴 파일을 씁니다
- Reviewer 차례가 되면 Author가 adapter를 실행해 Reviewer 턴 파일을 만듭니다
- 사람 결정이 필요할 때만 `awaiting-user`로 바꿔 사용자에게 돌립니다

## 언제 쓰는가

- `PROJECT_CONTEXT.md` 검토
- `REQUEST.md` 검토
- spec / plan 검토
- 최종 diff 검토

## 세션 위치

- `ai/workspace/handoffs/review_pipeline/<session-id>/`

## 세션 생성

권장 명령:

- `bash ai/scripts/ai/prepare_review_pipeline.sh <review-kind> [args...]`

스크립트를 쓸 수 없을 때:

- `bash ai/scripts/ai/init_review_pipeline.sh "<session-slug>" "<review-type>" "<review-target>" "<review-goal>"`

review kind:

- `project-context`
- `request`
- `spec-plan`
- `diff`

## 세션 기본 파일

- `SESSION.md`: 상태와 현재 차례
- `CHECKPOINT.md`: 합의 내용과 열린 쟁점
- `USER_ACTION.md`: 사람에게 물을 질문
- `turns/NNN_<agent>.md`: Author / Reviewer 턴 기록

## 상태 값

- `awaiting-author`
- `awaiting-reviewer`
- `awaiting-user`
- `closed`

## 기본 흐름

1. `prepare_review_pipeline.sh`로 세션 디렉터리와 기본 파일을 만듭니다
2. Author가 세션 파일과 검토 대상을 읽습니다
3. Author가 자기 턴 파일 하나를 씁니다
4. Reviewer 차례가 되면 `run_review_turn.sh ...`를 실행해 Reviewer 턴을 생성합니다
5. 최신 Reviewer 턴에 `이의 없음`이 나올 때까지 3~4 단계를 반복합니다
6. 사람 결정이 필요하거나 총 턴 수가 20에 도달하면 `awaiting-user`로 바꿉니다

## 턴 규칙

- 자기 차례가 아니면 새 턴 파일을 만들지 않는다
- 자기 차례면 새 턴 파일 하나만 추가한다
- `CHECKPOINT.md`와 `SESSION.md`를 함께 갱신한다
- 구현이나 머지를 직접 확정하지 않는다
- 이미 합의된 쟁점은 반복하지 않는다

## 종료 규칙

아래 중 하나면 `awaiting-user`로 전환합니다.

1. 최신 Reviewer 턴이 `이의 없음`을 명시했다
2. 사람의 우선순위 결정이나 승인 여부가 필요하다
3. 총 턴 수가 20에 도달했다

`awaiting-user` 전환 시:

- `SESSION.md`의 `Status`를 `awaiting-user`로 바꿉니다
- `Current Owner`를 `User`로 바꿉니다
- `CHECKPOINT.md`에 현재 결론과 남은 쟁점을 적습니다
- `USER_ACTION.md`에 사용자 질문을 남깁니다

## 리뷰 요약 report

리뷰 세션이 종료(`awaiting-user` 또는 `closed`)되면, 요약 report를 작성한다.

저장 위치: `ai/workspace/reports/reviews/YYYY-MM-DD-HHMM-작업명-<review종류>.md`

review종류: `request-review`, `spec-plan-review`, `diff-review`, `project-context-review`

형식:

```markdown
# [Review 종류] 요약

- 일시: YYYY-MM-DD HH:MM
- 세션: ai/workspace/handoffs/review_pipeline/<session-id>/
- 대상: [검토 대상 파일/경로]

## 주요 쟁점
1. [쟁점] — Author: [입장] / Reviewer: [입장]

## 결론
1. [합의 내용과 근거]

## 반영 내역
- [변경한 내용]
```

## 수동 fallback

Claude가 CLI를 실행할 수 없을 때만 `ai/docs/prompts/manual/` 안의 프롬프트를 사용합니다.

- 시작: `review_pipeline_start_manual.md`
- 이어가기: `review_pipeline_continue_manual.md`

## 관련 스크립트

- `ai/scripts/ai/prepare_review_pipeline.sh`
- `ai/scripts/ai/init_review_pipeline.sh`
- `ai/scripts/ai/run_review_turn.sh`
- `ai/scripts/ai/review_common.sh`
- `ai/scripts/ai/adapter_codex.sh`
- `ai/scripts/ai/adapter_claude.sh`

## 리뷰 도구 설정

설정 파일: `ai/config/review-tools.json`

예제를 복사해서 시작:

```bash
cp ai/config/review-tools.json.example ai/config/review-tools.json
```

주요 설정:

| 키 | 설명 | 기본값 |
|----|------|--------|
| `default_priority` | 도구 우선순위 | `["codex", "claude"]` |
| `tools.<name>.bin` | 바이너리 경로 (`null`이면 PATH 탐색) | `null` |
| `tools.claude.self_review_warning` | 셀프 리뷰 경고 표시 | `true` |
| `overrides.<type>.priority` | 리뷰 타입별 우선순위 오버라이드 | - |

`REVIEW_TOOLS_CONFIG` 환경변수로 설정 파일 경로를 override할 수 있다.

`jq`가 설치되지 않으면 설정 파일을 무시하고 기본값(`codex → claude`)으로 동작한다.
설정 파일이 없어도 기본값으로 동작한다.
