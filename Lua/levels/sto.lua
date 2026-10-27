-- Curated trackers for sto (element ids from the level's mission files).

-- In stealth the escape truck just stays where it is. When it gets loud (start_drive_away) it drives off and comes back after 120 or 180 s (by
-- difficulty or at random, random_return_timer). Where it comes back (random_escape_pos) is only decided when the time is up: one of three
-- drive-ins (start_drive_in001..003) that end at the escape spots of sto_escape_vehicle_005 / _004 / _003. The marker shows from the moment the
-- truck starts to drive in until it is there (on_pop_in_escape of that instance).
local function arrival(id, drive_in, position, popin)
    return {
        id = id,
        position = position,
        start = drive_in,
        stop = { popin },
        states = { { id = drive_in, text_id = "extraraidinfo_sto_truck", label = "Escape truck", icon = "waypoint_special_vehicle_truck" } },
    }
end

return {
    counters = {
        [100111] = { text_id = "extraraidinfo_sto_paintings", label = "Paintings", icon = "waypoint_special_loot", class = "ElementCounter" },
    },
    -- the wait until the truck comes back (the spot is not known yet: no waypoint)
    delays = {
        [100477] = { text_id = "extraraidinfo_sto_truck_returns", label = "Escape truck returns", icon = "waypoint_special_vehicle_truck", class = "MissionScriptElement", waypoint = false },
    },
    previews = {
        arrival("arrive_1", 100404, { -1991.02, 4068.11, 224 }, 131186), -- start_drive_in001 -> sto_escape_vehicle_005
        arrival("arrive_2", 100409, { -2837.77, 1761.53, 225 }, 131086), -- start_drive_in002 -> sto_escape_vehicle_004
        arrival("arrive_3", 100474, { 3307.86, 2436.69, 225 }, 130986), -- start_drive_in003 -> sto_escape_vehicle_003
    },
}
