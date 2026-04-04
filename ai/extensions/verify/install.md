# verify Extension

## 의존성
없음

## 설치

1. `mkdir -p ai/claude_skills/verify`
2. `ai/extensions/verify/SKILL.md`와 `rules.md`를 `ai/claude_skills/verify/`에 복사
3. `ai/extensions/verify/verify.sh`를 `ai/scripts/ai/verify.sh`로 복사
4. `mkdir -p ai/scripts/ai/verifiers` + `ai/extensions/verify/verifiers/` 내용 복사
5. `ai/extensions/verify/verification.json.example`을 `ai/config/verification.json.example`로 복사
6. `CURRENT_TASK.md`에 `## Verify` 필드 추가 (기본값 `-`, `## Design Review` 뒤 또는 `## Branch / Worktree` 앞에 삽입)

## 설치 확인
- `ai/claude_skills/verify/SKILL.md` 존재
- `ai/claude_skills/verify/rules.md` 존재
- `bash ai/scripts/ai/verify.sh --help` 실행 가능
- `ai/config/verification.json.example` 존재

## 업데이트
설치 단계를 다시 실행하면 최신으로 갱신됩니다 (덮어쓰기).

## 제거
- `ai/claude_skills/verify/` 삭제
- `ai/scripts/ai/verify.sh` 삭제
- `ai/scripts/ai/verifiers/` 삭제
- `ai/config/verification.json.example` 삭제
- `CURRENT_TASK.md`에서 `## Verify` 필드 제거
