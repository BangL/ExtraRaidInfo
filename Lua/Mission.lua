-- Mission side of ExtraRaidInfo: turns mission element events into trackers.
--   * delayed executions (an element that fires another one N seconds later)
--   * ElementTimer / ElementTimerHud
--   * ElementCounter
-- Per-level data (Lua/levels/<level_id>.lua) says what is worth showing and how it is called.

ExtraRaidInfo.Mission = ExtraRaidInfo.Mission or {}

local Mission = ExtraRaidInfo.Mission

-- Delayed executions that get a tracker without being listed in the level data: only targets that
-- are gameplay (a new objective, something in another mission part). Everything else is animation
-- and logic glue; list it under `delays` in the level data to show it anyway.
Mission.DELAY_AUTO_CLASSES = {
    ElementObjective = true,
    ElementExecuteInOtherMission = true,
}

function Mission:Data()
    local level_id = ExtraRaidInfo:CurrentLevelId()

    if self._level_id ~= level_id or not self._data then
        self._level_id = level_id
        self._data = ExtraRaidInfo:GetLevelData(level_id) or {}
    end

    return self._data
end

function Mission:Reset()
    self._level_id = nil
    self._data = nil
    self._seen = {}

    ExtraRaidInfo.Network:Reset()

    if ExtraRaidInfo.Trackers then
        ExtraRaidInfo.Trackers:Clear()
    end
end

local function pretty(name)
    name = tostring(name or "")
    name = name:gsub("^logic_", ""):gsub("^func_", ""):gsub("^timer_", ""):gsub("^counter_", "")
    name = name:gsub("_?%d+$", ""):gsub("_", " "):gsub("(%l)(%u)", "%1 %2")

    if name == "" then
        return "?"
    end

    return name:sub(1, 1):upper() .. name:sub(2)
end

Mission.pretty = pretty

-- curated label for an element id, falling back to the pretty editor name
function Mission:Label(kind, id, fallback)
    local entry = self:Data()[kind] and self:Data()[kind][id]

    if entry == false then
        return nil, true -- explicitly hidden
    end

    if type(entry) == "table" then
        return ExtraRaidInfo:Localize(entry.text_id, entry.label) or fallback, false, entry
    end

    return type(entry) == "string" and entry or fallback, false, nil
end

-- Delayed executions ------------------------------------------------------------------------

local function objective_title(element)
    local id = element._values.objective

    if not id or not managers.objectives then
        return nil
    end

    local objective = managers.objectives:get_objective(id)
    local text_id = objective and objective.text

    if text_id and managers.localization:exists(text_id) then
        return managers.localization:text(text_id)
    end
end

-- Where the waypoint of a delay goes (level data): `waypoint = false` none, `waypoint_pos = { x, y, z }` that spot,
-- `waypoint_unit` is handled by the waypoint itself (it follows the unit), otherwise the position of the target element.
function Mission:WaypointPosition(entry, target)
    if entry and entry.waypoint == false then
        return nil
    end

    if entry and entry.waypoint_pos then
        return Vector3(unpack(entry.waypoint_pos))
    end

    if entry and entry.waypoint_unit then
        return nil
    end

    return target._values.position
end

-- Called whenever `source` schedules `target` to execute after `delay` seconds.
function Mission:OnDelay(source, target_id, delay)
    if not ExtraRaidInfo:GetOption("show_delays") or delay < ExtraRaidInfo:GetOption("min_delay") or delay > 1800 then
        return
    end

    local target = source:get_mission_element(target_id)

    if not target then
        return
    end

    local label, hidden, entry = self:Label("delays", target_id)

    if hidden then
        return
    end

    if not entry and not self.DELAY_AUTO_CLASSES[target._ehi_class] then
        return
    end

    local name = target:editor_name() or ""

    label = label or objective_title(target) or pretty(name)

    ExtraRaidInfo.Trackers:AddTimer("delay_" .. tostring(source._sync_id) .. "_" .. tostring(target_id), label, delay, {
        color = entry and entry.color,
        position = self:WaypointPosition(entry, target),
        unit_id = entry and entry.waypoint_unit,
        unit_sync = source._sync_id,
        icon = entry and entry.icon or "waypoint_special_wait",
        category = "delays",
        text_id = entry and entry.text_id,
    })
end

-- Markers -----------------------------------------------------------------------------------

local function contains(list, id)
    for _, entry in ipairs(list or {}) do
        if entry == id then
            return true
        end
    end

    return false
end

