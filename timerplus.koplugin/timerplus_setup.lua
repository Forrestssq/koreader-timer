--[[
Countdown duration picker for the Timer+ plugin.

Layout:
  [ +/- hour column ]  HH : MM : SS  [ +/- minute column ]
each digit group has chevron up/down buttons and can be tapped to open a
spin widget; a keyboard button opens a free-form input dialog; preset
buttons set common durations.

Calls `on_start(total_seconds)` when the user taps Start.
]]

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonTable = require("ui/widget/buttontable")
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
local InputDialog = require("ui/widget/inputdialog")
local Size = require("ui/size")
local SpinWidget = require("ui/widget/spinwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen
local _ = require("timerplus_l10n").gettext

local MAX_TOTAL = 99 * 3600 + 59 * 60 + 59

local function clamp(secs)
    return math.max(0, math.min(math.floor(secs or 0), MAX_TOTAL))
end

local function parseTime(str)
    if not str then return nil end
    str = str:gsub("%s+", "")
    if str == "" then return nil end
    local h, m, s = str:match("^(%d+):(%d+):(%d+)$")
    if h then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end
    m, s = str:match("^(%d+):(%d+)$")
    if m then
        return tonumber(m) * 60 + tonumber(s)
    end
    local num, suffix = str:match("^(%d+%.?%d*)([smhSMH]?)$")
    if num then
        num = tonumber(num)
        suffix = suffix:lower()
        if suffix == "s" then
            return math.floor(num)
        elseif suffix == "h" then
            return math.floor(num * 3600)
        else -- bare number or "m" → minutes
            return math.floor(num * 60)
        end
    end
    return nil
end

local CountdownSetup = InputContainer:extend{
    duration = 300,
    on_start = nil, -- function(total_seconds)
}

function CountdownSetup:init()
    self.total = clamp(self.duration)
    if Device:hasKeys() then
        self.key_events = {
            Close = { { "Back" } },
        }
    end
    self.ges_events = {
        TapClose = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0, y = 0,
                    w = Screen:getWidth(),
                    h = Screen:getHeight(),
                },
            },
        },
    }
    self:_build()
end

function CountdownSetup:_hms()
    local h = math.floor(self.total / 3600)
    local m = math.floor(self.total % 3600 / 60)
    local s = self.total % 60
    return h, m, s
end

function CountdownSetup:_formatTotal()
    local h, m, s = self:_hms()
    return string.format("%02d:%02d:%02d", h, m, s)
end

function CountdownSetup:addSeconds(n)
    self.total = clamp(self.total + n)
    self:_rebuild()
end

function CountdownSetup:setTotal(secs)
    self.total = clamp(secs)
    self:_rebuild()
end

function CountdownSetup:setUnit(unit, v)
    local h, m, s = self:_hms()
    if unit == "hours" then
        h = v
    elseif unit == "minutes" then
        m = v
    else
        s = v
    end
    self:setTotal(h * 3600 + m * 60 + s)
end

function CountdownSetup:editUnit(unit)
    local h, m, s = self:_hms()
    local conf = {
        hours = { value = h, max = 99, title = _("Set hours") },
        minutes = { value = m, max = 59, title = _("Set minutes") },
        seconds = { value = s, max = 59, title = _("Set seconds") },
    }
    local c = conf[unit]
    UIManager:show(SpinWidget:new{
        title_text = c.title,
        value = c.value,
        value_min = 0,
        value_max = c.max,
        value_step = 1,
        value_hold_step = 5,
        wrap = true,
        callback = function(spin)
            self:setUnit(unit, spin.value)
        end,
    })
end

