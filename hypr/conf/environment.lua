-- 环境变量
-- 旧: env = KEY,VALUE → 新: hl.env("KEY", "VALUE")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- 缩略图相关
-- hl.env("XDG_CURRENT_DESKTOP", "Thunar")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("GTK_USE_PORTAL", "1")

-- 缩略图缓存
hl.env("XDG_CACHE_HOME", os.getenv("HOME") .. "/.cache")

-- 中文环境变量
hl.env("LANG", "zh_CN.UTF-8")
hl.env("LANGUAGE", "zh_CN:en_US")
hl.env("LC_CTYPE", "zh_CN.UTF-8")

-- fcitx5 输入法
--hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("INPUT_METHOD", "fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "ibus")

-- NVIDIA VA-API 硬件视频解码
hl.env("NVD_BACKEND", "direct")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")
hl.env("CUDA_DISABLE_PERF_BOOST", "1")

-- 用户本地二进制路径（去重，防止每次 reload 叠加）
local curPath = os.getenv("PATH") or ""
if not curPath:find("/.local/bin") then
    hl.env("PATH", os.getenv("HOME") .. "/.local/bin:" .. curPath)
end
