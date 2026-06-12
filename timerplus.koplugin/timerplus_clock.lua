--[[
Fullscreen stopwatch / countdown widget for the Timer+ plugin.

mode = "timer":     counts up from 0, with flag (lap) support.
mode = "countdown": counts down from `duration` seconds.
rotation_mode:      optional Screen.ORIENTATION_* value; the previous
                    rotation is restored when the widget closes.
]]

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen
local T = require("ffi/util").template
local _ = require("timerplus_l10n").gettext

local function fmtHMS(secs)
    secs = math.max(0, math.floor(secs or 0))
    local h = math.floor(secs / 3600)
    local m = math.floor(secs % 3600 / 60)
    local s = secs % 60
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

local ClockWidget = InputContainer:extend{
    mode = "timer", -- "timer" | "countdown"
    duration = 0,
    rotation_mode = nil,
}

function ClockWidget:init()
    self.covers_fullscreen = true
    if self.rotation_mode ~= nil then
        local cur = Screen:getRotationMode()
        if cur ~= self.rotation_mode then
            self.orig_rotation = cur
            Screen:setRotationMode(self.rotation_mode)
        end
    end
    self.acc = 0
    self.running = true
    self.started_at = os.time()
    self.flags = {}
    self.finished = false

    if Device:hasKeys() then
        self.key_events = {
            Close = { { "Back" } },
        }
    end
    self.ges_events = {
        TapTime = {
            GestureRange:new{
                ges = "tap",
                range = function()
                    return self.time_cont and self.time_cont.dimen
                end,
            },
        },
    }

    self:_build()
    self._tick = function()
        self:_onTick()
    end
    UIManager:scheduleIn(1, self._tick)
    -- keep the device from entering standby while the clock is on screen
    pcall(UIManager.preventStandby, UIManager)
end

function ClockWidget:getElapsed()
    local e = self.acc
    if self.running then
        e = e + os.time() - self.started_at
    end
    return e
end

function ClockWidget:_displaySeconds()
    if self.mode == "timer" then
        return self:getElapsed()
    end
    return math.max(self.duration - self:getElapsed(), 0)
end

function ClockWidget:_fitFace(sample)
    -- find a font size so the time string fills ~85% of the screen width,
    -- capped so it also fits vertically (matters in landscape)
    local target_w = math.floor(Screen:getWidth() * 0.85)
    local size = 50
    local probe = TextWidget:new{
        text = sample,
        face = Font:getFace("cfont", size),
        bold = true,
    }
    local w = probe:getSize().w
    probe:free()
    if w > 0 then
        size = math.max(20, math.floor(size * target_w / w))
    end
    probe = TextWidget:new{
        text = sample,
        face = Font:getFace("cfont", size),
        bold = true,
    }
    local h = probe:getSize().h
    probe:free()
    local max_h = math.floor(Screen:getHeight() * 0.4)
    if h > max_h then
        size = math.max(20, math.floor(size * max_h / h))
    end
    return Font:getFace("cfont", size)
end

