#!/usr/bin/env bash
# ============================================================
#  restore.sh — 从本仓库恢复 Gentoo 配置到本机
#  用法:
#     bash scripts/restore.sh              # 交互确认
#     bash scripts/restore.sh --yes        # 全部覆盖（自动备份）
#     bash scripts/restore.sh --only hypr  # 只恢复指定项
#  安全策略: 覆盖前一律先备份为 <目标>.bak-<时间戳>
# ============================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$HOME/.config"
TS="$(date +%Y%m%d-%H%M%S)"
YES=0; ONLY=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) YES=1; shift ;;
        --only)   ONLY="$2"; shift 2 ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

say()  { printf '\033[36m[•]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }
ask()  { [[ $YES -eq 1 ]] && return 0; read -r -p "$1 [Y/n] " a; [[ -z $a || $a =~ ^[Yy]$ ]]; }

as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"
    elif sudo -n true 2>/dev/null; then sudo "$@"
    else pkexec "$@"; fi
}

restore_dir() {
    local name="$1" dest="$2"
    [[ -n $ONLY && $ONLY != "$name" ]] && return 0
    [[ -d "$REPO/$name" ]] || return 0
    if [[ -e "$dest" ]]; then
        ask "覆盖 $dest ？" || { warn "跳过 $dest"; return 0; }
        mv "$dest" "${dest}.bak-$TS"
        ok "已备份 → ${dest}.bak-$TS"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a "$REPO/$name" "$dest"
    ok "恢复: $dest"
}

restore_file() {
    local src="$1" dest="$2" name="$3"
    [[ -n $ONLY && $ONLY != "$name" ]] && return 0
    [[ -f "$REPO/$src" ]] || return 0
    if [[ -f "$dest" ]]; then
        ask "覆盖 $dest ？" || { warn "跳过 $dest"; return 0; }
        cp -a "$dest" "${dest}.bak-$TS"
    fi
    cp -a "$REPO/$src" "$dest" 2>/dev/null || { warn "无权限写 $dest（请手动 sudo cp）"; return 0; }
    ok "恢复: $dest"
}

echo "仓库: $REPO"
echo "备份后缀: .bak-$TS"
echo

say "===== 家目录配置 ====="
restore_dir hypr          "$CONFIG/hypr"
restore_dir kitty         "$CONFIG/kitty"
restore_dir fish          "$CONFIG/fish"
restore_dir fcitx5        "$CONFIG/fcitx5"
restore_dir fastfetch     "$CONFIG/fastfetch"
restore_dir ohmyposh      "$CONFIG/ohmyposh"
restore_dir noctalia      "$CONFIG/noctalia"
restore_dir environment.d "$CONFIG/environment.d"
restore_dir systemd       "$CONFIG/systemd/user"
restore_dir opencode      "$CONFIG/opencode"
restore_file "shell/.bashrc"       "$HOME/.bashrc"       shell
restore_file "shell/.bash_profile" "$HOME/.bash_profile" shell
restore_dir scripts       "$HOME/opencode/scripts"

say "===== 系统配置（需要 root）====="
if ask "恢复 /etc 下的系统配置（portage / nftables / fail2ban / sysctl / pam / issue / fstab 等）？"; then
    as_root bash -s -- "$REPO" "$TS" <<'EOS'
set -e
REPO="$1"; TS="$2"
bk() { [ -e "$REPO/../$(basename "$1")" ] || true; }
# portage（先整体备份一份）
[ -d /etc/portage ] && cp -a /etc/portage "/etc/portage.bak-$TS"
rsync -a "$REPO/etc/portage/" /etc/portage/
for f in nftables.conf issue fstab; do
    [ -f "$REPO/etc/$f" ] && cp -a "/etc/$f" "/etc/$f.bak-$TS" 2>/dev/null || true
    [ -f "$REPO/etc/$f" ] && cp -a "$REPO/etc/$f" "/etc/$f"
done
[ -f "$REPO/etc/sysctl.d/99-hardening.conf" ] && cp -a "$REPO/etc/sysctl.d/99-hardening.conf" /etc/sysctl.d/
[ -f "$REPO/etc/fail2ban/jail.d/gentoo.local" ] && cp -a "$REPO/etc/fail2ban/jail.d/gentoo.local" /etc/fail2ban/jail.d/
[ -f "$REPO/etc/default/ufw" ] && cp -a "$REPO/etc/default/ufw" /etc/default/ufw
[ -f "$REPO/etc/ufw/user.rules" ] && cp -a "$REPO/etc/ufw/user.rules" /etc/ufw/user.rules
[ -f "$REPO/etc/pam.d/login" ] && cp -a "$REPO/etc/pam.d/login" /etc/pam.d/login
[ -f "$REPO/etc/systemd/system/getty@.service.d/10-clear.conf" ] && cp -a "$REPO/etc/systemd/system/getty@.service.d/10-clear.conf" /etc/systemd/system/getty@.service.d/
cp -a "$REPO"/etc/kernels/kernel-config-* /etc/kernels/ 2>/dev/null || true
echo "  /etc 恢复完成"
EOS
    ok "系统配置已恢复（原文件带 .bak-$TS）"
    warn "提示: dispatch-conf / etc-update 后再重启 systemd 与防火墙服务"
fi

echo
say "===== 别忘了（未纳入仓库的敏感文件）====="
echo "  ~/.config/opencode/service.json  · /etc/portage/gnupg/ · /etc/frp/frpc.toml · /etc/ssh/sshd_config · ~/.ssh/"
echo
ok "恢复流程结束，建议重登一次会话。"
