이 프로젝트는 이미 자체 규칙, 문서, 스크립트, 작업 방식이 있는 기존 프로젝트다.

배포 repo URL이 제공되었다면 먼저 임시 clone한다:
```bash
git clone --depth 1 <배포 repo URL> /tmp/rd-workflow-template-src
```

해야 할 일:
- 기존 규칙 문서와 스크립트를 읽는다
- 템플릿 파일(clone한 소스 또는 현재 프로젝트에 이미 있는 파일)과 충돌 지점을 찾는다
- 유지할 규칙, 합칠 규칙, 지워도 되는 중복을 구분한다
- 그 결과를 바탕으로 `PROJECT_CONTEXT.md`, `CLAUDE.md`, 검증 스크립트를 프로젝트 기준으로 수정한다

중요:
- 추측하지 말 것
- 실제 파일 기준으로 판단할 것
- 기존 규칙을 함부로 버리지 말 것

완료 후 임시 clone 디렉토리가 있으면 정리한다:
```bash
rm -rf /tmp/rd-workflow-template-src
```
