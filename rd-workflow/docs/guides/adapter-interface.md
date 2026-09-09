# 리뷰 어댑터 인터페이스

review pipeline(`run_review_turn.sh`)이 리뷰 도구를 실행할 때 사용하는 어댑터의 공통 인터페이스.

## 파일 위치

`rd-workflow/scripts/adapter_{도구명}.sh`

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
| 124 | 대기 초과 (유휴 또는 절대 상한) | **124를 그대로 전달.** 어댑터가 출력한 세션 상태·재개 안내를 신뢰하며 "오염"을 단정하지 않음 |
| 128 초과 (예: `129`=HUP, `130`=INT, `137`=KILL, `143`=TERM 등) | 외부 신호 종료 | **같은 코드를 그대로 전달.** 도구 결함이 아님을 알림. 열거가 아니라 부등식(POSIX `128+n` 규약)으로 판정하므로 열거에 없는 신호(예: OOM killer가 보내는 SIGKILL)도 같은 분기로 잡힙니다. **재실행 안내는 조건부이며 cleanup을 보장하는 신호에서만 허용됩니다.** 어댑터가 cleanup(= 도구 process group 종료)을 보장하는 것은 명시적으로 트랩한 `129`(HUP)·`130`(INT)·`143`(TERM) 뿐입니다. 이 셋에서만, 부모가 `EXPECTED_TURN_FILE` 부재 + `SESSION.md`의 `Current Owner=Reviewer` / `Status=awaiting-reviewer`를 **다시 읽어 확인한 경우에** "재실행하면 이어집니다"를 말합니다. `137`(SIGKILL, 트랩 불가)·`131`(QUIT) 등 **cleanup 미보장 신호에서는 어댑터만 죽고 별도 process group의 도구와 자손이 계속 실행·수정할 수 있으므로**(그 상태에서도 위 세션 조건은 그대로 참입니다) 재실행을 안내하지 않고, 잔존 process group 가능성과 "프로세스 종료를 확인하기 전에 재실행 금지"를 알립니다. 그 밖의 경우에는 실제 상태(턴 파일 존재 여부·두 필드 값)와 수동 확인 필요성을 알리며, 확인 범위(두 필드 + 턴 파일)도 함께 밝힙니다 |
| 그 밖의 non-zero | 실행 실패 | `1`로 매핑하고 즉시 중단 (다음 도구로 fallback 하지 않음) |

`turn_metrics.tsv`의 `status`는 `0→ok / 124→timeout / 그 외→fail`의 coarse tri-state로 **스키마가 불변**입니다. 신호 종료도 `fail`로 기록되며, 원인을 사용자에게 설명하는 책임은 위 메시지 층에 있습니다.

바이너리 미설치(`command -v` 실패)는 어댑터가 아닌 `run_review_turn.sh`에서 먼저 감지하여 건너뜀.

## 산출물

어댑터 실행 후 반드시 존재해야 하는 파일:
- `EXPECTED_TURN_FILE`: 리뷰 턴 마크다운 파일
- `SESSION.md`의 Current Owner가 Reviewer가 아닌 값으로 변경

선택적 산출물 (`adapter_codex.sh`만 해당):
- `.turn_ready` 마커 (디버깅용)
- `.codex_output.XXXXXX` → 종료 시 `.codex_output.log` — codex stdout+stderr 전체. 정상·타임아웃·신호 종료에서 **보존**(세션당 최신 턴 1개). 안정 이름은 `.review_wait_status`와 마찬가지로 **실행 중에는 존재하지 않습니다** — 이전 턴의 안정 로그를 codex spawn 전에 제거합니다. 이동은 **codex process group 종료를 확인한 뒤** 하고, 소스가 symlink가 아닌 정규 파일인지 확인합니다. 실행 중 경로가 소실됐거나 symlink로 대체됐으면 보존 불가이며 `.review_wait_status`에 그 사실을 **사유별로** 기록합니다(회수 경로는 실제로 남아 있을 때만 적습니다)
- `.review_wait_status` — 대기 상태 snapshot. **실행 중에는 존재하지 않고 종료 후에 나타납니다** (이전 턴이 발행한 안정 파일도 codex spawn 전에 제거하므로, 실행 중 이 경로가 보이면 계약 위반입니다). 진행 중 갱신은 세션 안 배타 `mktemp`(0600) 스트림 `.review_wait_status.XXXXXX`에만, 그것도 **codex spawn 전에 열어 둔 fd로만** 씁니다(경로를 다시 해석하지 않으므로 codex가 그 경로를 symlink로 바꿔도 쓰기가 세션 밖으로 새지 않습니다). 안정 이름으로의 rename은 **codex process group 종료를 확인한 뒤 cleanup에서 1회**만 하고, 그때 목적지가 symlink면 링크째 제거한 뒤 교체하고 실제 디렉터리면 교체를 포기합니다. 발행에 성공하면 스트림 파일은 남기지 않습니다.
  필드: `log_path` / `status_stream` / `observer` / `effective_cap` / `log_preserved`(`yes`\|`no`\|`pending`) / `log_preserved_reason` / `log_path_final` / `log_path_recovery`. 뒤의 네 관리 키는 발행 시 **한 번만** 렌더링되므로 재실행에도 중복되지 않습니다. 발행된 안정 파일은 모든 종료 경로에서 **보존**
- 어댑터가 codex spawn **전에** 여는 fd (모두 경로 재해석 없이 쓰고 읽기 위한 것이며 codex 자식에게는 닫아 전달합니다): last-message 읽기 / codex 로그 읽기 **부모용** / codex 로그 읽기 **watchdog용**(오프셋 독립을 위해 따로 엽니다) / 마커 읽기 / 마커 쓰기 / 상태 스트림 append. cleanup이 전부 닫습니다. **읽기 채널 open 실패는 시작 실패가 아니라 기능 저하입니다**(관측 fd 부재 → 관측기 고장 판정, 부모 쪽 fd 부재 → 해당 진단 출력 생략).
- `.wait_timeout.XXXXXX` — 타임아웃 마커. **안정 이름을 쓰지 않습니다** — codex spawn 전에 배타 `mktemp`로 만들고 쓰기·읽기 fd를 그 시점에 열어 둡니다(안정 이름은 예측 가능해 실행 중 codex가 외부 디렉터리 symlink를 심으면 마커가 세션 밖으로 나가고, 부모가 실제 타임아웃을 일반 조기 종료로 오분류합니다). 파일은 시작부터 존재하고 비어 있으므로 **판정 기준은 존재가 아니라 내용**입니다. 내용은 공백 구분 세 필드 `<사유(idle|cap)> <유효상한> <관측기상태(ok|failed)>`. cleanup 시 제거

## 공통 함수

어댑터는 `review_common.sh`를 source하여 아래 함수를 사용할 수 있다:
- `extract_section <file> <heading>`: 마크다운 섹션 추출
- `trim_blank_lines`: 앞뒤 공백 줄 제거

## 새 어댑터 추가 절차

1. `rd-workflow/scripts/adapter_{도구명}.sh` 생성
2. 위 환경변수를 읽고, 도구를 실행하고, exit code 계약을 지킨다
3. `rd-workflow/config/review-tools.json`의 `tools`에 도구 엔트리 추가
4. `default_priority`에 원하는 위치에 도구명 추가
