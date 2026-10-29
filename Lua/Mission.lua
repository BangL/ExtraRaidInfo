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
    self._routes = nil
    self._route = nil
    self._previews = nil
    self._interactions = nil

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
-- Element ids are only unique per world and per instance, the same id shows up in other parts of the level with
-- another class. An entry may therefore name the `class` of its element and (part of) the `world` directory it is in.
-- `raid_only` / `operation_only`: the element is used by both, the tracker belongs to one of them.
local function entry_matches(entry, element)
    if entry.class and entry.class ~= element._ehi_class then
        return false
    end

    if entry.raid_only and ExtraRaidInfo:IsOperation() or entry.operation_only and not ExtraRaidInfo:IsOperation() then
        return false
    end

    if entry.world then
        local ok, world = blt.pcall(function()
            return element._mission_script:worlddefinition()._world_dir
        end)

        if ok and world and not tostring(world):find(entry.world, 1, true) then
            return false
        end
    end

    return true
end

function Mission:Label(kind, id, fallback, element)
    local entry = self:Data()[kind] and self:Data()[kind][id]

    if entry == false then
        return nil, true -- explicitly hidden
    end

    if type(entry) == "table" and element and not entry_matches(entry, element) then
        entry = nil
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
-- `waypoint_unit` is handled by the waypoint itself (it follows the unit), otherwise (listed delays only) the position of the target element.
function Mission:WaypointPosition(entry, target)
    -- auto-detected delays: the editor position of an objective element is not a place in the world (often far up in the sky)
    if not entry or entry.waypoint == false then
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
function Mission:OnDelay(source, target_id, delay, listed_only)
    if not ExtraRaidInfo:GetOption("show_delays") or delay > 1800 then
        return
    end

    local target = source:get_mission_element(target_id)

    if not target then
        return
    end

    local label, hidden, entry = self:Label("delays", target_id, nil, target)

    -- a listed delay may name its own minimum (`min_delay`), e.g. a short delay that still matters
    if hidden or delay < (entry and entry.min_delay or ExtraRaidInfo:GetOption("min_delay")) then
        return
    end

    if not entry and (listed_only or not self.DELAY_AUTO_CLASSES[target._ehi_class]) then
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

-- Routes ------------------------------------------------------------------------------------

-- Level data `timers[id].routes = { [element id] = { label, text_id, waypoint_pos } }`: when the mission picks one of these
-- (the element executes), that route's label and waypoint belong to the timer, e.g. where the escape vehicle arrives.
function Mission:RouteIds()
    if not self._routes then
        self._routes = {}

        for timer_id, entry in pairs(self:Data().timers or {}) do
            for route_id in pairs(type(entry) == "table" and entry.routes or {}) do
                self._routes[route_id] = timer_id
            end
        end
    end

    return self._routes
end

function Mission:OnRoute(element)
    local timer_id = self:RouteIds()[element._id]
    local entry = timer_id and self:Data().timers[timer_id]
    local route = entry and entry.routes[element._id]

    if not route then
        return
    end

    self._route = { timer_id = timer_id, route = route }

    -- the timer is already running: show it again with the route (the sync to the clients is a plain remove and add)
    local timer = element:get_mission_element(timer_id)
    local trackers = ExtraRaidInfo.Trackers
    local id = timer and self:TimerId(timer)
    local tracker = id and trackers:Get(id)

    if tracker then
        trackers:AddTimer(id, ExtraRaidInfo:Localize(route.text_id, route.label) or route.label, tracker.time, {
            element = tracker.element,
            category = "timers",
            text_id = route.text_id,
            icon = route.icon or entry.icon or "waypoint_special_wait",
            position = route.waypoint_pos and Vector3(unpack(route.waypoint_pos)) or nil,
        })
    end
end

-- Previews ----------------------------------------------------------------------------------

-- Level data `previews = { { id, position = { x, y, z }, start = <element id>, stop = { element ids }, states = { { id, label, text_id, icon } } } }`:
-- decided before it happens what comes where (the convoy lanes of convoy). When `start` executes, the first state whose
-- element is enabled (or, with `counter = n`, is a counter that stands at n) gives the label of a waypoint at `position`; it goes away when one of `stop` executes.
function Mission:PreviewIds()
    if not self._previews then
        self._previews = {}

        for _, preview in ipairs(self:Data().previews or {}) do
            self._previews[preview.start] = self._previews[preview.start] or {}
            table.insert(self._previews[preview.start], { preview = preview, show = true })

            for _, stop in ipairs(preview.stop or {}) do
                self._previews[stop] = self._previews[stop] or {}
                table.insert(self._previews[stop], { preview = preview, show = false })
            end
        end
    end

    return self._previews
