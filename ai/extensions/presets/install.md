# presets Extension

## 의존성
depends: [verify]

## 설치

원하는 플랫폼의 프리셋을 선택하여 설치:

```bash
cp ai/extensions/presets/{platform}/verification.json ai/config/verification.json
```

사용 가능한 프리셋:
- `react-web` — Playwright, Lighthouse, axe-core
- `api` — k6, schema-validate
- `cli` — snapshot, hyperfine
- `ios` — XCUITest (manual starter template)
- `macos` — XCUITest (manual starter template)

각 프리셋의 README.md에 도구 설치 및 커스터마이징 가이드가 있습니다.

## 설치 확인
- `ai/config/verification.json` 존재
- `bash ai/scripts/ai/verify.sh --help` 실행 가능 (verify extension 필요)

## 업데이트
설치 단계를 다시 실행하면 최신으로 갱신됩니다 (덮어쓰기).

## 제거
- `ai/config/verification.json` 삭제
