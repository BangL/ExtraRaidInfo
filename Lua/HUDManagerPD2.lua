-- Tracker HUD: a column of rows (label, value, optional progress bar), one row per tracker.
-- Trackers are plain tables, see Trackers:AddTimer / AddCounter / AddInfo.

ExtraRaidInfo.Trackers = ExtraRaidInfo.Trackers or {}

local Trackers = ExtraRaidInfo.Trackers
local UPDATE_ID = "ExtraRaidInfo_update"
local PANEL_W = 250
local MARGIN = 8
local GAP = 3
local WARNING_TIME = 10
local FADE_SPEED = 8

Trackers._list = Trackers._list or {} -- ordered, oldest first
Trackers._by_id = Trackers._by_id or {}

local function fmt_time(seconds)
    seconds = math.max(0, math.ceil(seconds - 0.001))

    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- only touch a text when it changes, re-setting it every frame makes widgets flicker/vanish
local function set_text(widget, text)
    if widget:text() ~= text then
        widget:set_text(text)
    end
end

-- Waypoints (WaypointsLib, optional) --------------------------------------------------------

local function waypoint_id(tracker)
    return "extraraidinfo_" .. tostring(tracker.id)
end

-- the unit a waypoint follows (level data: waypoint_unit = editor unit id), nil if it is not there (yet)
local function follow_unit(tracker)
    if not tracker.unit_id then
        return nil
    end

    local wc = managers.worldcollection
    local ok, unit = blt.pcall(wc.get_unit_with_id, wc, tracker.unit_id, nil, tracker.unit_sync or 0)

    return ok and alive(unit) and unit or nil
end

function Trackers:_add_waypoint(tracker)
    if tracker.waypoint or tracker.kind == "counter" or not (tracker.position or tracker.unit_id) or not managers.waypoints or not ExtraRaidInfo:GetOption("show_waypoints") then
        return
    end

    local unit = follow_unit(tracker)

    if tracker.unit_id and not unit and not tracker.position then
        return
    end

    local id = waypoint_id(tracker)
    local icon = tracker.icon and tweak_data.gui.icons[tracker.icon] and {
        type = "icon",
        show = true,
        std_wp = tracker.icon,
        blend_mode = "normal",
        color = tweak_data.gui.colors.raid_gold,
    } or nil
    local ok, err = blt.pcall(managers.waypoints.add_waypoint, managers.waypoints, id, "CustomWaypoint", {
        unit = unit,
        position = not unit and tracker.position or nil,
        offset = Vector3(0, 0, 20),
        scale = 1.5,
        show_offscreen = true,
        color = tweak_data.gui.colors.raid_gold,
        visible_through_walls = true,
        icon = icon,
        label = { type = "label", show = true, text = tostring(tracker.label or "") },
        timer = tracker.kind == "timer" and { type = "timer", show = true, initial_value = tracker.time, auto_update = tracker.paused and 0 or -1 } or nil,
        distance = tracker.kind == "info" and { type = "distance", show = true } or nil,
        component_order = {
            icon and { "icon", "label" } or { "label" },
            { tracker.kind == "timer" and "timer" or "distance" },
        },
    }, true)

    if ok then
        tracker.waypoint = id
    else
        ExtraRaidInfo:Log("waypoint error: " .. tostring(err))
    end
end

function Trackers:_remove_waypoint(tracker)
    if tracker.waypoint and managers.waypoints then
        blt.pcall(managers.waypoints.remove_waypoint, managers.waypoints, tracker.waypoint)
    end

    tracker.waypoint = nil
end

-- API -------------------------------------------------------------------------------------

function Trackers:Get(id)
    return self._by_id[id]
end

local function add(self, id, tracker)
    local old = self._by_id[id]

    if old then
        self:Remove(id)
    end

    tracker.id = id
    tracker.alpha = 0
    tracker.age = 0
    self._by_id[id] = tracker
    table.insert(self._list, tracker)
    self:_add_waypoint(tracker)
    ExtraRaidInfo.Network:OnAdd(tracker)

    return tracker
end

