# Team Overlay Migration 가이드 (기존 프로젝트)

이미 팀 repo에 AI 워크플로 템플릿 파일이 커밋되어 있는 프로젝트에서, 템플릿 파일을 개인 private repo로 분리하는 방법.

## 언제 사용하는가

- 팀 프로젝트에 이미 `rd-workflow/`, `CLAUDE.md` 등이 커밋되어 있다
- 나만 이 템플릿을 사용하고 있어서 팀 repo에서 분리하고 싶다
- 여러 컴퓨터에서 워크플로 산출물에 접근하고 싶다

## 사전 준비

- GitHub에 private repo를 하나 만든다 (예: `me/myproject-ai-overlay`)
- 팀 repo에 대한 커밋 권한이 있는지 확인한다 (방법 선택에 영향)

## 상황별 분기

| 상황 | 방법 |
|------|------|
| `.gitignore` 변경을 팀에 커밋할 수 있다 | A. 깨끗한 분리 |
| 팀 repo를 건드리면 안 된다 | B. 조용한 분리 |

---

## 방법 A: 깨끗한 분리 (`.gitignore` 커밋 가능)

### 1. 기존 파일을 개인 overlay repo로 복사

```bash
cd /path/to/team-project

# overlay 디렉토리 생성 + 파일 복사
mkdir -p ~/ai-overlays/myproject
cp -r rd-workflow/ ~/ai-overlays/myproject/
for f in CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md; do
  [ -f "$f" ] && cp "$f" ~/ai-overlays/myproject/
done
[ -d .claude ] && cp -r .claude/ ~/ai-overlays/myproject/

# 개인 repo 초기화
cd ~/ai-overlays/myproject
git init
git add -A
git commit -m "init: team-project에서 AI workflow overlay 이관"
git remote add origin git@github.com:me/myproject-ai-overlay.git
git push -u origin main
```

### 2. 팀 repo에서 tracking 제거

```bash
cd /path/to/team-project

# git 추적만 제거 (로컬 파일은 그대로)
git rm -r --cached rd-workflow/
git rm --cached CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md 2>/dev/null
git rm -r --cached .claude/ 2>/dev/null

# .gitignore에 추가
cat >> .gitignore << 'EOF'
rd-workflow/
CLAUDE.md
CURRENT_TASK.md
REQUEST.md
PROJECT_CONTEXT.md
.claude/
EOF

git add .gitignore
git commit -m "chore: AI workflow 파일을 개인 관리로 전환

팀 repo에서 AI workflow 관련 파일의 tracking을 제거합니다.
해당 파일을 사용하는 사람은 개인 overlay repo에서 관리합니다."
```

### 3. 로컬 파일 제거 + symlink 연결

```bash
cd /path/to/team-project

# 로컬 파일 제거 (이미 overlay에 복사했으므로)
rm -rf rd-workflow/ CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md .claude/

# symlink 생성
ln -s ~/ai-overlays/myproject/ai ai
for f in CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md; do
  [ -f ~/ai-overlays/myproject/$f ] && ln -s ~/ai-overlays/myproject/$f $f
done
[ -d ~/ai-overlays/myproject/.claude ] && ln -s ~/ai-overlays/myproject/.claude .claude
```

### 4. 팀원에게 미치는 영향

- `git pull` 시 rd-workflow/ 파일이 삭제됨 → 팀원이 이 파일을 안 쓰고 있었다면 영향 없음
- 팀원 중 누군가 이 파일을 쓰고 있었다면 사전 공유 필요

---

## 방법 B: 조용한 분리 (팀 repo 변경 불가)

### 1. 기존 파일을 개인 overlay repo로 복사

방법 A의 1단계와 동일.

### 2. 로컬에서만 무시 설정

```bash
cd /path/to/team-project

# .git/info/exclude에 추가 (로컬 전용, 팀에 영향 없음)
cat >> .git/info/exclude << 'EOF'
rd-workflow/
CLAUDE.md
CURRENT_TASK.md
REQUEST.md
PROJECT_CONTEXT.md
.claude/
EOF
```

### 3. skip-worktree로 변경 감지 차단

