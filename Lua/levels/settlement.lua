-- Curated trackers for settlement, the castle raid (element ids from the level's mission files).
return {
    counters = {
        [100721] = { text_id = "extraraidinfo_castle_gates", label = "Gates opened", icon = "waypoint_special_door", class = "ElementCounter" },
    },
    timers = {
        -- the escape timer of the game's HUD; the route says which vehicle comes and where
        [102066] = {
            text_id = "extraraidinfo_castle_escape",
            label = "Escape",
            icon = "waypoint_special_escape",
            class = "ElementTimerHud",
            routes = {
                [100267] = { text_id = "extraraidinfo_castle_escape_truck", label = "Escape truck", waypoint_pos = { -788.45, 87.97, 176 } },
                [100266] = { text_id = "extraraidinfo_castle_escape_garden", label = "Escape (garden)", waypoint_pos = { 6077.96, -670.29, -1200 } },
                [100268] = { text_id = "extraraidinfo_castle_escape_cable_car", label = "Escape (cable car)", waypoint_pos = { -3650, 1250, -550 } },
            },
        },
    },
    waypoints = {
        -- the radio antenna is placed at one of six points; shown while the way to the radio and the radio call are the objective
        {
            id = "radio",
            text_id = "extraraidinfo_castle_radio",
            label = "Radio antenna",
            icon = "waypoint_special_portable_radio",
            start = { 100138 },
            stop = { 100165 },
            points = { 100145, 100146, 100147, 100148, 100167, 100168 },
            offset = { -200.35, -182.96, 120 },
        },
    },
}
