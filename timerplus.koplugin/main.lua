--[[
Timer+ : stopwatch & countdown plugin for KOReader.

Modes (all reachable from Tools menu → Timer):
  * fullscreen portrait stopwatch / countdown
  * fullscreen landscape (clockwise / counterclockwise) stopwatch / countdown
  * background stopwatch / countdown shown in the reader's bottom status bar

Background state lives in a module-local table so it survives switching
documents within the same KOReader session.
]]

local DataStorage = require("datastorage")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local T = require("ffi/util").template
local Screen = Device.screen

local _ = require("timerplus_l10n").gettext
local ClockWidget = require("timerplus_clock")
local CountdownSetup = require("timerplus_setup")

-- ButtonDialogTitle was merged into ButtonDialog in newer KOReader versions
local has_bdt, ButtonDialogTitle = pcall(require, "ui/widget/buttondialogtitle")
local ButtonDialog = require("ui/widget/buttondialog")

local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/timerplus.lua"

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

-- Shared background state, survives document switches.
local BgState = {
    mode = nil, -- nil | "timer" | "countdown"
    running = false,
    acc = 0, -- accumulated seconds while paused
    started_at = 0, -- os.time() of last (re)start
    duration = 0, -- countdown duration in seconds
    flags = {},
}

local function bgElapsed()
    local e = BgState.acc
    if BgState.running then
        e = e + os.time() - BgState.started_at
    end
    return e
end

local function bgRemaining()
    return math.max(BgState.duration - bgElapsed(), 0)
end

local MODES = {
    { id = "portrait_timer", kind = "timer", display = "fullscreen" },
    { id = "portrait_countdown", kind = "countdown", display = "fullscreen" },
    { id = "bg_timer", kind = "timer", display = "background" },
    { id = "bg_countdown", kind = "countdown", display = "background" },
    { id = "land_timer_cw", kind = "timer", display = "fullscreen", rotation = "cw" },
    { id = "land_timer_ccw", kind = "timer", display = "fullscreen", rotation = "ccw" },
    { id = "land_countdown_cw", kind = "countdown", display = "fullscreen", rotation = "cw" },
    { id = "land_countdown_ccw", kind = "countdown", display = "fullscreen", rotation = "ccw" },
}

local MODE_NAMES = {
    portrait_timer = _("Portrait timer"),
    portrait_countdown = _("Portrait countdown"),
    bg_timer = _("Background timer"),
    bg_countdown = _("Background countdown"),
    land_timer_cw = _("Landscape timer (clockwise)"),
    land_timer_ccw = _("Landscape timer (counterclockwise)"),
    land_countdown_cw = _("Landscape countdown (clockwise)"),
    land_countdown_ccw = _("Landscape countdown (counterclockwise)"),
}

local Timer = WidgetContainer:extend{
    name = "timerplus",
    is_doc_only = false,
}

function Timer:init()
    self.settings = LuaSettings:open(SETTINGS_FILE)
    self.ui.menu:registerToMainMenu(self)
end

function Timer:onReaderReady()
    if BgState.mode then
        self:_attachBg()
    end
end

function Timer:onCloseDocument()
    -- Footer dies with this ReaderUI instance; detach UI but keep BgState,
    -- so the timer keeps counting and re-attaches in the next book.
    self:_detachBgUI()
end

--- Menu -------------------------------------------------------------------

function Timer:addToMainMenu(menu_items)
    menu_items.timerplus = {
        text = _("Timer"),
        sorting_hint = "tools",
        sub_item_table_func = function()
            return self:getSubMenuItems()
        end,
    }
end

function Timer:isHidden(id)
    local hidden = self.settings:readSetting("hidden_modes")
    return hidden and hidden[id] or false
end

function Timer:toggleHidden(id)
    local hidden = self.settings:readSetting("hidden_modes") or {}
    hidden[id] = not hidden[id] or nil
    self.settings:saveSetting("hidden_modes", hidden)
    self.settings:flush()
end

