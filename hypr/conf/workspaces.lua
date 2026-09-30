-- 工作区规则
-- 旧: workspace = ... → 新: hl.workspace_rule({...})

hl.workspace_rule({
    workspace = 1,
    monitor   = "DP-3",
})
hl.workspace_rule({
    workspace = 2,
    monitor   = "HDMI-A-1",
})

-- 更多工作区分配 (注释掉, 按需启用)
-- hl.workspace_rule({ workspace = 3, monitor = "eDP-1" })
-- hl.workspace_rule({ workspace = 4, monitor = "eDP-1" })

-- hl.workspace_rule({
--     workspace = 3,
--     rounding  = false,
--     decorate  = false,
-- })
-- hl.workspace_rule({
--     workspace = "name:coding",
--     rounding = false, decorate = false,
--     gaps_in = 0, gaps_out = 0, border = false,
--     monitor = "DP-1",
-- })
-- hl.workspace_rule({ workspace = 8, border_size = 8 })
-- hl.workspace_rule({
--     workspace = "name:gaming",
--     monitor   = "desc:Chimei Innolux Corporation 0x150C",
--     default   = true,
-- })
-- hl.workspace_rule({
--     workspace = "name:Hello",
--     monitor   = "DP-1",
--     default   = true,
-- })
-- hl.workspace_rule({
--     workspace = 5,
--     on_created_empty = { action = "exec", command = "firefox" },
-- })
-- hl.workspace_rule({
--     workspace = "special:scratchpad",
--     on_created_empty = { action = "exec", command = "foot" },
-- })
