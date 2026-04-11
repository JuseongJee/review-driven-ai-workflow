# verify Extension

## 의존성
없음

## 설치

1. `mkdir -p rd-workflow/claude_skills/verify`
2. `rd-workflow/extensions/verify/SKILL.md`와 `rules.md`를 `rd-workflow/claude_skills/verify/`에 복사
3. `CURRENT_TASK.md`에 `## Verify` 필드 추가 (기본값 `-`, `## Design Review` 뒤 또는 `## Branch / Worktree` 앞에 삽입). 이미 존재하면 건너뜀
4. `rd-workflow/config/extensions.json` 갱신 (파일이 없으면 `{"extensions": {}}` 생성)
   - `extensions.verify.installed_at`을 현재 ISO 8601 시각으로 기록

verify.sh, verifiers/, verification.json.example은 `rd-workflow/extensions/verify/`에서 직접 실행하므로 별도 복사 불필요.

## 설치 확인
- `rd-workflow/claude_skills/verify/SKILL.md` 존재
- `rd-workflow/claude_skills/verify/rules.md` 존재
- `bash rd-workflow/extensions/verify/verify.sh --help` 실행 가능

## 업데이트 (템플릿 동기화 시)

`/tpl update` 실행 시 매니페스트에 `verify.preset`이 기록되어 있으면 자동으로 AI 머지가 수행됩니다. 머지 규칙은 `rd-workflow/docs/guides/sync_template.md` 8.6단계를 참조하세요.

## 제거
- `rd-workflow/claude_skills/verify/` 삭제 (이것만으로 비활성화 완료)
- `CURRENT_TASK.md`에서 `## Verify` 필드 제거
- `rd-workflow/config/extensions.json`에서 `extensions.verify` 항목 삭제 (legacy `extensions.presets`가 남아 있으면 함께 삭제)
- `verification.json`과 `.bak`는 사용자 데이터이므로 삭제하지 않음 (필요 시 수동 삭제)

## 프리셋 선택 (선택)

verify 설치 후 플랫폼별 검증 프리셋을 선택할 수 있습니다.
선택하지 않아도 verify는 독립 실행 가능합니다.

사용 가능한 프리셋:
- `react-web` — Playwright, Lighthouse, axe-core
- `api` — k6, schema-validate
- `cli` — snapshot, hyperfine
- `ios` — XCUITest (macOS 전용, non-Darwin에서 선택 시 중단)
- `macos` — XCUITest (macOS 전용, non-Darwin에서 선택 시 중단)

ios/macos preset은 모든 호스트에서 `(macOS 전용)` 라벨과 함께 표시한다. non-macOS(`uname -s` != Darwin)에서 선택 시 즉시 중단하고 경고한다.

설치 절차:

```bash
# 기존 verification.json이 있고 .bak가 없을 때만 최초 백업
[ -f rd-workflow/config/verification.json ] && [ ! -f rd-workflow/config/verification.json.bak ] && \
  cp rd-workflow/config/verification.json rd-workflow/config/verification.json.bak

# ios/macos preset은 macOS에서만 사용 가능
# [[ "$(uname -s)" != "Darwin" ]] && preset이 ios/macos이면 → 중단 + 경고

# 예: react-web
cp rd-workflow/extensions/verify/presets/react-web/verification.json rd-workflow/config/verification.json
```

설치 완료 후 `rd-workflow/config/extensions.json`을 갱신합니다:
- `extensions.verify.preset`에 선택한 preset 이름을 기록 (예: `react-web`)

각 프리셋의 README.md에 도구 설치 및 커스터마이징 가이드가 있습니다.

## 프리셋 변경

프리셋 선택 절차를 다시 실행하면 verification.json을 덮어씁니다 (.bak 정책 유지).
`extensions.verify.preset`을 새 값으로 갱신합니다.
