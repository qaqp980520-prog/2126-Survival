# Run 33 — KROLL Deep Current Angler + CropPlotController M0.1

## Game asset
- Path: `daily_games/KROLL_Deep_Current_Angler/`
- Godot 4.3+, no external assets/plugins.
- Turn-based fishing loop: cast, wait for deterministic bite, hook, alternate reel/ease to manage line tension, catch three fish before 30 valid actions.
- Files: `project.godot`, `main.tscn`, `main.gd`, `rules.gd`, `tests/rules_test.gd`, `tests/game_smoke_test.gd`, `README.md`.
- Import via Godot Project Manager: open `daily_games/KROLL_Deep_Current_Angler/project.godot`.
- CI status at authoring time: pending; no local Godot executable, so no local engine test is claimed.

## Existing-system integration
- Added `systems/CropPlotController.gd`, a world-facing adapter around the existing `CropRegistry`.
- `plant_crop`, `water_crop`, `advance_crop`, `harvest_crop`, `get_crop`, and `remove_crop` delegate to the validated registry.
- `advance_crops` validates the entire ID batch, snapshots schema-1 state, and restores the snapshot if any tick fails; this prevents partial growth updates across a group of plots.
- `prototypes/BackroomsPortalPlayground.gd` now instantiates the controller and binds it to the existing registry. Existing save envelope still serializes the registry; no schema change.
- Test: `tests/crop_plot_controller_integration_test.gd` uses the actual active-world scene and save/load path. It covers planting, atomic rollback when the later crop timestamp is ahead, batch growth, save/reload, watering, maturity, and harvest receipt.
- Limits: this is an API integration, not yet visible crop meshes or player proximity interactions. The formal production `scripts/world.gd` controller remains absent. Complete chunk unload/reload persistence and async streaming remain open.
