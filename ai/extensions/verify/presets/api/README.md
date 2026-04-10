# API Verification Preset

API 서버 검증용 프리셋. 부하 테스트(k6)와 스키마 검증(schema-validate) 두 verifier로 구성됩니다.

## 사용법

### 1. 프리셋 설치

```bash
cp ai/extensions/verify/presets/api/verification.json ai/config/verification.json
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

## 처음부터 설정하기

프리셋을 설치했지만 k6 스크립트나 schema-validate 스크립트가 아직 없는 경우, 아래 예시를 참고하여 작성합니다.

### 1. k6 테스트 스크립트 작성

`tests/load/api.js` 예시:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,
  duration: '30s',
  thresholds: {
    http_req_duration: ['p(95)<500'], // TODO: P95 기준값 설정
    http_req_failed: ['rate<0.01'],   // TODO: 허용 에러율 설정
  },
};

export default function () {
  // TODO: 프로젝트의 실제 엔드포인트로 수정
  const res = http.get('http://localhost:3000/api/health');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
```

### 2. schema-validate 스크립트 작성

`tests/schema/validate.js` 예시:

```javascript
const Ajv = require('ajv');
const ajv = new Ajv();

// TODO: 프로젝트의 실제 API 응답 스키마로 수정
const schema = {
  type: 'object',
  required: ['id', 'name'],
  properties: {
    id: { type: 'integer' },
    name: { type: 'string' },
  },
};

async function validate() {
  // TODO: 프로젝트의 실제 엔드포인트로 수정
  const res = await fetch('http://localhost:3000/api/items/1');
  const data = await res.json();

  const valid = ajv.validate(schema, data);
  if (!valid) {
    console.error('스키마 불일치:', ajv.errors);
    process.exit(1);
  }
  console.log('스키마 검증 통과');
}

validate();
```

npm 의존성: `npm install ajv`

### 3. 실행 확인

```bash
# k6
k6 run tests/load/api.js

# schema-validate
node tests/schema/validate.js
```

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
