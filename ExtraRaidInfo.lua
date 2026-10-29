ExtraRaidInfo = ExtraRaidInfo or {}

if not ExtraRaidInfo.setup then
    ExtraRaidInfo.setup = true
    ExtraRaidInfo.VERSION = "0.2.2"
    ExtraRaidInfo._path = ModPath
    ExtraRaidInfo._config_path = SavePath .. "ExtraRaidInfo.json"
    ExtraRaidInfo._config = {}
    ExtraRaidInfo._defaults = {}

    -- Per-level data, filled by Lua/levels/<level_id>.lua (see ExtraRaidInfo:GetLevelData).
    ExtraRaidInfo.Levels = {}

    function ExtraRaidInfo:Log(msg)
        log("[ExtraRaidInfo] " .. tostring(msg))
    end

    -- Runs f and logs errors; a Lua error in an update or hook must never reach the engine.
    function ExtraRaidInfo:Safe(f, ...)
        local ok, ret = blt.pcall(f, ...)

        if not ok then
            if ret ~= self._last_error then
                self._last_error = ret
                self:Log("error: " .. tostring(ret))
            end

            return nil
        end

        return ret
    end

    function ExtraRaidInfo:LoadDefaults()
        local file = io.open(self._path .. "default_config.json")

        if file then
            self._defaults = json.decode(file:read("*all"))
            file:close()
        end
    end

    function ExtraRaidInfo:LoadConfig()
        self._config = clone(self._defaults)

        local file = io.open(self._config_path, "r")

        if file then
            local config = json.decode(file:read("*all"))

            file:close()

            if type(config) == "table" then
                for k, v in pairs(config) do
                    if self._defaults[k] ~= nil then
                        self._config[k] = v
                    end
                end
            end
        end
    end

    function ExtraRaidInfo:SaveConfig()
        local file = io.open(self._config_path, "w+")

        if file then
            file:write(json.encode(self._config))
            file:close()
        end
    end

    function ExtraRaidInfo:GetOption(id)
        return self._config[id]
    end

    -- Returns true if the value changed.
    function ExtraRaidInfo:SetOption(id, value)
        if self._config[id] == value then
            return false
        end

        self._config[id] = value

        if self.Trackers then
            self.Trackers:OptionChanged(id)
        end

        return true
    end

    -- Level id of the running raid (tweak_data.operations.missions[...].level_id), nil in the camp.
    function ExtraRaidInfo:CurrentLevelId()
        local job = managers.raid_job and managers.raid_job:current_job()

        -- an operation has no level of its own, the level belongs to the running event
        return job and (job.level_id or (job.current_event_data and job.current_event_data.level_id)) or nil
    end

    function ExtraRaidInfo:IsOperation()
        local job = managers.raid_job and managers.raid_job:current_job()

        return job ~= nil and job.job_type == OperationsTweakData.JOB_TYPE_OPERATION
    end

    -- Loads and caches Lua/levels/<level_id>.lua; the file returns a table (or nothing).
    function ExtraRaidInfo:GetLevelData(level_id)
        if not level_id then
            return nil
        end

        if self.Levels[level_id] == nil then
            local path = self._path .. "Lua/levels/" .. level_id .. ".lua"
            local file = io.open(path, "r")
            local data = false

            if file then
                -- loadfile does not exist in RAID's Lua
                local chunk, err = loadstring(file:read("*all"), "@" .. path)

                file:close()

                if chunk then
                    data = self:Safe(chunk) or false
                else
                    self:Log("level data " .. level_id .. ": " .. tostring(err))
                end
            end

            self.Levels[level_id] = data
        end

        return self.Levels[level_id] or nil
    end

    function ExtraRaidInfo:Localize(id, fallback)
        local loc = managers.localization

        if loc and id and loc:exists(id) then
            return loc:text(id)
        end

        return fallback
    end

    ExtraRaidInfo:LoadDefaults()
    ExtraRaidInfo:LoadConfig()

    dofile(ExtraRaidInfo._path .. "Lua/Network.lua")
    dofile(ExtraRaidInfo._path .. "Lua/Mission.lua")
    dofile(ExtraRaidInfo._path .. "Lua/ElementHooks.lua")
end
