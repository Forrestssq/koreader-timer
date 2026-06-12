--[[
Fullscreen stopwatch / countdown widget for the Timer+ plugin.

mode = "timer":     counts up from 0, with flag (lap) support.
mode = "countdown": counts down from `duration` seconds.
rotation_mode:      optional Screen.ORIENTATION_* value; the previous
                    rotation is restored when the widget closes.
]]

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
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
    local max_h = math.floor(Screen:getHeight() * 0.35)
    if h > max_h then
        size = math.max(20, math.floor(size * max_h / h))
    end
    return Font:getFace("cfont", size)
end

-- Plain or inverted (black background, white text, larger font) button.
-- Inversion falls back to a regular white button if Button's internals
-- ever change, so the label can never end up black-on-black.
function ClockWidget:_makeButton(opts)
    local btn = Button:new{
        text = opts.text,
        width = opts.width,
        text_font_size = opts.font_size,
        text_font_bold = true,
        radius = Screen:scaleBySize(8),
        enabled = opts.enabled ~= false,
        callback = opts.callback,
        show_parent = self,
    }
    if opts.invert and btn.frame and btn.label_widget then
        btn.frame.background = Blitbuffer.COLOR_BLACK
        btn.label_widget.fgcolor = Blitbuffer.COLOR_WHITE
    end
    return btn
end

function ClockWidget:_build()
    local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
    local time_str = fmtHMS(self:_displaySeconds())
    self._time_len = #time_str
    self.time_face = self:_fitFace(time_str)

    self.time_widget = TextWidget:new{
        text = time_str,
        face = self.time_face,
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

    -- Buttons: a row of small secondary buttons, then the two main
    -- actions as big, inverted, well-separated buttons.
    local small_w = math.floor(screen_w * 0.32)
    local big_w = math.floor(screen_w * 0.62)
    local small_gap = Screen:scaleBySize(40)
    local row_gap = Screen:scaleBySize(36)

    local secondary
    if self.mode == "timer" then
        secondary = self:_makeButton{
            text = _("Flag"),
            width = small_w,
            enabled = self.running,
            callback = function() self:addFlag() end,
        }
    else
        secondary = self:_makeButton{
            text = _("+1 min"),
            width = small_w,
            enabled = not self.finished,
            callback = function() self:addTime(60) end,
        }
    end
    local small_row = HorizontalGroup:new{
        align = "center",
        secondary,
        HorizontalSpan:new{ width = small_gap },
        self:_makeButton{
            text = _("Reset"),
            width = small_w,
            callback = function() self:reset() end,
        },
    }

    local main_text, main_cb
    if self.mode == "countdown" and self.finished then
        main_text = _("Restart")
        main_cb = function() self:restart() end
    else
        main_text = self.running and _("Pause") or _("Resume")
        main_cb = function() self:togglePause() end
    end
    local main_btn = self:_makeButton{
        text = main_text,
        width = big_w,
        font_size = 28,
        invert = true,
        callback = main_cb,
    }
    local close_btn = self:_makeButton{
        text = _("Close"),
        width = big_w,
        font_size = 28,
        invert = true,
        callback = function() self:onClose() end,
    }

    local flags_widget
    if self.mode == "timer" and #self.flags > 0 then
        local max_lines = screen_h < 700 and 3 or 6
        local lines = {}
        local first = math.max(1, #self.flags - (max_lines - 1))
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
    table.insert(vg, VerticalSpan:new{ width = Screen:scaleBySize(30) })
    table.insert(vg, self.time_cont)
    table.insert(vg, VerticalSpan:new{ width = Screen:scaleBySize(40) })
    table.insert(vg, small_row)
    table.insert(vg, VerticalSpan:new{ width = row_gap })
    table.insert(vg, main_btn)
    table.insert(vg, VerticalSpan:new{ width = Screen:scaleBySize(28) })
    table.insert(vg, close_btn)
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

function ClockWidget:_updateTime()
    -- Recreate the time text widget and refresh the whole widget: relying
    -- on the sub-widget's recorded position for a region refresh proved
    -- unreliable, leaving the display frozen on some devices.
    local str = fmtHMS(self:_displaySeconds())
    if #str ~= self._time_len then
        -- e.g. crossing the one-hour boundary changes the layout
        self:_refreshStructural()
        return
    end
    local old = self.time_cont[1]
    self.time_widget = TextWidget:new{
        text = str,
        face = self.time_face,
        bold = true,
    }
    self.time_cont[1] = self.time_widget
    if old and old.free then
        old:free()
    end
    UIManager:setDirty(self, "ui")
end

function ClockWidget:_onTick()
    if self.finished or not self.running then return end
    if self.mode == "countdown" and self:_displaySeconds() <= 0 then
        self:_finish()
        return
    end
    self:_updateTime()
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
    self:_updateTime()
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
