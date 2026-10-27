-- Curated trackers for forest_bunker (element ids from the running mission: instance elements carry the id of their instance copy).
local function gas()
    return { text_id = "extraraidinfo_forest_bunker_t_gas", label = "Gas", icon = "waypoint_special_valve", class = "ElementTimer" }
end

local function timeout()
    return { text_id = "extraraidinfo_forest_bunker_t_timeout", label = "Time limit", icon = "waypoint_special_wait", class = "ElementTimer" }
end

return {
    timers = {
        -- fb_puzzle_pipe_hint (logic_timer_gas), three copies
        [150013] = gas(), [150113] = gas(), [150213] = gas(),
        -- fb_secret_radio_placed (timer_timeout), three copies
        [150946] = timeout(), [151146] = timeout(), [151346] = timeout(),
    },
}
