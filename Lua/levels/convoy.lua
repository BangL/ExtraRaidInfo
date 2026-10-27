-- Curated trackers for convoy (element ids from the level's mission files).
-- What a lane gets is decided at the start of the mission: the *_chosen element of its vehicle is enabled
-- (tank / enemies / loot / armored, ids base + 0 .. 3; loot is the default that is switched off by the others).
local function convoy_states(base)
    return {
        { id = base, text_id = "extraraidinfo_convoy_lane_tank", label = "Tank", icon = "waypoint_special_explosive" },
        { id = base + 3, text_id = "extraraidinfo_convoy_lane_armored", label = "Armored truck", icon = "waypoint_special_vehicle_kugelwagen" },
        { id = base + 1, text_id = "extraraidinfo_convoy_lane_enemies", label = "Truck (enemies)", icon = "waypoint_special_kill" },
        { id = base + 2, text_id = "extraraidinfo_convoy_lane_loot", label = "Truck (loot)", icon = "waypoint_special_loot" },
    }
end

return {
    counters = {
        [102489] = { text_id = "extraraidinfo_convoy_vehicles", label = "Vehicles cleared", icon = "waypoint_special_vehicle_kugelwagen", class = "ElementCounter" },
    },
    -- Which of the two escape zones it is is picked at random (logic_random_001); only the chosen branch runs, so only its delays show.
    -- The wait before the escape (by difficulty) ends in escapeN, the vehicle then drives in 19 s later.
    delays = {
        [101856] = { text_id = "extraraidinfo_convoy_escape", label = "Escape", icon = "waypoint_special_escape", class = "MissionScriptElement", waypoint_pos = { -6463.66, 1181.73, -200.15 } },
        [101875] = { text_id = "extraraidinfo_convoy_escape", label = "Escape", icon = "waypoint_special_escape", class = "MissionScriptElement", waypoint_pos = { 4943.93, -1156.07, 389.30 } },
        [100817] = { text_id = "extraraidinfo_convoy_escape_vehicle", label = "Escape vehicle arrives", icon = "waypoint_special_escape", class = "MissionScriptElement", waypoint_pos = { -6463.66, 1181.73, -200.15 } },
        [100818] = { text_id = "extraraidinfo_convoy_escape_vehicle", label = "Escape vehicle arrives", icon = "waypoint_special_escape", class = "MissionScriptElement", waypoint_pos = { 4943.93, -1156.07, 389.30 } },
    },
    -- the mine spots: what drives in at each of the five lanes
    previews = {
        {
            id = "lane1",
            position = { 99.9999, 1950, 100 },
            start = 134281, -- enable_dynamite: the mines can be planted
            stop = { 100635 }, -- drive_in_convoy: stays until the convoy drives in
            states = convoy_states(134268),
        },
        {
            id = "lane2",
            position = { 100, 1000, 100 },
            start = 137281, -- enable_dynamite: the mines can be planted
            stop = { 100635 }, -- drive_in_convoy: stays until the convoy drives in
            states = convoy_states(137268),
        },
        {
            id = "lane3",
            position = { 100.001, 25, 96 },
            start = 140281, -- enable_dynamite: the mines can be planted
            stop = { 100635 }, -- drive_in_convoy: stays until the convoy drives in
            states = convoy_states(140268),
        },
        {
            id = "lane4",
            position = { 100.002, -950, 95 },
            start = 143281, -- enable_dynamite: the mines can be planted
            stop = { 100635 }, -- drive_in_convoy: stays until the convoy drives in
            states = convoy_states(143268),
        },
        {
            id = "lane5",
            position = { 100.002, -1900, 95 },
            start = 146281, -- enable_dynamite: the mines can be planted
            stop = { 100635 }, -- drive_in_convoy: stays until the convoy drives in
            states = convoy_states(146268),
        },
    },
}
