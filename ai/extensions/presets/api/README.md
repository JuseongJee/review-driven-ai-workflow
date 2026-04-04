# API Verification Preset

API 서버 검증용 프리셋. 부하 테스트(k6)와 스키마 검증(schema-validate) 두 verifier로 구성됩니다.

## 사용법

### 1. 프리셋 설치

```bash
cp ai/extensions/presets/api/verification.json ai/config/verification.json
```

### 2. 도구 설치

#### k6

```bash
# macOS
brew install k6

# Linux
sudo apt-get install k6

# 공식 문서: https://grafana.com/docs/k6/latest/set-up/install-k6/
```

#### schema-validate (Node.js 필요)

```bash
node --version  # v18 이상 권장
```

### 3. 환경 변수 설정

| 변수 | 설명 | 예시 |
|------|------|------|
| `$K6_SCRIPT` | k6 테스트 스크립트 경로 | `tests/load/api.js` |
| `$SCHEMA_VALIDATE_SCRIPT` | 스키마 검증 Node 스크립트 경로 | `tests/schema/validate.js` |
| `$OUTPUT_DIR` | 결과 출력 디렉토리 (자동 주입) | `.verification/latest/k6` |

## Criteria

### k6

- **latency**: P95 응답 시간 기준. `verification.json`의 `TODO: set P95 threshold`를 실제 값으로 교체 (예: `p(95)<500`).
- **error-rate**: 허용 에러율 기준. `TODO: set max error %`를 실제 값으로 교체 (예: `rate<0.01`).

### schema-validate

- **response-schema**: 성공 응답이 정의된 JSON Schema와 일치해야 합니다.
- **error-handling**: 4xx/5xx 응답이 표준 에러 포맷(`{ error, message }` 등)을 따라야 합니다.

## 커스터마이징

1. `verification.json`의 `TODO` 항목을 실제 값으로 교체합니다.
2. `$K6_SCRIPT`와 `$SCHEMA_VALIDATE_SCRIPT`를 프로젝트에 맞게 설정합니다.
3. k6 스크립트 내 threshold를 `verification.json`의 criteria와 일치시킵니다.
