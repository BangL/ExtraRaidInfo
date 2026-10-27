-- Curated trackers for gold_rush (element ids from the level's mission files).
return {
    counters = {
        [100746] = { text_id = "extraraidinfo_gold_rush_bags", label = "Gold bags secured", icon = "waypoint_special_gold", class = "ElementCounter" },
        [100806] = { text_id = "extraraidinfo_gold_rush_flags", label = "Flags", icon = "waypoint_special_defend", class = "ElementCounter" },
    },
    delays = {
        [101373] = { text_id = "extraraidinfo_gold_rush_truck", label = "Truck arrives", waypoint_pos = { -4043, -10889, 300 }, icon = "waypoint_special_vehicle_truck", class = "ElementUnitSequence" },
    },
}
