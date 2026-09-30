# Gentoo + Hyprland Dotfiles（梦梦的 Gentoo 侧配置）

本仓库是 **Gentoo Linux + systemd + Hyprland** 这套系统的配置备份，
与 Arch 侧的 [`my-dotfiles`](https://gitee.com/luminous-spirit/my-dotfiles) 仓库是姊妹仓库。

> 同机双系统：Arch（用户 `dovahkiin`）+ Gentoo（用户 `luckyhit`），共用 btrfs 上的 `/home`、`/srv/work`。
> 两份仓库互不干扰：Arch 侧管 Arch 的家目录配置，本仓库管 Gentoo 的家目录配置 + Gentoo 特色系统配置。

## 目录结构

```
├── hypr/            → ~/.config/hypr          # Hyprland（Lua 配置，conf/*.lua）
├── kitty/           → ~/.config/kitty
├── fish/            → ~/.config/fish          # 含 functions/opencode.fish 包装
├── fcitx5/          → ~/.config/fcitx5        # 含 rime 输入法框架配置
├── fastfetch/       → ~/.config/fastfetch
├── ohmyposh/        → ~/.config/ohmyposh      # 提示符主题
├── noctalia/        → ~/.config/noctalia      # 桌面 Shell（Noctalia）
├── environment.d/   → ~/.config/environment.d
├── systemd/         → ~/.config/systemd/user  # 用户级 unit / wants 链接
├── opencode/        → ~/.config/opencode      # opencode 配置与 agent（不含 service.json）
├── shell/           → ~/.bashrc / ~/.bash_profile
├── scripts/         → ~/opencode/scripts      # 截图 / 剪贴板 / 密钥环 / 快照脚本
└── etc/             → /etc                    # Gentoo 系统级配置（见下）
```

### `etc/` 收录内容（Gentoo 特色）

| 路径 | 说明 |
|:--|:--|
| `etc/portage/make.conf` | 编译参数、USE、镜像、LUA_SINGLE_TARGET |
| `etc/portage/package.use/*` | 各包 USE 覆盖 |
| `etc/portage/package.accept_keywords/*` | ~amd64 关键字（kernel / hyprland / zh / rime-lua …） |
| `etc/portage/package.mask/noctalia` | 屏蔽 `noctalia-shell-9999` |
| `etc/portage/package.env/*` + `etc/portage/env/*` | 单包环境覆盖（noctalia live git、gcc、kitty） |
| `etc/portage/repos.conf/*.conf` | 官方源 + 第三方 overlay（gentoo-zh / guru / hyprland…） |
| `etc/nftables.conf` | nftables 防火墙规则（默认 DROP，放行 lo/icmp/22） |
| `etc/fail2ban/jail.d/gentoo.local` | fail2ban：backend=systemd，nftables banaction，放行 frp 的 127.0.0.1 |
| `etc/default/ufw` + `etc/ufw/user.rules` | ufw 策略与规则 |
| `etc/sysctl.d/99-hardening.conf` | 内核安全加固参数 |
| `etc/pam.d/login` | 含 `pam_gnome_keyring.so`（开机自动解锁密钥环） |
| `etc/systemd/system/getty@.service.d/10-clear.conf` | 登录前清屏（配合 `/etc/issue` 欢迎页） |
| `etc/issue` | 欢迎横幅 |
| `etc/fstab` | 挂载表（btrfs 子卷：@gentoo/@home/@MyAgent/@opencode/@work/@.snapshots） |
| `etc/kernels/kernel-config-*` | 内核配置（genkernel 用） |

## 同步 / 恢复

```bash
# 把本机当前配置同步进仓库（保存）
bash scripts/save.sh            # 加 -n 只看差异
# 从仓库恢复到本机
bash scripts/restore.sh
```

`save.sh` 的家目录部分不需要 root；`etc/` 与 `systemd` 的系统部分会用 `sudo`（或 `pkexec` 弹窗）执行。

## ⚠️ 未纳入仓库的敏感文件（请单独备份）

| 路径 | 原因 |
|:--|:--|
| `~/.config/opencode/service.json` | 含 opencode 服务端密码 |
| `/etc/portage/gnupg/` | GnuPG 私钥 + `pass`（本地口令） |
| `/etc/frp/frpc.toml` | 含 frp 隧道 token（且权限 600） |
| `/etc/ssh/sshd_config` | 权限 600，且含主机侧安全策略 |
| `~/.ssh/` | SSH 私钥 |

## 相关文档

- 系统改动记录：`~/opencode/reports/`、`~/MyAgent/WORKFLOWS/`
- 姊妹仓库（Arch 侧）：<https://gitee.com/luminous-spirit/my-dotfiles>

## 许可证

仅供个人使用与参考。
