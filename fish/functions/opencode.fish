function opencode --wraps=opencode --description "Launch opencode in shared workdir /srv/work and auto-resume last session"
    # 不带参数时：切到共享工作目录 /srv/work 再启动（Gentoo/Arch 同路径挂载，会话历史互通）
    # 带参数时：原样透传，例如 opencode session list / opencode models
    # 注：默认 agent 由 ~/.config/opencode/opencode.jsonc 的 default_agent=mengmeng 决定，
    #     V2 的根命令不再支持 --agent 标志（那是 V1 的写法），不要再加。
    if test (count $argv) -eq 0; and mountpoint -q /srv/work
        pushd /srv/work >/dev/null
        command opencode --continue
        popd >/dev/null
    else
        command opencode $argv
    end
end
