#!/usr/bin/env bash
# ============================================================
#  secretscan.sh — 隐私 / 密钥扫描（供 sync.sh 与 .githooks/pre-commit 共用）
#
#  用法:
#     bash scripts/secretscan.sh              # 扫描整个仓库
#     bash scripts/secretscan.sh --staged     # 只扫描 git 暂存区（pre-commit 用）
#     bash scripts/secretscan.sh --quiet      # 只在命中时输出
#     bash scripts/secretscan.sh <目录>       # 扫描指定目录
#
#  退出码: 0=干净  2=命中（会阻断提交）
#  白名单: 仓库根目录 .secretscan-ignore（每行一个 grep -E 正则）
# ============================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGED=0; QUIET=0; TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --staged) STAGED=1; shift ;;
        -q|--quiet) QUIET=1; shift ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) TARGET="$1"; shift ;;
    esac
done
[[ -z "$TARGET" ]] && TARGET="$REPO"

PATTERNS=(
    'BEGIN [A-Z ]*PRIVATE KEY'
    'sk-[A-Za-z0-9]{16,}'
    'ghp_[A-Za-z0-9]{20,}'
    'gho_[A-Za-z0-9]{20,}'
    'glpat-[A-Za-z0-9_-]{10,}'
    'AKIA[0-9A-Z]{16}'
    'xox[bapr]-[A-Za-z0-9-]{10,}'
    '(password|passwd|passphrase|secret|token|api[_-]?key|access[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]]{4,}'
    '1[3-9][0-9]{9}'
)
GREP_ARGS=(); for p in "${PATTERNS[@]}"; do GREP_ARGS+=(-e "$p"); done
SKIP=(--exclude='kernel-config-*' --exclude='linux-firmware-*' --exclude='.secretscan-ignore')

HITS=$(mktemp)
cleanup() { rm -f "$HITS" "$HITS.tmp"; }
trap cleanup EXIT

if [[ $STAGED -eq 1 ]]; then
    # 只看暂存区内容（git show :file），确保"即将提交的东西"本身干净
    while IFS= read -r f; do
        [[ -f "$REPO/$f" || -n "$(git -C "$REPO" cat-file -e ":$f" 2>/dev/null && echo y)" ]] || continue
        case "$f" in kernel-config-*|*/kernel-config-*|*linux-firmware*|.secretscan-ignore) continue ;; esac
        git -C "$REPO" show ":$f" 2>/dev/null \
          | grep -nEi "${GREP_ARGS[@]}" 2>/dev/null \
          | sed "s|^|$f:|" >> "$HITS"
    done < <(git -C "$REPO" diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
else
    grep -rInEi "${SKIP[@]}" --exclude-dir=.git "${GREP_ARGS[@]}" "$TARGET" 2>/dev/null >> "$HITS" || true
    # 公网 IPv4（排除私网/回环，以及 1.2.3.4.fw 这类版本号写法）
    grep -rInE "${SKIP[@]}" --exclude-dir=.git \
         -e '\b([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)' "$TARGET" 2>/dev/null \
      | grep -vE '\b(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|0\.0\.0\.0|255\.|169\.254\.)' >> "$HITS" || true
fi

# 白名单过滤
IGNORE="$REPO/.secretscan-ignore"
if [[ -f "$IGNORE" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        grep -vE "$line" "$HITS" > "$HITS.tmp" 2>/dev/null; mv "$HITS.tmp" "$HITS"
    done < "$IGNORE"
fi
sort -u "$HITS" -o "$HITS"

R_=$'\033[31m'; G_=$'\033[32m'; N_=$'\033[0m'
if [[ -s "$HITS" ]]; then
    echo -e "${R_}✗ 隐私扫描命中 $(wc -l < "$HITS") 行：${N_}" >&2
    sed "s|$REPO/||" "$HITS" | head -40 | sed 's/^/    /' >&2
    echo -e "${R_}  处理: 改掉内容 / 把误报写进 .secretscan-ignore / 临时用 git commit --no-verify${N_}" >&2
    exit 2
fi
[[ $QUIET -eq 0 ]] && echo -e "${G_}✓ 隐私扫描通过：无异见（密码/token/私钥/公网 IP/手机号）${N_}"
exit 0
