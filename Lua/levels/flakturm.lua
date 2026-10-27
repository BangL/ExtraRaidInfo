-- Curated trackers for flakturm (element ids from the level's mission files).
-- Of the three bunkers only one can be opened: at the start of the mission the game sets the counter of the chosen one to 1
-- (bunker00 / bunker01 / bunker02 = left / middle / right). Shown from the "find the bunker" objective until a bunker is opened.
local function bunker(id, counter, position)
    return {
        id = id,
        position = position,
        start = 100054, -- func_objective_find_bunker
        stop = { 100132, 146577, 147177, 147777 }, -- func_objective_bunker_opened, func_objective_marian_flak_bunker_opened (3x)
        states = { { id = counter, counter = 1, text_id = "extraraidinfo_flakturm_bunker", label = "Bunker with a door", icon = "waypoint_special_door" } },
    }
end

return {
    previews = {
        bunker("bunker_left", 100304, { -1595, 150, 133 }),
        bunker("bunker_mid", 100306, { 2079, -1672, 117 }),
        bunker("bunker_right", 100308, { 4511, 3925, 408 }),
    },
}