-- World position of a marker: the instance point that actually spawned its instance (points) plus the offset
-- inside that instance, or a fixed position.
function Mission:MarkerPosition(marker, element)
    for _, point_id in ipairs(marker.points or {}) do
        local point = element:get_mission_element(point_id)

        if point and point._has_created then
            -- not point:get_orientation(): on the host that logs the call for the clients and changes what they get
            local source = point
            local index = point._last_orientation_index

            if index and index ~= 0 and point._values.orientation_elements then
                source = point:get_mission_element(point._values.orientation_elements[index]) or point
            end

            local position, rotation = source._values.position, source._values.rotation
            local offset = Vector3(unpack(marker.offset or { 0, 0, 0 }))

            mvector3.rotate_with(offset, rotation)

            return position + offset
        end
    end

    return marker.position and Vector3(unpack(marker.position)) or nil
end

-- Level data `waypoints`: { id, label, text_id, icon, start = { objective element ids }, stop = { ... },
-- points = { instance point ids }, offset = { x, y, z } or position = { x, y, z } }. The marker is shown while an
-- objective that starts it is active.
function Mission:OnObjective(element)
    if not ExtraRaidInfo:GetOption("show_waypoints") then
        return
    end

    for index, marker in ipairs(self:Data().waypoints or {}) do
        local id = "marker_" .. tostring(element._sync_id or 0) .. "_" .. tostring(marker.id or index)

        if contains(marker.stop, element._id) then
            ExtraRaidInfo.Trackers:Remove(id)
        elseif contains(marker.start, element._id) then
            local position = self:MarkerPosition(marker, element)

            if position then
                ExtraRaidInfo.Trackers:AddInfo(id, ExtraRaidInfo:Localize(marker.text_id, marker.label) or marker.label, "", {
                    position = position,
                    category = "waypoints",
                    text_id = marker.text_id,
                    icon = marker.icon,
                })
            end
        end
    end
end

-- Timers ------------------------------------------------------------------------------------

function Mission:TimerId(element)
    return "timer_" .. tostring(element._sync_id or 0) .. "_" .. tostring(element._id)
end

-- op: "start" "pause" "add" "subtract" "reset" "set" "done"
function Mission:OnTimer(element, op)
    if not ExtraRaidInfo:GetOption("show_timers") then
        return
    end

    local id = self:TimerId(element)
    local trackers = ExtraRaidInfo.Trackers
    local is_hud = element._total_timer_value ~= nil
    local time = element._timer

    if type(time) ~= "number" then
        return
    end

    if op == "done" then
        trackers:Remove(id)

        return
    end

    local tracker = trackers:Get(id)

    if tracker then
        trackers:SetTime(id, time, op == "reset" or op == "set")
        trackers:SetPaused(id, op == "pause" or (op ~= "start" and tracker.paused))

        return
    end

    if op ~= "start" or time < ExtraRaidInfo:GetOption("min_delay") then
        return
    end

    -- plain timers: only the listed ones (most are logic glue); HUD timers: all, if enabled
    local label, hidden, entry = self:Label("timers", element._id, pretty(element:editor_name()))

    if hidden or not (entry or (is_hud and ExtraRaidInfo:GetOption("show_hud_timers"))) then
        return
    end

    trackers:AddTimer(id, label, time, { element = element, category = "timers", text_id = entry and entry.text_id, icon = entry and entry.icon or "waypoint_special_wait" })
end

-- Counters ----------------------------------------------------------------------------------

-- Only curated counters are shown: the unnamed ones are plain logic glue.
function Mission:OnCounter(element, op)
    if not ExtraRaidInfo:GetOption("show_counters") then
        return
    end

    local label, hidden, entry = self:Label("counters", element._id)

    if hidden or not entry then
        return
    end

    local remaining = element._values.counter_target

    -- The total is not the value the element starts with: the mission sets it per difficulty (gold_rush bags 3 -> 16)
    -- and adds to it. A set/reset starts over, everything else only ever raises it.
    if op == "counter_operation_set" or op == "counter_operation_reset" or op == "reset_counter_target" then
        element._extraraidinfo_max = remaining
    else
        element._extraraidinfo_max = math.max(element._extraraidinfo_max or element._original_value, remaining)
    end

    local max = entry.max or element._extraraidinfo_max
    local current = entry.remaining and remaining or (max - remaining)
    local id = "counter_" .. tostring(element._sync_id or 0) .. "_" .. tostring(element._id)
    local trackers = ExtraRaidInfo.Trackers
    local tracker = trackers:Get(id)

    if not tracker then
        tracker = trackers:AddCounter(id, label, current, entry.remaining and nil or max, { color = entry.color, category = "counters", text_id = entry.text_id, icon = entry.icon })
        tracker.done_keep = entry.keep
    else
        trackers:SetCount(id, current, not entry.remaining and max or nil)
    end

    -- finished counters leave the HUD after a moment
    if not entry.remaining and current >= max then
        tracker.remove_after = 5
    end
end
