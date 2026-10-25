-- Syncs the trackers from the host to the clients that run ExtraRaidInfo as well (clients do not run the mission
-- script, so they could not build the delay, timer and counter trackers themselves).
--
-- Messages go through LuaNetworking (id "ExtraRaidInfo"), fields are separated by "|":
--   client -> host   H|protocol                          hello, the host starts sending to this peer
--   host -> client   K                                    ack of the hello
--   host -> client   T|id|category|label|text_id|time|total|paused|x,y,z|color|keep|unit_id|unit_sync|icon     add a timer
--                    N|id|category|label|text_id|current|max|color|icon                      add a counter
--                    M|id|category|label|text_id|icon|x,y,z                           add a marker (info with a waypoint)
--                    U|id|time|restart_total   P|id|paused   S|id|current|max   R|id   X (clear)
-- Loot is not synced: every client gets sync_secure_loot itself.

ExtraRaidInfo.Network = ExtraRaidInfo.Network or {}

local Net = ExtraRaidInfo.Network

Net.ID = "ExtraRaidInfo"
Net.PROTOCOL = 1
Net.HELLO_INTERVAL = 3
Net.HELLO_TRIES = 10
Net.RESYNC_INTERVAL = 10

-- host: peer ids that said hello
Net.peers = Net.peers or {}

-- option that switches a tracker category off on the receiving side
Net.CATEGORY_OPTIONS = {
    waypoints = "show_waypoints",
    delays = "show_delays",
    timers = "show_timers",
    counters = "show_counters",
}

local function field(value)
    return (tostring(value or ""):gsub("[|/%c]", " "))
end

local function number(value)
    return string.format("%.2f", value or 0)
end

local function pack(...)
    local parts = { ... }

    for i = 1, select("#", ...) do
        parts[i] = field(parts[i])
    end

    return table.concat(parts, "|")
end

