#!/usr/bin/env bash
# ============================================================
#  sync.sh — 一键把配置同步到 dotfiles 仓库
#  流程: 同步文件 → 隐私/密钥扫描（不通过就中止）→ git commit → 推送到所有远程
#
#  用法:
#     bash scripts/sync.sh                  # 同步 + 扫描 + 提交 + 推送
#     bash scripts/sync.sh -n               # 预览（绝不改文件、不提交、不推送）
#     bash scripts/sync.sh -m "改了键位"     # 自定义提交说明
#     bash scripts/sync.sh -H /home/xxx     # 指定源家目录（默认从仓库路径推导）
#     bash scripts/sync.sh --no-push        # 只提交，不推送
#     bash scripts/sync.sh --allow-secrets  # 扫描命中仍继续（⚠️ 仅确认无害时用）
#
#  设计说明:
#    * 源家目录 SRC_HOME 默认由仓库位置推导 —— 仓库放在 <home>/opencode/<name>，
#      所以 dirname(dirname(REPO)) 就是 <home>。这样在 Gentoo 上也能正确地
#      同步 Arch 的配置（/home/dovahkiin），不会串味。
#    * 仓库布局由仓库自身决定：有 etc/ 目录 = Gentoo 布局（带系统级配置），
#      否则 = Arch 布局。可用 -H 覆盖源、--layout 覆盖布局。
#    * /etc 部分永远是"当前主机"的 /etc（需要 root）。
#
#  作者: 梦梦  2026-10-01
# ============================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY=0; NOPUSH=0; ALLOW=0; MSG=""; SRC_HOME=""; LAYOUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)    DRY=1; shift ;;
        --no-push)       NOPUSH=1; shift ;;
        --allow-secrets) ALLOW=1; shift ;;
        -m)              MSG="${2:-}"; shift 2 ;;
        -H|--home)       SRC_HOME="${2:-}"; shift 2 ;;
        --layout)        LAYOUT="${2:-}"; shift 2 ;;
        -h|--help)       sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "未知参数: $1（-h 看帮助）"; exit 1 ;;
    esac
done

