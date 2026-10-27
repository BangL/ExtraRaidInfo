# ExtraRaidInfo

Port of **Extra Heist Info** (PAYDAY 2, by Dom - https://modworkshop.net/mod/31915) to RAID: World War II.

A tracker list on the HUD for what the mission script is doing behind the scenes:

- **Delayed events** - countdown for things the mission triggers after a delay (objectives, sequences, ...), detected generically in every raid.
- **Timers** - mission timers (`ElementTimer`), the ones listed per level; optionally the HUD timers the game already shows.
- **Progress counters** - destroyed targets, collected items, ... for the raids that have them listed.
- **Loot** - loot secured this mission.

Requires **WaypointsLib** (hard dependency, for the waypoints of timers and delays).

Delays, timers and counters are built by the host (clients do not run the mission script). If the host runs ExtraRaidInfo as
well, it sends them to every client that runs it too (`Lua/Network.lua`, through LuaNetworking): a client says hello when it
is in a mission, the host answers with everything that is showing right now and then keeps the client up to date. The options
of the client decide what it shows. Loot needs no sync, every client gets it from the game. Without ExtraRaidInfo on the host
a client only sees the loot tracker.

## Per-level data

`Lua/levels/<level_id>.lua` returns a table keyed by element id:

```lua
return {
    counters = { [700135] = { text_id = "extraraidinfo_flakturm_shells", label = "Shells loaded" } },
    timers   = { [100195] = { text_id = "...", label = "Gate opens" } },
    delays   = { [100018] = false, [100019] = { label = "Truck arrives", waypoint = false } }, -- optional per entry: class = "ElementTimer" and world = "<part of the world directory>" (ids repeat in other parts of a level); false hides a delay, waypoint = false: no waypoint, waypoint_pos = { x, y, z }: the waypoint goes there, waypoint_unit = <editor unit id>: it follows that unit, icon = <gui icon id>: icon next to the label
}
```

The element ids come from the level's `*.mission` files (extracted to `extracted/levels/`). Labels are looked up
via `text_id` in `Loc/*.json`, `label` is the fallback.

## Options

Options > Mod Options > Extra Raid Info. All options apply immediately.
