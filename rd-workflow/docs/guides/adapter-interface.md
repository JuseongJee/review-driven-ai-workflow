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

### 대기 계약 환경변수 (두 어댑터 공통)

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `WAIT_TIMEOUT` | 절대 상한(초). 아래 `POLL_TIMEOUT`·기본값보다 우선 | 도구별 |
| `POLL_TIMEOUT` | 절대 상한의 2순위 원천 (하위 호환) | 도구별 |
| `RD_REVIEW_IDLE_TIMEOUT` | 유휴 임계(초). **`0` 이면 유휴 판별을 끄고 절대 상한만 적용** | 도구별 |
| `RD_REVIEW_OBSERVER_FALLBACK_CAP` | 관측기 고장 시 유효 상한의 천장 | `600` |
| `RD_REVIEW_HEARTBEAT` | heartbeat 주기(초) | `60` |

해석 규칙은 **"설정됐고 유효한(양의 정수) 첫 값"** 입니다 — 설정됐지만 무효한 값은 경고 후 무시하고 다음 원천으로 내려갑니다. **사용자가 지정한 더 짧은 상한은 어떤 경로에서도 늘어나지 않습니다** (관측기가 고장나 유효 상한이 조여질 때도 마찬가지입니다).

도구별 기본 임계값은 아래 「대기 계약 산출물」 표를 보십시오.

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

### 대기 계약 산출물 (두 어댑터 공통)

두 어댑터는 같은 대기 엔진(`review_wait.sh`)을 쓰므로 계약이 같습니다. 도구별로 갈리는 것은 **로그 이름과 기본 임계값, 표시 방식**뿐입니다.

| 항목 | codex | claude |
|------|-------|--------|
| 실행 중 로그 | `.codex_output.XXXXXX` | `.claude_output.XXXXXX` |
| 종료 후 로그 | `.codex_output.log` | `.claude_output.log` |
| 대기 상태 | `.review_wait_status` (**공유**) | 〃 |
| 타임아웃 마커 | `.wait_timeout.XXXXXX` (**공유**) | 〃 |
| last-message | 있음 (`--output-last-message`) | **없음** — 턴 파일을 Write 도구로 직접 생성 |
| 기본 절대 상한 | `7200` | `7200` |
| 기본 유휴 임계 | `600` | **`900`** |
| heartbeat 표시 | 로그 마지막 줄 **그대로** | **요약 + 200자 절단** |
| 타임아웃 escalation | TERM 1회 (watchdog) | TERM → grace → **KILL** |

상태 파일과 마커 이름을 공유하는 이유: 한 턴에 어댑터는 **하나만** 실행되므로 충돌이 없고, 안정 경로만 보는 소비자가 도구별 분기 없이 읽을 수 있습니다.

**유휴 임계가 다른 이유.** codex 는 실행 내내 stderr 로 진행을 내며 관측 최대 무출력 구간이 123초였습니다(600 = 약 4.9배). claude 는 `--output-format stream-json` 이 **메시지 단위**로 이벤트를 내므로, 가장 길게 침묵하는 구간이 곧 **마지막 메시지를 생성하는 구간**입니다 — 2026-09-22 실측에서 리뷰 규모 작업의 최대 무출력은 71.67초였고 그 침묵은 hang 이 아니라 정상 생성이었습니다. 침묵 길이가 **생성물 길이에 비례**해 커져 관측값이 상한의 추정치가 되지 못하므로 배수를 크게 잡았습니다(900 = 약 12.6배).

> **남는 위험:** 이것은 확률적 완화이지 증명이 아닙니다. 긴 `Write` 도구 호출 하나가 900초를 넘으면 일하는 리뷰어를 죽입니다. 회수 수단은 `WAIT_TIMEOUT` 과 `RD_REVIEW_IDLE_TIMEOUT=0` 입니다.

**claude 의 호출 형태.** `-p --output-format stream-json --verbose` 를 씁니다. 평범한 `-p` 는 종료 직전까지 아무 출력도 내지 않아(실측: 29.83초 전 구간 무출력, stderr 도 없음) **활동 신호를 만들 수 없습니다.** `--include-partial-messages` 는 쓰지 않습니다 — 최대 침묵이 3.90초로 줄지만 이벤트가 46배(31 → 1,448), 로그가 19배(약 7KB/s)로 늘고 heartbeat 가 보여줄 마지막 줄이 토큰 델타 조각이 되어 사람에게 무의미해집니다. 그 대가는 **유휴 임계를 더 낮게 잡을 수 없다**는 것입니다(탐지 시간은 두 경우 모두 임계값이 정합니다). CLI 가 이 옵션을 지원하지 않으면 **조용히 옛 형태로 되돌리지 않고** 그대로 실패를 보입니다 — 자동 fallback 은 진단을 숨깁니다.

