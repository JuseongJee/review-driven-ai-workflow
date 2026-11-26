---
name: model-strategy
description: Configure model strategy per workflow stage — show stage recommendations and set the implementation subagent model·effort in rd-workflow/config/models.json
---

# Model Strategy Setup

워크플로 단계별 모델 추천을 보여 주고, 구현 subagent 의 모델·effort 를 `rd-workflow/config/models.json` 에 저장하는 대화형 위저드.

## rd-workflow 버전 대조

이 skill 은 아래 `RD_SKILL_BASE` 보다 나중에 배포된 rd-workflow 를 전제한다. 첫 작업 단계보다 먼저, 프로젝트 루트에서 아래 명령을 이 호출에서 한 번 실행한다.

- 출력이 없으면 그대로 진행한다.
- 출력이 있으면 출력 전문을 사용자에게 알리고, 템플릿을 sync 할지 그대로 계속할지 묻고 멈춘다. 사용자가 계속을 지시하면 진행한다.
- autopilot·무인 실행처럼 물을 사람이 없으면 계속하지 않고 그 출력을 중단 사유로 보고한다.

```bash
bash -s <<'RD_SKILL_COMPAT'
RD_SKILL_BASE=2026-11-21-001711 RD_SKILL_NAME=model-strategy
vf="rd-workflow/VERSION"
if [ ! -f "$vf" ] && [ -f "_ROOT_FILES/rd-workflow/VERSION" ]; then exit 0; fi
v=""; [ -f "$vf" ] && v="$(cat "$vf")"; v="${v#lite-}"
if [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ ]] && [[ "$v" > "$RD_SKILL_BASE" ]]; then exit 0; fi
echo "rd-workflow 버전 불일치 — skill '$RD_SKILL_NAME' 은 $RD_SKILL_BASE 보다 나중에 배포된 rd-workflow 가 필요합니다."
echo "프로젝트: $PWD"
echo "프로젝트 VERSION: ${v:-없음} (파일: $vf)"
echo "이 상태로 진행하면 skill 이 가리키는 문서 절·스크립트·인자가 없어 중간에 실패할 수 있습니다."
echo "해결: 템플릿을 sync 하십시오 (/tpl update 또는 rd-workflow/docs/guides/sync_template.md 절차)."
RD_SKILL_COMPAT
```

## 사용 시점

- 프로젝트 초기 설정 시
- 비용 최적화를 위해 모델 전략을 조정할 때
- 구현 subagent 의 모델·effort 를 바꿀 때

## 워크플로 단계 개요 (advisory 안내용)

아래는 각 단계의 추천 모델과 제어 방식을 정리한 참고 테이블이다. **세션 기동을 뺀 나머지 단계는 advisory 이고, 이 위저드가 쓰는 칸은 `models.json` 의 `subagent.claude.model`·`subagent.claude.effort` 뿐이다.** 이 위저드는 옛 파일 `model-strategy.json` 을 만들거나 고치지 않는다.

| 키 | 단계 | 제어 | 설명 |
|----|------|------|------|
| `orchestration` | 오케스트레이션 | advisory | 메인 세션 — 워크플로 전체 진행 |
| `brainstorming` | 브레인스토밍 | advisory | 설계 탐색, 대안 제시 |
| `spec` | spec 작성 | advisory | 설계 구조화 |
| `plan` | plan 작성 | advisory | spec → task 분해 |
| `review_author` | review author 턴 | advisory | Reviewer 피드백 반영 |
| `subagent` | subagent 구현 | **direct** | plan task 실행 (Agent dispatch) — `models.json` 의 `subagent.claude.*` 로 제어 |
| `archive` | 아카이브/보고 | advisory | 기계적 정리 작업 |

**direct**: Agent 도구 `model`·`effort` 인자로 직접 제어. 값은 `models.json` 의 `subagent.claude.*` 에서 온다.
**advisory**: 메인 세션 모델에 의존. 사용자가 세션 시작 시 직접 선택해야 함.

## 설정 파일 형식