-- Countdown. params: element (ElementTimer, read each frame instead of counting down ourselves),
-- paused, color (gui color name), position (waypoint), category ("delays", "timers" or "counters": synced to
-- the clients, see Network.lua), text_id (localization id of the label, for the clients), remote (received from the host)
function Trackers:AddTimer(id, label, time, params)
    params = params or {}

    return add(self, id, {
        kind = "timer",
        position = params.position, -- optional world position, shown as a waypoint
        unit_id = params.unit_id, -- or the editor id of a unit the waypoint follows (and the sync id of its mission)
        unit_sync = params.unit_sync,
        icon = params.icon, -- gui icon id shown left of the waypoint label
        category = params.category,
        text_id = params.text_id,
        remote = params.remote,
        label = label,
        time = time,
        total = math.max(time, 0.001),
        paused = params.paused,
        hide_paused = params.hide_paused, -- no row while paused (the level pauses it until the player fixes something)
        element = params.element,
        color = params.color,
        keep = params.keep, -- seconds to keep showing 0:00 after finishing
    })
end

-- x / max progress; max may be nil (then only x is shown)
function Trackers:AddCounter(id, label, current, max, params)
    params = params or {}

    return add(self, id, {
        kind = "counter",
        label = label,
        current = current,
        max = max,
        color = params.color,
        category = params.category,
        text_id = params.text_id,
        icon = params.icon,
        remote = params.remote,
    })
end

function Trackers:AddInfo(id, label, text, params)
    params = params or {}

    return add(self, id, {
        kind = "info",
        label = label,
        text = text,
        color = params.color,
        position = params.position, -- shown as a waypoint, like the timers
        waypoint_only = params.waypoint_only, -- no row in the list, only the waypoint
        category = params.category,
        text_id = params.text_id,
        icon = params.icon,
        remote = params.remote,
    })
end

function Trackers:SetTime(id, time, restart_total)
    local tracker = self._by_id[id]

    if tracker and tracker.kind == "timer" then
        tracker.time = time
        tracker.finished = nil

        if tracker.waypoint then
            blt.pcall(managers.waypoints.set_waypoint_timer, managers.waypoints, tracker.waypoint, "timer", time, tracker.paused and 0 or -1)
        end

        if restart_total or time > tracker.total then
            tracker.total = math.max(time, 0.001)
        end

        ExtraRaidInfo.Network:OnSetTime(tracker, restart_total)
    end
end

function Trackers:SetPaused(id, paused)
    local tracker = self._by_id[id]

    if tracker then
        tracker.paused = paused

        ExtraRaidInfo.Network:OnSetPaused(tracker)

        if tracker.waypoint then
            blt.pcall(managers.waypoints.set_waypoint_timer, managers.waypoints, tracker.waypoint, "timer", tracker.time, paused and 0 or -1)
        end
    end
end

function Trackers:SetCount(id, current, max)
    local tracker = self._by_id[id]

    if tracker and tracker.kind == "counter" then
        tracker.current = current

        if max then
            tracker.max = max
        end

        ExtraRaidInfo.Network:OnSetCount(tracker)
    end
end

function Trackers:Remove(id)
    local tracker = self._by_id[id]

    if not tracker then
        return
    end

    ExtraRaidInfo.Network:OnRemove(tracker)

    self._by_id[id] = nil

    for i, t in ipairs(self._list) do
        if t == tracker then
            table.remove(self._list, i)
            break
        end
    end

    self:_remove_waypoint(tracker)

    if tracker.row then
        self:_destroy_row(tracker)
    end
end

function Trackers:Clear()
    ExtraRaidInfo.Network:OnClear()

    for i = #self._list, 1, -1 do
        local tracker = self._list[i]

        self:_remove_waypoint(tracker)

        if tracker.row then
            self:_destroy_row(tracker)
        end
    end

    self._list = {}
    self._by_id = {}
end

function Trackers:OptionChanged(id)
    if id == "enabled" or id == "scale" or id == "background_alpha" then
        self:Recreate()
    end

    if id == "enabled" or id == "show_waypoints" then
        local on = ExtraRaidInfo:GetOption("enabled") and ExtraRaidInfo:GetOption("show_waypoints")

        for _, tracker in ipairs(self._list) do
            if on then
                self:_add_waypoint(tracker)
            else
                self:_remove_waypoint(tracker)
            end
        end
    end
end

-- Layout ----------------------------------------------------------------------------------

