# Backrooms Entity Runtime Persistence — M0.1.67

## Scope

Add versioned, validated persistence for mobile entity state before enabling cross-cell navigation. The runtime preserves a mobile entity's cell-local position, AI decision snapshot, elapsed decision time, and patrol waypoint across streamed-cell unload/reload and combined-world save/restore.

## Files

- `systems/BackroomsEntityRuntimeState.gd` — capture, deterministic spawn identity validation, bounded record validation and restore.
- `systems/BackroomsEntityBrain.gd` — versioned behavior save/load contract.
- `systems/BackroomsMazeStreamState.gd` — schema 3 entity-state cache, schema 1/2 migration and transactional clone support.
- `systems/BackroomsMazeCellRuntime.gd` — transactional capture, staging, restore and one-cell-halo retention.
- `systems/BackroomsEntityMovementDriver.gd` — patrol waypoint index mirrored to entity metadata.
- `tests/backrooms_maze_cell_runtime_test.gd` — unload/reload, save/restore and tampered-position regressions.
- `tests/backrooms_maze_stream_state_test.gd` — schema 1/2 migration and transactional clone coverage.
- `tests/backrooms_runtime_session_integration_test.gd` — JSON serialization/deserialization of the canonical Session envelope.
- `tests/backrooms_combined_world_save_test.gd` — combined-envelope schema 3 coverage.
- `.github/workflows/godot-validation.yml` — required input checks for the new codec and versioned asset.

## Dependencies and import

Godot 4.3; existing Backrooms EntityDirector, MazeLayout, EntityBrain, MazeCellRuntime, LocationSession and Combined World Save systems. No external plugin or asset import is required. Files are loaded by existing `preload("res://systems/...")` references.

## State contract

- Codec version: 1.
- Maze stream save schema: 3 (schema 1 and 2 remain readable).
- Captured fields: cell key, entity ID, spawn algorithm version, cell-local position, validated AI save state and patrol index.
- Only mobile entities are persisted; Window and Clump remain deterministic anchored entities.
- Every record must match a deterministic spawn descriptor for the same level, world seed, cell and spawn algorithm.
- Positions must remain inside the owning cell's safe interior and bounded vertical range.
- Duplicate identities, unknown entities, invalid AI states, unsupported versions and out-of-bounds positions fail closed. Integral numeric fields are validated after JSON round-trip whether decoded as integers or integral floats.
- Runtime state is retained within a one-cell halo beyond the current stream radius. The cache is capped at 4096 records.
- Streaming shifts clone the complete logical state, including loaded-cell keys and generation, before staging. A failed stage/commit leaves the live stream state and roots untouched.
- Cross-cell entity movement and ownership transfer remain disabled.

## Validation

Exact-head GitHub Actions Godot 4.3 Full Compatibility Gate is required. The new regression exercises a real cell unload/reload, checks position/AI/patrol restoration, round-trips the cache through save/load, and rejects a tampered out-of-cell position without mutating the existing runtime. Stream-state tests verify transactional clones preserve loaded-cell keys and a one-cell shift plan.

## Known limitations

- No NavigationAgent3D or cross-cell roaming.
- Entities outside the bounded one-cell retention halo return to deterministic spawn state when revisited.
- No combat, damage, animation, audio, or hardware/mobile performance validation.
- Local Godot executable availability is not assumed; GitHub Actions is the engine test source.

## Next step

After independent review and parent-chain validation, implement deterministic cell-graph routing and cross-cell ownership migration as a separate change, using this persisted state contract as the foundation.
