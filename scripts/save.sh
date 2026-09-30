#!/usr/bin/env bash
# ============================================================
#  save.sh — 把 Gentoo 本机当前配置同步进本仓库
#  用法:
#     bash scripts/save.sh            # 真正同步
#     bash scripts/save.sh -n         # 只显示差异（dry-run）
#  作者: 梦梦    日期: 2026-10-01
# ============================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$HOME/.config"
DRY=()
[[ "${1:-}" == "-n" || "${1:-}" == "--dry-run" ]] && DRY=(--dry-run)

say()  { printf '\033[36m[•]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }

# ---------- root 执行器：优先 sudo，无免密则 pkexec 弹窗 ----------
as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"
    elif sudo -n true 2>/dev/null; then sudo "$@"
    else pkexec "$@"; fi
}

# ---------- 1. 家目录 dotfiles ----------
say "同步家目录配置 → $REPO"
for d in hypr kitty fish fcitx5 fastfetch ohmyposh noctalia environment.d systemd; do
    [[ -d "$CONFIG/$d" ]] || continue
    mkdir -p "$REPO/$d"
    rsync -a --delete --exclude='*.bak*' "${DRY[@]}" "$CONFIG/$d/" "$REPO/$d/"
    ok "$d"
done

mkdir -p "$REPO/shell"
for f in .bashrc .bash_profile; do
    [[ -f "$HOME/$f" ]] && cp -a "$HOME/$f" "$REPO/shell/$f" && ok "shell/$f"
done

# ---------- 2. opencode 配置（不含 service.json / node_modules）----------
if [[ -d "$CONFIG/opencode" ]]; then
    mkdir -p "$REPO/opencode/agent"
    for f in opencode.jsonc package.json package-lock.json .gitignore; do
        [[ -f "$CONFIG/opencode/$f" ]] && cp -a "$CONFIG/opencode/$f" "$REPO/opencode/$f"
    done
    [[ -d "$CONFIG/opencode/agent" ]] && rsync -a --delete "$CONFIG/opencode/agent/" "$REPO/opencode/agent/"
    ok "opencode/（已排除 service.json）"
fi

# ---------- 3. 用户脚本 ----------
if [[ -d "$HOME/opencode/scripts" ]]; then
    mkdir -p "$REPO/scripts"
    rsync -a --delete --exclude='*.bak*' "${DRY[@]}" "$HOME/opencode/scripts/" "$REPO/scripts/"
    cp -a "$CONFIG/hypr/auto-snapshots.sh" "$REPO/scripts/auto-snapshots.sh" 2>/dev/null || true
    ok "scripts/"
fi

# ---------- 4. 系统级配置 → etc/（需要 root）----------
say "同步系统配置 → $REPO/etc（需要 root，可能会弹一次密码框）"
ETC_FILES=(
    etc/nftables.conf
    etc/issue
    etc/fstab
    etc/sysctl.d/99-hardening.conf
    etc/fail2ban/jail.d/gentoo.local
    etc/default/ufw
    etc/ufw/user.rules
    etc/pam.d/login
    etc/systemd/system/getty@.service.d/10-clear.conf
    etc/kernels/kernel-config-7.2.8-gentoo-x86_64
)
KERNEL_SRC="$(ls -1 /etc/kernels/kernel-config-* 2>/dev/null | tail -1 || true)"

as_root bash -s -- "$REPO" "$KERNEL_SRC" "${DRY[@]}" <<'EOS'
set -e
REPO="$1"; KERNEL_SRC="$2"; shift 2
mkdir -p "$REPO/etc/portage"
# portage 配置（排除 gnupg 私钥目录）
rsync -a --exclude='gnupg/' "$@" /etc/portage/ "$REPO/etc/portage/"
for f in nftables.conf issue fstab; do cp -a "/etc/$f" "$REPO/etc/$f"; done
cp -a /etc/sysctl.d/99-hardening.conf "$REPO/etc/sysctl.d/"
cp -a /etc/fail2ban/jail.d/gentoo.local "$REPO/etc/fail2ban/jail.d/"
cp -a /etc/default/ufw "$REPO/etc/default/"
cp -a /etc/ufw/user.rules "$REPO/etc/ufw/"
cp -a /etc/pam.d/login "$REPO/etc/pam.d/"
cp -a /etc/systemd/system/getty@.service.d/10-clear.conf "$REPO/etc/systemd/system/getty@.service.d/"
if [ -n "$KERNEL_SRC" ]; then cp -a "$KERNEL_SRC" "$REPO/etc/kernels/$(basename "$KERNEL_SRC")"; fi
# 注：etc/polkit-1/rules.d/ 是「仓库 → 系统」的部署方向（见 sync.sh），save.sh 不动它
EOS
ok "etc/"

# ---------- 5. 汇总 ----------
echo
say "仓库当前状态："
cd "$REPO" && git status --short || true
echo
if [[ ${#DRY[@]} -gt 0 ]]; then
    warn "这是 dry-run，没有实际写入。去掉 -n 才会真的同步。"
else
    ok "同步完成。检查无误后：git add -A && git commit -m '更新配置' && git push"
fi
