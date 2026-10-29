-- Curated trackers for ger_bridge (element ids from the level's mission files).
return {
    counters = {
        [106171] = { text_id = "extraraidinfo_ger_bridge_planes", label = "Planes destroyed", icon = "waypoint_special_air_strike", class = "ElementCounter" },
        [101040] = { text_id = "extraraidinfo_ger_bridge_planes", label = "Planes destroyed", icon = "waypoint_special_air_strike", class = "ElementCounter" },
    },
    -- The boat that takes you off: one of three landings, picked at random (random_boat_drive_in_anim) when 20 s are left on the
    -- boat timer. The route says which one it is.
    timers = {
        [100376] = {
            text_id = "extraraidinfo_ger_bridge_boat",
            label = "Boat",
            icon = "waypoint_special_boat",
            class = "ElementTimerHud",
            routes = {
                [102004] = { text_id = "extraraidinfo_ger_bridge_boat_start", label = "Boat (start side)", waypoint_pos = { -1780.06, 2221.92, -1750 } },
                [101821] = { text_id = "extraraidinfo_ger_bridge_boat_left", label = "Boat (left)", waypoint_pos = { 2861.84, 1559.92, -1811 } },
                [101822] = { text_id = "extraraidinfo_ger_bridge_boat_right", label = "Boat (right)", waypoint_pos = { 3027.19, -1970.21, -1705 } },
            },
        },
    },
    -- Which of the two bridge pillars is blown (instance ger_bridge_dual_arch_001 / _002 = logic_link_destroy_dual_arch_1 / _2) is decided at the
    -- start of the mission (logic_random_001, ~2.5 s in): the link of the chosen one is enabled. Shown from reaching the top of the bridge
    -- (logic_link_player_on_the_bridge, before the dynamite objective; expo skips that one) until the blast.
    previews = {
        {
            id = "pillar_1",
            position = { 129.65, 2140.63, -550.61 },
            start = 100401, -- logic_link_player_on_the_bridge
            stop = { 100636 }, -- detonate_arches
            states = { { id = 100097, text_id = "extraraidinfo_ger_bridge_pillar", label = "Blow this pillar", icon = "waypoint_special_dynamite_stick" } },
        },
        {
            id = "pillar_2",
            position = { 129.65, -2734.37, -550.61 },
            start = 100401,
            stop = { 100636 },
            states = { { id = 100105, text_id = "extraraidinfo_ger_bridge_pillar", label = "Blow this pillar", icon = "waypoint_special_dynamite_stick" } },
        },
    },
}