`rd-workflow/config/models.json` 의 `subagent` 절:
```json
{
  "subagent": {
    "claude": {
      "model": "sonnet",
      "effort": null
    }
  }
}
```

| 칸 | 허용값 | 비어 있을 때(칸 없음·`null`) |
|----|--------|------------------------------|
| `subagent.claude.model` | `opus`, `sonnet`, `haiku`, `fable` (Agent 도구 별칭), `default`(모델을 넘기지 않음), `null`(칸 비우기) | 옛 키 `model-strategy.json` 의 `subagent`, 그것도 없으면 `sonnet` |
| `subagent.claude.effort` | `low`, `medium`, `high`, `xhigh`, `max`, `default`(넘기지 않음), `null`(칸 비우기) | effort 를 넘기지 않음 |

고정 모델 이름(`claude-…`·`fable-…`)은 Agent 도구가 받지 않아 경고 뒤 `sonnet` 으로 대체된다. `models.json` 을 해석할 수 없으면 경고 뒤 `sonnet` 이고 옛 키로 내려가지 않는다.

적용값과 출처는 아래 명령으로 확인한다. 출력은 `model=`, `effort=`, `설정 파일:`, 표시 줄 네 줄이고 경고는 stderr 로 나온다.

```bash
bash rd-workflow/scripts/model_select.sh subagent
```

### 옛 키 — `model-strategy.json`

`rd-workflow/config/model-strategy.json` 의 `subagent`·`session_model` 은 옛 키다. 읽기만 하고, 쓰면 `models.json` 으로 옮기라고 안내한다. 이 위저드는 이 파일을 만들거나 고치지 않는다. 파일에 이미 있는 값은 그대로 둔다.

### `session_model` — 세션 기동 전용 (옛 키)

`subagent` 와 소비 경로가 다르다. 아래 표로 구분한다.

| 키 | 소비 스크립트 | 적용 방식 | 파일 없음/키 없음 | 허용 범위 밖 |
|----|--------------|-----------|-------------------|-------------|
| `subagent` (옛 키, 읽기만) | `model_select.sh subagent` | `models.json` 의 `subagent.claude.model` 이 비었을 때만 읽어 Agent 도구 `model` 인자로 dispatch | 기본값 `sonnet` | 경고 후 `sonnet` |
| `session_model` (옛 키, 읽기만, `models.json` 으로 옮김 안내) | `rd-workflow/scripts/lifecycle/session_launch.sh` | `claude` CLI `--model` 플래그(자동·수동 기동 모두) | 현재 세션 모델 상속, 실패 시 미지정(CLI 기본값) | 경고 후 미지정 |

새 자리는 `rd-workflow/config/models.json` 의 `session.claude.model` 과 `session.claude.effort` 입니다. 옛 키는 읽기만 하고, 쓰면 promote 가 `models.json` 으로 옮기라고 안내합니다.

세션 기동의 우선순위는 칸마다 아래와 같습니다. 높은 것부터입니다.

| 순서 | 모델 | effort |
| --- | --- | --- |
| 1 | `RD_SESSION_MODEL` | `RD_SESSION_EFFORT` |
| 2 | `models.json` `session.claude.model` | `models.json` `session.claude.effort` |
| 3 | 이 파일의 `session_model` (옛 키) | 없음 |
| 4 | 현재 세션 상속 | 현재 세션 상속 |
| 5 | 미지정 | 미지정 |

`default` 는 그 칸에서 값을 넘기지 않습니다. 상속도 하지 않습니다. **이 위저드는 `session_model` 을 만들거나 지우지 않는다.**

#### 상속은 무엇을 읽는가 (2026-09-21)

`session_launch.sh` 가 `CLAUDE_CODE_SESSION_ID` 로 transcript
(`~/.claude/projects/*/<세션 id>.jsonl`)를 찾아 마지막 유효 `message.model` 을 쓴다.
설정 파일이 없어도 작업 탭이 부모와 같은 모델로 뜬다 — 이 파일은 사람이 만들어야 하는데
그 사실이 여기에만 적혀 있어 실제로는 만들어지지 않았고, 그 결과 탭이 조용히 CLI
기본값으로 뜨는 일이 반복됐다.

