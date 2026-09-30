#!/usr/bin/env bash
# ============================================================
#  grub-gentoo-sync.sh — Gentoo 换内核后，自动更新 Arch 里的 GRUB 菜单项
#
#  为什么需要它：
#    这台机器由 Arch 的 GRUB 统一引导（GRUB 的 prefix 编译成了
#    `(,gpt2)/@arch/boot/grub`），而 Gentoo 的菜单项写在 Arch 的 grub.cfg 里、
#    引用了带版本号的文件名（vmlinuz-7.2.8-gentoo-x86_64 / initramfs-….img）。
#    所以每次 Gentoo 升级内核（eselect kernel set + genkernel）都得手动去改 Arch
#    那边的 grub.cfg —— 本脚本就是干这个的。
#
#  用法（需要 root，会自己 sudo/pkexec 提权）：
#     bash scripts/grub-gentoo-sync.sh             # 检测并更新
#     bash scripts/grub-gentoo-sync.sh --status    # 只看当前状态（对比两边版本）
#     bash scripts/grub-gentoo-sync.sh -n          # 显示将写入的内容，不改文件
#     bash scripts/grub-gentoo-sync.sh --kernel 7.2.9-gentoo-x86_64
#
#  它维护的内容（标记块内的东西请勿手改，两处会自动保持一致）：
#     1) /mnt/btrfs/@arch/boot/grub/grub.cfg        ← 立即生效
#     2) /mnt/btrfs/@arch/etc/grub.d/40_custom      ← 让 grub-mkconfig 不会丢掉它
#
#  安全性：先备份（保留最近 5 份）；内核/initramfs 文件不存在就中止；
#          写入用「临时文件 + 原子替换」，并保留原属主权限；花括号配平检查。
# ============================================================
set -uo pipefail

TOP=/mnt/btrfs                       # btrfs 顶层（subvolid=5）
ARCH_TOP="$TOP/@arch"
GRUB_CFG="$ARCH_TOP/boot/grub/grub.cfg"
GRUB_40CUSTOM="$ARCH_TOP/etc/grub.d/40_custom"
BEGIN_MARK="# >>> GENTOO AUTO —— 由 Gentoo 的 scripts/grub-gentoo-sync.sh 维护，勿手改 >>>"
END_MARK="# <<< GENTOO AUTO <<<"
KEEP_BACKUPS=5

C_=$'\033[36m'; G_=$'\033[32m'; Y_=$'\033[33m'; R_=$'\033[31m'; N_=$'\033[0m'
say()  { printf '%s[•]%s %s\n' "$C_" "$N_" "$*"; }
ok()   { printf '%s[✓]%s %s\n' "$G_" "$N_" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y_" "$N_" "$*"; }
die()  { printf '%s[✗]%s %s\n' "$R_" "$N_" "$*" >&2; exit 1; }

MODE=update; WANT_KV=""; DRY=0
ARGS=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        --status) MODE=status; shift ;;
        -n|--dry-run) DRY=1; shift ;;
        --kernel) WANT_KV="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) die "未知参数: $1（-h 看帮助）" ;;
    esac
done

# ---------- 提权 ----------
SELF="$(readlink -f "$0")"
if [[ $EUID -ne 0 ]]; then
    if [[ -t 0 ]]; then exec sudo bash "$SELF" "${ARGS[@]}"
    elif sudo -n true 2>/dev/null; then exec sudo bash "$SELF" "${ARGS[@]}"
    else exec pkexec bash "$SELF" "${ARGS[@]}"; fi
fi

# ---------- 环境检查 ----------
if ! mountpoint -q "$TOP"; then
    say "$TOP 未挂载，尝试挂载 btrfs 顶层"
    mount "$TOP" 2>/dev/null || mount -o subvolid=5 "$(findmnt -no SOURCE / | sed 's/\[.*\]$//')" "$TOP" || die "挂载 $TOP 失败"
fi
[[ -d "$ARCH_TOP" ]] || die "找不到 $ARCH_TOP（@arch 子卷）"
[[ -f "$GRUB_CFG" ]] || die "找不到 $GRUB_CFG"

