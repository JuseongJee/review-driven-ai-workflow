# presets Extension

## 의존성
depends: [verify]

## 설치

### 1. 플랫폼 선택

사용 가능한 프리셋:
- `react-web` — Playwright, Lighthouse, axe-core
- `api` — k6, schema-validate
- `cli` — snapshot, hyperfine
- `ios` — XCUITest (manual starter template)
- `macos` — XCUITest (manual starter template)

사용자에게 플랫폼을 선택하게 한다.

### 2. verification.json 복사

```bash
cp ai/extensions/presets/{platform}/verification.json ai/config/verification.json
```

### 3. 도구 설치

선택한 플랫폼의 `ai/extensions/presets/{platform}/README.md`를 읽고, "도구 설치" 섹션에 따라 필요한 도구를 설치한다.

- 프로젝트의 패키지 매니저(npm, pip, brew 등)를 확인하여 적절한 설치 명령 실행
- 이미 설치된 도구는 건너뛴다
- 설치에 실패하면 사용자에게 안내하고 수동 설치를 권장한다

### 4. 프로젝트별 설정

`ai/config/verification.json`을 프로젝트에 맞게 커스터마이징한다:

- `TODO:` 표시된 항목을 프로젝트 실제 값으로 채운다 (threshold, 대상 route, device 등)
- 불필요한 verifier는 제거한다
- criteria의 weight를 조절한다

README.md의 "커스터마이징" 섹션을 참고한다.

### 5. 동작 확인

```bash
bash ai/scripts/ai/verify.sh --all
```

각 verifier의 실행 결과를 확인한다. 도구 미설치나 설정 오류가 있으면 안내한다.

## 설치 확인
- `ai/config/verification.json` 존재
- `bash ai/scripts/ai/verify.sh --help` 실행 가능 (verify extension 필요)
- 최소 1개 verifier가 정상 실행 (PASSED)

## 업데이트

설치 단계를 다시 실행하면 최신으로 갱신된다:
1. verification.json 갱신 (사용자 커스터마이징은 보존할지 물어본다)
2. 도구 버전 확인 및 업데이트 안내
3. 동작 확인

## 제거
- `ai/config/verification.json` 삭제
