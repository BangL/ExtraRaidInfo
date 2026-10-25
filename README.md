# ExtraRaidInfo

Port of **Extra Heist Info** (PAYDAY 2, by Dom - https://modworkshop.net/mod/31915) to RAID: World War II.

A tracker list on the HUD for what the mission script is doing behind the scenes:

- **Delayed events** - countdown for things the mission triggers after a delay (objectives, sequences, ...), detected generically in every raid.
- **Timers** - mission timers (`ElementTimer`), the ones listed per level; optionally the HUD timers the game already shows.
- **Progress counters** - destroyed targets, collected items, ... for the raids that have them listed.
- **Loot** - loot secured this mission.

Requires **WaypointsLib** (hard dependency, for the waypoints of timers and delays).

Delays, timers and counters only work as host or in singleplayer (clients do not run the mission script).

## Per-level data

`Lua/levels/<level_id>.lua` returns a table keyed by element id:

```lua
return {
    counters = { [700135] = { text_id = "extraraidinfo_flakturm_shells", label = "Shells loaded" } },
    timers   = { [100195] = { text_id = "...", label = "Gate opens" } },
    delays   = { [100018] = false }, -- false hides a delay
}
```

The element ids come from the level's `*.mission` files (extracted to `extracted/levels/`). Labels are looked up
via `text_id` in `Loc/*.json`, `label` is the fallback.

## Options

Options > Mod Options > Extra Raid Info. All options apply immediately.
