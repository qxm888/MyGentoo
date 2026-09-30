-- 显示器配置
-- 旧: monitor=... → 新: hl.monitor({...})

-- 副屏在左侧坚位
hl.monitor({
    output   = "DP-3",
    mode     = "3440x1440@100",
    position = "1080x0",
    scale    = "1",
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = "1",
    transform = 3, -- 顺时针旋转 270°
})
--左侧横位
--hl.monitor({
--    output   = "DP-3",
--    mode     = "3440x1440@100",
--    position = "1920x0",
--    scale    = "1",
--})

--hl.monitor({
--    output   = "HDMI-A-1",
--    mode     = "1920x1080@60",
--    position = "0x0",
--    scale    = "1",
--    transform = 0, -- 顺时针旋转 270°
--})
-- 副屏在右侧 (备用，注释掉)
-- hl.monitor({
--     output   = "DP-3",
--     mode     = "3440x1440@100",
--     position = "0x0",
--     scale    = "1",
-- })
-- hl.monitor({
--     output   = "HDMI-A-1",
--     mode     = "1920x1080@60",
--     position = "3440x0",
--     scale    = "1",
--     transform = 3,
-- })
