# verify Extension

## 의존성
없음

## 설치

### 1. 파일 복사

1. `mkdir -p ai/claude_skills/verify`
2. `ai/extensions/verify/SKILL.md`와 `rules.md`를 `ai/claude_skills/verify/`에 복사
3. `ai/extensions/verify/verify.sh`를 `ai/scripts/ai/verify.sh`로 복사
4. `mkdir -p ai/scripts/ai/verifiers` + `ai/extensions/verify/verifiers/` 내용 복사
5. `ai/extensions/verify/verification.json.example`을 `ai/config/verification.json.example`로 복사
6. `CURRENT_TASK.md`에 `## Verify` 필드 추가 (기본값 `-`, `## Design Review` 뒤 또는 `## Branch / Worktree` 앞에 삽입)

### 2. 도구 확인

verify.sh는 `jq` 또는 `python3`가 필요하다. 둘 중 하나가 있는지 확인:

```bash
command -v jq && echo "jq OK" || echo "jq 없음"
command -v python3 && echo "python3 OK" || echo "python3 없음"
```

둘 다 없으면 설치를 안내한다:
- macOS: `brew install jq`
- Linux: `apt install jq` 또는 `yum install jq`
- Windows: `choco install jq` 또는 python3 설치

### 3. 동작 확인

```bash
bash ai/scripts/ai/verify.sh --help
```

정상 출력되면 설치 완료.

## 설치 확인
- `ai/claude_skills/verify/SKILL.md` 존재
- `ai/claude_skills/verify/rules.md` 존재
- `bash ai/scripts/ai/verify.sh --help` 실행 가능
- `ai/config/verification.json.example` 존재

## 업데이트

설치 단계를 다시 실행하면 최신으로 갱신된다 (덮어쓰기).
- 프로젝트별 `ai/config/verification.json`은 보존 (example만 갱신)
- 도구 버전 확인 후 업데이트 필요 시 안내

## 제거
- `ai/claude_skills/verify/` 삭제
- `ai/scripts/ai/verify.sh` 삭제
- `ai/scripts/ai/verifiers/` 삭제
- `ai/config/verification.json.example` 삭제
- `CURRENT_TASK.md`에서 `## Verify` 필드 제거
