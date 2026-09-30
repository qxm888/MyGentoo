-- 快捷键绑定

local mainMod = "SUPER"

-- ========== 应用程序 ==========

hl.bind(mainMod .. " + RETURN",         hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + B",              hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + E",              hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + CTRL + RETURN",  hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))

-- ========== 壁纸切换（由 noctalia 管理）==========

hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("noctalia msg wallpaper-random"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper"))

-- ========== 剪贴板历史 ==========

hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("~/opencode/scripts/cliphist-dmenu.sh"))

-- ========== 截图 ==========

hl.bind("PRINT",          hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind("SHIFT + PRINT",  hl.dsp.exec_cmd("hyprshot -m window --clipboard-only"))
hl.bind("CTRL + PRINT",   hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))
hl.bind(mainMod .. " + PRINT",      hl.dsp.exec_cmd("hyprshot -m region -o ~/screenshot"))
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m window -o ~/screenshot"))
hl.bind(mainMod .. " + CTRL + PRINT",  hl.dsp.exec_cmd("hyprshot -m output -o ~/screenshot"))
hl.bind(mainMod .. " + ALT + PRINT",  hl.dsp.exec_cmd("~/opencode/scripts/hyprshot-delay.sh 3"))

-- ========== 窗口行为 ==========

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + CTRL + M", hl.dsp.exit())
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen_state({ internal = 0, client = 1 }))
hl.bind(mainMod .. " + CTRL + C", hl.dsp.window.center())
hl.bind("CTRL + ALT + Z", hl.dsp.exec_cmd("poweroff"))
hl.bind(mainMod .. " + CTRL + ALT + Z", hl.dsp.exec_cmd("reboot"))

-- Alt+Tab
hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
--hl.bind("ALT + Tab", hl.dsp.window.bring_to_top())

-- 备份
--hl.bind(mainMod .. " + CTRL + K", hl.dsp.exec_cmd("bash -i -c 'hypr-snapshot'"))

-- ========== 焦点移动 ==========

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))

-- ========== 窗口交换 ==========

hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "d" }))

-- ========== 窗口缩放 ==========

hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = 100, relative = true }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -100, relative = true }))

-- ========== 工作区切换 ==========

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end

-- ========== Scratchpad ==========

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + CTRL + S",  hl.dsp.window.move({ workspace = "special:magic" }))

-- ========== 滚动切换 ==========

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ========== 鼠标拖拽 ==========

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ========== 多媒体键 ==========

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                    { locked = true, repeating = true })

-- ========== 媒体控制 ==========

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