function Timer:getSubMenuItems()
    local items = {}
    for _i, m in ipairs(MODES) do
        if not self:isHidden(m.id) then
            local item = {
                text_func = function()
                    local name = MODE_NAMES[m.id]
                    if m.display == "background" and BgState.mode == m.kind then
                        local cur = m.kind == "timer" and bgElapsed() or bgRemaining()
                        return name .. " (" .. fmtHMS(cur) .. ")"
                    end
                    return name
                end,
                callback = function()
                    if m.display == "background" then
                        self:onBgMenuTap(m)
                    else
                        self:openFullscreen(m)
                    end
                end,
            }
            if m.display == "background" then
                item.checked_func = function()
                    return BgState.mode == m.kind
                end
            end
            table.insert(items, item)
        end
    end
    if #items > 0 then
        items[#items].separator = true
    end
    table.insert(items, {
        text = _("Settings"),
        sub_item_table = self:getSettingsItems(),
    })
    return items
end

function Timer:getSettingsItems()
    local items = {}
    for _i, m in ipairs(MODES) do
        table.insert(items, {
            text = MODE_NAMES[m.id],
            checked_func = function()
                return not self:isHidden(m.id)
            end,
            callback = function(touchmenu_instance)
                self:toggleHidden(m.id)
                if touchmenu_instance then
                    touchmenu_instance:updateItems()
                end
            end,
            keep_menu_open = true,
        })
    end
    return items
end

--- Fullscreen modes -------------------------------------------------------

local function landscapeRotation(direction)
    if direction == "cw" then
        return Screen.ORIENTATION_LANDSCAPE or 1
    end
    return Screen.ORIENTATION_LANDSCAPE_ROTATED or 3
end

function Timer:openFullscreen(m)
    local rotation
    if m.rotation then
        rotation = landscapeRotation(m.rotation)
    end
    if m.kind == "timer" then
        UIManager:show(ClockWidget:new{
            mode = "timer",
            rotation_mode = rotation,
        })
    else
        self:askDuration(function(secs)
            UIManager:show(ClockWidget:new{
                mode = "countdown",
                duration = secs,
                rotation_mode = rotation,
            })
        end)
    end
end

function Timer:askDuration(cb)
    local last = self.settings:readSetting("last_duration") or 300
    UIManager:show(CountdownSetup:new{
        duration = last,
        on_start = function(secs)
            self.settings:saveSetting("last_duration", secs)
            self.settings:flush()
            cb(secs)
        end,
    })
end

--- Background modes -------------------------------------------------------

function Timer:getFooter()
    return self.ui and self.ui.view and self.ui.view.footer
end

function Timer:bgFooterText()
    if not BgState.mode then return "" end
    local text
    if BgState.mode == "timer" then
        text = _("Timer") .. " " .. fmtHMS(bgElapsed())
    else
        text = _("Countdown") .. " " .. fmtHMS(bgRemaining())
    end
    if not BgState.running then
        text = text .. " (" .. _("paused") .. ")"
    end
    return text
end

function Timer:onBgMenuTap(m)
    if BgState.mode == m.kind then
        self:showBgDialog()
        return
    end
    local footer = self:getFooter()
    if not footer then
        UIManager:show(InfoMessage:new{
            text = _("Please open a book first: background mode shows the time in the reader's bottom status bar."),
        })
        return
    end
    if not footer.addAdditionalFooterContent then
        UIManager:show(InfoMessage:new{
            text = _("This KOReader version does not support extra status bar content. Please update KOReader, or use a fullscreen mode instead."),
        })
        return
    end
    if m.kind == "countdown" then
        self:askDuration(function(secs)
            self:startBg("countdown", secs)
        end)
    else
        self:startBg("timer", 0)
    end
end

function Timer:startBg(kind, duration)
    self:stopBg(true) -- replace any other background mode silently
    BgState.mode = kind
    BgState.running = true
    BgState.acc = 0
    BgState.started_at = os.time()
    BgState.duration = duration or 0
    BgState.flags = {}
    self:_attachBg()
    self:_ensureFooterVisible()
    UIManager:show(InfoMessage:new{
        text = kind == "timer" and _("Background timer started.")
            or _("Background countdown started."),
        timeout = 2,
    })
end

function Timer:stopBg(silent)
    if not BgState.mode then return end
    local was = BgState.mode
    BgState.mode = nil
    BgState.running = false
    BgState.acc = 0
    BgState.duration = 0
    BgState.flags = {}
    self:_detachBgUI()
    if not silent then
        UIManager:show(InfoMessage:new{
            text = was == "timer" and _("Background timer stopped.")
                or _("Background countdown stopped."),
            timeout = 2,
        })
    end
end

function Timer:_attachBg()
    local footer = self:getFooter()
    if not footer or not footer.addAdditionalFooterContent then return end
    if not self._bg_gen then
        self._bg_gen = function()
            return self:bgFooterText()
        end
    end
    if not self._bg_attached then
        footer:addAdditionalFooterContent(self._bg_gen)
        self._bg_attached = true
    end
    if not self._bg_tick then
        self._bg_tick = function()
            self:_onBgTick()
        end
    end
    UIManager:unschedule(self._bg_tick)
    UIManager:scheduleIn(1, self._bg_tick)
    self:_updateFooter()
end

function Timer:_detachBgUI()
    if self._bg_tick then
        UIManager:unschedule(self._bg_tick)
    end
    local footer = self:getFooter()
    if footer and self._bg_attached then
        pcall(footer.removeAdditionalFooterContent, footer, self._bg_gen)
        pcall(footer.onUpdateFooter, footer, true)
    end
    self._bg_attached = false
end

function Timer:_updateFooter()
    local footer = self:getFooter()
    if footer then
        pcall(footer.onUpdateFooter, footer, true)
    end
end

function Timer:_onBgTick()
    if not BgState.mode then return end
    if BgState.mode == "countdown" and BgState.running
            and bgElapsed() >= BgState.duration then
        self:_bgFinished()
        return
    end
    self:_updateFooter()
    if BgState.running then
        UIManager:scheduleIn(1, self._bg_tick)
    end
end

function Timer:_bgFinished()
    self:stopBg(true)
    for i = 0, 2 do
        UIManager:scheduleIn(i * 0.7, function()
            UIManager:setDirty("all", "full")
        end)
    end
    UIManager:show(InfoMessage:new{ text = _("Time is up!") })
end

function Timer:_ensureFooterVisible()
    local footer = self:getFooter()
    if not footer then return end
    if self.ui.view.footer_visible then return end
    -- Try to turn the status bar on for the user.
    pcall(function()
        local mode = footer.mode_list and footer.mode_list.page_progress or 1
        footer.mode = mode
        footer:applyFooterMode(mode)
        footer:onUpdateFooter(true)
    end)
    if self.ui.view.footer_visible then
        UIManager:show(InfoMessage:new{
            text = _("The status bar has been turned on so the timer is visible."),
            timeout = 3,
        })
    else
        UIManager:show(InfoMessage:new{
            text = _("Could not turn on the status bar automatically. Please enable it manually: tap the bottom edge of the screen, or use the top menu → Settings → Status bar."),
        })
    end
end

function Timer:bgTogglePause()
    if not BgState.mode then return end
    if BgState.running then
        BgState.acc = bgElapsed()
        BgState.running = false
        if self._bg_tick then
            UIManager:unschedule(self._bg_tick)
        end
    else
        BgState.started_at = os.time()
        BgState.running = true
        if self._bg_tick then
            UIManager:unschedule(self._bg_tick)
            UIManager:scheduleIn(1, self._bg_tick)
        end
    end
    self:_updateFooter()
end

function Timer:bgFlag()
    if BgState.mode ~= "timer" then return end
    table.insert(BgState.flags, bgElapsed())
    self:showBgFlags()
end

function Timer:showBgFlags()
    local lines = {}
    local prev = 0
    for i, f in ipairs(BgState.flags) do
        table.insert(lines, T(_("Flag %1: %2 (+%3)"), i, fmtHMS(f), fmtHMS(f - prev)))
        prev = f
    end
    local body = #lines > 0 and table.concat(lines, "\n") or _("No flags yet.")
    UIManager:show(InfoMessage:new{
        text = _("Flags:") .. "\n" .. body,
        timeout = 5,
    })
end

function Timer:_newButtonDialog(args)
    if has_bdt then
        return ButtonDialogTitle:new(args)
    end
    return ButtonDialog:new(args)
end

function Timer:showBgDialog()
    if not BgState.mode then return end
    local name = BgState.mode == "timer" and _("Background timer")
        or _("Background countdown")
    local cur = BgState.mode == "timer" and bgElapsed() or bgRemaining()
    local dlg
    local row1 = {
        {
            text = BgState.running and _("Pause") or _("Resume"),
            callback = function()
                UIManager:close(dlg)
                self:bgTogglePause()
            end,
        },
    }
    if BgState.mode == "timer" then
        table.insert(row1, {
            text = _("Flag"),
            callback = function()
                UIManager:close(dlg)
                self:bgFlag()
            end,
        })
    end
    local buttons = {
        row1,
        {
            {
                text = _("Stop"),
                callback = function()
                    UIManager:close(dlg)
                    self:stopBg()
                end,
            },
            {
                text = _("Close"),
                callback = function()
                    UIManager:close(dlg)
                end,
            },
        },
    }
    dlg = self:_newButtonDialog{
        title = name .. "  " .. fmtHMS(cur),
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(dlg)
end

return Timer
