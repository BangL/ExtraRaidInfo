-- Wraps the mission element classes. The core modules are executed again when a mission loads, which puts
-- the original functions back; so the wrappers are (re)installed whenever a mission script is added,
-- and only if the class does not carry ours already. (Importing the modules from inside their own hook
-- would recurse endlessly, hence nothing here runs at load time.)

ExtraRaidInfo.ElementHooks = ExtraRaidInfo.ElementHooks or {}

local ElementHooks = ExtraRaidInfo.ElementHooks
local installed = ElementHooks._installed or setmetatable({}, { __mode = "k" })

ElementHooks._installed = installed

-- make(original) returns the wrapper
local function wrap(class, name, make)
    local ours = installed[class]

    if not ours then
        ours = {}
        installed[class] = ours
    end

    local current = class[name]

    if not current or ours[name] == current then
        return
    end

    local wrapper = make(current)

    ours[name] = wrapper
    class[name] = wrapper
end

local function report(f, ...)
    ExtraRaidInfo:Safe(f, ExtraRaidInfo.Mission, ...)
end

function ElementHooks:Install()
    local script_element = core:import("CoreMissionScriptElement").MissionScriptElement
    local timer_module = core:import("CoreElementTimer")
    local counter = core:import("CoreElementCounter").ElementCounter

    -- Elements do not know their own class name; keep it for the delay filter.
    wrap(script_element, "init", function(original)
        return function(self, mission_script, data, ...)
            local ret = original(self, mission_script, data, ...)

            self._ehi_class = data and data.class

            return ret
        end
    end)

    -- objectives show and hide the markers of the level data
    if ElementObjective then
        wrap(ElementObjective, "on_executed", function(original)
            return function(self, ...)
                local ret = original(self, ...)

                if Network:is_server() then
                    report(ExtraRaidInfo.Mission.OnObjective, self)
                end

                return ret
            end
        end)
    end

    -- level data routes: which of several alternatives the mission picks
    wrap(script_element, "on_executed", function(original)
        return function(self, ...)
            if Network:is_server() and self._values and self._values.enabled then
                local mission = ExtraRaidInfo.Mission

                if mission:RouteIds()[self._id] then
                    report(mission.OnRoute, self)
                end

                if mission:PreviewIds()[self._id] then
                    report(mission.OnPreview, self)
                end
            end

            return original(self, ...)
        end
    end)

    -- every delayed execution of a follow-up element goes through here
    wrap(script_element, "_calc_element_delay", function(original)
        return function(self, params)
            local delay = original(self, params)

            if delay and delay > 0 and Network:is_server() then
                report(ExtraRaidInfo.Mission.OnDelay, self, params.id, delay)
            end

            return delay
        end
    end)

    -- the element's own delay before it executes (base_delay): only the listed ones (level data), the auto detection is for follow-up delays
    wrap(script_element, "_calc_base_delay", function(original)
        return function(self, ...)
            local delay = original(self, ...)

            if delay and delay > 0 and Network:is_server() then
                report(ExtraRaidInfo.Mission.OnDelay, self, self._id, delay, true)
            end

            return delay
        end
    end)

    -- timers (ElementTimerHud derives from ElementTimer but overrides the operations)
    for _, class in ipairs({ timer_module.ElementTimer, timer_module.ElementTimerHud }) do
        for name, op in pairs({
            timer_operation_start = "start",
            timer_operation_pause = "pause",
            timer_operation_add_time = "add",
            timer_operation_subtract_time = "subtract",
            timer_operation_reset = "reset",
            timer_operation_set_time = "set",
            on_executed = "done", -- finished: the timer executes its follow-up elements
        }) do
            wrap(class, name, function(original)
                return function(self, ...)
                    local ret = original(self, ...)

                    report(ExtraRaidInfo.Mission.OnTimer, self, op)

                    return ret
                end
            end)
        end
    end

    -- all counter operations change _values.counter_target
    for _, name in ipairs({
        "on_executed",
        "reset_counter_target",
        "counter_operation_add",
        "counter_operation_subtract",
        "counter_operation_reset",
        "counter_operation_set",
    }) do
        wrap(counter, name, function(original)
            return function(self, ...)
                local ret = original(self, ...)

                report(ExtraRaidInfo.Mission.OnCounter, self, name)

                return ret
            end
        end)
    end
end

function ElementHooks:SafeInstall()
    ExtraRaidInfo:Safe(self.Install, self)
end
