# react-web Verification Preset

React 웹 앱 프로젝트에서 바로 사용할 수 있는 검증 프리셋입니다.  
Lighthouse, Playwright, axe 세 가지 verifier를 포함합니다.

---

## 처음부터 설정하기

이 프리셋을 사용하려면 Playwright, Lighthouse, axe가 필요합니다. 아래 순서대로 설정하세요.

### 1. Playwright 프로젝트 초기화

```bash
# Playwright 설치 + 브라우저 다운로드
npm init playwright@latest
# 또는 기존 프로젝트에 추가
npm install --save-dev @playwright/test
npx playwright install
```

### 2. 검증용 테스트 파일 작성

`tests/verification.spec.ts` 예시:

```typescript
import { test, expect } from '@playwright/test';

test('메인 플로우 스크린샷', async ({ page }) => {
  // 1단계: 홈
  await page.goto('/');
  await page.screenshot({ path: '.verification/latest/playwright/step1-home.png', fullPage: true });

  // 2단계: 다음 페이지 — TODO: 프로젝트에 맞게 수정
  // await page.click('[data-testid="nav-link"]');
  // await page.screenshot({ path: '.verification/latest/playwright/step2-detail.png', fullPage: true });
});

test('반응형 스크린샷', async ({ page }) => {
  const viewports = [
    { name: 'mobile', width: 375, height: 812 },
    { name: 'tablet', width: 768, height: 1024 },
    { name: 'desktop', width: 1440, height: 900 },
  ];

  for (const vp of viewports) {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    await page.goto('/');
    await page.screenshot({ path: `.verification/latest/playwright/${vp.name}.png`, fullPage: true });
  }
});
```

### 3. Lighthouse 실행 확인

```bash
# Chrome이 설치되어 있어야 함
npm install -g lighthouse
lighthouse http://localhost:3000 --output json --output-path ./report.json --chrome-flags="--headless"
```

### 4. axe 접근성 검사 확인

```bash
npm install -g @axe-core/cli
axe http://localhost:3000 --exit
```

---

## 사용법

### 1. 프리셋 설치

```bash
cp ai/extensions/presets/react-web/verification.json ai/config/verification.json
```

### 2. 도구 설치

```bash
# Lighthouse
npm install -g lighthouse

# Playwright (및 브라우저 설치)
npm install --save-dev @playwright/test
npx playwright install

# axe CLI
npm install -g @axe-core/cli
```

### 3. 환경 변수 설정

| 변수  | 설명                                 | 예시                    |
|-------|--------------------------------------|-------------------------|
| `$URL` | 검증 대상 URL (모든 verifier에서 사용) | `http://localhost:3000` |

```bash
export URL=http://localhost:3000
```

### 4. 실행

```bash
bash ai/extensions/verify/verify.sh --all
```

특정 verifier만 실행:

```bash
bash ai/extensions/verify/verify.sh --verifier lighthouse
bash ai/extensions/verify/verify.sh --verifier playwright
bash ai/extensions/verify/verify.sh --verifier axe
```

---

## Adapter 목록

| Verifier   | Adapter 경로                                  | 필요 도구              |
|------------|-----------------------------------------------|------------------------|
| lighthouse | `ai/extensions/verify/verifiers/lighthouse.sh`       | Node.js, npx, Chrome   |
| playwright | `ai/extensions/verify/verifiers/playwright.sh`       | Node.js, npx           |
| axe        | `ai/extensions/verify/verifiers/axe.sh`             | Node.js, npx           |

---

## 기본 Criteria 목록

### lighthouse
| ID            | 설명                                      |
|---------------|-------------------------------------------|
| performance   | Lighthouse 성능 점수 (기본값 TODO)        |
| accessibility | Lighthouse 접근성 점수 (기본값 TODO)      |

### playwright
| ID            | 설명                                          |
|---------------|-----------------------------------------------|
| design-quality | 디자인 목업/토큰 일치 여부                   |
| craft          | UI 인터랙션 품질 (애니메이션, 포커스 등)     |
| functionality  | 핵심 사용자 플로우 E2E                       |
| responsive     | 대상 뷰포트 레이아웃 정합성                  |

### axe
| ID            | 설명                                                  |
|---------------|-------------------------------------------------------|
| accessibility | Critical/Serious 접근성 위반 0건 (대상 라우트 TODO)  |

---

## 연속 스크린샷 (인터랙션 리뷰)

정지 화면뿐 아니라 인터랙션 흐름도 리뷰하려면, Playwright 테스트에서 단계별 스크린샷을 찍으세요.

```typescript
// tests/flow.spec.ts
test('checkout flow', async ({ page }) => {
  await page.goto('/cart');
  await page.screenshot({ path: '.verification/latest/playwright/step1-cart.png' });

  await page.click('[data-testid="checkout-btn"]');
  await page.screenshot({ path: '.verification/latest/playwright/step2-checkout.png' });

  await page.fill('#card-number', '4242424242424242');
  await page.click('[data-testid="pay-btn"]');
  await page.screenshot({ path: '.verification/latest/playwright/step3-confirm.png' });
});
```

AI Evaluator가 스크린샷 시퀀스를 보고 전환의 자연스러움, 누락된 상태, UI 일관성을 평가합니다.

Playwright `video: 'on'` 옵션으로 영상 녹화도 가능하지만, 현재 AI는 영상 분석을 지원하지 않으므로 단계별 스크린샷이 더 효과적입니다.

---

## 커스터마이징 가이드

`ai/config/verification.json`을 열고 각 criteria의 `description`에 표시된 `TODO:` 항목을 프로젝트 실정에 맞게 채웁니다.

주요 TODO 항목:

- **lighthouse**: 목표 점수(예: 90), 감사할 라우트 목록
- **playwright**: 테스트 파일 경로, 검증할 인터랙션/플로우/뷰포트
- **axe**: 스캔할 라우트, moderate 위반 처리 방침

`run` 필드의 npx 명령어도 프로젝트 설정(config file 위치, reporter 옵션 등)에 맞게 수정할 수 있습니다.
