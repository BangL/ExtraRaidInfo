-- Curated trackers for settlement, the castle raid (element ids from the level's mission files).
return {
    counters = {
        [100721] = { text_id = "extraraidinfo_castle_gates", label = "Gates opened", icon = "waypoint_special_door" },
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
