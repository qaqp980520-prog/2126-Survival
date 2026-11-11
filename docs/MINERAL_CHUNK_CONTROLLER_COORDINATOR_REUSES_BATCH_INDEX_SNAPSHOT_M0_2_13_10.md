# Mineral Chunk Controller Coordinator Reuses Batch Index Snapshot — M0.2.13.10

## Purpose

Reuse the exact detached pre-delta Patch map captured by MineralChunkController for add/remove/restore classification when the same batch enters SurfaceTerrainAdjacencyCoordinator.execute_delta().

Before this change, one incremental batch could resolve the committed Index WeakRefs into a full Patch map in the Controller and then resolve the same committed map again inside the Coordinator. Both maps represented the same immutable base generation.

The Controller now passes its batch baseline map and the generation at which it was captured to the Coordinator. The Coordinator validates that the supplied generation equals the new plan's base_generation before using the map. Direct Coordinator callers that do not supply a batch snapshot retain the original Index-read path.

## Changes

- systems/MineralChunkController.gd
  - Capture _terrain_adjacency_batch_original_patch_map_generation together with the detached map.
  - Reuse the cached map for delta classification and the Coordinator handoff.
  - Reject an Index generation change during the batch and route the failed incremental attempt through the existing authoritative recovery/rebind path.
  - Reset the generation marker with the other batch-scoped state.
- systems/SurfaceTerrainAdjacencyCoordinator.gd
  - Add optional old_patches_snapshot and old_patches_snapshot_generation parameters to execute_delta().
  - Validate the supplied snapshot generation against the Index plan's base_generation.
  - Skip the redundant full get_patches_by_stable_id() resolution when a validated batch snapshot is supplied.
  - Preserve the existing fallback read for direct callers.
- tests/mineral_chunk_controller_test.gd
  - Add a counting Index subclass and assert that a batch with multiple additions, and a removal followed by restore, resolves the full committed Patch map exactly once including Coordinator finalization.
- tests/surface_terrain_adjacency_coordinator_test.gd
  - Add a stale-generation snapshot regression proving that the Coordinator aborts the uncommitted plan without changing Index, Patch adjacency, or Collider resources.

## Dependencies and import

- Godot 4.3.
- MineralChunkController.gd.
- SurfaceTerrainAdjacencyCoordinator.gd.
- SurfaceTerrainAdjacencyIndex.gd.
- SurfaceTerrainAdjacencyScopedTransaction.gd.
- SurfaceTerrainTransitionColliderManager.gd.
- Existing SurfaceTerrainPatch.gd and Controller integration test fixtures.

No external packages, autoloads, Project Settings, scene wiring, save-schema changes, or new runtime assets. Open the repository root or run the existing GitHub Actions Godot 4.3 validation workflows; the Full Gate performs the deterministic root import first.

## Correctness contract

- The Controller snapshot is a detached map of strong Patch references resolved from the committed Index at one generation.
- The Index is treated as immutable during a Controller adjacency batch.
- The captured generation must still equal the Index generation before the Controller begins the incremental transaction.
- The Coordinator independently checks the supplied generation against the delta plan's base_generation.
- A mismatch aborts the uncommitted plan before reservation/publication; it must not apply scoped Patch state or Collider resources.
- Direct Coordinator calls without a supplied snapshot continue to resolve the old Patch map from the Index.
- Failed or unavailable Controller snapshots continue to use the existing fail-closed Full Binder recovery path.

## Validation

Exact-head validation is required for this PR:

1. Mineral Chunk Controller integration regression.
2. Surface Terrain Coordinator transaction regression, including stale-generation rejection.
3. Full Godot 4.3 compatibility gate.
4. Production Chunk Benchmark and artifact reconciliation.

No test pass is claimed in this document until the exact child HEAD's workflows complete. Local Godot is not available in the current development environment; engine tests run on GitHub Actions with Godot 4.3.

Headless CI does not validate rendered FPS, GPU behavior, iPhone performance, physical-device memory, touch input, or PhysicsServer internal allocation failures.

## Next steps

- Verify exact-head focused Controller and Coordinator suites.
- Complete the exact-head Full Godot 4.3 Gate and inspect the transaction rollback and clean-workspace steps.
- Confirm the Production Benchmark remains free of Engine/SCRIPT errors and that sample counts reconcile.
- Keep the child PR Draft/unmerged until the parent stack is independently reviewed; do not merge it independently of its parent or merge main.
