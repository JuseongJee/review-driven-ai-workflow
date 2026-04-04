# ios 프리셋 (manual starter template)

iOS 검증 프리셋입니다. 이는 프로젝트에 맞게 커스터마이징이 필요한 템플릿입니다.

## 개요

이 프리셋은 XCUITest 기반의 iOS 앱 UI 검증을 위해 설계되었습니다. 디자인 품질, 사용성, 플랫폼 컨벤션, 접근성 등을 평가합니다.

## 사용법

### 1. 프리셋 설치

```bash
cp ai/extensions/presets/ios/verification.json ai/config/verification.json
```

### 2. Xcode 프로젝트 구성

프리셋을 사용하기 전에 프로젝트에서 다음을 확인하세요:

- **Workspace**: `.xcworkspace` 파일이 존재하고 정상 구성되어 있는지 확인
  - CocoaPods를 사용하는 경우 필수
  - 단일 프로젝트 사용 시 `.xcodeproj` 사용 가능
- **Scheme**: 테스트 대상 scheme이 존재하고 테스트 타겟이 포함되어 있는지 확인
  - Scheme 설정: Xcode > Product > Scheme > Edit Scheme > Test에서 테스트 타겟 추가
- **Simulator**: 기본 시뮬레이터가 부팅 가능한지 확인

### 3. 환경변수 설정

XCUITest adapter를 실행하기 전에 다음 환경변수를 설정하세요:

```bash
# .env 또는 shell profile에 추가
export WORKSPACE="MyApp.xcworkspace"  # 또는 MyApp.xcodeproj
export SCHEME="MyAppTests"             # 테스트 scheme 이름
export DESTINATION="generic/platform=iOS Simulator"
# 또는 특정 시뮬레이터: "name=iPhone 16 Pro"
```

### 4. XCUITest 타겟 작성

프로젝트에 XCUITest 타겟이 있어야 합니다:

```bash
# Xcode UI 또는 명령줄에서
xcodebuild test -workspace MyApp.xcworkspace \
  -scheme MyAppTests \
  -destination "name=iPhone 16 Pro"
```

## 연속 스크린샷 (인터랙션 리뷰)

### XCUITest 사용 시

테스트 코드에서 단계별로 스크린샷을 캡처합니다:

```swift
func testCheckoutFlow() {
    let app = XCUIApplication()
    app.launch()

    // 1단계: 장바구니
    app.buttons["Cart"].tap()
    let screenshot1 = XCUIScreen.main.screenshot()
    let attach1 = XCTAttachment(screenshot: screenshot1)
    attach1.name = "step1-cart"
    add(attach1)

    // 2단계: 결제
    app.buttons["Checkout"].tap()
    let screenshot2 = XCUIScreen.main.screenshot()
    let attach2 = XCTAttachment(screenshot: screenshot2)
    attach2.name = "step2-checkout"
    add(attach2)
}
```

xcresult에서 스크린샷을 추출하여 `.verification/latest/xcuitest/`에 저장합니다.

### XCUITest 없이 수동 캡처

시뮬레이터에서 단계별로 캡처:

```bash
xcrun simctl io booted screenshot .verification/latest/xcuitest/step1-cart.png
# (앱에서 다음 단계로 이동)
xcrun simctl io booted screenshot .verification/latest/xcuitest/step2-checkout.png
```

AI Evaluator가 스크린샷 시퀀스를 보고 전환 흐름, safe area 유지, Dynamic Type 대응을 평가합니다.

## 검증 기준 커스터마이징

`verification.json`의 criteria를 프로젝트에 맞게 수정하세요:

### design-quality
- 디자인 시안 URL이나 경로 명시
- 예: "Figma URL: https://figma.com/...", "로컬 경로: docs/designs/"

### craft
- 프로젝트 디자인 시스템 기준 명시
- 예: "타이포 스케일: h1=32pt, h2=24pt, body=16pt"
- 예: "색상 팔레트: 이 파일 docs/design-system.md 참조"

### functionality
- 검증할 주요 user flow 목록
- 예:
  - 로그인 → 대시보드 진입
  - 게시물 작성 → 게시물 상세 조회
  - 사용자 프로필 수정

### accessibility
- 대상 화면 목록 명시
- 예: "홈 탭, 프로필 탭, 설정 화면에서 VoiceOver 지원 확인"
- Dynamic Type 대응 화면 목록

### safe-area
- 대상 device와 orientation 명시
- 예: "iPhone 16 Pro (portrait), iPhone SE (landscape), iPad (split view)"

### dynamic-type
- 접근성 크기에서 레이아웃 유지 확인할 화면
- 예: "홈 화면, 디테일 페이지에서 accessibility size 소/중/대 모두 테스트"

## xcresult 수집

XCUITest 실행 후 결과를 자동으로 수집합니다:

```bash
xcodebuild test \
  -workspace MyApp.xcworkspace \
  -scheme MyAppTests \
  -destination "name=iPhone 16 Pro" \
  -resultBundlePath "./build/test-results.xcresult"
```

xcresult 파일은 Xcode에서 직접 열 수 있으며, 스크린샷, 비디오, 로그 등을 포함합니다.

## 어댑터 구현

`ai/scripts/ai/verifiers/xcuitest.sh`를 프로젝트에 맞게 구현하세요:

1. 환경변수 검증
2. XCUITest 실행 및 결과 수집
3. 검증 기준에 따른 평가
4. 결과를 구조화된 형식으로 출력

현재는 스켈레톤 상태이므로, README.md의 지침을 따라 구현해야 합니다.

## 참고

- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
- [XCUITest 공식 문서](https://developer.apple.com/xcode/xcuitest/)
- [Accessibility 가이드](https://developer.apple.com/accessibility/)
