# Verifier Adapters

이 디렉토리에는 도구별 실행 adapter 스크립트를 둔다.

## adapter 규약

- 파일명: `{verifier-name}.sh`
- 입력: `$1` = verifier name, `$2` = verification.json 경로, `$3` = 결과 출력 디렉토리
- 출력: `$3` 디렉토리에 자유 형식으로 저장 (JSON, 스크린샷, 로그 등)
- exit code: 0 = 실행 성공, 1 = 실행 실패
- 도구 미설치 시: exit 1 + stderr에 설치 안내 메시지

## 예시

```bash
#!/usr/bin/env bash
set -euo pipefail

NAME="$1"
CONFIG="$2"
OUTPUT_DIR="$3"

if ! command -v npx &>/dev/null; then
  echo "npx가 설치되지 않았습니다. Node.js를 설치해주세요." >&2
  exit 1
fi

# verification.json에서 run 명령 추출 후 실행
# 결과는 $OUTPUT_DIR에 저장
```
