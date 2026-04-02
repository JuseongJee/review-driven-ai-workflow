# workspace 디렉토리 구조 마이그레이션

구형 디렉토리 구조(`ai/docs/superpowers/`)를 신형 구조(`ai/workspace/`)로 마이그레이션합니다.

## 감지 조건

`ai/docs/superpowers/` 디렉토리가 존재하면 구형 구조입니다.

## 마이그레이션 절차

### 1. 디렉토리 생성

```bash
mkdir -p ai/workspace/specs/base
mkdir -p ai/workspace/specs/changes
mkdir -p ai/workspace/plans
mkdir -p ai/workspace/reports/reviews
mkdir -p ai/workspace/reports/autopilot
mkdir -p ai/workspace/backlog
```

### 2. 파일 이동

기존 작업 산출물을 보존하면서 이동합니다.

```bash
# specs
mv ai/docs/superpowers/specs/base/* ai/workspace/specs/base/ 2>/dev/null
mv ai/docs/superpowers/specs/changes/* ai/workspace/specs/changes/ 2>/dev/null

# plans
mv ai/docs/superpowers/plans/* ai/workspace/plans/ 2>/dev/null

# backlog
mv ai/docs/backlog/* ai/workspace/backlog/ 2>/dev/null

# reports (존재하는 경우)
mv ai/docs/reports/* ai/workspace/reports/ 2>/dev/null

# handoffs (존재하는 경우)
mkdir -p ai/workspace/handoffs
mv handoffs/* ai/workspace/handoffs/ 2>/dev/null
```

**참고**: 위 목록에 없지만 `ai/docs/` 아래에 작업 산출물 성격의 프로젝트 고유 디렉토리가 남아 있으면, `ai/workspace/`로 이동할지 사용자에게 확인한다.

### 3. 빈 디렉토리 정리

```bash
rm -rf ai/docs/superpowers
rm -rf ai/docs/backlog
rm -rf ai/docs/reports
rm -rf handoffs
```

### 4. 확인

마이그레이션 결과를 사용자에게 보여줍니다:
- 이동된 파일 목록
- 정리된 디렉토리 목록

이후 동기화 단계에서 템플릿의 최신 파일(CLAUDE.md, skill 등)로 덮어쓰면 경로 참조도 자동으로 업데이트됩니다.
