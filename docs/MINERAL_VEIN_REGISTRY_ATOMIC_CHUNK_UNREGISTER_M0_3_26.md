# Atomic Mineral Vein Chunk Unregistration — M0.3.26

Date: 2026-11-26

## Problem

The production `MineralChunkLifecycleAdapter.unload_chunk()` unregistered veins one at a time. If a later vein failed validation, earlier veins had already advanced offline regeneration and moved from the live registry into saved records. The adapter then attempted best-effort re-registration, ignored rollback return values, and could not guarantee that a rejected chunk unload left every vein unchanged.

## Changes

- Added `MineralVeinRegistry.unregister_veins_atomic(chunk_id, veins_by_local_id, now_unix)`.
- Validate every local ID, live-node identity, mineral catalog entry, and serialized vein state before committing any registry mutation.
- Prepare each post-regeneration save record on a detached `MineralMiningNode` probe. Rejected candidates therefore do not advance the original live node.
- Commit all prepared saved records, then erase all corresponding live registry entries only after every participant has passed preflight.
- Updated `MineralChunkLifecycleAdapter.bind_registry()` to require the atomic batch API and `unload_chunk()` to use it instead of best-effort per-vein rollback.
- Updated `MineralChunkController.bind_registry()` capability checks.
- Strengthened the controller regression to inject an invalid second vein with a 120-second elapsed-regeneration window, then assert the first vein and the entire registry snapshot remain byte-for-byte equivalent after rejection. A repaired retry must commit the expected regeneration.

## Files

- `systems/MineralVeinRegistry.gd`
- `systems/MineralChunkLifecycleAdapter.gd`
- `systems/MineralChunkController.gd`
- `tests/mineral_chunk_controller_test.gd`
- `docs/MINERAL_VEIN_REGISTRY_ATOMIC_CHUNK_UNREGISTER_M0_3_26.md`

## Dependencies and import

Uses the existing Godot 4.3 GDScript project and the existing `MineralMiningNode`, `MineralCatalog`, `MineralChunkLifecycleAdapter`, and `MineralChunkController` APIs. No plugin, external package, scene import, autoload, save schema, or Project Settings change is required. The save payload schema remains unchanged.

## Validation

- Focused controller integration: `godot --headless --path . --script res://tests/mineral_chunk_controller_test.gd`
- Existing mineral registry and lifecycle adapter regressions remain included in the full validation workflow.
- Full project validation: `.github/workflows/godot-validation.yml` using Godot 4.3 headless.

The regression proves that a later invalid vein rejects the entire batch before the earlier vein's offline regeneration or registry membership changes. It then repairs the second vein and verifies that a successful unload stores the expected regenerated state.

## Limitations

- This closes the partial mineral-unregister rollback gap; it does not integrate the separate incremental terrain adjacency prototype.
- The existing `MineralVeinRegistry.unregister_vein()` remains available for single-vein callers.
- The detached probe path uses the existing `MineralMiningNode.load_save_dict()` and `apply_elapsed_regeneration()` logic, so save semantics remain shared with ordinary registration.
- No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device result is claimed.

## Next step

After independent review and exact-head Godot 4.3 validation, keep the full Binder rebuild as the terrain correctness/recovery oracle. Continue the separate Index/Binder/Collider incremental transaction integration only after its parent chain is independently reviewed.