2026-09-17 에는 "셸에서 현재 세션의 실제 모델을 알 수 없다(전역 설정은 기본값일 뿐)"는
이유로 상속을 배제했으나 **2026-09-21 실측이 그 전제를 반증했다** — transcript 의
`message.model` 은 기본값이 아니라 실제 응답 모델의 기록이고(`/model` 변경도 따라온다),
subagent 응답은 부모 transcript 에 기록되지 않아(조사한 세션 60건 모두 단일 모델,
`isSidechain` 0건) 모델이 섞이지 않는다. 같은 배제 판단을 반복하지 않도록 근거를 남긴다.

effort 상속도 같은 transcript 를 읽습니다. `type` 이 `assistant` 인 기록의 최상위 `effort` 값을 마지막 유효 값부터 씁니다.

한계는 셋이다. transcript 포맷·`CLAUDE_CODE_SESSION_ID` 는 CLI 내부 구조라 바뀌면 상속이
깨지는데, 그때는 **종전과 같은 미지정**으로 떨어진다(조용한 오작동이 아니라 조용한
원복). `/model` 로 바꾼 직후 새 모델로 아직 응답하지 않았으면 직전 모델을 집는다. 이미
기동된 세션에는 소급 적용되지 않는다.

상속이 쓰였는지는 `promote.sh` 의 `다음 기동에 사용할 모델 — … (출처: 현재 세션 상속)`
한 줄로 확인한다.

## 위저드 흐름

### 1. 현재 설정 표시

`bash rd-workflow/scripts/model_select.sh subagent` 를 실행하고 출력(stderr 경고 포함)을 그대로 보인다.

### 2. 추천 프리셋 제시

아래 테이블을 사용자에게 보여준다:

| 단계 | 추천 모델 | 근거 | 제어 방식 | 위험 포인트 |
|------|----------|------|-----------|------------|
| orchestration | opus | 워크플로 판단, 규칙 준수 | advisory | - |
| brainstorming | opus | 창의적 설계 판단 필요 | advisory | Sonnet은 얕은 대안 |
| spec | sonnet | 설계 완료 후 구조화 | advisory | brainstorming 품질 의존 |
| plan | sonnet | spec → task 분해 | advisory | task 경계 품질 차이 가능 |
| review_author | sonnet | 피드백 반영/수정 | advisory | Reviewer 잘못된 지적 무비판 수용 가능 |
| subagent | sonnet (effort 비움 — Agent 도구 기본값) | plan 기반 구현 | **direct** | plan에 없는 예외 대처 약함 |
| archive | haiku | 기계적 아카이브/보고 | advisory | 복잡한 보고서 품질 저하 |

### 3. subagent 모델 선택

AskUserQuestion으로 묻는다:

> subagent 구현에 사용할 모델을 선택하세요 (추천: sonnet):
> - **opus** — 높은 품질, 높은 비용
> - **sonnet** (추천) — 충분한 품질, 비용 절감
> - **haiku** — 최저 비용, 단순 작업만
> - **fable**

### 4. subagent effort 선택

AskUserQuestion 질문 하나로 묻는다. 이 도구는 질문마다 선택지를 2~4개만 받으므로 선택지는 아래 네 개이고, `xhigh`·`max` 는 도구가 자동으로 붙이는 「Other」 입력으로 받는다:

> subagent 구현에 사용할 effort 를 선택하세요 (추천: 비움). xhigh·max 는 「Other」 에 그 값을 입력하세요:
> - **비움** (추천) — effort 를 넘기지 않음(Agent 도구 기본값)
> - **low**
> - **medium**
> - **high**

- 「비움」 은 5단계에서 `null` 로 저장한다. 나머지 선택지는 그 값으로 저장한다.
- 「Other」 입력은 앞뒤 공백을 지우고 소문자로 바꾼 값이 `low`·`medium`·`high`·`xhigh`·`max` 중 하나일 때만 그 값으로 저장한다. 그 밖의 입력이면 허용 값을 알리고 이 질문을 다시 묻는다.

