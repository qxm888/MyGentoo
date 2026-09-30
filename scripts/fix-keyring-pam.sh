#!/usr/bin/env bash
# fix-keyring-pam.sh
# 目的：解决每次开机 gnome-keyring 弹窗 “An application wants access to the keyring 默认密钥环, but it is locked”
# 原理：登录 PAM 栈里缺 pam_gnome_keyring.so → 密钥环拿不到登录密码，永远不会自动解锁。
#       1) 备份并移除旧的 默认密钥环（它的密码和登录密码不一致，PAM 也解不开）
#       2) 在 /etc/pam.d/login 里加入 pam_gnome_keyring，登录时用登录密码自动解锁/创建 login 密钥环
# 注意：需要 sudo（只用于改 /etc/pam.d/login），密钥环部分以当前用户身份操作。
set -euo pipefail

KEYRING_DIR="$HOME/.local/share/keyrings"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/opencode/backup/keyrings-$STAMP"
PAM_LOGIN=/etc/pam.d/login

echo "==> 1/4 备份密钥环目录 → $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -av "$KEYRING_DIR/." "$BACKUP_DIR/" || true
echo "   备份完成，里面是修复前的所有密钥环（含旧密码的那个，别删，可留作恢复）"

echo "==> 2/4 移除旧的默认密钥环（密码与登录密码不一致的那个）"
for f in "默认密钥环.keyring" "default"; do
    if [ -e "$KEYRING_DIR/$f" ]; then
        mv -v "$KEYRING_DIR/$f" "$BACKUP_DIR/$f.moved"
    fi
done
echo "   现在密钥环目录："; ls -la "$KEYRING_DIR"

echo "==> 3/4 修改 $PAM_LOGIN （需要 sudo 密码）"
if grep -q 'pam_gnome_keyring' "$PAM_LOGIN"; then
    echo "   已存在 pam_gnome_keyring 配置，跳过（幂等）"
else
    sudo cp -a "$PAM_LOGIN" "$PAM_LOGIN.bak-$STAMP"
    TMP="$(mktemp)"
    awk '
      { print }
      /^auth[ \t]+include[ \t]+system-local-login/ { print "auth\t\toptional\tpam_gnome_keyring.so" }
      /^session[ \t]+include[ \t]+system-local-login/ { print "session\t\toptional\tpam_gnome_keyring.so auto_start" }
    ' "$PAM_LOGIN" > "$TMP"
    if ! grep -q 'pam_gnome_keyring' "$TMP"; then
        echo "   !! 未能插入配置，已放弃（原文件未改）：请检查 $PAM_LOGIN 内容" >&2
        rm -f "$TMP"; exit 1
    fi
    sudo install -m 644 -o root -g root "$TMP" "$PAM_LOGIN"
    rm -f "$TMP"
    echo "   已写入（原文件备份为 $PAM_LOGIN.bak-$STAMP）"
fi

echo "---- 当前 $PAM_LOGIN ----"
cat "$PAM_LOGIN"

echo
echo "==> 4/4 完成！接下来：注销 → 重新用密码登录（或直接重启）"
echo "    验证："
echo "      journalctl --user -b | grep -i 'gkr-pam'          # 期望看到 unlocked login keyring"
echo "      ls -la ~/.local/share/keyrings/                    # 期望出现 login.keyring"