function CountdownSetup:openKeyboard()
    local dlg
    dlg = InputDialog:new{
        title = _("Enter time"),
        description = _("Formats: HH:MM:SS, MM:SS, or a number (minutes). Suffixes s/m/h also work, e.g. 90s or 1.5h."),
        input = self:_formatTotal(),
        input_type = "string",
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(dlg)
                    end,
                },
                {
                    text = _("OK"),
                    is_enter_default = true,
                    callback = function()
                        local secs = parseTime(dlg:getInputText())
                        if secs then
                            UIManager:close(dlg)
                            self:setTotal(secs)
                        else
                            UIManager:show(InfoMessage:new{
                                text = _("Invalid time format."),
                                timeout = 2,
                            })
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

function CountdownSetup:start()
    if self.total <= 0 then
        UIManager:show(InfoMessage:new{
            text = _("Duration must be greater than zero."),
            timeout = 2,
        })
        return
    end
    local total = self.total
    local cb = self.on_start
    UIManager:close(self)
    if cb then cb(total) end
end

--- UI construction --------------------------------------------------------

function CountdownSetup:_adjustColumn(label, unitsec)
    local vg = VerticalGroup:new{ align = "center" }
    table.insert(vg, TextWidget:new{
        text = label,
        face = Font:getFace("smallinfofont"),
    })
    table.insert(vg, VerticalSpan:new{ width = Size.span.vertical_default })
    for _i, v in ipairs{ 10, 5, 3, 1, -1, -3, -5, -10 } do
        table.insert(vg, Button:new{
            text = string.format("%+d", v),
            width = Screen:scaleBySize(56),
            margin = 0,
            radius = 0,
            show_parent = self,
            callback = function()
                self:addSeconds(v * unitsec)
            end,
        })
    end
    return vg
end

function CountdownSetup:_unitColumn(unit)
    local h, m, s = self:_hms()
    local conf = {
        hours = { value = h, unitsec = 3600, label = _("hr") },
        minutes = { value = m, unitsec = 60, label = _("min") },
        seconds = { value = s, unitsec = 1, label = _("sec") },
    }
    local c = conf[unit]
    local up = Button:new{
        icon = "chevron.up",
        bordersize = 0,
        show_parent = self,
        callback = function()
            self:addSeconds(c.unitsec)
        end,
    }
    local num = Button:new{
        text = string.format("%02d", c.value),
        text_font_size = 34,
        text_font_bold = true,
        bordersize = 0,
        show_parent = self,
        callback = function()
            self:editUnit(unit)
        end,
    }
    local down = Button:new{
        icon = "chevron.down",
        bordersize = 0,
        show_parent = self,
        callback = function()
            self:addSeconds(-c.unitsec)
        end,
    }
    local label = TextWidget:new{
        text = c.label,
        face = Font:getFace("smallinfofont"),
    }
    return VerticalGroup:new{ align = "center", up, num, down, label }
end

function CountdownSetup:_build()
    local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
    local dlg_width = math.min(
        screen_w - Screen:scaleBySize(20),
        Screen:scaleBySize(540)
    )
    local inner_width = dlg_width - 2 * Size.padding.large
    local gap = Screen:scaleBySize(10)

    local title = TextWidget:new{
        text = _("Set countdown duration"),
        face = Font:getFace("tfont"),
        bold = true,
    }
    local title_cont = CenterContainer:new{
        dimen = Geom:new{ w = inner_width, h = title:getSize().h },
        title,
    }

    local function colon()
        return TextWidget:new{
            text = ":",
            face = Font:getFace("cfont", 30),
            bold = true,
        }
    end

    local main_row = HorizontalGroup:new{
        align = "center",
        self:_adjustColumn(_("hr"), 3600),
        HorizontalSpan:new{ width = gap },
        self:_unitColumn("hours"),
        HorizontalSpan:new{ width = gap / 2 },
        colon(),
        HorizontalSpan:new{ width = gap / 2 },
        self:_unitColumn("minutes"),
        HorizontalSpan:new{ width = gap / 2 },
        colon(),
        HorizontalSpan:new{ width = gap / 2 },
        self:_unitColumn("seconds"),
        HorizontalSpan:new{ width = gap },
        self:_adjustColumn(_("min"), 60),
    }
    local main_cont = CenterContainer:new{
        dimen = Geom:new{ w = inner_width, h = main_row:getSize().h },
        main_row,
    }

    local presets = {
        { 30, _("30 s") }, { 60, _("1 min") }, { 180, _("3 min") }, { 300, _("5 min") },
        { 600, _("10 min") }, { 1200, _("20 min") }, { 1800, _("30 min") }, { 3600, _("1 h") },
    }
    local preset_rows = { {}, {} }
    for i, p in ipairs(presets) do
        local row = i <= 4 and preset_rows[1] or preset_rows[2]
        table.insert(row, {
            text = p[2],
            callback = function()
                self:setTotal(p[1])
            end,
        })
    end
    local preset_table = ButtonTable:new{
        width = inner_width,
        buttons = preset_rows,
        zero_sep = true,
        show_parent = self,
    }

    local action_table = ButtonTable:new{
        width = inner_width,
        buttons = {
            {
                {
                    text = _("Keyboard"),
                    callback = function() self:openKeyboard() end,
                },
                {
                    text = _("Cancel"),
                    callback = function() self:onClose() end,
                },
                {
                    text = _("Start"),
                    callback = function() self:start() end,
                },
            },
        },
        zero_sep = true,
        show_parent = self,
    }

    local vg = VerticalGroup:new{
        align = "center",
        title_cont,
        VerticalSpan:new{ width = Size.span.vertical_large },
        main_cont,
        VerticalSpan:new{ width = Size.span.vertical_large },
        preset_table,
        VerticalSpan:new{ width = Size.span.vertical_default },
        action_table,
    }

    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        radius = Size.radius.window,
        padding = Size.padding.large,
        vg,
    }
    self[1] = CenterContainer:new{
        dimen = Geom:new{ w = screen_w, h = screen_h },
        self.frame,
    }
    self.dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h }
end

function CountdownSetup:_rebuild()
    self:_build()
    UIManager:setDirty(self, "ui")
end

function CountdownSetup:onTapClose(_arg, ges)
    if ges.pos:notIntersectWith(self.frame.dimen) then
        self:onClose()
    end
    return true
end

function CountdownSetup:onShow()
    UIManager:setDirty(self, "ui", self.frame.dimen)
    return true
end

function CountdownSetup:onClose()
    UIManager:close(self)
    return true
end

function CountdownSetup:onCloseWidget()
    UIManager:setDirty(nil, "ui", self.frame.dimen)
end

return CountdownSetup