function Trackers:Create(hud)
    if self._panel and self._panel_parent then
        blt.pcall(self._panel_parent.remove, self._panel_parent, self._panel)
    end

    -- rows of the old panel are gone with it
    for _, tracker in ipairs(self._list) do
        tracker.row = nil
    end

    self._hud = hud

    local scale = ExtraRaidInfo:GetOption("scale")
    local font = tweak_data.gui.fonts.din_compressed
    local size = math.round(tweak_data.gui.font_sizes.size_20 * scale)

    self._scale = scale
    self._w = math.round(PANEL_W * scale)
    self._pad = math.round(10 * scale)
    self._row_h = size + math.round(10 * scale)
    self._font = tweak_data.gui:get_font_path(font, size)
    self._font_size = size
    self._panel_parent = hud.panel
    self._panel = hud.panel:panel({
        name = "extraraidinfo_panel",
        w = self._w,
        h = 10,
        layer = 5,
    })

    if not self._registered then
        self._registered = true
        managers.hud:add_updator(UPDATE_ID, callback(self, self, "Update"))
    end
end

function Trackers:Recreate()
    if self._hud and self._hud.panel then
        self:Create(self._hud)
    end
end

function Trackers:_create_row(tracker)
    local colors = tweak_data.gui.colors
    local w, h, pad = self._w, self._row_h, self._pad
    local panel = self._panel:panel({
        name = "row_" .. tostring(tracker.id),
        w = w,
        h = h,
        alpha = 0,
    })
    local bar_h = math.max(2, math.round(2 * self._scale))
    -- gui objects are userdata, so the widgets live in a plain table next to the panel
    local row = { panel = panel }

    row.bg = panel:rect({
        color = colors.raid_black,
        alpha = ExtraRaidInfo:GetOption("background_alpha"),
        layer = -2,
    })
    row.accent = panel:rect({
        color = colors[tracker.color or "raid_red"] or colors.raid_red,
        w = math.max(2, math.round(3 * self._scale)),
        layer = 1,
    })
    row.bar = panel:rect({
        color = colors.raid_gold,
        alpha = 0.7,
        x = 0,
        y = h - bar_h,
        w = 0,
        h = bar_h,
        layer = 1,
        visible = false,
    })
    -- optional gui icon (tweak_data.gui.icons id) in front of the label
    local icon = tracker.icon and tweak_data.gui.icons[tracker.icon]
    local label_x = pad

    if icon then
        local size = h - math.round(10 * self._scale)

        row.icon = panel:bitmap({
            texture = icon.texture,
            texture_rect = icon.texture_rect,
            x = pad,
            y = math.round((h - size) / 2),
            w = size,
            h = size,
            color = colors.raid_white,
            alpha = 0.85,
            layer = 2,
        })
        label_x = pad + size + math.round(6 * self._scale)
    end

    row.label = panel:text({
        text = "",
        font = self._font,
        font_size = self._font_size,
        color = colors.raid_grey,
        x = label_x,
        w = w - label_x - 8 - 70,
        h = h,
        vertical = "center",
        layer = 2,
    })
    row.value = panel:text({
        text = "",
        font = self._font,
        font_size = self._font_size,
        color = colors.raid_white,
        x = pad,
        w = w - pad - 8,
        h = h,
        align = "right",
        vertical = "center",
        layer = 2,
    })

    tracker.row = row
end

function Trackers:_destroy_row(tracker)
    local row = tracker.row

    tracker.row = nil

    if row and self._panel then
        blt.pcall(self._panel.remove, self._panel, row.panel)
    end
end

-- Update ----------------------------------------------------------------------------------

function Trackers:Update(t, dt)
    ExtraRaidInfo:Safe(ExtraRaidInfo.Network.Tick, ExtraRaidInfo.Network, dt)

    local ok, err = blt.pcall(self._update, self, t, dt)

    if not ok and err ~= self._last_error then
        self._last_error = err
        ExtraRaidInfo:Log("update error: " .. tostring(err))
    end
end

