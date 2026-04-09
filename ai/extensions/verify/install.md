# verify Extension

## 의존성
없음

## 설치

1. `mkdir -p ai/claude_skills/verify`
2. `ai/extensions/verify/SKILL.md`와 `rules.md`를 `ai/claude_skills/verify/`에 복사
3. `CURRENT_TASK.md`에 `## Verify` 필드 추가 (기본값 `-`, `## Design Review` 뒤 또는 `## Branch / Worktree` 앞에 삽입). 이미 존재하면 건너뜀
4. `ai/config/extensions.json` 갱신 (파일이 없으면 `{"extensions": {}}` 생성)
   - `extensions.verify.installed_at`을 현재 ISO 8601 시각으로 기록

verify.sh, verifiers/, verification.json.example은 `ai/extensions/verify/`에서 직접 실행하므로 별도 복사 불필요.

## 설치 확인
- `ai/claude_skills/verify/SKILL.md` 존재
- `ai/claude_skills/verify/rules.md` 존재
- `bash ai/extensions/verify/verify.sh --help` 실행 가능

## 제거
- `ai/claude_skills/verify/` 삭제 (이것만으로 비활성화 완료)
- `CURRENT_TASK.md`에서 `## Verify` 필드 제거
- `ai/config/extensions.json`에서 `extensions.verify` 항목 삭제
