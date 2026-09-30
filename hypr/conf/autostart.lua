-- 自启动程序
-- 旧: exec-once → 新: hl.on("hyprland.start", ...)

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    -- 壁纸由 noctalia 管理（不再用 hyprpaper）
    -- 已被 noctalia 取代
    -- hl.exec_cmd("waybar")
    -- hl.exec_cmd("swaync")
    hl.exec_cmd("noctalia -d")
    hl.exec_cmd("elephant")
    hl.exec_cmd("fcitx5")

    -- 剪贴板管理 (cliphist + 智能清空 + 收藏)
    hl.exec_cmd("wl-paste --type text --watch ~/opencode/scripts/cliphist-smart-store.sh")
    hl.exec_cmd("wl-paste --type image --watch ~/opencode/scripts/cliphist-smart-store.sh")
end)
