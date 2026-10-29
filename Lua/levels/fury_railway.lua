-- Curated trackers for fury_railway (element ids from the level's mission files).
-- The seven crates a bundle of dynamite can be in (wp = the game's WP_dynamite_found of the crate). The dynamite only gets an outline,
-- which is seen from close by. show_WP (wp + 2) runs when the crate with dynamite is opened (it is only enabled in those that have some),
-- the remove operator (wp + 1) ends it again (the level never calls it). It also goes away when the dynamite is put on the safe
-- (logic_link_004 of the train segment instances, ids = local id + start_index + 30000) or the train leaves (train_flee /
-- func_sequence_003: all wagons locked, or gate opened and every wagon empty).
local DYNAMITE_DONE = { 130388, 130888, 131388, 131888, 132388, 101332, 101742 }

local function dynamite(wp, position)
    local stop = { wp + 1 }
    for _, id in ipairs(DYNAMITE_DONE) do
        table.insert(stop, id)
    end

    return {
        id = "dynamite_" .. wp,
        position = position,
        start = wp + 2,
        stop = stop,
        states = { { id = wp, text_id = "extraraidinfo_fury_railway_dynamite", label = "Dynamite", icon = "waypoint_special_dynamite_stick" } },
    }
end

return {
    counters = {
        [102159] = { text_id = "extraraidinfo_fury_railway_trains", label = "Trains emptied of gold", icon = "waypoint_special_gold", class = "ElementCounter" },
    },
    -- The escape vehicle (instance fury_railway_escape_vehicle_001 / _002) is picked at random (logic_random_005) when it is called;
    -- link_popinescape then waits 17.5 s until the vehicle is there (WP_escape_truck).
    delays = {
        [142066] = { text_id = "extraraidinfo_fury_railway_truck", label = "Escape truck arrives", icon = "waypoint_special_vehicle_truck", class = "MissionScriptElement", waypoint_pos = { -3975, 550, 484 } },
        [142566] = { text_id = "extraraidinfo_fury_railway_truck", label = "Escape truck arrives", icon = "waypoint_special_vehicle_truck", class = "MissionScriptElement", waypoint_pos = { 7375, -425, 483 } },
    },
    timers = {
        [100195] = { text_id = "extraraidinfo_fury_railway_t_gate", label = "Gate opens", icon = "waypoint_special_door", class = "ElementTimer" },
    },
    previews = {
        dynamite(137450, { 6937.99, -2149.32, 100 }),
        dynamite(137150, { 365, -2308, 100 }),
        dynamite(140150, { -3592.3, -1787.87, 229 }),
        dynamite(141250, { -3690, 1717, 104 }),
        dynamite(136850, { 3650, 2342, 100 }),
        dynamite(139550, { 7238.38, 961.145, 106 }),
        dynamite(139850, { 1870.68, -1757.82, 212.152 }),
    },
}
