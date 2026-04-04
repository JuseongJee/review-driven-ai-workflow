# macos Verification Preset

macOS 앱 프로젝트에서 바로 사용할 수 있는 검증 프리셋입니다.  
XCUITest를 통한 자동화 테스트 및 수동 검증을 지원합니다.

---

## 사용법

### 1. 프리셋 설치

```bash
cp ai/extensions/presets/macos/verification.json ai/config/verification.json
```

### 2. Xcode 설정 확인

프로젝트의 Xcode 설정을 확인합니다:

```bash
# 프로젝트 파일 확인
ls -la *.xcodeproj

# 사용 가능한 scheme 확인
xcodebuild -list -project <프로젝트명>.xcodeproj
```

### 3. 환경 변수 설정

| 변수     | 설명                                      | 예시                          |
|----------|-------------------------------------------|-------------------------------|
| `$PROJECT` | Xcode 프로젝트 경로                       | `MyApp.xcodeproj`             |
| `$SCHEME`  | 테스트할 scheme 이름                     | `MyAppTests` 또는 `MyApp`      |

```bash
export PROJECT=MyApp.xcodeproj
export SCHEME=MyApp
```

### 4. 실행

```bash
bash ai/scripts/ai/verify.sh --all
```

특정 verifier만 실행:

```bash
bash ai/scripts/ai/verify.sh --verifier xcuitest-macos
```

---

## Adapter 정보

| Verifier       | Adapter 경로                              | 필요 도구        |
|----------------|-------------------------------------------|------------------|
| xcuitest-macos | `ai/scripts/ai/verifiers/xcuitest-macos.sh` | Xcode CLI Tools  |

---

## 기본 Criteria 목록

| ID                    | 설명                                           | 가중치   |
|-----------------------|------------------------------------------------|---------|
| design-quality        | 디자인 시안과 시각적 일치 여부                  | high    |
| craft                 | UI 품질 (타이포, 간격, 색상 조화)             | high    |
| functionality         | 핵심 사용자 플로우 동작 확인                    | high    |
| platform-conventions  | macOS HIG 준수 (menu bar, shortcuts, window) | high    |
| accessibility         | VoiceOver 지원, 키보드 탐색 가능성             | high    |
| window-resize         | window 리사이징 시 레이아웃 유지               | medium  |
| keyboard              | keyboard shortcut 및 focus 순서 검증          | medium  |

---

## 연속 스크린샷 (인터랙션 리뷰)

### XCUITest 사용 시

iOS와 동일하게 `XCUIScreen.main.screenshot()`으로 단계별 캡처합니다.

### XCUITest 없이 수동 캡처

macOS CLI로 단계별 캡처:

```bash
screencapture -x .verification/latest/xcuitest-macos/step1-main.png
# (앱에서 다음 단계로 이동)
screencapture -x .verification/latest/xcuitest-macos/step2-detail.png
```

`-x` 옵션은 캡처 사운드를 끕니다.

window 크기별 캡처도 가능합니다:

```bash
# 앱 window를 특정 크기로 조정 후
screencapture -x .verification/latest/xcuitest-macos/resize-small.png
# window 크기 변경 후
screencapture -x .verification/latest/xcuitest-macos/resize-large.png
```

AI Evaluator가 스크린샷 시퀀스를 보고 window resize 대응, 키보드 네비게이션 흐름, menu bar 일관성을 평가합니다.

---

## 커스터마이징 가이드

`ai/config/verification.json`을 열고 각 criteria의 `description`에 표시된 `TODO:` 항목을 프로젝트 실정에 맞게 채웁니다.

### 주요 TODO 항목

1. **design-quality**: 
   - 디자인 시안이 저장된 URL 또는 파일 경로
   - 검증 대상 화면 목록

2. **craft**:
   - 프로젝트에서 따르는 디자인 시스템의 타이포, 간격, 색상 기준
   - 참고 문서 또는 가이드 링크

3. **functionality**:
   - 검증할 주요 user flow 목록
   - 각 flow의 입력값/예상 결과

4. **platform-conventions**:
   - menu bar 항목 목록
   - 필수 keyboard shortcut 목록
   - window 최소/최대 크기 규칙

5. **accessibility**:
   - VoiceOver 지원 대상 화면 목록
   - 검증할 키보드 탐색 경로

6. **window-resize**:
   - 최소/최대 window 크기 설정값
   - 리사이징 시 유지할 UI 요소 목록

7. **keyboard**:
   - 필수 keyboard shortcut 전체 목록
   - 각 shortcut의 기능 설명
   - focus 순서 검증 방법

### Adapter 커스터마이징

`ai/scripts/ai/verifiers/xcuitest-macos.sh`의 `run` 명령어를 프로젝트 설정에 맞게 수정할 수 있습니다:

```bash
# 기본값
xcodebuild test -project $PROJECT -scheme $SCHEME -destination 'platform=macOS'

# workspace 사용 시
xcodebuild test -workspace $WORKSPACE -scheme $SCHEME -destination 'platform=macOS'

# 특정 xctest 파일만 실행
xcodebuild test -project $PROJECT -scheme $SCHEME -destination 'platform=macOS' \
  -only-testing MyAppTests/VerificationTests
```

결과는 `$3` 디렉토리(OUTPUT_DIR)에 저장됩니다. xcresult 번들 위치 등을 커스터마이징할 수 있습니다.

---

## 주의사항

- 이 프리셋은 **manual starter template**입니다. 실제 테스트 로직은 adapter 스크립트에 구현되어야 합니다.
- `ai/scripts/ai/verifiers/xcuitest-macos.sh`를 프로젝트의 XCUITest 구조에 맞게 작성해야 합니다.
- environment variable(`$PROJECT`, `$SCHEME`) 설정 후 실행하세요.
