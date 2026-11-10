# Surface Terrain Coordinator — Retryable Collider Abort M0.2.10.3

## Status

Implementation and a focused fault-injection regression are committed on a child branch of PR #304. Exact-head CI must complete before this change is treated as validated. No merge is performed.

## Exact branch and validation status

- Child PR: [#305](https://github.com/qaqp980520-prog/2126-Survival/pull/305), based on PR #304.
- Exact branch HEAD before this status commit: `179397be15e03fbe809a8838092d834de9a5bb20`.
- The focused coordinator workflow and the full Godot 4.3 gate must be checked on the final synchronized HEAD. No pass is claimed in this document until those exact-head runs complete.

## Problem

The three-participant coordinator previously called `abort_sync_transitions()` but ignored its result. On a downstream Collider Commit failure, it could continue to roll back the scoped Patch neighbor state and the published Index even when the Collider Manager still owned staged replacement bodies.

That could leave the manager holding an orphaned pending transaction while the Index and Patch participants had already returned to the old generation. The coordinator also cleared its own recovery state, so there was no retry path for the failed Collider cleanup.

## Changes

- Add `_abort_collider_transaction()` as an idempotent cleanup adapter.
- Treat the production manager's `no_pending_transaction` result as already-aborted success. The production Commit implementation may have performed its own internal abort before returning a failure.
- Preserve all participant snapshots when Collider abort returns any other failure.
- Add explicit coordinator pending stages:
  - `abort_collider`: staged Collider cleanup must succeed before aborting the un-published Index plan.
  - `rollback`: staged Collider cleanup must succeed before rolling back scoped Patch state and then aborting/rolling back the Index.
  - `index_abort`: retry only the Index plan abort after Collider cleanup has succeeded.
- In the rollback retry path, stop immediately if Collider abort still fails. Do not mutate Patch or Index participants ahead of resource cleanup.
- Use the same checked cleanup path for closure mismatch, scoped Prepare failure, scoped Apply failure without retained scoped state, Collider acceptance failure, Index publication failure, and Collider Commit failure.
- Keep the existing Finalize-only retry path unchanged after a successful Collider Commit.

## Files

- `systems/SurfaceTerrainAdjacencyCoordinator.gd`
- `tests/surface_terrain_adjacency_coordinator_test.gd`
- `docs/SURFACE_TERRAIN_COORDINATOR_ABORT_RETRY_M0_2_10_3.md`

## Regression

A fault-injecting production-manager subclass:
1. Allows Prepare to stage the replacement resources.
2. Fails Collider Commit once without clearing the pending manager transaction.
3. Fails Collider Abort twice.
4. Verifies that the coordinator retains the published Index candidate, scoped Patch candidate, old active Collider body, and pending transaction.
5. Verifies that the first retry stops at Collider Abort and does not roll back Patch or Index state.
6. Allows the second retry to abort staged resources, then verifies exact old Patch Node identities, Index mapping, old Collider body identity, monotonic generation, and reservation release.

The test also preserves the production manager's self-abort contract: `no_pending_transaction` is accepted as idempotent cleanup after a production Commit failure has already aborted internally.

## Dependencies and import

- `SurfaceTerrainAdjacencyCoordinator.gd`
- `SurfaceTerrainAdjacencyIndex.gd`
- `SurfaceTerrainAdjacencyScopedTransaction.gd`
- `SurfaceTerrainTransitionColliderManager.gd`
- `SurfaceTerrainPatch.gd`

No new autoload, project setting, or asset import is required. The focused test is invoked through the existing Surface Terrain Adjacency Coordinator GitHub Actions workflow using the repository's Godot 4.3 headless test setup.

## Limitations

- This is coordinator recovery hardening; it does not wire the coordinator into `MineralChunkController` or `MineralGridStreamingDirector`.
- The candidate descriptor/geometry path still evaluates the complete candidate Patch/Descriptor set before the partial resource filter.
- No PhysicsServer-internal allocation failure, rendered/GPU, iPhone, target-device memory, or touch QA is claimed.
- Keep the PR Draft and unmerged until exact-head focused/full CI and the parent review chain are complete.

## Next

Complete exact-head focused and full Godot 4.3 gates. Then continue the production integration work: bind the coordinator to the MineralChunkController batch boundary, preserve pending Chunk roots until `finalized=true`, and add a real streaming-window rollback regression before enabling it for normal world streaming.
