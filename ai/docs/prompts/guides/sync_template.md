# 템플릿 변경사항을 프로젝트에 동기화

이 문서는 Claude가 읽고 실행하는 템플릿 동기화 가이드입니다.

사용자는 프로젝트 디렉토리에서 Claude Code를 열고 아래처럼 말하면 됩니다.

```text
템플릿 최신으로 업데이트해
```

배포 repo URL을 알고 있다면:

```text
이 템플릿으로 업데이트해: <배포 repo URL>
```

---

## Claude가 실행할 절차

### 1. 버전 확인 및 템플릿 소스 확보

먼저 버전 가드 스크립트를 실행합니다.

```bash
bash ai/scripts/ai/sync_template.sh <배포 repo URL>
```

- 스크립트가 정상 종료(exit 0)하면 마지막 줄에 출력된 임시 clone 경로를 사용합니다.
- 스크립트가 다운그레이드 경고로 중단(exit 1)하면:
  - 사용자에게 "현재 프로젝트의 템플릿이 원격보다 최신입니다. 강제로 다운그레이드하시겠습니까?" 확인
  - 사용자가 동의하면 `--force`를 붙여 재실행
  - 사용자가 거부하면 동기화 중단

배포 repo URL을 모르면 사용자에게 물어봅니다.

동기화 대상은 현재 작업 디렉토리 (프로젝트 루트)입니다.

### 2. 파일 분류

양쪽 디렉토리의 파일 목록을 비교해서 아래 4가지로 분류합니다.

**동기화 대상** — 템플릿 소스에 있고, 프로젝트에도 있고, 내용이 다른 파일:
- `CLAUDE.md`, `WORKING_WITH_AI.md`
- `ai/claude_skills/`
- `ai/config/` (설정 예제 파일)
- `ai/docs/` (adr, flows, library, policies, prompts, review_prompts, templates, backlog 구조 문서)
- `ai/scripts/ai/` 중 review pipeline 관련 스크립트

**신규 추가** — 템플릿에 있지만 프로젝트에 없는 파일

**삭제 후보** — 프로젝트에 있지만 템플릿에 없는 파일 중, 프로젝트 작업물이 아닌 것

**보존** — 절대 덮어쓰거나 지우지 않는 파일:
- `PROJECT_CONTEXT.md`
- `REQUEST.md`, `CURRENT_TASK.md` (프로젝트 고유 내용이 있는 경우)
- `ai/workspace/backlog/FUTURE_REQUESTS.md` (항목이 있는 경우)
- `ai/workspace/backlog/request-archive/` 안의 아카이브 파일
- `ai/workspace/specs/`, `ai/workspace/plans/` 안의 작업 산출물 (README 제외)
- `ai/scripts/ai/{build,test,lint,typecheck}.sh` (프로젝트별 명령이 들어 있음)
- `ai/workspace/handoffs/` 안의 작업 내용물
- `ai/config/review-tools.json` (프로젝트별 리뷰 도구 설정, `.example`은 동기화 대상)
- `ai/config/verification.json` (프로젝트별 검증 설정, `.example`은 동기화 대상)
- 프로젝트 고유 설정 파일 (`.gitignore`, `.swiftlint.yml`, `.claude/` 등)

### 3. 사용자 확인

분류 결과를 사용자에게 보여주고 확인을 받습니다.

보여줄 내용:
- 내용이 바뀌어서 덮어쓸 파일 목록
- 새로 추가할 파일 목록
- 삭제할 파일 목록 (있다면)
- 보존할 파일 요약

### 4. 구조 마이그레이션 감지

동기화 실행 전에, 템플릿의 구조 변경으로 프로젝트에 마이그레이션이 필요한지 확인합니다.

아래 마이그레이션을 순서대로 감지하고, 해당되는 항목만 실행합니다.

#### 4-1. workspace 디렉토리 구조 마이그레이션

`ai/docs/superpowers/` 디렉토리가 존재하면 구형 구조입니다.
`ai/docs/prompts/guides/migrate_workspace_structure.md`의 절차를 실행합니다.

#### 4-2. FUTURE_REQUESTS 인덱스 마이그레이션

`ai/workspace/backlog/FUTURE_REQUESTS.md`에 `## 인덱스` 섹션이 없으면 구형(인라인) 포맷입니다.

구형 포맷이 감지되면:
1. 기존 `FUTURE_REQUESTS.md`에서 `## YYYY-MM-DD` 패턴의 항목을 각각 추출
2. `ai/workspace/backlog/items/YYYY-MM-DD-제목.md` 개별 파일로 생성
3. `FUTURE_REQUESTS.md`를 인덱스 테이블 형식으로 변환 (템플릿 헤더 + 항목당 1줄)
4. `FUTURE_REQUESTS_DONE.md`가 있으면 동일하게 항목을 `items/`로 추출 후 삭제
5. 마이그레이션 결과를 사용자에게 보여주고 확인을 받는다

### 5. 동기화 실행

사용자 확인 후:
- 변경된 템플릿 파일을 프로젝트에 복사합니다
- 신규 파일을 추가합니다
- 확인받은 삭제 후보를 제거합니다

### 6. 검증

동기화 후 임시 clone의 템플릿 파일과 프로젝트 파일이 일치하는지 확인합니다. (보존 대상 제외)

검증이 끝나면 임시 clone 디렉토리를 정리합니다:
```bash
rm -rf /tmp/ai-dev-template-latest
```

### 7. 버전 갱신

동기화가 완료되면 원격 템플릿의 `ai/VERSION`을 프로젝트에 복사합니다.

```bash
cp <임시 clone 경로>/ai/VERSION ai/VERSION
```

이미 동기화 과정에서 복사되었다면 이 단계는 건너뜁니다.

### 8. 확장 기능 안내

동기화 후 `ai/extensions/` 디렉토리에 새로운 extension이 있는지 확인합니다.

프로젝트에 아직 설치되지 않은 extension이 있으면 사용자에게 안내합니다:

```
새로운 확장 기능이 감지되었습니다:
1. design-review — UI 디자인 레퍼런스 확인 + AI 체크리스트
2. verify — 런타임 검증 루프 (도구 실행 → AI 평가 → 수정 반복)
3. presets — 플랫폼별 검증 프리셋 (react-web, api, cli, ios, macos)

설치할 확장을 선택하세요 (예: 1,2,3 또는 건너뛰기):
```

설치 여부 판단: `ai/claude_skills/{name}/SKILL.md`가 없으면 미설치.

사용자가 선택하면 해당 extension의 `ai/extensions/{name}/install.md`를 읽고 안내에 따라 설치합니다.
`depends`가 있으면 먼저 설치할지 물어봅니다.

기존에 설치된 extension은 동기화 과정에서 `ai/extensions/` 원본이 갱신되었으므로, 재설치(덮어쓰기)할지 사용자에게 물어봅니다.

### 9. 완료 보고

- 복사/추가/삭제된 파일 수
- 마이그레이션 실행 여부와 결과
- 보존된 파일 요약
- Skill 재설치가 필요하면 안내: `bash ai/scripts/ai/install_claude_skills.sh project`