function Trackers:_update_tracker(tracker, dt)
    tracker.age = tracker.age + dt

    if tracker.remove_after then
        tracker.remove_after = tracker.remove_after - dt

        if tracker.remove_after <= 0 then
            return false
        end
    end

    if tracker.kind == "timer" then
        local element = tracker.element

        if element and element._timer ~= nil then
            tracker.time = element._timer
        elseif not tracker.paused then
            tracker.time = tracker.time - dt
        end

        if tracker.time <= 0 then
            tracker.time = 0

            if not tracker.finished then
                tracker.finished = tracker.keep or 0
            end

            tracker.finished = tracker.finished - dt

            if tracker.finished <= 0 then
                return false
            end
        end
    end

    return true
end

function Trackers:_update_row(tracker, dt)
    local row = tracker.row
    local colors = tweak_data.gui.colors
    local color_name = tracker.color

    if tracker.kind == "timer" then
        local warn = tracker.time <= WARNING_TIME and tracker.time > 0 and not tracker.paused

        color_name = color_name or (warn and "raid_red" or nil)
        set_text(row.value, fmt_time(tracker.time) .. (tracker.paused and " ||" or ""))

        local frac = math.clamp(tracker.time / tracker.total, 0, 1)

        row.bar:set_visible(true)
        row.bar:set_w(row.panel:w() * frac)
    elseif tracker.kind == "counter" then
        local text = tracker.max and string.format("%d / %d", tracker.current, tracker.max) or tostring(tracker.current)

        set_text(row.value, text)

        if tracker.max and tracker.max > 0 then
            row.bar:set_visible(true)
            row.bar:set_w(row.panel:w() * math.clamp(tracker.current / tracker.max, 0, 1))
        else
            row.bar:set_visible(false)
        end

        if tracker.max and tracker.current >= tracker.max then
            color_name = color_name or "progress_green"
        end
    else
        set_text(row.value, tracker.text or "")
    end

    local color = colors[color_name or "raid_gold"] or colors.raid_gold

    row.accent:set_color(color)
    row.bar:set_color(color)
    set_text(row.label, tracker.label or "")
end

function Trackers:_update(t, dt)
    if not (alive(self._panel) and alive(self._hud.panel)) then
        managers.hud:remove_updator(UPDATE_ID)
        self._registered = nil

        return
    end

    local enabled = ExtraRaidInfo:GetOption("enabled")

    self._panel:set_visible(enabled)

    if not enabled then
        return
    end

    ExtraRaidInfo:Safe(ExtraRaidInfo.Mission.UpdateInteractions, ExtraRaidInfo.Mission, t)

    -- update trackers, drop the finished ones
    for i = #self._list, 1, -1 do
        local tracker = self._list[i]

        if not self:_update_tracker(tracker, dt) then
            self:Remove(tracker.id)
        end
    end

    -- layout
    local y = 0

    for _, tracker in ipairs(self._list) do
        local hidden = tracker.hide_paused and tracker.paused

        if tracker.row then
            tracker.row.panel:set_visible(not hidden)
        end

        if not tracker.waypoint_only and not hidden then
            if not tracker.row then
                self:_create_row(tracker)
            end

            local row = tracker.row

            tracker.alpha = math.min(1, tracker.alpha + dt * FADE_SPEED)
            row.panel:set_alpha(tracker.alpha)
            row.panel:set_y(y)
            self:_update_row(tracker, dt)

            y = y + self._row_h + GAP
        end
    end

    self._panel:set_h(math.max(1, y))
    self:_position(y)
end

-- horizontal anchor from the "align" option, top edge at "y_pos" of the screen height (kept on screen)
function Trackers:_position(h)
    local hud_panel = self._hud.panel
    local align = ExtraRaidInfo:GetOption("align")

    if align == 1 then
        self._panel:set_left(MARGIN)
    elseif align == 2 then
        self._panel:set_center_x(hud_panel:w() / 2)
    else
        self._panel:set_right(hud_panel:w() - MARGIN)
    end

    self._panel:set_top(math.clamp(ExtraRaidInfo:GetOption("y_pos") * hud_panel:h(), 0, math.max(0, hud_panel:h() - h)))
end

Hooks:PostHook(HUDManager, "_setup_ingame_hud_saferect", "ExtraRaidInfo_HUDManager_post_setup_ingame_hud_saferect", function(self)
    if not self:alive(PlayerBase.INGAME_HUD_SAFERECT) then
        return
    end

    Trackers:Create(self:script(PlayerBase.INGAME_HUD_SAFERECT))
end)
