-- Trackers belong to one mission: drop them whenever a mission starts or ends.
for _, name in ipairs({ "on_mission_started", "on_mission_ended", "_on_restart_to_camp" }) do
    if RaidJobManager[name] then
        Hooks:PostHook(RaidJobManager, name, "ExtraRaidInfo_RaidJobManager_post_" .. name, function()
            ExtraRaidInfo.Mission:Reset()
        end)
    end
end