# ---------- 探测 Gentoo 内核 ----------
if [[ -n "$WANT_KV" ]]; then
    KV="$WANT_KV"
else
    KV=$(ls -1 /boot/vmlinuz-*-gentoo-x86_64 2>/dev/null | sed 's|.*/vmlinuz-||' | sort -V | tail -1)
fi
[[ -n "$KV" ]] || die "在 /boot 找不到 vmlinuz-*-gentoo-x86_64（genkernel 跑过了吗？）"

# ---------- 推导 root 设备 / UUID / 子卷 / 微码 ----------
# 注意：btrfs 子卷挂载时 findmnt 的 SOURCE 形如 "/dev/nvme0n1p2[/@gentoo]"，要先剥掉方括号
ROOT_DEV=$(findmnt -no SOURCE / | sed 's/\[.*\]$//')
UUID=$(findmnt -no UUID / 2>/dev/null)
[[ -n "$UUID" ]] || UUID=$(lsblk -no UUID "$ROOT_DEV" 2>/dev/null | head -1)
[[ -n "$UUID" ]] || UUID=$(blkid -s UUID -o value "$ROOT_DEV" 2>/dev/null)
SUBVOL=$(findmnt -no OPTIONS / | tr ',' '\n' | sed -n 's|^subvol=||p'); SUBVOL=${SUBVOL#/}
[[ -n "$ROOT_DEV" && -n "$UUID" && -n "$SUBVOL" ]] || die "无法推导 root 设备/UUID/子卷（dev=${ROOT_DEV:-?} uuid=${UUID:-?} subvol=${SUBVOL:-?}）"

MC=""
if grep -qm1 GenuineIntel /proc/cpuinfo 2>/dev/null; then MC=intel-uc.img
elif grep -qm1 AuthenticAMD /proc/cpuinfo 2>/dev/null; then MC=amd-uc.img; fi
MC_PATH=""
if [[ -n "$MC" && -f "$TOP/$SUBVOL/boot/$MC" ]]; then MC_PATH="/$SUBVOL/boot/$MC"; fi

# ---------- 校验文件真实存在（从 GRUB 的视角）----------
[[ -f "$TOP/$SUBVOL/boot/vmlinuz-$KV" ]]            || die "GRUB 视角下找不到 $TOP/$SUBVOL/boot/vmlinuz-$KV"
[[ -f "$TOP/$SUBVOL/boot/initramfs-$KV.img" ]]      || die "GRUB 视角下找不到 $TOP/$SUBVOL/boot/initramfs-$KV.img"

CUR_KV=$(sed -n 's/^set gentoo_ver=//p' "$GRUB_CFG" 2>/dev/null | head -1)
if [[ -z "$CUR_KV" ]]; then
    CUR_KV=$(grep -oE 'vmlinuz-[0-9][^ ]*gentoo-x86_64' "$GRUB_CFG" 2>/dev/null | head -1 | sed 's/^vmlinuz-//')
fi

# ---------- 状态模式 ----------
if [[ $MODE == status ]]; then
    echo
    printf '  %-24s %s\n' "Gentoo 当前内核"   "$KV"
    printf '  %-24s %s\n' "GRUB 里记录的内核" "${CUR_KV:-（未识别到）}"
    printf '  %-24s %s\n' "Gentoo 子卷"       "$SUBVOL"
    printf '  %-24s %s\n' "root UUID"         "$UUID"
    printf '  %-24s %s\n' "微码 initrd"       "${MC_PATH:-（无）}"
    printf '  %-24s %s\n' "GRUB 配置"         "$GRUB_CFG"
    echo
    [[ "$CUR_KV" == "$KV" ]] && ok "两边版本一致，无需更新" || warn "不一致 → 直接跑一次脚本即可同步"
    if grep -qF "$BEGIN_MARK" "$GRUB_40CUSTOM" 2>/dev/null; then
        ok "40_custom 里有自动块（以后在 Arch 跑 grub-mkconfig 也不会丢菜单项）"
    else
        warn "40_custom 里没有自动块（现在这份 Gentoo 菜单项是手工塞进 grub.cfg 的，grub-mkconfig 会丢）"
    fi
    exit 0
fi

# ---------- 生成块内容 ----------
gen_block() {
    local initrd_line="/$SUBVOL/boot/initramfs-\$gentoo_ver.img"
    [[ -n "$MC_PATH" ]] && initrd_line="$MC_PATH /$SUBVOL/boot/initramfs-\$gentoo_ver.img"
    cat <<EOF
$BEGIN_MARK
# 由 Gentoo 侧 scripts/grub-gentoo-sync.sh 生成于 $(date '+%F %T')
# 当前内核: $KV
set gentoo_ver=$KV

menuentry "Gentoo Linux (\$gentoo_ver)" {
    insmod gzio
    insmod part_gpt
    insmod btrfs
    search --fs-uuid --set=root $UUID

    linux /$SUBVOL/boot/vmlinuz-\$gentoo_ver \\
        root=UUID=$UUID \\
        rootflags=subvol=$SUBVOL \\
        rw quiet loglevel=3

    initrd $initrd_line
}
$END_MARK
EOF
}
BLOCK="$(gen_block)"

# ---------- 替换 / 插入逻辑（纯 awk 状态机，不搞花活）----------
# replace_block <文件> <新块文件> > 输出
replace_block() {
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v nf="$2" '
        $0 == e { state=2; next }
        $0 == b { state=1; next }
        state != 1 { print }
        END {
            if (state == 1) exit 3          # 只有开始标记、没有结束标记 → 报错
        }
    ' "$1"
}
# insert_block <文件> <新块文件>：grub.cfg 插到 30_os-prober 之前，其它追加到末尾
insert_block() {
    local file="$1" nf="$2"
    if [[ "$file" == "$GRUB_CFG" ]] && grep -qF '### BEGIN /etc/grub.d/30_os-prober ###' "$file"; then
        awk -v nf="$nf" '
            /^### BEGIN \/etc\/grub\.d\/30_os-prober ###/ {
                while ((getline line < nf) > 0) print line
                print ""
            }
            { print }
        ' "$file"
    else
        cat "$file"; echo; cat "$nf"
    fi
}