**claude 의 타임아웃 escalation.** watchdog 이 마커를 쓴 뒤 TERM 을 보내고, grace 후에도 살아 있으면 KILL 합니다. 리더가 TERM 을 무시하면 부모의 `wait` 가 복귀하지 않아 `cleanup` 의 KILL 단계에 영원히 닿지 못하기 때문이며, SIGKILL 은 무시할 수 없으므로 `wait` 가 반드시 복귀합니다. **pgid 를 확보하지 못한 경로에서는 리더만 회수하며 자손 전체 회수를 보장하지 않습니다** — 확인되지 않은 pgid 를 추정해 그룹 신호를 보내지 않기 때문입니다(남의 그룹을 죽일 수 있습니다).

공통 계약(아래는 두 어댑터가 동일):

- `.turn_ready` 마커 (디버깅용)
- **실행 중 로그** — 도구의 stdout+stderr 전체. 정상·타임아웃·신호 종료에서 **보존**(세션당 최신 턴 1개). 안정 이름은 `.review_wait_status` 와 마찬가지로 **실행 중에는 존재하지 않습니다** — 이전 턴의 안정 로그를 spawn 전에 제거합니다. 이동은 **도구 process group 종료를 확인한 뒤** 하고, 소스가 symlink 가 아닌 정규 파일인지 확인합니다. 실행 중 경로가 소실됐거나 symlink 로 대체됐으면 보존 불가이며 `.review_wait_status` 에 그 사실을 **사유별로** 기록합니다(회수 경로는 실제로 남아 있을 때만 적습니다)
- `.review_wait_status` — 대기 상태 snapshot. **실행 중에는 존재하지 않고 종료 후에 나타납니다** (이전 턴이 발행한 안정 파일도 spawn 전에 제거하므로, 실행 중 이 경로가 보이면 계약 위반입니다). 진행 중 갱신은 세션 안 배타 `mktemp`(0600) 스트림 `.review_wait_status.XXXXXX` 에만, 그것도 **spawn 전에 열어 둔 fd 로만** 씁니다. 안정 이름으로의 rename 은 **process group 종료를 확인한 뒤 1회**만 하고, 그때 목적지가 symlink 면 링크째 제거한 뒤 교체하고 실제 디렉터리면 교체를 포기합니다.
  필드: `log_path` / `status_stream` / `observer` / `effective_cap` / `log_preserved`(`yes`\|`no`\|`pending`) / `log_preserved_reason` / `log_path_final` / `log_path_recovery` / **`outcome`**(claude 전용)

  **`outcome` — 종료 사유.** 진행 중 snapshot 은 정상·타임아웃·중단 어느 결말에서나 (경로를 빼면) 같은 모습이라, 이 필드가 없으면 터미널 출력을 놓친 사용자가 **디스크만으로는 무슨 일이 있었는지 알 수 없습니다.** 값은 `ok: claude exit 0, 턴 파일 확인됨` / `turn-missing: ...` / `group-alive: ...` / `timeout: <idle\|cap> (유효 상한 Ns, 관측기 ok\|failed, exit 124)` / `cli-failed: ...` / `signal: SIG... (exit N)` / 사유를 확정하지 못한 채 발행된 경우 `unknown` 입니다. **`ok` 는 CLI 종료 코드만으로 정해지지 않습니다** — CLI 가 `exit 0` 이어도 턴 파일을 만들지 않았으면 어댑터는 실패이므로 `turn-missing` 으로 남습니다(그 판정은 writer 가 모두 정리된 뒤 발행 직전에 합니다). 이 필드는 **발행 시점의 사실**이며, 그 뒤 일어나는 self-review 헤더 삽입의 성패는 담지 않습니다 — 헤더 삽입이 실패하면 그 사실을 화면에 알리고 `exit 1` 합니다. 엔진은 `RW_OUTCOME` 이 설정됐을 때만 이 줄을 쓰며 **codex 는 설정하지 않으므로 codex 상태 파일은 그대로입니다.**
- 어댑터가 spawn **전에** 여는 fd (모두 경로 재해석 없이 쓰고 읽기 위한 것이며 **도구 자식에게는 닫아 전달합니다** — 상속 fd 로는 마커·상태 파일에 직접 쓸 수 있고 내부 채널의 수명이 자손에 묶입니다): 로그 읽기 **부모용**·**watchdog용**(오프셋 독립을 위해 따로 엽니다) / 마커 읽기·쓰기 / 상태 스트림 append / 타이머 fifo. codex 는 여기에 last-message 읽기가 더 있습니다. cleanup 이 전부 닫습니다. **읽기 채널 open 실패는 시작 실패가 아니라 기능 저하입니다**(관측 fd 부재 → 관측기 고장 판정, 부모 쪽 fd 부재 → 해당 진단 출력 생략).
- `.wait_timeout.XXXXXX` — 타임아웃 마커. **안정 이름을 쓰지 않습니다** — spawn 전에 배타 `mktemp` 로 만들고 쓰기·읽기 fd 를 그 시점에 열어 둡니다. 파일은 시작부터 존재하고 비어 있으므로 **판정 기준은 존재가 아니라 내용**입니다. 내용은 공백 구분 세 필드 `<사유(idle|cap)> <유효상한> <관측기상태(ok|failed)>`. cleanup 시 제거