C_=$'\033[36m'; G_=$'\033[32m'; Y_=$'\033[33m'; R_=$'\033[31m'; N_=$'\033[0m'
say()  { printf '%s[•]%s %s\n' "$C_" "$N_" "$*"; }
ok()   { printf '%s[✓]%s %s\n' "$G_" "$N_" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y_" "$N_" "$*"; }
err()  { printf '%s[✗]%s %s\n' "$R_" "$N_" "$*"; }

# ---------- 确定源家目录 & 布局 ----------
if [[ -z "$SRC_HOME" ]]; then
    SRC_HOME="$(dirname "$(dirname "$REPO")")"          # <home>/opencode/<repo> → <home>
    [[ -d "$SRC_HOME" ]] || SRC_HOME="$HOME"
fi
if [[ -z "$LAYOUT" ]]; then
    [[ -d "$REPO/etc" ]] && LAYOUT=gentoo || LAYOUT=arch
fi
CONFIG="$SRC_HOME/.config"
say "布局=${LAYOUT}  源家目录=${SRC_HOME}  仓库=${REPO}  主机=$(hostname)"
[[ $DRY -eq 1 ]] && warn "DRY-RUN：只预览，不改文件、不提交、不推送"

# 仓库自带工具，绝不能被 --delete 干掉
KEEP_TOOLS=(--exclude=sync.sh --exclude=save.sh --exclude=restore.sh --exclude=auto-snapshots.sh --exclude=secretscan.sh --exclude=grub-gentoo-sync.sh)
RSYNC_OPTS=(-a --delete --exclude='*.bak*' --exclude='*.bak.*' "${KEEP_TOOLS[@]}")
[[ $DRY -eq 1 ]] && RSYNC_OPTS+=(--dry-run -i)
CP_OPTS=(-a)          # dry-run 时根本不走复制分支，见 sync_file

sync_dir() {  # $1=仓库内目录  $2=源目录
    [[ -d "$2" ]] || return 0
    [[ $DRY -eq 0 ]] && mkdir -p "$REPO/$1"
    if [[ $DRY -eq 1 ]]; then
        local out; out=$(rsync "${RSYNC_OPTS[@]}" "$2/" "$REPO/$1/" 2>/dev/null)
        if [[ -n "$out" ]]; then ok "$1  ←  $2"; echo "$out" | sed 's/^/      /' | head -15
        else warn "$1  无变化"; fi
    else
        rsync "${RSYNC_OPTS[@]}" "$2/" "$REPO/$1/" >/dev/null && ok "$1  ←  $2"
    fi
}
sync_file() {  # $1=仓库内路径  $2=源文件
    [[ -f "$2" ]] || return 0
    [[ $DRY -eq 0 ]] && mkdir -p "$(dirname "$REPO/$1")"
    if [[ $DRY -eq 1 ]]; then
        diff -q "$REPO/$1" "$2" >/dev/null 2>&1 && warn "$1  无变化" || ok "$1  ←  $2（有变化）"
    else
        cp "${CP_OPTS[@]}" "$2" "$REPO/$1" && ok "$1  ←  $2"
    fi
}

say "===== 1/4 同步家目录配置 ====="
for d in hypr kitty fish fcitx5 fastfetch ohmyposh btop; do sync_dir "$d" "$CONFIG/$d"; done
sync_dir systemd "$CONFIG/systemd/user"      # 仓库 systemd/ 直接对应 ~/.config/systemd/user
if [[ $LAYOUT == gentoo ]]; then
    for d in noctalia environment.d; do sync_dir "$d" "$CONFIG/$d"; done
    # opencode：只挑配置文件，绝不带 service.json（里面有服务端密码）
    for f in opencode.jsonc package.json package-lock.json .gitignore; do
        sync_file "opencode/$f" "$CONFIG/opencode/$f"
    done
    [[ -d "$CONFIG/opencode/agent" ]] && sync_dir opencode/agent "$CONFIG/opencode/agent"
fi
for f in .bashrc .bash_profile; do sync_file "shell/$f" "$SRC_HOME/$f"; done
sync_dir scripts "$SRC_HOME/opencode/scripts"        # 已排除 sync/save/restore/auto-snapshots.sh
sync_file "scripts/auto-snapshots.sh" "$CONFIG/hypr/auto-snapshots.sh"

if [[ $LAYOUT == gentoo && $DRY -eq 0 ]]; then
    say "===== 2/4 同步本机 /etc 系统级配置 ====="
    # 先用普通用户比对一遍，完全没变化就别弹密码框了
    NEED_ROOT=0
    rsync -a --dry-run -i --exclude='gnupg/' /etc/portage/ "$REPO/etc/portage/" 2>/dev/null | grep -q . && NEED_ROOT=1
    for f in nftables.conf issue fstab sysctl.d/99-hardening.conf fail2ban/jail.d/gentoo.local \
             default/ufw ufw/user.rules pam.d/login systemd/system/getty@.service.d/10-clear.conf; do
        cmp -s "/etc/$f" "$REPO/etc/$f" 2>/dev/null || NEED_ROOT=1
    done
    K=$(ls -1 /etc/kernels/kernel-config-* 2>/dev/null | tail -1 || true)
    [[ -n $K ]] && { cmp -s "$K" "$REPO/etc/kernels/$(basename "$K")" 2>/dev/null || NEED_ROOT=1; }

    # polkit 规则目录（750 root:polkitd，普通用户读不到）→ 比对"仓库里记录的已安装校验和"
    PR="$REPO/etc/polkit-1/rules.d"
    if compgen -G "$PR/*.rules" >/dev/null 2>&1; then
        want=$(cd "$PR" && sha256sum *.rules 2>/dev/null)
        have=$(cat "$PR/.installed.sha256" 2>/dev/null || true)
        [[ "$want" == "$have" ]] || NEED_ROOT=1
    fi

    if [[ $NEED_ROOT -eq 0 ]]; then
        ok "etc/ 无变化（跳过，不打扰 root）"
    else
    # 有终端时优先 sudo（问"你自己的"密码）；无终端才退到 pkexec 图形弹窗
    as_root() {
        if [[ $EUID -eq 0 ]]; then "$@"
        elif [[ -t 0 ]]; then sudo "$@"
        elif sudo -n true 2>/dev/null; then sudo "$@"
        else pkexec "$@"; fi
    }
    if as_root bash -s -- "$REPO" <<'EOS'; then ok "etc/ 已更新"
set -e
REPO="$1"
mkdir -p "$REPO/etc/portage"
rsync -a --exclude='gnupg/' /etc/portage/ "$REPO/etc/portage/"   # gnupg 里有私钥，必须排除
for f in nftables.conf issue fstab; do cp -a "/etc/$f" "$REPO/etc/$f"; done
cp -a /etc/sysctl.d/99-hardening.conf            "$REPO/etc/sysctl.d/"
cp -a /etc/fail2ban/jail.d/gentoo.local          "$REPO/etc/fail2ban/jail.d/"
cp -a /etc/default/ufw                           "$REPO/etc/default/"
cp -a /etc/ufw/user.rules                        "$REPO/etc/ufw/"
cp -a /etc/pam.d/login                           "$REPO/etc/pam.d/"
cp -a /etc/systemd/system/getty@.service.d/10-clear.conf "$REPO/etc/systemd/system/getty@.service.d/"
K=$(ls -1 /etc/kernels/kernel-config-* 2>/dev/null | tail -1 || true)
[ -n "$K" ] && cp -a "$K" "$REPO/etc/kernels/$(basename "$K")"
# polkit 规则：特殊！方向是「仓库 → 系统」（部署），因为这条规则是在仓库里维护的，
# 它让 pkexec 弹窗问"你自己的"密码而不是 root 的。改完仓库里的规则，跑一次同步即可生效。
if compgen -G "$REPO/etc/polkit-1/rules.d/*.rules" >/dev/null 2>&1; then
    mkdir -p /etc/polkit-1/rules.d
    install -o root -g root -m 644 "$REPO"/etc/polkit-1/rules.d/*.rules /etc/polkit-1/rules.d/ 2>/dev/null || true
    ( cd "$REPO/etc/polkit-1/rules.d" && sha256sum *.rules ) > "$REPO/etc/polkit-1/rules.d/.installed.sha256" 2>/dev/null || true
    chown --reference="$REPO" "$REPO/etc/polkit-1/rules.d/.installed.sha256" 2>/dev/null || true
fi
EOS
    else warn "/etc 同步失败（跳过，不影响后续）"; fi
    fi
fi

say "===== 3/4 隐私与密钥扫描 ====="
bash "$REPO/scripts/secretscan.sh" "$REPO"
SCAN_RC=$?
if [[ $SCAN_RC -eq 2 && $ALLOW -eq 1 ]]; then
    warn "--allow-secrets 已指定，继续（命中内容见上）"
elif [[ $SCAN_RC -ne 0 ]]; then
    err "已中止（未提交、未推送）。处理：改文件 / 把误报写进 .secretscan-ignore / 加 --allow-secrets"
    exit 2
fi

say "===== 4/4 提交并推送 ====="
cd "$REPO"
# 确保 pre-commit 隐私扫描钩子生效（公开仓库防手滑）
[[ -d "$REPO/.githooks" ]] && git config core.hooksPath .githooks
if [[ -z "$(git status --porcelain)" ]]; then
    ok "工作区干净，没有变化"
else
    git status --short | head -30
    echo "    共 $(git status --porcelain | wc -l) 项变化"
    if [[ $DRY -eq 1 ]]; then
        warn "dry-run：不提交、不推送"
    else
        [[ -z "$MSG" ]] && MSG="sync: ${LAYOUT} 配置更新 $(date '+%Y-%m-%d %H:%M')"
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