### 5. 설정 저장

임시 저장 목록 파일(`mktemp`)에 두 줄을 쓰고 `apply` 로 `models.json` 에 저장한다. effort 「비움」 은 값 자리에 `null` 을 쓴다.

```
models subagent.claude.model <값>
models subagent.claude.effort <값|null>
```

```bash
bash rd-workflow/scripts/model_select.sh apply <목록 파일>
```

두 칸은 한 칸씩 저장되므로 일부만 저장될 수 있다. 종료 코드로 갈린다.

- **exit 0**: 목록 파일을 지우고 `model_select.sh subagent` 를 다시 실행해 적용값을 보인 뒤 6단계로 간다.
- **exit 1 이고 stdout 에 `다시 실행:` 줄이 있음**(일부만 저장된 경우 포함): 성공 표시를 내지 않는다. `반영됨:`·`실패:`·`미적용:` 은 결과에 따라 일부만 나온다(첫 칸이 실패하면 `반영됨:` 이 없고, 둘째 칸이 실패하면 `미적용:` 이 없다). stdout 에 실제로 나온 줄과 stderr 를 그대로 보이고, `model_select.sh subagent` 를 다시 실행해 지금 적용값과 `설정 파일:` 경로를 보인다. 원인을 고친 뒤 `다시 실행:` 명령을 실행하거나 `설정 파일:` 경로의 `subagent.claude.<칸>` 을 직접 편집하라고 알린다. 목록 파일은 지우지 않는다.
- **exit 1 이고 `다시 실행:` 줄이 없음**(jq 없음 `⚠️  jq 가 없어 실행할 수 없습니다 (brew install jq).` 등): 성공 표시를 내지 않는다. stderr 를 그대로 보이고, `model_select.sh subagent` 를 다시 실행해 지금 적용값과 `설정 파일:` 경로를 보인다. 목록 파일 경로를 알리고, jq 설치(`brew install jq`) 뒤 실행할 `RD_MODELS_CONFIG=<설정 파일 경로> bash rd-workflow/scripts/model_select.sh apply <목록 파일 경로>` 전문 또는 위저드 재실행을 안내한다. 두 경로는 각각 셸 인용(`printf '%q'` 결과)으로 넣는다. 기존 `apply` 의 `다시 실행:` 줄과 같은 방식이고, 공백이 든 경로도 복사해 그대로 실행된다(예: `RD_MODELS_CONFIG=/tmp/sa\ other/m.json`). jq 를 설치하지 않으려면 `설정 파일:` 경로의 `subagent.claude.model`·`subagent.claude.effort` 에 넣을 값을 보이고 직접 편집하라고 알린다.

### 6. 요약 출력

적용값 표시 줄과 아래 안내를 낸다:

> 다음 구현 subagent dispatch 부터 적용됩니다. 이 체크아웃에서는 저장한 `models.json` 을 바로 읽습니다. 다른 체크아웃(기본 체크아웃·다른 작업 worktree)은 각자의 `models.json` 을 읽으므로, 이 체크아웃의 커밋하지 않은 변경은 그쪽에 닿지 않습니다. 그쪽에도 적용하려면 변경을 커밋해 그 체크아웃에 들이거나 그곳에서 `/model-strategy` 를 다시 실행하십시오.
>
> **참고:** orchestration, brainstorming, spec, plan, review_author, archive 단계는 메인 세션 모델에 의존합니다. 이 단계들의 모델을 변경하려면 Claude Code 세션을 해당 모델로 시작하세요.

## 오류 처리

- 저장 실패(`apply` exit 1) → 위 5단계대로 처리한다. 성공 표시를 내지 않는다.
- 허용되지 않은 값 → `apply` 가 그 칸을 거부하고 `실패:` 줄을 낸다. 위 5단계의 두 번째 경우로 처리한다.
