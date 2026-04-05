# presets Extension

## 의존성
depends: [verify]

## 설치

원하는 플랫폼의 프리셋을 선택하여 설치:

```bash
# 기존 verification.json이 있고 .bak가 없을 때만 최초 백업
[ -f ai/config/verification.json ] && [ ! -f ai/config/verification.json.bak ] && \
  cp ai/config/verification.json ai/config/verification.json.bak

# ios/macos preset은 macOS에서만 사용 가능
# [[ "$(uname -s)" != "Darwin" ]] && preset이 ios/macos이면 → 중단 + 경고

# 예: react-web
cp ai/extensions/presets/react-web/verification.json ai/config/verification.json
```

사용 가능한 프리셋:
- `react-web` — Playwright, Lighthouse, axe-core
- `api` — k6, schema-validate
- `cli` — snapshot, hyperfine
- `ios` — XCUITest (manual starter template, macOS 전용, non-Darwin에서 선택 시 중단)
- `macos` — XCUITest (manual starter template, macOS 전용, non-Darwin에서 선택 시 중단)

ios/macos preset은 모든 호스트에서 `(macOS 전용)` 라벨과 함께 표시한다. non-macOS(`uname -s` != Darwin)에서 선택 시 install.md가 즉시 중단하고 경고한다.

## 의존성 거절 시
verify extension이 미설치 상태에서 presets를 선택하면:
1. "verify를 먼저 설치해야 합니다. 같이 설치할까요?" 확인
2. 사용자가 거절하면 presets 설치를 즉시 중단
3. "verify를 먼저 설치해야 presets를 사용할 수 있습니다"로 안내

각 프리셋의 README.md에 도구 설치 및 커스터마이징 가이드가 있습니다.

## 설치 확인
- `ai/config/verification.json` 존재
- `bash ai/extensions/verify/verify.sh --help` 실행 가능 (verify extension 필요)

## 제거
- `ai/config/verification.json` 삭제 (또는 `.bak`에서 복원)
