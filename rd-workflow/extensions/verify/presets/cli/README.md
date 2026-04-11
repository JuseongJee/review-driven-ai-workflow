# CLI Verification Preset

CLI 도구용 검증 프리셋입니다. snapshot 테스트와 hyperfine 벤치마크를 포함합니다.

## 사용법

### 1. 프리셋 설치

```bash
cp rd-workflow/extensions/verify/presets/cli/verification.json rd-workflow/config/verification.json
```

## 처음부터 설정하기

### 1. 도구 설치

```bash
# hyperfine (벤치마크)
brew install hyperfine  # macOS
# 또는 cargo install hyperfine
```

### 2. snapshot 테스트 스크립트 작성

`tests/snapshot.sh` 예시:

```bash
# 요구사항: Bash 4+ (macOS는 brew install bash 필요)
#!/usr/bin/env bash
set -euo pipefail

CLI_CMD="./my-cli"  # TODO: 프로젝트의 CLI 명령으로 수정
SNAPSHOT_DIR="tests/snapshots"

mkdir -p "$SNAPSHOT_DIR"

# 테스트 케이스 정의 — TODO: 프로젝트에 맞게 수정
declare -A cases=(
  ["help"]="--help"
  ["version"]="--version"
  # ["list"]="list --format json"
)

failed=0
for name in "${!cases[@]}"; do
  args="${cases[$name]}"
  expected="$SNAPSHOT_DIR/$name.expected.txt"
  actual="$SNAPSHOT_DIR/$name.actual.txt"

  eval "$CLI_CMD $args" > "$actual" 2>&1 || true

  if [[ ! -f "$expected" ]]; then
    echo "[snapshot] $name: 기준 파일 없음 — 현재 출력을 기준으로 저장합니다"
    cp "$actual" "$expected"
    continue
  fi

  if ! diff -q "$expected" "$actual" > /dev/null 2>&1; then
    echo "[snapshot] $name: FAILED"
    diff "$expected" "$actual" || true
    failed=1
  else
    echo "[snapshot] $name: PASSED"
  fi
done

exit $failed
```

### 3. hyperfine 벤치마크 실행 확인

```bash
# 기본 벤치마크
hyperfine './my-cli --help'

# 여러 명령 비교
hyperfine './my-cli process small.txt' './my-cli process large.txt'

# JSON 결과 출력 (adapter에서 사용)
hyperfine './my-cli --help' --export-json result.json
```

### 4. 실행 확인

```bash
# snapshot
chmod +x tests/snapshot.sh
bash tests/snapshot.sh

# hyperfine
hyperfine './my-cli --help'
```

## Verifiers

### snapshot

CLI 출력을 기준 스냅샷과 비교해 정확성을 검증합니다.

**환경 변수**

| 변수 | 설명 | 예시 |
|------|------|------|
| `$SNAPSHOT_TEST_SCRIPT` | 스냅샷 테스트를 실행할 스크립트 경로 | `./tests/snapshot.sh` |

**설정 방법**

1. `verification.json`의 `snapshot.criteria[0].description`에서 `TODO: set snapshot path`를 실제 스냅샷 파일 경로로 교체합니다.
2. 스냅샷 기준 파일을 생성합니다 (예: `tests/snapshots/expected_output.txt`).
3. `$SNAPSHOT_TEST_SCRIPT`가 실제 출력과 스냅샷을 비교하고 exit 0/1을 반환하도록 작성합니다.

**Criteria**

- `output-correctness` (high): 실제 출력이 기준 스냅샷과 일치하는가
- `help-usability` (medium): help 메시지가 명확하고 옵션·예시·설명을 포함하는가

---

### hyperfine

CLI 명령의 실행 시간을 측정해 성능 기준을 검증합니다.

**설치**

```bash
# macOS
brew install hyperfine

# Cargo
cargo install hyperfine
```

**환경 변수**

| 변수 | 설명 | 예시 |
|------|------|------|
| `$BENCHMARK_CMD` | 벤치마크 대상 명령 | `"./my-cli --input data.txt"` |

**설정 방법**

1. `verification.json`의 `hyperfine.criteria[0].description`에서 `TODO: set time threshold`를 허용 시간 기준으로 교체합니다 (예: `500ms 이내`).
2. `$BENCHMARK_CMD`에 실제 측정 대상 명령을 지정합니다.

**Criteria**

- `execution-performance` (high): 명령 실행 시간이 허용 기준 이내인가

---

## 커스터마이징

- verifier를 추가하려면 `verification.json`에 항목을 추가하고 대응하는 adapter를 `rd-workflow/extensions/verify/verifiers/`에 작성합니다.
- criteria의 `weight`는 `high` / `medium` / `low` 중 하나입니다.
- `run` 값에 환경 변수를 자유롭게 사용할 수 있습니다.
