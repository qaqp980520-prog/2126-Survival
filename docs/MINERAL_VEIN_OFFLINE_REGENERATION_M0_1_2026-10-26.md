# Mineral Vein Offline Regeneration M0.1 — 2026-10-26

## Goal
Make each mineral vein recover stock according to elapsed real-world seconds, including time while the game is closed, without exceeding its configured original maximum.

## Runtime behavior
- `max_units` sets the vein's capacity (default 24).
- `regen_interval_seconds` sets the time needed to restore one unit (default 300 seconds).
- `last_regen_unix` stores the start of the current partial interval.
- The node applies elapsed-time regeneration while active, before mining, and after loading a save.
- Whole elapsed intervals restore whole units. Partial elapsed time is preserved until the next unit is due.
- When the vein reaches capacity, the clock resets to the current time so a full vein does not accumulate a large offline backlog.
- A system-clock rollback never moves the saved timestamp backwards or creates stock.

## Save compatibility
Schema version remains 1. New saves include `max_units`, `regen_interval_seconds`, and `last_regen_unix`. Older schema-v1 saves containing only `schema_version`, `mineral_id`, and `remaining_units` remain accepted; they begin a new regeneration clock at load time. If a legacy save contains more stock than the node's current default maximum, capacity is inferred from the saved stock so old stock is not silently discarded.

Invalid schema, mineral ID, stock, capacity, interval, or timestamp is rejected before live state changes.

## Files
- `systems/MineralMiningNode.gd`: elapsed-time regeneration, bounded restore, save/load extension.
- `tests/mineral_catalog_test.gd`: deterministic tests for offline elapsed time, fractional intervals, capacity, clock rollback, legacy save compatibility, and invalid data.
- Existing mineral catalog/visual/VFX files are unchanged by this feature.

## Import and validation
Open the repository in Godot 4.3 or newer. The existing GitHub Actions workflow runs:
```sh
godot --headless --path . --script res://tests/mineral_catalog_test.gd
```
The feature branch must pass the full workflow before merging. No local Godot executable is available in this run, so local engine execution is not claimed.

## Limitations
- Uses system wall-clock time; manually changing the device clock backwards pauses regeneration until time catches up.
- Regeneration is attached to the prototype vein node, not yet wired into a full streamed world/chunk persistence manager.
- Production tuning of interval duration and per-mineral capacity remains open.
- No graphical playtest or iPhone test has been performed.
