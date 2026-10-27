-- Curated trackers for forest_bunker (element ids from the level's mission files).
return {
    timers = {
        [100013] = { text_id = "extraraidinfo_forest_bunker_t_gas", label = "Gas", icon = "waypoint_special_valve", class = "ElementTimer", world = "fb_puzzle_pipe_hint" },
        [100006] = { text_id = "extraraidinfo_forest_bunker_t_timeout", label = "Time limit", icon = "waypoint_special_wait", class = "ElementTimer", world = "fb_secret_radio_placed" },
    },
}