# replace_manual_entry <文件> <新块文件>：把手工写的 "Gentoo" menuentry 整块就地换成新块
# （迁移用：避免 GRUB 菜单里出现两个 Gentoo 条目）
replace_manual_entry() {
    local file="$1" nf="$2" start end
    start=$(grep -nE '^[[:space:]]*menuentry.*Gentoo' "$file" | head -1 | cut -d: -f1)
    [[ -n "$start" ]] || return 1
    end=$(awk -v s="$start" '
        NR < s { next }
        {
            o = gsub(/\{/, "{"); c = gsub(/\}/, "}")
            depth += o - c
            if (depth <= 0) { print NR; exit }
        }' "$file")
    [[ -n "$end" ]] || return 1
    [[ "$end" -ge "$start" ]] || return 1
    { head -n $((start - 1)) "$file"; cat "$nf"; tail -n +$((end + 1)) "$file"; }
    return 0
}

build_new() {   # build_new <文件> <新块文件> → 打印新内容，失败返回非 0
    local file="$1" nf="$2" out
    if grep -qF "$BEGIN_MARK" "$file"; then
        out=$(replace_block "$file" "$nf") || { warn "$file 里的标记不成对（缺结束标记）"; return 1; }
    elif grep -qE '^[[:space:]]*menuentry.*Gentoo' "$file"; then
        # 迁移：把手工写的 Gentoo 条目就地换成自动块（不会多出一个菜单项）
        out=$(replace_manual_entry "$file" "$nf") || { warn "$file 迁移手工条目失败"; return 1; }
    else
        out=$(insert_block "$file" "$nf") || return 1
    fi
    printf '%s\n' "$out"
}

echo
say "Gentoo 内核 : $KV"
say "GRUB 里记录 : ${CUR_KV:-（未识别）}"
say "目标文件    : 1) $GRUB_CFG   2) $GRUB_40CUSTOM"
echo

NEED_40=$(grep -qF "$BEGIN_MARK" "$GRUB_40CUSTOM" 2>/dev/null && echo 0 || echo 1)
NEED_CFG=$(grep -qF "$BEGIN_MARK" "$GRUB_CFG" 2>/dev/null && echo 0 || echo 1)
if [[ "$CUR_KV" == "$KV" && $NEED_40 -eq 0 && $NEED_CFG -eq 0 ]]; then
    ok "版本一致，且 grub.cfg 与 40_custom 都已有自动块，无需修改"
    exit 0
fi
[[ "$CUR_KV" != "$KV" ]] || warn "版本一致，但还有块没铺好 → 顺手补齐"

BLOCKFILE=$(mktemp); printf '%s\n' "$BLOCK" > "$BLOCKFILE"

how() {   # 说明某个文件将会怎么处理
    local f="$1"
    if grep -qF "$BEGIN_MARK" "$f" 2>/dev/null; then echo "替换已有的自动块"
    elif grep -qE '^[[:space:]]*menuentry.*Gentoo' "$f" 2>/dev/null; then echo "迁移：把手写的 Gentoo 条目就地换成自动块（不会多出菜单项）"
    else echo "新插入块"; fi
}

if [[ $DRY -eq 1 ]]; then
    echo "----- 将写入的块内容 -----"; cat "$BLOCKFILE"
    echo "----- 各文件的处理方式 -----"
    for f in "$GRUB_CFG" "$GRUB_40CUSTOM"; do
        printf '  %-42s %s\n' "$(basename "$f")" "$(how "$f")"
    done
    echo
    warn "dry-run：没有改动任何文件"
    rm -f "$BLOCKFILE"; exit 0
fi

# ---------- 备份 ----------
TS=$(date +%Y%m%d-%H%M%S)
for f in "$GRUB_CFG" "$GRUB_40CUSTOM"; do
    [[ -f "$f" ]] || continue
    cp -a "$f" "$f.bak-$TS" && ok "备份 $(basename "$f").bak-$TS"
done

# ---------- 写入 ----------
for f in "$GRUB_CFG" "$GRUB_40CUSTOM"; do
    new=$(mktemp)
    if ! build_new "$f" "$BLOCKFILE" > "$new"; then
        rm -f "$new"; die "$f 处理失败，已放弃（未改动任何文件）"
    fi
    grep -qF "$END_MARK" "$new" || { rm -f "$new"; die "$f 结果里没有结束标记，已放弃"; }
    nopen=$(tr -cd '{' < "$new" | wc -c); nclose=$(tr -cd '}' < "$new" | wc -c)
    [[ "$nopen" == "$nclose" ]] || { rm -f "$new"; die "$f 花括号不配对（${nopen}/${nclose}），已放弃"; }
    cnt=$(grep -cF "$BEGIN_MARK" "$new")
    [[ "$cnt" == "1" ]] || { rm -f "$new"; die "$f 里自动块出现 $cnt 次（应为 1），已放弃"; }
    chown --reference="$f" "$new" 2>/dev/null || true
    chmod --reference="$f" "$new" 2>/dev/null || true
    mv "$new" "$f" && ok "已更新 $f"
done
rm -f "$BLOCKFILE"

# ---------- 清理旧备份 ----------
for f in "$GRUB_CFG" "$GRUB_40CUSTOM"; do
    ls -1t "$f".bak-* 2>/dev/null | tail -n +$((KEEP_BACKUPS+1)) | xargs -r rm -f
done

# ---------- 可选校验 ----------
if command -v grub-script-check >/dev/null 2>&1; then
    grub-script-check "$GRUB_CFG" && ok "grub-script-check 语法校验通过"
else
    warn "本机没装 grub-script-check（可 emerge sys-boot/grub 做完整语法校验）"
fi

echo
ok "完成！重启后 GRUB 菜单会显示：Gentoo Linux ($KV)"
say "以后每次 Gentoo 升级内核后，跑一次：bash scripts/grub-gentoo-sync.sh"