```bash
# 팀 repo가 추적 중인 파일에 대해 로컬 변경을 무시하게 설정
git ls-files rd-workflow/ CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md .claude/ 2>/dev/null | \
  xargs -I{} git update-index --skip-worktree {}
```

### 4. 로컬 파일 제거 + symlink 연결

```bash
# 추적 중인 파일을 로컬에서 삭제 (skip-worktree 덕에 git이 무시)
rm -rf rd-workflow/ CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md .claude/

# symlink 생성
ln -s ~/ai-overlays/myproject/ai ai
for f in CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md; do
  [ -f ~/ai-overlays/myproject/$f ] && ln -s ~/ai-overlays/myproject/$f $f
done
[ -d ~/ai-overlays/myproject/.claude ] && ln -s ~/ai-overlays/myproject/.claude .claude
```

### 5. 주의사항 (방법 B 한정)

- `git reset --hard`: skip-worktree가 풀리고 원본 파일이 복원됨 → setup.sh 재실행 필요
- `git pull`로 팀이 rd-workflow/ 파일을 수정하면: 충돌 가능 → skip-worktree 재설정 필요
- 새 컴퓨터마다: `.git/info/exclude` + `skip-worktree` 재설정 필요 → setup.sh 필수

---

## setup.sh (양쪽 방법 공통)

개인 overlay repo에 넣어두면 새 컴퓨터에서 한 번에 설정 가능:

```bash
cat > ~/ai-overlays/myproject/setup.sh << 'SCRIPT'
#!/bin/bash
# 사용법: team-project 루트에서 실행
#   bash ~/ai-overlays/myproject/setup.sh

OVERLAY_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"

if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "error: git repo 루트에서 실행하세요"
  exit 1
fi

# 기존 파일/symlink 제거
for f in ai CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md .claude; do
  rm -rf "$PROJECT_DIR/$f"
done

# symlink 생성
ln -s "$OVERLAY_DIR/ai" "$PROJECT_DIR/ai"
for f in CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md; do
  [ -f "$OVERLAY_DIR/$f" ] && ln -s "$OVERLAY_DIR/$f" "$PROJECT_DIR/$f"
done
[ -d "$OVERLAY_DIR/.claude" ] && ln -s "$OVERLAY_DIR/.claude" "$PROJECT_DIR/.claude"

# .git/info/exclude 설정
for f in "rd-workflow/" "CLAUDE.md" "CURRENT_TASK.md" "REQUEST.md" "PROJECT_CONTEXT.md" ".claude/"; do
  grep -qxF "$f" "$PROJECT_DIR/.git/info/exclude" 2>/dev/null || echo "$f" >> "$PROJECT_DIR/.git/info/exclude"
done

# skip-worktree (방법 B용 — 이미 .gitignore에 있으면 무해)
git ls-files rd-workflow/ CLAUDE.md CURRENT_TASK.md REQUEST.md PROJECT_CONTEXT.md .claude/ 2>/dev/null | \
  xargs -I{} git update-index --skip-worktree {} 2>/dev/null

echo "done: $PROJECT_DIR ← $OVERLAY_DIR"
SCRIPT

chmod +x ~/ai-overlays/myproject/setup.sh
```

## 다른 컴퓨터에서 복구

```bash
# 1. 팀 repo clone
git clone git@github.com:team/project.git && cd project

# 2. 개인 overlay clone
git clone git@github.com:me/myproject-ai-overlay.git ~/ai-overlays/myproject

# 3. setup 실행
bash ~/ai-overlays/myproject/setup.sh
```

## 검증 체크리스트

- [ ] `ls -la rd-workflow/` → symlink 확인 (`ai -> ~/ai-overlays/...`)
- [ ] `git status` → rd-workflow/, CLAUDE.md 등이 untracked/ignored로 표시
- [ ] `cat rd-workflow/docs/flows/WORKFLOW.md` → 정상 읽힘
- [ ] Claude Code에서 `REQUEST.md`, `PROJECT_CONTEXT.md` 정상 접근
- [ ] `git diff` → 템플릿 파일 변경이 diff에 안 나옴
- [ ] 팀 브랜치에서 `git push` → 템플릿 파일 미포함 확인
