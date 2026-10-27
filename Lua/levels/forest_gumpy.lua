-- Curated trackers for forest_gumpy (element ids from the level's mission files).
return {
    counters = {
        [100470] = { text_id = "extraraidinfo_forest_gumpy_blockers", label = "Road blockers removed", icon = "waypoint_special_tools", class = "ElementCounter" },
    },
    -- the trucks of this map that are still closed
    interactions = {
        { tweak = "open_truck_trunk", text_id = "extraraidinfo_forest_gumpy_truck", label = "Truck (closed)", icon = "waypoint_special_vehicle_truck", offset = 150 },
    },
}
