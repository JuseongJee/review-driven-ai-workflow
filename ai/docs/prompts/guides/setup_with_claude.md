# Claude에게 템플릿 설치 시키기

이 문서는 Claude가 읽고 실행하는 설치 가이드입니다.

사용자는 프로젝트 디렉토리에서 Claude Code를 열고 아래처럼만 말하면 됩니다.

```text
이 AI 개발 템플릿 적용해: <배포 repo URL>
```

---

## Claude가 실행할 절차

이 문서를 읽고 있다면 아래 절차를 순서대로 실행하세요.

### 1. 템플릿 소스 확보

사용자가 제공한 배포 repo URL을 임시 디렉토리에 clone합니다.

```bash
git clone --depth 1 <배포 repo URL> /tmp/ai-dev-template-src
```

clone한 디렉토리가 템플릿 소스입니다.

### 2. 현재 프로젝트에 파일 복사

템플릿 소스에서 현재 작업 디렉토리(프로젝트 루트)에 아래 파일을 복사합니다.

복사 대상:
- `CLAUDE.md`
- `REQUEST.md`
- `PROJECT_CONTEXT.md`
- `CURRENT_TASK.md`
- `WORKING_WITH_AI.md`
- `.claude/settings.json`
- `ai/` (전체 디렉토리)

이미 존재하는 파일이 있으면 사용자에게 덮어쓸지 확인합니다.

`.gitignore` 처리:
- 프로젝트에 `.gitignore`가 없으면 템플릿의 `.gitignore`를 그대로 복사합니다.
- 이미 존재하면 템플릿의 `.gitignore` 내용 중 프로젝트에 없는 항목을 기존 파일에 머지합니다. 기존 항목은 건드리지 않습니다.

임시 clone 디렉토리가 있으면 정리합니다:
```bash
rm -rf /tmp/ai-dev-template-src
```

### 3. PROJECT_CONTEXT.md 채우기

프로젝트의 실제 파일 구조, 빌드 시스템, 설정 파일 등을 읽고 `PROJECT_CONTEXT.md`를 채웁니다.

- `Project Type`: 프로젝트 종류 파악 (Web, macOS, iOS, backend 등)
- `Product Summary`: README나 주요 코드에서 제품 요약 추출
- `Tech Stack`: package.json, Podfile, build.gradle, Cargo.toml 등에서 파악
- `Build / Test / Lint / Typecheck`: 실제 명령 파악 후 기입
- `Architecture Rules`, `Code Style`: 기존 코드 패턴에서 추론
- `Platform Notes`: 해당 플랫폼 섹션만 채우고 나머지는 삭제

파일만으로 확정할 수 없는 항목은 사용자에게 질문합니다.

### 4. 검증 스크립트 채우기

`ai/scripts/ai/` 아래 4개 스크립트를 프로젝트에 맞게 채웁니다.

- `build.sh`: 3단계에서 파악한 build 명령
- `test.sh`: 3단계에서 파악한 test 명령
- `lint.sh`: 3단계에서 파악한 lint 명령
- `typecheck.sh`: 3단계에서 파악한 typecheck 명령

해당 도구가 프로젝트에 없으면 `echo "이 프로젝트에서는 사용하지 않습니다" && exit 0`으로 채웁니다.

채운 뒤 각 스크립트를 실행해서 정상 동작하는지 확인합니다.

### 5. Skill 설치

```bash
bash ai/scripts/ai/install_claude_skills.sh project
```

### 6. PROJECT_CONTEXT 검토 (선택)

3단계에서 채운 내용에 빈칸이나 불확실한 부분이 있으면 사용자에게 PROJECT_CONTEXT review를 돌릴지 물어봅니다.

### 7. 확장 기능 설치 (선택)

프로젝트에 복사된 `ai/extensions/` 디렉토리에서 사용 가능한 확장 기능을 확인하고 사용자에게 안내합니다.

```
사용 가능한 확장 기능:
1. design-review — UI 디자인 레퍼런스 확인 + AI 체크리스트
2. verify — 런타임 검증 루프 (도구 실행 → AI 평가 → 수정 반복)
3. presets — 플랫폼별 검증 프리셋 (react-web, api, cli, ios, macos)

설치할 확장을 선택하세요 (예: 1,2,3 또는 건너뛰기):
```

사용자가 선택하면:
1. 해당 extension의 `install.md`를 읽고 안내에 따라 설치
2. `depends`가 있으면 "verify extension이 먼저 필요합니다. 같이 설치할까요?" 확인
3. 설치 확인 항목 체크

### 8. 완료 보고

설치 결과를 사용자에게 보고합니다.

보고 항목:
- 복사된 파일 목록
- PROJECT_CONTEXT.md 요약 (채워진 항목 / 빈 항목)
- 검증 스크립트 실행 결과
- Skill 설치 결과
- 다음 단계 안내: "WORKING_WITH_AI.md를 열어두고 작업하면 됩니다"
