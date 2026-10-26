# Mineral Chunk Controller M0.1 — 2026-10-26

## Purpose
Provide the first actual owner for chunk-root lifetime and connect instantiated chunks to the existing stable-ID mineral registry through MineralChunkLifecycleAdapter.

## Files
- `systems/MineralChunkController.gd`: owns loaded chunk roots, discovers nested MineralMiningNode nodes, registers/unregisters them before freeing roots, and delegates world-save serialization/restoration to MineralVeinRegistry.
- `tests/mineral_chunk_controller_test.gd`: tests save -> unload -> registry restore -> reload with offline regeneration, empty chunks, and duplicate chunk ID rejection.
- `.github/workflows/godot-validation.yml`: adds a guarded headless test and the new daily-game checks.
- `daily_games/KROLL_Pulse_Rhythm/`: standalone four-lane rhythm/timing game.

## Integration contract
The world generator creates a chunk root and calls `load_chunk(chunk_id, chunk_root, now_unix)`. The controller takes ownership. Call `unload_chunk(chunk_id, now_unix)` before the world generator discards a chunk. Use `to_save_dict()` / `restore_save_dict()` to persist mineral registry data as part of the enclosing world save.

Local vein IDs derive from node-name hierarchy, so scene node names must remain stable between saved versions.

## Import and run
Open `daily_games/KROLL_Pulse_Rhythm/project.godot` in Godot 4.3 or later. For the survival controller, open the repository's main project in Godot 4.3; the controller is a system script intended to be instantiated by the future world generator.

## Validation
Full Godot 4.3 headless CI is required before merge. Local Godot executable is unavailable in the authoring environment; no local editor, graphical playtest, or iPhone test is claimed.

## Limits and next step
This controller manages lifecycle for chunk roots supplied by the world generator, but does not yet implement spatial chunk selection, distance-based streaming, asynchronous scene loading, or world-map generation. Next: connect the controller to the actual world generator and add an end-to-end scene test.