**장애 등급** (두 어댑터 공통):

| 장애 | 결과 |
|------|------|
| 쓰기 채널 실패 (로그 생성·상태 스트림·마커 fd) | **시작 실패 `exit 1`** — fallback 하지 않습니다 |
| 로그 관측 fd 확보 실패 | **관측기 고장** — 유휴 판별을 끄고 유효 상한을 `min(절대 상한, RD_REVIEW_OBSERVER_FALLBACK_CAP)` 으로 조입니다 |
| 부모용 진단 fd 확보 실패 | 해당 진단 출력만 생략, 대기는 정상 수행 |
| 시간 원천 부재 (`date` 실패) | **fail-open** — 판정을 포기하고 부모 `wait` 에 맡깁니다 |

**후처리 순서.** `wait` 복귀 → 마커·진단을 열린 fd 에서 변수로 확보 → 멱등 `cleanup`(watchdog 정리 → 그룹 종료·확인 → 로그 이동·보존 결과 → 상태 발행 → fd 정리) → 마커·rc 판정 → **그룹이 정리됐을 때만** 턴 파일 검증과 self-review 헤더 삽입. 타임아웃·실패·신호 경로에서는 부분 턴 파일이 있어도 **성공으로 취급하지 않습니다.**

## 공통 함수

공용 파일은 둘이며 **도메인이 다릅니다** — `review_common.sh` 는 세션·프롬프트·검증, `review_wait.sh` 는 프로세스 관리 전용입니다.

`review_common.sh`:
- `extract_section <file> <heading>`: 마크다운 섹션 추출
- `trim_blank_lines`: 앞뒤 공백 줄 제거

`review_wait.sh` — 대기 계약의 단일 구현입니다. 두 어댑터가 source 하며 도구별로 다른 것은 spawn 방식·로그 대상·종료 대상(pgid)·표시 포맷터뿐입니다.

| 함수 | 역할 |
|------|------|
| `rw_is_uint` | 부호 없는 정수 판정 |
| `rw_resolve_tunable` / `rw_resolve_abs_cap` / `rw_resolve_idle` | 임계값 해석 ("설정됐고 유효한 첫 값") |
| `rw_effective_cap` | 유효 상한 계산 (관측기 고장 시 조임, 사용자 지정 상한은 늘리지 않음) |
| `rw_hms` | 초를 사람이 읽는 형태로 |
| `rw_group_alive` / `rw_acquire_pgid` | process group 생존 판정과 spawn 직후 pgid 확정 |
| `rw_status_append` / `rw_status_init_snapshot` / `rw_publish_final_status` | 상태 snapshot 과 종료 후 1회 발행 |
| `rw_display_line` | heartbeat 표시값 (`RW_LINE_FORMATTER` 훅이 없으면 원본 그대로) |
| `rw_watchdog_loop` | tick 루프 — 활동 관측·상한/유휴 판정·heartbeat |

호출자는 **부모 셸에서 `RW_*` 변수를 설정**하고, watchdog 서브셸이 그것을 상속합니다. 인자 전달과 섞지 않습니다.

선택 훅:
- `RW_LINE_FORMATTER` — heartbeat 표시를 줄이는 함수 이름. **설정하지 않으면 원본 줄을 그대로 씁니다**(codex 가 이 경우입니다). 절단 책임은 전적으로 포맷터에 있으며, claude 의 `claude_format_line` 은 `assistant: tool_use Grep` 같은 요약으로 줄이고 미분류 입력도 **생략 부호를 포함해 200자 이하**로 자릅니다. 이 변환은 **표시 전용**이며 원본 로그와 활동 관측(fd 의 새 바이트 유무)에는 영향을 주지 않습니다.
- `RW_KILL_ESCALATE` — `1` 이면 타임아웃 시 TERM 후 grace 를 기다렸다가 KILL 합니다. **claude 만 설정합니다.**

## 새 어댑터 추가 절차

1. `rd-workflow/scripts/adapter_{도구명}.sh` 생성
2. 위 환경변수를 읽고, 도구를 실행하고, exit code 계약을 지킨다
3. `rd-workflow/config/review-tools.json`의 `tools`에 도구 엔트리 추가
4. `default_priority`에 원하는 위치에 도구명 추가