function ClockWidget:_build()
    local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
    local time_str = fmtHMS(self:_displaySeconds())
    self._time_len = #time_str

    self.time_widget = TextWidget:new{
        text = time_str,
        face = self:_fitFace(time_str),
        bold = true,
    }
    self.time_cont = CenterContainer:new{
        dimen = Geom:new{ w = screen_w, h = self.time_widget:getSize().h },
        self.time_widget,
    }

    local title = TextWidget:new{
        text = self.mode == "timer" and _("Timer") or _("Countdown"),
        face = Font:getFace("smallinfofont"),
    }
    local title_cont = CenterContainer:new{
        dimen = Geom:new{ w = screen_w, h = title:getSize().h },
        title,
    }

    local buttons
    if self.mode == "timer" then
        buttons = {
            {
                {
                    text = self.running and _("Pause") or _("Resume"),
                    callback = function() self:togglePause() end,
                },
                {
                    text = _("Flag"),
                    enabled = self.running,
                    callback = function() self:addFlag() end,
                },
            },
            {
                {
                    text = _("Reset"),
                    callback = function() self:reset() end,
                },
                {
                    text = _("Close"),
                    callback = function() self:onClose() end,
                },
            },
        }
    else
        local main_btn
        if self.finished then
            main_btn = {
                text = _("Restart"),
                callback = function() self:restart() end,
            }
        else
            main_btn = {
                text = self.running and _("Pause") or _("Resume"),
                callback = function() self:togglePause() end,
            }
        end
        buttons = {
            {
                main_btn,
                {
                    text = _("+1 min"),
                    enabled = not self.finished,
                    callback = function() self:addTime(60) end,
                },
            },
            {
                {
                    text = _("Reset"),
                    callback = function() self:reset() end,
                },
                {
                    text = _("Close"),
                    callback = function() self:onClose() end,
                },
            },
        }
    end
    self.button_table = ButtonTable:new{
        width = math.floor(screen_w * 0.8),
        buttons = buttons,
        zero_sep = true,
        show_parent = self,
    }

    local flags_widget
    if self.mode == "timer" and #self.flags > 0 then
        local lines = {}
        local first = math.max(1, #self.flags - 5)
        for i = #self.flags, first, -1 do
            local f = self.flags[i]
            local prev = i > 1 and self.flags[i - 1] or 0
            table.insert(lines, T(_("Flag %1: %2 (+%3)"), i, fmtHMS(f), fmtHMS(f - prev)))
        end
        if first > 1 then
            table.insert(lines, "…")
        end
        flags_widget = TextBoxWidget:new{
            text = table.concat(lines, "\n"),
            face = Font:getFace("smallinfofont"),
            width = math.floor(screen_w * 0.8),
            alignment = "center",
        }
    end

    local vg = VerticalGroup:new{ align = "center" }
    table.insert(vg, title_cont)
    table.insert(vg, VerticalSpan:new{ width = Size.span.vertical_large * 2 })
    table.insert(vg, self.time_cont)
    table.insert(vg, VerticalSpan:new{ width = Size.span.vertical_large * 2 })
    table.insert(vg, self.button_table)
    if flags_widget then
        table.insert(vg, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(vg, flags_widget)
    end

    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = screen_w, h = screen_h },
            vg,
        },
    }
    self[1] = self.frame
    self.dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h }
end

function ClockWidget:_refreshStructural()
    self:_build()
    UIManager:setDirty(self, "ui")
end

function ClockWidget:_onTick()
    if self.finished or not self.running then return end
    local secs = self:_displaySeconds()
    if self.mode == "countdown" and secs <= 0 then
        self:_finish()
        return
    end
    local str = fmtHMS(secs)
    if #str ~= self._time_len then
        -- e.g. crossing the one-hour boundary changes the layout
        self:_refreshStructural()
    else
        self.time_widget:setText(str)
        UIManager:setDirty(self, "ui", self.time_cont.dimen)
    end
    UIManager:scheduleIn(1, self._tick)
end

function ClockWidget:_finish()
    self.finished = true
    self.running = false
    self.acc = self.duration
    UIManager:unschedule(self._tick)
    self:_refreshStructural()
    for i = 0, 2 do
        UIManager:scheduleIn(i * 0.7, function()
            UIManager:setDirty("all", "full")
        end)
    end
    UIManager:show(InfoMessage:new{ text = _("Time is up!") })
end

function ClockWidget:togglePause()
    if self.finished then return end
    if self.running then
        self.acc = self:getElapsed()
        self.running = false
        UIManager:unschedule(self._tick)
    else
        self.started_at = os.time()
        self.running = true
        UIManager:unschedule(self._tick)
        UIManager:scheduleIn(1, self._tick)
    end
    self:_refreshStructural()
end

function ClockWidget:addFlag()
    if not self.running then return end
    table.insert(self.flags, self:getElapsed())
    self:_refreshStructural()
end

function ClockWidget:addTime(secs)
    if self.finished then return end
    self.duration = self.duration + secs
    self:_refreshStructural()
end

function ClockWidget:reset()
    self.acc = 0
    self.started_at = os.time()
    self.flags = {}
    self.finished = false
    self.running = false
    UIManager:unschedule(self._tick)
    self:_refreshStructural()
end

function ClockWidget:restart()
    self.finished = false
    self.acc = 0
    self.started_at = os.time()
    self.running = true
    UIManager:unschedule(self._tick)
    UIManager:scheduleIn(1, self._tick)
    self:_refreshStructural()
end

function ClockWidget:onTapTime()
    if self.finished then return true end
    self:togglePause()
    return true
end

function ClockWidget:onShow()
    UIManager:setDirty(self, "full")
    return true
end

function ClockWidget:onClose()
    UIManager:close(self)
    return true
end

function ClockWidget:onCloseWidget()
    UIManager:unschedule(self._tick)
    pcall(UIManager.allowStandby, UIManager)
    if self.orig_rotation ~= nil then
        Screen:setRotationMode(self.orig_rotation)
        self.orig_rotation = nil
    end
    UIManager:setDirty(nil, "full")
end

return ClockWidget
