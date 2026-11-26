# M0.3.27 — Atomic Mineral Vein Chunk Registration

Date: 2026-11-26

## Purpose

Close the load-side counterpart to M0.3.26. A chunk containing multiple mineral veins must not partially restore earlier live nodes or registry records when a later saved record is incompatible with its incoming mineral identity.

## Implementation

- Add `MineralVeinRegistry.register_veins_atomic(chunk_id, veins_by_local_id, now_unix)`.
- Validate chunk/local IDs, incoming node identity, `can_register()`, current registry ownership, saved-record shape, mineral identity, and regeneration inputs before changing live state.
- Prepare every restore and offline-regeneration result on detached `MineralMiningNode` probes. Seed probes from incoming authored defaults so legacy schema-v1 records retain the same fallback capacities and regeneration intervals as single-node registration.
- Apply the fully prepared schema-v2 records to live nodes only after every participant passes preflight. Keep exact snapshots of every live node field changed by `load_save_dict()`; if an unexpected apply rejection occurs, restore already-applied nodes before returning false.
- Commit `_veins` and `_saved_records` only after every live node accepts its prepared state.
- Change `MineralChunkLifecycleAdapter.load_chunk()` to require and call the registry batch API; remove sequential registration and best-effort per-vein rollback.
- Update Controller and Adapter capability checks.
- Add adapter and controller regressions for a later saved-record mineral mismatch after an earlier valid participant. Both tests verify unchanged live-node state, unchanged registry payload, no published chunk ownership, then repair the record and retry the same nodes successfully.

## Files

- `systems/MineralVeinRegistry.gd`
- `systems/MineralChunkLifecycleAdapter.gd`
- `systems/MineralChunkController.gd`
- `tests/mineral_chunk_lifecycle_adapter_test.gd`
- `tests/mineral_chunk_controller_test.gd`
- `docs/MINERAL_VEIN_REGISTRY_ATOMIC_CHUNK_REGISTER_M0_3_27.md`

## Dependencies and import

Godot 4.3 project; existing `MineralMiningNode`, `MineralCatalog`, `MineralVeinRegistry`, `MineralChunkLifecycleAdapter`, and `MineralChunkController`. No plugin, external package, scene, autoload, Project Settings, or save-schema migration. Existing save payload schema remains unchanged.

## Validation

- Focused Adapter lifecycle test: `godot --headless --path . --script res://tests/mineral_chunk_lifecycle_adapter_test.gd`.
- Focused Controller integration test: `godot --headless --path . --script res://tests/mineral_chunk_controller_test.gd`.
- Registry chunk-stream persistence test remains part of the full Godot 4.3 validation workflow.
- Exact-head focused and Full Compatibility Gate results will be recorded after GitHub Actions completes. No result is claimed before completion.
- Local Godot executable is unavailable; GitHub Actions Godot 4.3 headless is the executable validation environment.

## Safety and limitations

- The atomic guarantee covers registry-owned mineral node state and registry maps. It does not make the entire Controller load (crops, world objects, terrain adjacency, and mineral registration) a single cross-system transaction; Controller retains its existing compensating rollback paths for those participants.
- `Object` and `Resource` references outside the serialized mineral-node state are not deep-cloned.
- The single-vein `register_vein()` API remains available for existing callers; chunk streaming now requires the atomic batch capability.
- No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is claimed.
- Keep the PR Draft until exact-head Focused Adapter, Focused Controller, and Full Compatibility Gate all pass and independent review is obtained. Do not merge main.

## Next

Inspect MineralGridStreamingDirector's synchronous registration recovery report and assert active-window restoration separately. Keep terrain Binder full rebuild as its existing correctness/recovery path until cross-participant equivalence is proven.