-- keeps empty fields, unlike string.split
local function split(data)
    local fields = {}

    for part in (data .. "|"):gmatch("(.-)|") do
        fields[#fields + 1] = part
    end

    return fields
end

local function position_string(position)
    if not position then
        return ""
    end

    return string.format("%.1f,%.1f,%.1f", position.x, position.y, position.z)
end

local function parse_position(text)
    local x, y, z = tostring(text):match("^(-?[%d.]+),(-?[%d.]+),(-?[%d.]+)$")

    if x then
        return Vector3(tonumber(x), tonumber(y), tonumber(z))
    end
end

function Net:Session()
    return managers.network and managers.network:session()
end

function Net:IsHost()
    return self:Session() ~= nil and Network:is_server()
end

function Net:IsClient()
    return self:Session() ~= nil and Network:is_client()
end

-- only the trackers the mission script produced: they carry a category, loot and trackers received from the host do not
function Net:Syncs(tracker)
    return tracker.category ~= nil and not tracker.remote
end

function Net:SendTo(peer_id, data)
    if LuaNetworking and LuaNetworking:GetPeers()[peer_id] then
        LuaNetworking:SendToPeer(peer_id, self.ID, data)
    else
        self.peers[peer_id] = nil
    end
end

function Net:Send(data)
    for peer_id in pairs(self.peers) do
        self:SendTo(peer_id, data)
    end
end

-- Host: outgoing --------------------------------------------------------------------------

function Net:_describe(tracker)
    if tracker.kind == "timer" then
        return pack("T", tracker.id, tracker.category, tracker.label, tracker.text_id, number(tracker.time), number(tracker.total),
            tracker.paused and 1 or 0, position_string(tracker.position), tracker.color, number(tracker.keep), tracker.unit_id, tracker.unit_sync, tracker.icon)
    end

    if tracker.kind == "info" then
        return pack("M", tracker.id, tracker.category, tracker.label, tracker.text_id, tracker.icon, position_string(tracker.position))
    end

    return pack("N", tracker.id, tracker.category, tracker.label, tracker.text_id, tracker.current, tracker.max, tracker.color, tracker.icon)
end

function Net:OnAdd(tracker)
    if next(self.peers) and self:Syncs(tracker) then
        self:Send(self:_describe(tracker))
    end
end

function Net:OnSetTime(tracker, restart_total)
    if next(self.peers) and self:Syncs(tracker) then
        self:Send(pack("U", tracker.id, number(tracker.time), restart_total and 1 or 0))
    end
end

function Net:OnSetPaused(tracker)
    if next(self.peers) and self:Syncs(tracker) then
        self:Send(pack("P", tracker.id, tracker.paused and 1 or 0))
    end
end

function Net:OnSetCount(tracker)
    if next(self.peers) and self:Syncs(tracker) then
        self:Send(pack("S", tracker.id, tracker.current, tracker.max))
    end
end

function Net:OnRemove(tracker)
    if next(self.peers) and self:Syncs(tracker) then
        self:Send(pack("R", tracker.id))
    end
end

function Net:OnClear()
    if next(self.peers) then
        self:Send("X")
    end
end

-- Everything the host shows right now, for a peer that just said hello.
function Net:SendSnapshot(peer_id)
    for _, tracker in ipairs(ExtraRaidInfo.Trackers._list) do
        if self:Syncs(tracker) then
            self:SendTo(peer_id, self:_describe(tracker))
        end
    end
end

-- Called every frame from the tracker update.
function Net:Tick(dt)
    if not LuaNetworking then
        return
    end

    if self:IsClient() then
        if self.acked or (self.tries or 0) >= self.HELLO_TRIES then
            return
        end

        self.timer = (self.timer or 0) - dt

        if self.timer > 0 then
            return
        end

        local server = self:Session():server_peer()

        self.timer = self.HELLO_INTERVAL
        self.tries = (self.tries or 0) + 1

        if server then
            LuaNetworking:SendToPeer(server:id(), self.ID, pack("H", self.PROTOCOL))
        end
    elseif next(self.peers) then
        -- the clients count down on their own, a resync now and then catches drift
        self.resync = (self.resync or 0) - dt

        if self.resync > 0 then
            return
        end

        self.resync = self.RESYNC_INTERVAL

        for _, tracker in ipairs(ExtraRaidInfo.Trackers._list) do
            if tracker.kind == "timer" and self:Syncs(tracker) then
                self:Send(pack("U", tracker.id, number(tracker.time), 0))
            end
        end
    end
end

-- A new mission (or the camp) starts: forget the ack, say hello again.
function Net:Reset()
    self.acked = nil
    self.tries = 0
    self.timer = 0
end

-- Client: incoming --------------------------------------------------------------------------

function Net:_clear_remote()
    local trackers = ExtraRaidInfo.Trackers

    for i = #trackers._list, 1, -1 do
        local tracker = trackers._list[i]

        if tracker.remote then
            trackers:Remove(tracker.id)
        end
    end
end

-- data: one message from the host, already checked to come from the host
function Net:Apply(data)
    local f = split(data)
    local op = f[1]
    local trackers = ExtraRaidInfo.Trackers

    if op == "K" then
        self.acked = true
    elseif op == "M" then
        if not ExtraRaidInfo:GetOption(self.CATEGORY_OPTIONS.waypoints) then
            return
        end

        trackers:AddInfo(f[2], f[5] ~= "" and ExtraRaidInfo:Localize(f[5], f[4]) or f[4], "", {
            remote = true,
            category = f[3],
            text_id = f[5] ~= "" and f[5] or nil,
            icon = f[6] ~= "" and f[6] or nil,
            position = parse_position(f[7]),
        })
    elseif op == "T" or op == "N" then
        local category = f[3]
        local option = self.CATEGORY_OPTIONS[category]

        if not option or not ExtraRaidInfo:GetOption(option) then
            return
        end

        local label = f[5] ~= "" and ExtraRaidInfo:Localize(f[5], f[4]) or f[4]
        local params = { remote = true, category = category, text_id = f[5] ~= "" and f[5] or nil }

        if op == "T" then
            params.paused = f[8] == "1"
            params.position = parse_position(f[9])
            params.color = f[10] ~= "" and f[10] or nil
            params.keep = tonumber(f[11])
            params.unit_id = tonumber(f[12])
            params.unit_sync = tonumber(f[13])
            params.icon = f[14] ~= "" and f[14] or nil

            local tracker = trackers:AddTimer(f[2], label, tonumber(f[6]) or 0, params)

            tracker.total = math.max(tonumber(f[7]) or 0, 0.001)
        else
            params.color = f[8] ~= "" and f[8] or nil
            params.icon = f[9] ~= "" and f[9] or nil

            trackers:AddCounter(f[2], label, tonumber(f[6]) or 0, tonumber(f[7]), params)
        end
    elseif op == "U" then
        trackers:SetTime(f[2], tonumber(f[3]) or 0, f[4] == "1")
    elseif op == "P" then
        trackers:SetPaused(f[2], f[3] == "1")
    elseif op == "S" then
        local current, max = tonumber(f[3]) or 0, tonumber(f[4])
        local tracker = trackers:Get(f[2])

        trackers:SetCount(f[2], current, max)

        -- like the host: finished counters leave the HUD after a moment
        if tracker and tracker.max and current >= tracker.max then
            tracker.remove_after = 5
        end
    elseif op == "R" then
        trackers:Remove(f[2])
    elseif op == "X" then
        self:_clear_remote()
    end
end

function Net:Receive(sender, data)
    local peer_id = tonumber(sender)

    if not peer_id then
        return
    end

    if self:IsHost() then
        -- only a hello is of interest, everything else is meant for clients
        if split(data)[1] == "H" and LuaNetworking:GetPeers()[peer_id] then
            self.peers[peer_id] = true

            self:SendTo(peer_id, "K")
            self:SendSnapshot(peer_id)
        end
    elseif self:IsClient() then
        local server = self:Session():server_peer()

        if server and server:id() == peer_id then
            self:Apply(data)
        end
    end
end

Hooks:Add("NetworkReceivedData", "ExtraRaidInfo_Network_NetworkReceivedData", function(sender, id, data)
    if id == Net.ID and data then
        ExtraRaidInfo:Safe(Net.Receive, Net, sender, data)
    end
end)
