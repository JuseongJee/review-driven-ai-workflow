# design-review Extension

## 의존성
없음

## 설치

1. `mkdir -p ai/claude_skills/design-review`
2. `ai/extensions/design-review/SKILL.md`와 `rules.md`를 `ai/claude_skills/design-review/`에 복사
3. `CURRENT_TASK.md`에 `## Design Review` 필드 추가 (기본값 `-`, `## Branch / Worktree` 앞에 삽입)

## 설치 확인
- `ai/claude_skills/design-review/SKILL.md` 존재
- `ai/claude_skills/design-review/rules.md` 존재
- `CURRENT_TASK.md`에 `## Design Review` 필드 존재

## 업데이트
설치 단계를 다시 실행하면 최신으로 갱신됩니다 (덮어쓰기).

## 제거
- `ai/claude_skills/design-review/` 삭제
- `CURRENT_TASK.md`에서 `## Design Review` 필드 제거
