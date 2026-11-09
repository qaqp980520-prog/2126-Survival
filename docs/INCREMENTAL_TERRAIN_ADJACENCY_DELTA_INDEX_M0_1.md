# Incremental Terrain Adjacency Delta Index M0.1

## Purpose

Introduce the first isolated primitive for the incremental terrain-adjacency work tracked by GitHub Issue #282. This version maintains a Stable-ID keyed weak-reference index, prepares detached load/unload delta plans, and rejects stale plans before committing index metadata.

The existing `SurfaceTerrainAdjacencyBinder.bind_patches()` full rebuild remains the production path and the authoritative correctness oracle. This asset does **not** mutate live patch edges, activate/deactivate terrain sides, or change transition-collider-manager ownership.

## Files

- `systems/SurfaceTerrainAdjacencyIndex.gd`
- `tests/surface_terrain_adjacency_index_test.gd`
- `.github/workflows/godot-validation.yml`
- `.github/workflows/surface-terrain-adjacency-index-validation.yml`
- `docs/INCREMENTAL_TERRAIN_ADJACENCY_DELTA_INDEX_M0_1.md`

## API

- `rebuild(patches, stable_ids_by_instance)`: validates a complete live patch set and atomically replaces the index snapshot.
- `plan_delta(remove_stable_ids, additions)`: prepares a candidate index and old/new descriptors for edges incident to changed Stable IDs. Each addition is a dictionary containing `stable_id` and `patch`. A Stable ID may be removed and re-added in the same plan for unload/reload.
- `commit_delta(plan_id)`: commits only if the index generation is unchanged and every touched live patch still matches its captured instance, position and world-object state.
- `abort_delta(plan_id)`: discards a prepared plan.
- `get_patch`, `get_snapshot`, `get_neighbors`, `get_edge_descriptors`, `get_generation` and `get_patch_count`: read-only accessors returning detached data where applicable.

The index stores `WeakRef` values rather than owning Node references. The spatial bucket map is copied at the dictionary level for a candidate plan; only bucket arrays touched by additions/removals are copied and mutated. Untouched bucket arrays remain shared. Duplicate-position validation checks the 27 neighboring tolerance-sized buckets and then applies the existing Euclidean distance contract.

## Dependencies and import

- Godot 4.3 root project.
- `SurfaceTerrainPatch.gd` patch profile and world-object-state validation API.
- `SurfaceTerrainTransitionDescriptor.gd` pure cardinal-edge descriptor builder.
- No external plugins, services, network access, assets or save-schema migration.
- No special import step. The dedicated `Surface Terrain Adjacency Index Validation` workflow imports the root project and runs `res://tests/surface_terrain_adjacency_index_test.gd`; the full Godot compatibility workflow also runs the same regression.

## Regression coverage

- Initial rebuild and full descriptor enumeration.
- Full-rebuild binder oracle comparison after initial build, same-Stable-ID replacement, one-patch addition, pure removal, stale-plan rejection and failed rebuild.
- Negative-coordinate spatial buckets and tolerance-sized cardinal adjacency.
- Duplicate-position rejection without mutating the committed generation.
- Remove/re-add of the same Stable ID with a new Node instance.
- Local edge delta scoping for a one-patch addition and a pure removal.
- Concurrent same-generation plans; the second commit must fail as stale.
- Patch-state mutation between plan and commit; commit must fail as stale.
- Patch release between plan and commit; commit must reject the stale WeakRef.
- Explicit plan abort and unknown-removal rejection.
- Mixed patch-size rejection.
- Failed full rebuild preserving the previously committed index.

## Status and limitations

- This is a preparatory index/delta-planning primitive only; `MineralChunkController` does not use it yet.
- No production adjacency mutation or transition-manager delta API is enabled.
- Corner-cap fallback closure across the junction↔edge graph is not implemented in this version.
- Transactional rollback of patch edges, descriptors and manager-owned resources is not implemented in this version.
- Exact-head Godot 4.3 focused and full CI are required before this PR can be marked Ready. Local Godot, rendered/GPU, physical iPhone and target-device performance tests are not available in this run.

## Next

1. Complete the focused index regression and full Godot 4.3 compatibility gate on this exact HEAD.
2. Add full affected junction↔edge connected-component closure and preserve-set ownership planning before any production edge/cap mutation.
3. Add injected preflight/activation failures and exact rollback assertions.
4. Keep the Controller on the full rebuild until those regressions pass at exact HEAD.
