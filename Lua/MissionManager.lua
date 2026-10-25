-- Reinstall the element wrappers before a mission script (and its elements) is created.
Hooks:PreHook(MissionManager, "_add_script", "ExtraRaidInfo_MissionManager_pre_add_script", function()
    ExtraRaidInfo.ElementHooks:SafeInstall()
end)
