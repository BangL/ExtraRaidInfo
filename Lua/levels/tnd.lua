-- Curated trackers for tnd (element ids from the level's mission files).
return {
    counters = {
        [100878] = { text_id = "extraraidinfo_tnd_tanks", label = "Tanks destroyed", icon = "waypoint_special_explosive", class = "ElementCounter" },
    },
    delays = {
        -- the marker elements sit in the editor's logic row (z 9202), the waypoints go to the escape zones (escape_north_wp / escape_west_wp)
        [101010] = { text_id = "extraraidinfo_tnd_escape", label = "Escape marker", icon = "waypoint_special_escape", class = "ElementUnitSequence", waypoint_pos = { 6719.11, -2878.30, -197.33 } },
        [101011] = { text_id = "extraraidinfo_tnd_escape", label = "Escape marker", icon = "waypoint_special_escape", class = "ElementUnitSequence", waypoint_pos = { 7259.31, 3330.67, 58.67 }, min_delay = 0 },
    },
}
