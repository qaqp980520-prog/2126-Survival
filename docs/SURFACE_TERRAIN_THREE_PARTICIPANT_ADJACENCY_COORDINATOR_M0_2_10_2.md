# Surface Terrain Three-Participant Adjacency Coordinator — M0.2.10.2

## Status

Coordinator implementation and focused Godot 4.3 regression are committed on the child branch of PR #303. Exact-head CI is pending. No pass is claimed until the workflow completes on the final PR HEAD.

## Goal

Coordinate one terrain topology delta across:

1. SurfaceTerrainAdjacencyIndex.
2. SurfaceTerrainAdjacencyScopedTransaction.
3. SurfaceTerrainTransitionColliderManager.

The coordinator keeps removed Patch/Chunk roots alive until all participants have finalized. It also retains the Index's old generation snapshot while the Collider and scoped Patch participants publish, so a downstream failure can restore the Index without decreasing its monotonic generation counter.

## Files

- systems/SurfaceTerrainAdjacencyCoordinator.gd — participant binding, plan/reserve, closure parity, scoped Patch apply, reversible Index publication, partial Collider commit, finalize retry, and rollback retry.
- systems/SurfaceTerrainAdjacencyIndex.gd — reversible publish/finalize/rollback APIs, candidate Patch/descriptor projections, and pending-plan diagnostics.
- systems/SurfaceTerrainTransitionColliderManager.gd — partial-prepare result now exposes exact affected Edge and Junction keys for pre-publication parity checks.
- tests/surface_terrain_adjacency_coordinator_test.gd — successful three-participant publication, injected Collider commit failure with full rollback, transient scoped Finalize failure/retry, and Index-only isolated-Patch delta.
- This document records the transaction contract and remaining integration boundary.

## Transaction sequence

For a delta with affected Edges:

1. Index plan_delta builds candidate entries, descriptors, persistent Corner/Junction graph, and old/new union closure.
2. Index reserve_delta reserves the committed generation.
3. Coordinator resolves the current and candidate Patch maps and the full candidate descriptor cache from the prepared Index plan.
4. Collider Manager prepare_partial_sync_transitions stages the partial resource plan. Its reported Edge/Junction closure is compared exactly with the Index closure before Patch state is mutated.
5. Scoped Neighbor-State Transaction prepares from old/new closure descriptor projections and the union of their Edge keys.
6. Scoped apply updates reciprocal Patch neighbor state while retaining snapshots and segmentation batches.
7. Collider Manager accepts the scoped endpoint expectations.
8. Index publish_delta publishes the candidate maps but retains the complete old snapshot and generation reservation.
9. Collider Manager commit_sync_transitions publishes the partial resource set.
10. Scoped finalize closes the segmentation batches.
11. Index finalize_delta discards the retained rollback snapshot and releases the generation reservation.
12. Only after execute_delta returns finalized=true may the caller retire old Chunk roots.

A Patch addition/removal with no adjacent Edge changes uses an Index-only publish/finalize path and does not invoke the Patch or Collider participants.

## Reversible Index publication

New Index APIs:

- publish_delta(plan_id): publishes the candidate generation while retaining the previous entries, buckets, descriptor cache, Corner reports, and graph maps.
- finalize_delta(plan_id): discards the previous snapshot and releases the reservation after external participants have finalized.
- rollback_published_delta(plan_id): restores the exact previous maps and advances generation monotonically by one more step. Competing plans from the old generation remain stale.
- commit_delta(plan_id): compatibility wrapper that publishes and immediately finalizes for callers without external participants.
- get_patches_by_stable_id(), get_plan_patches_by_stable_id(), and get_plan_edge_descriptors() expose validated current/candidate projections without leaking WeakRef-backed internal records.
- has_pending_plan() and get_reserved_plan_id() allow idempotent recovery after a failed publish has already discarded its plan.

## Recovery behavior

- Failure before scoped apply: abort the prepared Collider and Index plan.
- Scoped apply failure with retained recovery state: retain coordinator state and retry scoped rollback before releasing the Index reservation.
- Collider acceptance or Index publication failure: abort the staged Collider, roll back scoped Patch state, then abort the Index plan.
- Collider commit failure: abort any still-pending Collider transaction, roll back scoped Patch state, then call rollback_published_delta.
- Scoped Finalize failure after Collider commit: do not roll back already-committed resources. Retain the published Index generation and retry only scoped Finalize, then Index Finalize.
- Index Finalize failure after the other participants have finalized: retain an Index-finalize-only retry state.
- Post-commit closure mismatch is fail-closed and requires manual recovery; it is not automatically finalized.

The coordinator never retries a participant commit that has already succeeded.

## Regression coverage

The new Godot test fixture starts from two adjacent real SurfaceTerrainPatch instances and a committed transition body.

- Successful path: replace one Patch with a same-Stable-ID Node at a height that removes the transition; verify Index mapping, reciprocal Patch neighbor state, Collider retirement, old body release, and reservation release.
- Collider failure path: inject a one-shot Collider commit failure after Index publication; verify the exact old Index Patch mapping, old reciprocal Patch links, old active Collider body, monotonic Index generation, and reservation release are restored.
- Finalize retry path: inject one transient end_collision_segmentation_batch failure; verify the Index remains published/reserved, the Collider is not recommitted, and retry_pending completes only the remaining finalization.
- Index-only path: add an isolated Patch with no adjacent Edge; verify the Index publishes while existing Patch and Collider state remains untouched.

## Dependencies and import

- SurfaceTerrainAdjacencyIndex.gd
- SurfaceTerrainAdjacencyScopedTransaction.gd
- SurfaceTerrainTransitionColliderManager.gd
- SurfaceTerrainAdjacencyBinder.gd
- SurfaceTerrainTransitionDescriptor.gd
- SurfaceTerrainCornerConflictResolver.gd
- SurfaceTerrainAffectedComponentPlanner.gd
- SurfaceTerrainPatch.gd

No new autoload or project setting is required. Instantiate the coordinator through preload("res://systems/SurfaceTerrainAdjacencyCoordinator.gd"), call bind_participants(index, scoped_transaction, collider_manager), then call execute_delta(remove_stable_ids, additions, profile_enabled). Keep removed Chunk roots alive until finalized=true. If execute_delta returns pending_retained=true, call retry_pending() and do not retire roots.

## Limitations

- MineralChunkController.end_terrain_adjacency_batch() is not yet wired to this coordinator; production world streaming still uses the existing full Binder/full Collider sync path.
- Collider Manager still resolves and constructs candidate geometry from the full candidate descriptor set before its partial preserve/stage/retire filter. This PR coordinates the participants but does not yet eliminate that full candidate geometry scan.
- The coordinator uses a single synchronous call path. Threaded/async world-stream scheduling and cancellation ownership are not integrated.
- The failure-injection test uses a manager subclass to fail commit before the real manager publishes. It does not simulate a PhysicsServer allocation failure inside Godot.
- No rendered/GPU, iPhone, target-device memory, or touch QA is claimed.

## Next

Integrate the coordinator into MineralChunkController and MineralGridStreamingDirector while preserving their existing outer batch rollback. Then add real Manager fault injection around body creation/activation and test a multi-Junction partial update with both old and candidate topology. After that, optimize Collider candidate geometry generation so only closure Edge/Corner resources are constructed.
