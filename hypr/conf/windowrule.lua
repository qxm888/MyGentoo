-- 窗口规则
-- 旧: windowrule = ... → 新: hl.window_rule({...})

-- 以下规则原来都是注释掉的，按需启用

-- hl.window_rule({
--     name  = "float-kitty",  -- 让特定 kitty 窗口浮动
--     match = { class = "^(kitty)$", title = "^(kitty)$" },
--     float = true,
-- })

-- hl.window_rule({
--     name  = "suppress-maximize",
--     match = { class = ".*" },
--     suppress_event = "maximize",
-- })

-- hl.window_rule({
--     name  = "fix-xwayland-drags",
--     match = {
--         class      = "^$",
--         title      = "^$",
--         xwayland   = true,
--         float      = true,
--         fullscreen = false,
--         pin        = false,
--     },
--     no_focus = true,
-- })

