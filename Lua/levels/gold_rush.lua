-- Curated trackers for gold_rush (element ids from the level's mission files).
return {
    counters = {
        [100746] = { text_id = "extraraidinfo_gold_rush_bags", label = "Gold bags secured", icon = "waypoint_special_gold", class = "ElementCounter" },
        [100806] = { text_id = "extraraidinfo_gold_rush_flags", label = "Flags", icon = "waypoint_special_defend", class = "ElementCounter" },
    },
    -- the truck is part of the operation version of this raid only; in the raid job the escape is the Kuebelwagen at the plane (nothing to show)
    delays = {
        [101373] = { text_id = "extraraidinfo_gold_rush_truck", label = "Truck arrives", waypoint_pos = { -4043, -10889, 300 }, icon = "waypoint_special_vehicle_truck", class = "ElementUnitSequence" },
    },
    -- The raid job: the Kuebelwagen leaves through one of two fences (gates), picked at the start of the mission (the waypoint of the
    -- chosen side is enabled). Each side has two gate doors; the marker sits between them. Shown from the "find an escape car" objective
    -- until the gate is done.
    previews = {
        {
            id = "exit_east",
            position = { 6200, -5000, 150 }, -- gates (6200, -4500) and (6200, -5500)
            start = 101737, -- obj_Find an escape car and put the gold onto it_b
            stop = { 100252 }, -- done_gate
            states = { { id = 100269, text_id = "extraraidinfo_gold_rush_exit", label = "Exit", icon = "waypoint_special_escape" } },
        },
        {
            id = "exit_west",
            position = { -5000, -5425, 150 }, -- gates (-5000, -4925) and (-5000, -5925)
            start = 101737,
            stop = { 100252 },
            states = { { id = 100268, text_id = "extraraidinfo_gold_rush_exit", label = "Exit", icon = "waypoint_special_escape" } },
        },
    },
}
