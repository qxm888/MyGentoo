#!/usr/bin/env bash
# ============================================================
#  sync.sh — 一键把本机配置同步到 dotfiles 仓库
#  流程: 同步文件 → 隐私/密钥扫描（不通过就中止）→ git commit → 推送到所有远程
#
#  用法:
#     bash scripts/sync.sh                  # 同步 + 扫描 + 提交 + 推送
#     bash scripts/sync.sh -n               # 预览（绝不改文件、不提交、不推送）
#     bash scripts/sync.sh -m "改了键位"     # 自定义提交说明
#     bash scripts/sync.sh --no-push        # 只提交，不推送
#     bash scripts/sync.sh --allow-secrets  # 扫描命中仍继续（⚠️ 仅确认无害时用）
#
#  作者: 梦梦  2026-10-01
# ============================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY=0; NOPUSH=0; ALLOW=0; MSG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)    DRY=1; shift ;;
        --no-push)       NOPUSH=1; shift ;;
        --allow-secrets) ALLOW=1; shift ;;
        -m)              MSG="${2:-}"; shift 2 ;;
        -h|--help)       sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "未知参数: $1（-h 看帮助）"; exit 1 ;;
    esac
done

C_=$'\033[36m'; G_=$'\033[32m'; Y_=$'\033[33m'; R_=$'\033[31m'; N_=$'\033[0m'
say()  { printf '%s[•]%s %s\n' "$C_" "$N_" "$*"; }
ok()   { printf '%s[✓]%s %s\n' "$G_" "$N_" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y_" "$N_" "$*"; }
err()  { printf '%s[✗]%s %s\n' "$R_" "$N_" "$*"; }
[[ $DRY -eq 1 ]] && { R_=$'\033[35m'; warn "DRY-RUN 模式：只预览，不会改动任何文件"; }

# ---------- 判定系统 ----------
if [[ -d /etc/portage || -e /etc/gentoo-release ]]; then SYSTEM=gentoo; else SYSTEM=arch; fi
CONFIG="$HOME/.config"
say "系统=${SYSTEM}  仓库=${REPO}  主机=$(hostname)  分支=$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"

# 绝不能被 --delete 干掉的仓库自带工具
KEEP_TOOLS=(--exclude=sync.sh --exclude=save.sh --exclude=restore.sh --exclude=auto-snapshots.sh)
RSYNC_OPTS=(-a --delete --exclude='*.bak*' --exclude='*.bak.*' "${KEEP_TOOLS[@]}")
[[ $DRY -eq 1 ]] && RSYNC_OPTS+=(--dry-run -i)
CP_OPTS=(-a); [[ $DRY -eq 1 ]] && CP_OPTS=(-a --no-clobber --dry-run)   # dry-run 时不覆盖

sync_dir() {  # $1=仓库内目录名 $2=源目录
    [[ -d "$2" ]] || return 0
    mkdir -p "$REPO/$1"
    if [[ $DRY -eq 1 ]]; then
        local out; out=$(rsync "${RSYNC_OPTS[@]}" "$2/" "$REPO/$1/" 2>/dev/null)
        if [[ -n "$out" ]]; then ok "$1  ←  $2"; echo "$out" | sed 's/^/      /' | head -15
        else warn "$1  无变化"; fi
    else
        rsync "${RSYNC_OPTS[@]}" "$2/" "$REPO/$1/" >/dev/null
        ok "$1  ←  $2"
    fi
}
sync_file() {  # $1=仓库内路径 $2=源文件
    [[ -f "$2" ]] || return 0
    mkdir -p "$(dirname "$REPO/$1")"
    if [[ $DRY -eq 1 ]]; then
        diff -q "$REPO/$1" "$2" >/dev/null 2>&1 && warn "$1  无变化" || ok "$1  ←  $2（有变化）"
    else
        cp "${CP_OPTS[@]}" "$2" "$REPO/$1" && ok "$1  ←  $2"
    fi
}

say "===== 1/4 同步家目录配置 ====="
for d in hypr kitty fish fcitx5 fastfetch ohmyposh btop; do sync_dir "$d" "$CONFIG/$d"; done
sync_dir systemd "$CONFIG/systemd/user"          # 仓库里 systemd/ 直接对应 ~/.config/systemd/user
if [[ $SYSTEM == gentoo ]]; then
    for d in noctalia environment.d; do sync_dir "$d" "$CONFIG/$d"; done
    # opencode：只挑配置文件，绝不带 service.json（里面有服务端密码）
    for f in opencode.jsonc package.json package-lock.json .gitignore; do
        sync_file "opencode/$f" "$CONFIG/opencode/$f"
    done
    [[ -d "$CONFIG/opencode/agent" ]] && sync_dir opencode/agent "$CONFIG/opencode/agent"
fi
for f in .bashrc .bash_profile; do sync_file "shell/$f" "$HOME/$f"; done
sync_dir scripts "$HOME/opencode/scripts"          # 已排除 sync/save/restore/auto-snapshots.sh
sync_file "scripts/auto-snapshots.sh" "$CONFIG/hypr/auto-snapshots.sh"

if [[ $SYSTEM == gentoo && $DRY -eq 0 ]]; then
    say "===== 2/4 同步 /etc 系统级配置（需要 root）====="
    as_root() { if [[ $EUID -eq 0 ]]; then "$@"; elif sudo -n true 2>/dev/null; then sudo "$@"; else pkexec "$@"; fi; }
    if as_root bash -s -- "$REPO" <<'EOS'; then ok "etc/"
set -e
REPO="$1"
mkdir -p "$REPO/etc/portage"
rsync -a --exclude='gnupg/' /etc/portage/ "$REPO/etc/portage/"   # gnupg 有私钥，必须排除
for f in nftables.conf issue fstab; do cp -a "/etc/$f" "$REPO/etc/$f"; done
cp -a /etc/sysctl.d/99-hardening.conf            "$REPO/etc/sysctl.d/"
cp -a /etc/fail2ban/jail.d/gentoo.local          "$REPO/etc/fail2ban/jail.d/"
cp -a /etc/default/ufw                           "$REPO/etc/default/"
cp -a /etc/ufw/user.rules                        "$REPO/etc/ufw/"
cp -a /etc/pam.d/login                           "$REPO/etc/pam.d/"
cp -a /etc/systemd/system/getty@.service.d/10-clear.conf "$REPO/etc/systemd/system/getty@.service.d/"
K=$(ls -1 /etc/kernels/kernel-config-* 2>/dev/null | tail -1 || true)
[ -n "$K" ] && cp -a "$K" "$REPO/etc/kernels/$(basename "$K")"
EOS
    else warn "/etc 同步失败（跳过，不影响后续）"; fi
fi

say "===== 3/4 隐私与密钥扫描 ====="
SCAN=$(mktemp)
scan_grep() {
    grep -rInEi --exclude-dir=.git --exclude='kernel-config-*' --exclude='linux-firmware-*' \
         --exclude='.secretscan-ignore' -e "$1" "$REPO" 2>/dev/null >> "$SCAN" || true
}
scan_grep 'BEGIN [A-Z ]*PRIVATE KEY'
scan_grep 'sk-[A-Za-z0-9]{16,}'
scan_grep 'ghp_[A-Za-z0-9]{20,}'
scan_grep 'gho_[A-Za-z0-9]{20,}'
scan_grep 'glpat-[A-Za-z0-9_-]{10,}'
scan_grep 'AKIA[0-9A-Z]{16}'
scan_grep 'xox[bapr]-[A-Za-z0-9-]{10,}'
scan_grep '(password|passwd|passphrase|secret|token|api[_-]?key|access[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]]{4,}'
scan_grep '1[3-9][0-9]{9}'
grep -rInE --exclude-dir=.git --exclude='kernel-config-*' --exclude='linux-firmware-*' \
     -e '\b([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)' "$REPO" 2>/dev/null \
  | grep -vE '\b(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|0\.0\.0\.0|255\.|169\.254\.)' >> "$SCAN" || true

IGNORE="$REPO/.secretscan-ignore"
if [[ -f "$IGNORE" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        grep -vE "$line" "$SCAN" > "$SCAN.tmp" 2>/dev/null; mv "$SCAN.tmp" "$SCAN"
    done < "$IGNORE"
fi
sort -u "$SCAN" -o "$SCAN"

if [[ -s "$SCAN" ]]; then
    err "扫描命中 $(wc -l < "$SCAN") 行，请人工确认："
    sed "s|$REPO/||" "$SCAN" | head -40 | sed 's/^/    /'
    if [[ $ALLOW -eq 0 ]]; then
        err "已中止（未提交、未推送）。处理方式：改文件 / 把误报写进 $IGNORE / 加 --allow-secrets"
        rm -f "$SCAN"; exit 2
    fi
    warn "--allow-secrets 已指定，继续"
else
    ok "未发现 密码 / token / 私钥 / 公网 IP / 手机号"
fi
rm -f "$SCAN"

say "===== 4/4 提交并推送 ====="
cd "$REPO"
if [[ -z "$(git status --porcelain)" ]]; then
    ok "工作区干净，没有变化"
else
    git status --short | head -30
    echo "    共 $(git status --porcelain | wc -l) 项变化"
    if [[ $DRY -eq 1 ]]; then
        warn "dry-run：不提交、不推送"
    else
        [[ -z "$MSG" ]] && MSG="sync: ${SYSTEM} 配置更新 $(date '+%Y-%m-%d %H:%M')"
        git add -A && git commit -q -m "$MSG"
        ok "已提交: $(git log --oneline -1)"
        if [[ $NOPUSH -eq 1 ]]; then
            warn "--no-push：跳过推送"
        else
            BR="$(git rev-parse --abbrev-ref HEAD)"; FAIL=0
            for r in $(git remote); do
                if git push "$r" "$BR" >"/tmp/.sync-push-$r.log" 2>&1; then
                    ok "推送 $r  ($(git remote get-url "$r"))"
                else
                    err "推送失败 $r"; tail -3 "/tmp/.sync-push-$r.log" | sed 's/^/      /'; FAIL=1
                fi
                rm -f "/tmp/.sync-push-$r.log"
            done
            [[ $FAIL -eq 0 ]] && ok "全部远程推送完成 🎉" || err "有远程失败，看上面输出"
        fi
    fi
fi
