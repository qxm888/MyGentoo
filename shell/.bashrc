# /etc/skel/.bashrc
#
# This file is sourced by all *interactive* bash shells on startup,
# including some apparently interactive shells such as scp and rcp
# that can't tolerate any output.  So make sure this doesn't display
# anything or bad things will happen !


# Test for an interactive shell.  There is no need to set anything
# past this point for scp and rcp, and it's important to refrain from
# outputting anything in those cases.
if [[ $- != *i* ]] ; then
	# Shell is non-interactive.  Be done now!
	return
fi


# Put your fun stuff here.

# opencode
export PATH=/home/luckyhit/.opencode/bin:$PATH

# 直接敲 `opencode` 就在共享工作目录 /srv/work 里启动，并自动续上次会话
# （/srv/work 是 @work 共享子卷，Gentoo 与 Arch 同路径挂载 → 会话历史两边互通）
# 带参数时原样透传，例如：opencode session list / opencode models / opencode --version
# 注：默认 agent 由 ~/.config/opencode/opencode.jsonc 的 default_agent 决定，V2 根命令不支持 --agent
opencode() {
	if [ "$#" -eq 0 ] && mountpoint -q /srv/work 2>/dev/null; then
		( cd /srv/work && command opencode --continue )
	else
		command opencode "$@"
	fi
}
