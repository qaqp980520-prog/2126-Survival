# Mineral vein persistence in active world saves M0.1

Date: 2026-10-28

## Scope

Integrate the existing `MineralVeinRegistry` with the active `BackroomsPortalPlayground` world-save envelope. Preserve schema-v2 saves that predate the `mineral_veins` field, and validate registry data before the world mutates inventory or player state.

## Changes

- `systems/MineralVeinRegistry.gd`: add non-mutating `validate_save_dict()`; share validation and candidate-record construction with `restore_save_dict()` through `_prepare_restore()`.
- `prototypes/BackroomsPortalPlayground.gd`: create a registry with the active world, serialize it under `mineral_veins`, validate the payload before applying the save, then restore the registry.
- `tests/world_inventory_mining_lifecycle_test.gd`: extend the active-world test to cover saved vein stock, unloaded-record persistence across a fresh world instance, stable-ID node re-registration, legacy saves without the new field, and rejection of invalid mineral IDs without partial mutation.
- `.github/workflows/godot-validation.yml`: add Memory Matrix import/rules/runtime checks and the expanded world-mining/vein persistence test.

## Compatibility and safety

- World envelope version remains 2; older saves without `mineral_veins` are accepted.
- Registry schema remains 1; individual vein records retain their existing schema.
- Invalid registry data is rejected before inventory, player position, or live vein state is changed.
- Unloaded stable-ID records remain in the registry payload so streamed chunks can restore later.

## Dependencies and import

Godot 4.3+. No external assets or add-ons. Open `daily_games/KROLL_Memory_Matrix/project.godot` in the Project Manager.

## Validation status

Pending exact-candidate Godot 4.3 CI. No local Godot executable is available, so no local engine, GUI, GPU or iPhone hardware result is claimed.
