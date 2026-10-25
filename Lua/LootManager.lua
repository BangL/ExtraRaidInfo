-- Loot secured this mission.
Hooks:PostHook(LootManager, "sync_secure_loot", "ExtraRaidInfo_LootManager_post_sync_secure_loot", function(self)
    if not ExtraRaidInfo:GetOption("show_loot") then
        return
    end

    local trackers = ExtraRaidInfo.Trackers
    local count = #self:get_secured()

    if count <= 0 then
        return
    end

    if trackers:Get("loot") then
        trackers:SetCount("loot", count)
    else
        trackers:AddCounter("loot", ExtraRaidInfo:Localize("extraraidinfo_loot", "Loot secured"), count, nil, { icon = "waypoint_special_loot" })
    end
end)
