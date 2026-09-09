# mktemp -d 가드 정적 대조.
# 호출: awk -f _mktemp_scan.awk <파일...>
# 출력: VIOLATION<TAB>file<TAB>lineno<TAB>reason<TAB>line  (위반 1건당 한 줄)
#       SUMMARY<TAB>sites<TAB>violations                    (마지막 한 줄)
# files 는 내지 않습니다 — awk 의 FNR==1 은 빈 파일을 세지 않으므로 호출부가 셉니다.
#
# 후보 제외는 세 가지뿐입니다 — ① 주석 줄 ② `mktemp-scan: literal` 마커가 있는 줄
# ③ 검사 자신의 파일(호출부가 목록에서 뺍니다). 이스케이프·백슬래시 parity·인용 구간
# 판정을 하지 않습니다 — 그 판정을 세 번 고쳤고 매번 새 false negative 가 나왔습니다.
#
# **아래 Step 4~6 으로 실제 실행 검증됐습니다** (BSD awk 20200816):
#   표본 → SUMMARY 12 11 · 블록별 집합 일치 · 비위반 블록 교집합 없음
#   정본 트리 → 변경 전 10건, promote.sh:456 마커 적용 시 그 파일 0건, 변경 후 8건

BEGIN {
  sites = 0; violations = 0; pend = 0
  NEEDLE = "mktemp" " -d"
  SUB    = "$("
  MARKER = "mktemp" "-scan: literal"   # 선언적 제외 마커 (리터럴을 쪼개 자기참조 회피)
  A_MID  = "=\"" SUB NEEDLE
  A_TAIL = ")\" || { echo \""
  A_MSG  = ": 임시 디렉터리 생성 실패 (" "mktemp" " rc≠0, TMPDIR='${TMPDIR:-}')\" >&2; "
  B_PRE  = "[[ -n \"$"
  B_MID  = "\" && -d \"$"
  B_TAIL = "\" ]] || { echo \""
  B_MSG  = ": 임시 디렉터리 경로 검증 실패 (TMPDIR='${TMPDIR:-}')\" >&2; "
  TAIL   = "; }"
}
FNR == 1 { resolve("") }
{
  if (pend) resolve($0)
  line = $0
  if (line ~ /^[ \t]*#/) next               # ① 주석 줄
  if (index(line, NEEDLE) == 0) next
  if (index(line, MARKER) > 0) next         # ② 선언적 제외 마커
  sites++
  p_line = line; p_no = FNR; p_file = FILENAME; pend = 1
}
END { resolve(""); printf "SUMMARY\t%d\t%d\n", sites, violations }




function resolve(second) {
  if (!pend) return
  pend = 0
  if (p_line ~ /^[ \t]*(local|export)[ \t]/) { report("decl-combined"); return }
  if (second == "") { report("template-mismatch"); return }
  if (!template_ok(p_line, second)) report("template-mismatch")
}
function report(reason) {
  printf "VIOLATION\t%s\t%d\t%s\t%s\n", p_file, p_no, reason, p_line
  violations++
}
function template_ok(a, b,   ia, ib, ra, rb, v, args, label, term, want, p) {
  ia = indent_of(a); ib = indent_of(b)
  if (ia == "TAB" || ib == "TAB" || ia != ib) return 0
  ra = substr(a, length(ia) + 1); rb = substr(b, length(ib) + 1)
  v = head_ident(ra)
  if (v == "") return 0
  if (substr(ra, length(v) + 1, length(A_MID)) != A_MID) return 0
  args = substr(ra, length(v) + length(A_MID) + 1)
  if (substr(args, 1, length(A_TAIL)) == A_TAIL) { args = "" }
  else {
    p = index(args, A_TAIL)
    if (p == 0) return 0
    args = substr(args, 1, p - 1)
    if (args !~ /^ "[^"]*"$/) return 0
  }
  ra = substr(ra, length(v) + length(A_MID) + length(args) + length(A_TAIL) + 1)
  p = index(ra, A_MSG)
  if (p == 0) return 0
  label = substr(ra, 1, p - 1)
  if (label == "" || index(label, "\"") > 0) return 0
  term = substr(ra, p + length(A_MSG))
  if (substr(term, length(term) - length(TAIL) + 1) != TAIL) return 0
  term = substr(term, 1, length(term) - length(TAIL))
  if (!term_ok(term)) return 0
  want = B_PRE v B_MID v B_TAIL label B_MSG term TAIL
  return (rb == want)
}
function indent_of(s,   i, c, r) {
  r = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == " ") r = r " "
    else if (c == "\t") return "TAB"
    else break
  }
  return r
}
function head_ident(s,   i, c, r) {
  r = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (i == 1) { if (c !~ /^[A-Za-z_]$/) return "" }
    else if (c !~ /^[A-Za-z0-9_]$/) break
    r = r c
  }
  return r
}
function term_ok(t,   n) {
  if (t !~ /^(exit|return) [1-9][0-9]*$/) return 0
  n = t; sub(/^(exit|return) /, "", n); n = n + 0
  return (n >= 1 && n <= 255)
}
