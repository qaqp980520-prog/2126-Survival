# Surface Terrain Unload Failure Atomicity — M0.3.25

Date: 2026-11-26

## Problem

The production `MineralChunkController.unload_chunk()` removed the chunk from all ownership maps, detached and queued its root for deletion, and only then rebuilt terrain adjacency. If the rebuild failed, the method logged an error but still returned `true`. The caller therefore observed a successful unload even though the derived terrain state could be invalid.

A second failure mode was coupled to this: `_rebind_terrain_patches()` cleared every transition collider and the published descriptor map for all Binder errors, including preflight errors that occur before the Binder mutates any live patch edge. A rejected candidate could therefore destroy a previously valid seam.

## Changes

- Keep the departing chunk root, mineral registrations, and controller ownership alive until the remaining terrain set has rebound successfully.
- Temporarily remove only the departing chunk's patch map while preparing the remaining terrain set. The old root remains parented and its Nodes remain valid for reciprocal-edge cleanup and rollback.
- If Binder preflight or collider synchronization fails, restore the patch map and object-registry snapshot, attempt a full adjacency refresh, and return `false`.
- Unregister minerals and release the root only after adjacency succeeds. If mineral unload fails, restore the map and object snapshot, then rebuild the original adjacency.
- Add `has_pending_terrain_adjacency_recovery()` and a fail-closed readiness gate. Further loads/unloads are rejected while recovery is pending; a successful explicit full refresh clears the barrier.
- Binder results now report `live_state_mutated`. Preflight failures explicitly report `false`; failures after live edge mutation report `true`. The Controller only clears published colliders/descriptors when the Binder says live state was mutated and skips full refresh for a non-mutating preflight rejection.

## Files

- `systems/MineralChunkController.gd`
- `systems/SurfaceTerrainAdjacencyBinder.gd`
- `tests/mineral_chunk_controller_test.gd`
- `tests/surface_terrain_adjacency_binder_test.gd`
- `docs/MINERAL_CHUNK_CONTROLLER_UNLOAD_ADJACENCY_FAILURE_ATOMICITY_M0_3_25.md`

## Dependencies and import

Uses the existing `MineralVeinRegistry`, `MineralChunkLifecycleAdapter`, `WorldObjectStateRegistry`, `SurfaceTerrainAdjacencyBinder`, `SurfaceTerrainTransitionColliderManager`, and `SurfaceTerrainPatch` APIs. No new plugin, package, scene import, or project setting is required. The new recovery flag is runtime-only and is not serialized.

## Validation

- Focused Controller regression: `godot --headless --path . --script res://tests/mineral_chunk_controller_test.gd`
- Binder contract regression: `godot --headless --path . --script res://tests/surface_terrain_adjacency_binder_test.gd`
- Full project validation: existing `.github/workflows/godot-validation.yml` Godot 4.3 headless gate.

The new regression creates two adjacent unequal-height terrain chunks, injects an invalid edge profile on the remaining patch so Binder rejects unload during preflight, and verifies that the departing root, both reciprocal edge policies, the exact transition collider instance, published descriptors, and object-registry snapshot remain intact. It then verifies that subsequent unloads fail closed until the patch is repaired and a full refresh succeeds.

## Limitations

- The production Binder still performs a full rebuild; this change fixes failure atomicity, not incremental adjacency performance.
- A permanent failure after live edge mutation still requires a successful full refresh before chunk operations resume.
- Object/Resource references inside world-object payloads retain their existing ownership semantics.
- CI is headless and does not establish rendered GPU, FPS, or target-device behavior.

## Next step

After exact-head Godot 4.3 validation and independent review, evaluate the existing Director's synchronous and asynchronous failure reports against the new recovery barrier. Keep the full Binder rebuild as the recovery and correctness oracle while the separate incremental-adjacency stack remains unmerged.
