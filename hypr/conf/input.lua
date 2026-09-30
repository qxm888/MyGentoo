-- 输入设备配置
-- 旧: input { ... } → 新: hl.config({ input = { ... } })

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 ~ 1.0, 0 表示无调整

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- 三指水平滑动切换工作区
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- 按设备单独配置
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})