end

function Mission:OnPreview(element)
    if not ExtraRaidInfo:GetOption("show_waypoints") then
        return
    end

    for _, entry in ipairs(self:PreviewIds()[element._id] or {}) do
        local preview = entry.preview
        local id = "preview_" .. tostring(element._sync_id or 0) .. "_" .. tostring(preview.id)

        if not entry.show then
            ExtraRaidInfo.Trackers:Remove(id)
        else
            for _, state in ipairs(preview.states or {}) do
                local target = element:get_mission_element(state.id)

                -- a state is either an enabled element or a counter that was set to `counter` (the bunker choice of flakturm)
                local match = target and (state.counter ~= nil and target._values.counter_target == state.counter or state.counter == nil and target._values.enabled)

                if match then
                    ExtraRaidInfo.Trackers:AddInfo(id, ExtraRaidInfo:Localize(state.text_id, state.label) or state.label, "", {
                        position = Vector3(unpack(preview.position)),
                        waypoint_only = true,
                        category = "waypoints",
                        text_id = state.text_id,
                        icon = state.icon,
                    })

                    break
                end
            end
        end
    end
end

-- Interactions ------------------------------------------------------------------------------

-- Level data `interactions = { { tweak = "<interaction tweak id>", label, text_id, icon, offset = z } }`: a waypoint on every unit
-- with that interaction as long as it can still be used (the trucks to open in forest_gumpy). Local only, nothing is synced.
function Mission:UpdateInteractions(t)
    if t < (self._interaction_t or 0) then
        return
    end

    self._interaction_t = t + 0.5

    local list = self:Data().interactions
    local trackers = ExtraRaidInfo.Trackers

    self._interactions = self._interactions or {}

    if not list or not ExtraRaidInfo:GetOption("show_waypoints") then
        for id in pairs(self._interactions) do
            trackers:Remove(id)
        end

        self._interactions = {}

        return
    end

    local seen = {}

    for _, unit in ipairs(managers.interaction._interactive_units or {}) do
        local interaction = alive(unit) and unit:interaction()

        if interaction then
            for _, entry in ipairs(list) do
                if interaction.tweak_data == entry.tweak then
                    local id = "interaction_" .. tostring(unit:key())

                    if interaction:active() then
                        seen[id] = true

                        if not trackers:Get(id) then
                            trackers:AddInfo(id, ExtraRaidInfo:Localize(entry.text_id, entry.label) or entry.label, "", {
                                position = unit:position() + Vector3(0, 0, entry.offset or 100),
                                waypoint_only = true,
                                icon = entry.icon,
                            })
                        end
                    end
                end
            end
        end
    end

    -- used up or gone
    for id in pairs(self._interactions) do
        if not seen[id] then
            trackers:Remove(id)
        end
    end

    self._interactions = seen
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
    local label, hidden, entry = self:Label("timers", element._id, pretty(element:editor_name()), element)

    if hidden or not (entry or (is_hud and ExtraRaidInfo:GetOption("show_hud_timers"))) then
        return
    end

    local route = entry and entry.routes and self._route and self._route.timer_id == element._id and self._route.route

    if route then
        label = ExtraRaidInfo:Localize(route.text_id, route.label) or route.label
    end

    trackers:AddTimer(id, label, time, {
        element = element,
        category = "timers",
        text_id = route and route.text_id or entry and entry.text_id,
        hide_paused = entry and entry.hide_paused,
        icon = route and route.icon or entry and entry.icon or "waypoint_special_wait",
        position = route and route.waypoint_pos and Vector3(unpack(route.waypoint_pos)) or nil,
    })
end

-- Counters ----------------------------------------------------------------------------------

-- Only curated counters are shown: the unnamed ones are plain logic glue.
function Mission:OnCounter(element, op)
    if not ExtraRaidInfo:GetOption("show_counters") then
        return
    end

    local label, hidden, entry = self:Label("counters", element._id, nil, element)

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
