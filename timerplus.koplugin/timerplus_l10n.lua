--[[
Tiny self-contained localization for the Timer+ plugin.

KOReader's gettext only knows about strings shipped with KOReader itself,
so a third-party plugin has to carry its own translations. Strings are
keyed by the English text; if no translation is found the English text
is returned as-is.
]]

local M = {}

local zh = {
    -- plugin / menu
    ["Timer"] = "计时器",
    ["Countdown"] = "倒计时",
    ["Portrait timer"] = "竖屏计时器",
    ["Portrait countdown"] = "竖屏倒计时",
    ["Background timer"] = "后台计时器",
    ["Background countdown"] = "后台倒计时",
    ["Landscape timer (clockwise)"] = "横屏计时器（顺时针）",
    ["Landscape timer (counterclockwise)"] = "横屏计时器（逆时针）",
    ["Landscape countdown (clockwise)"] = "横屏倒计时（顺时针）",
    ["Landscape countdown (counterclockwise)"] = "横屏倒计时（逆时针）",
    ["Settings"] = "设置",
    ["Shown menu entries"] = "显示的菜单项",

    -- common buttons
    ["Start"] = "开始",
    ["Pause"] = "暂停",
    ["Resume"] = "继续",
    ["Restart"] = "重新开始",
    ["Reset"] = "重置",
    ["Flag"] = "标记",
    ["Stop"] = "停止",
    ["Close"] = "关闭",
    ["Cancel"] = "取消",
    ["OK"] = "确定",
    ["+1 min"] = "+1 分钟",
    ["Keyboard"] = "键盘输入",

    -- countdown setup
    ["Set countdown duration"] = "设置倒计时时长",
    ["Enter time"] = "输入时间",
    ["Formats: HH:MM:SS, MM:SS, or a number (minutes). Suffixes s/m/h also work, e.g. 90s or 1.5h."]
        = "支持格式：时:分:秒、分:秒，或纯数字（按分钟）。也支持 s/m/h 后缀，如 90s、1.5h。",
    ["Invalid time format."] = "时间格式无效。",
    ["Duration must be greater than zero."] = "时长必须大于零。",
    ["Set hours"] = "设置小时",
    ["Set minutes"] = "设置分钟",
    ["Set seconds"] = "设置秒",
    ["hr"] = "时",
    ["min"] = "分",
    ["sec"] = "秒",
    ["30 s"] = "30秒",
    ["1 min"] = "1分钟",
    ["3 min"] = "3分钟",
    ["5 min"] = "5分钟",
    ["10 min"] = "10分钟",
    ["20 min"] = "20分钟",
    ["30 min"] = "30分钟",
    ["1 h"] = "1小时",

    -- running / flags
    ["Time is up!"] = "时间到！",
    ["Flag %1: %2 (+%3)"] = "标记 %1：%2（+%3）",
    ["Flags:"] = "标记：",
    ["No flags yet."] = "暂无标记。",
    ["paused"] = "已暂停",

    -- background mode
    ["Background timer started."] = "后台计时器已启动。",
    ["Background countdown started."] = "后台倒计时已启动。",
    ["Background timer stopped."] = "后台计时器已停止。",
    ["Background countdown stopped."] = "后台倒计时已停止。",
    ["Please open a book first: background mode shows the time in the reader's bottom status bar."]
        = "请先打开一本书：后台模式会在阅读界面底部状态栏中显示时间。",
    ["This KOReader version does not support extra status bar content. Please update KOReader, or use a fullscreen mode instead."]
        = "当前 KOReader 版本不支持在状态栏显示附加内容。请升级 KOReader，或改用全屏模式。",
    ["The status bar has been turned on so the timer is visible."]
        = "已自动开启底部状态栏以显示计时。",
    ["Could not turn on the status bar automatically. Please enable it manually: tap the bottom edge of the screen, or use the top menu → Settings → Status bar."]
        = "无法自动开启底部状态栏。请手动开启：点击屏幕底部边缘，或在顶部菜单 → 设置 → 状态栏 中开启。",
}

local lang -- cached: "en" or "zh"

local function detect()
    if lang then return lang end
    lang = "en"
    local ok, set = pcall(function()
        return G_reader_settings and G_reader_settings:readSetting("language")
    end)
    if ok and type(set) == "string" and set:lower():match("^zh") then
        lang = "zh"
    end
    return lang
end

function M.gettext(s)
    if detect() == "zh" then
        return zh[s] or s
    end
    return s
end

return M
