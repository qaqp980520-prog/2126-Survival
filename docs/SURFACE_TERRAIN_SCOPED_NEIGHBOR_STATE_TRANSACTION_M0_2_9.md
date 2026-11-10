# Surface Terrain Scoped Neighbor-State Transaction M0.2.9

## Purpose

Provide a reversible, Patch-local neighbor-state transaction that can be coordinated with the existing partial collider manager. The transaction changes only the edge endpoints in an exact scoped projection of an adjacency-index delta; unrelated Patch neighbor references and segmentation state remain untouched.

This is the missing mutation boundary between the non-mutating M0.2.8 candidate descriptor builder and the M0.2.7 partial collider resource transaction.

## API

File: `systems/SurfaceTerrainAdjacencyScopedTransaction.gd`

Class: `SurfaceTerrainAdjacencyScopedTransaction`

Public methods:

- `prepare(old_descriptors, candidate_descriptors, old_patches_by_stable_id, candidate_patches_by_stable_id, changed_edge_keys)`
- `apply(transaction_id)`
- `finalize(transaction_id)`
- `rollback(transaction_id)`
- `abort(transaction_id)`
- `has_pending_transaction()`

The descriptor dictionaries are scoped projections, not complete world descriptor maps. The intended source is the `old_descriptors`, `new_descriptors`, and `affected_edge_keys` returned by `SurfaceTerrainAdjacencyIndex.plan_delta()`.

The changed-edge list must exactly equal the union of the scoped old/new descriptor keys. This rejects omitted seeds and accidental whole-world projections before any live Patch state is mutated.

## Transaction contract

1. Prepare validates canonical Stable IDs, opposite cardinal sides, live old/candidate Patch references, one edge per Patch-side endpoint, exact changed-key coverage, reciprocal old neighbor bindings, and clean replacement endpoints.
2. Prepare captures the old endpoint neighbor Node, shared-transition flag, global transform, and world-object state. Replacement candidate endpoints are also snapshotted as clean/unbound.
3. Apply revalidates snapshots immediately before mutation, opens segmentation batches only for the affected endpoint Patches, clears old scoped pairs, and binds candidate pairs reciprocally.
4. Segmentation batches remain open after Apply. The caller can now commit the matching partial collider-manager transaction; collider activation updates are coalesced into the same Patch refresh.
5. If the downstream collider commit succeeds, call Finalize to flush each affected Patch segmentation once and release temporary strong Node references.
6. If the downstream collider commit fails, call Rollback. It clears candidate pairs, restores old reciprocal Node bindings, restores the exact old shared-transition flags, and then closes the segmentation batches.
7. Abort is safe before Apply; after Apply it delegates to Rollback.

The transaction deliberately holds strong Patch references only while pending so an old Chunk cannot disappear between Prepare and downstream Commit. Finalize, successful Rollback, or Abort releases those references.

## Intended coordinator order

The future Chunk/World coordinator should:

1. Keep retiring Chunk roots attached while preparing all participants.
2. Call `SurfaceTerrainAdjacencyIndex.plan_delta()`.
3. Build the complete non-mutating candidate descriptor set with M0.2.8.
4. Prepare `SurfaceTerrainTransitionColliderManager.prepare_partial_sync_transitions()` using the complete candidate descriptor map and the delta's `affected_edge_keys`.
5. Prepare this scoped neighbor-state transaction using the delta's old/new descriptor projections and old/candidate Stable-ID-to-Patch maps.
6. Apply the scoped neighbor-state transaction.
7. Commit the collider-manager transaction.
8. On collider failure, Rollback the scoped neighbor-state transaction and abort any still-pending participants.
9. On success, Finalize the scoped neighbor-state transaction and commit the index snapshot while the coordinator's single-threaded critical section is still held.
10. Only after every participant succeeds may the coordinator detach and free retiring Chunk roots.

The coordinator itself is not wired in this PR. In particular, index generation commit and post-collider failure recovery still need one owner in the future Controller integration. Do not call the legacy full mutating Binder before this scoped transaction; it clears neighbor state outside the affected closure.

## Files and dependencies

- `systems/SurfaceTerrainAdjacencyScopedTransaction.gd` — reversible scoped transaction coordinator.
- `tests/surface_terrain_adjacency_scoped_transaction_test.gd` — real SurfaceTerrainPatch replacement, batching, rollback, and under-seed regressions.
- `.github/workflows/surface-terrain-adjacency-scoped-transaction-validation.yml` — Godot 4.3 focused validation.
- `docs/SURFACE_TERRAIN_SCOPED_NEIGHBOR_STATE_TRANSACTION_M0_2_9.md` — this contract.

Dependencies:

- `SurfaceTerrainAdjacencyIndex.gd` delta summary contract.
- `SurfaceTerrainAdjacencyBinder.gd` descriptor schema.
- `SurfaceTerrainTransitionDescriptor.gd` canonical Stable-ID and side fields.
- `SurfaceTerrainPatch.gd` reciprocal bind/clear, shared-transition state, world-state snapshot, and nested segmentation batch APIs.
- The existing partial collider manager Prepare/Commit/Abort API from M0.2.7.

## Import and test

Run from repository root with Godot 4.3:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/surface_terrain_adjacency_scoped_transaction_test.gd`

Focused workflow: `.github/workflows/surface-terrain-adjacency-scoped-transaction-validation.yml`.

## Regression coverage

- Prepare is non-mutating and leaves old reciprocal references and shared-transition flags unchanged.
- Apply replaces only the affected Stable-ID endpoint pair and preserves an unrelated pair by exact Node identity.
- Apply keeps segmentation refresh deferred until the downstream collider participant is committed and Finalize is called.
- Finalize refreshes each affected Patch once and does not refresh unrelated Patches.
- Rollback restores the exact old neighbor Node instances and shared-transition flags after a simulated downstream collider failure.
- An under-seeded old/new descriptor projection is rejected before creating a pending transaction or changing live Patch state.

## Limits

- This PR adds a reversible scoped neighbor-state participant; it does not wire the production MineralChunkController or SurfaceWorld coordinator.
- The candidate descriptor builder still produces the complete supplied candidate descriptor map; spatial-index delta-to-scoped projection wiring remains in the Controller.
- The existing partial collider manager still resolves candidate corner reports from the complete candidate set.
- PhysicsServer-internal allocation failure injection, GPU/Rendered FPS, iPhone, target-device memory, and touch QA are not covered.
- Full Binder and full collider rebuild remain the compatibility/fallback oracle.
- No main merge is included.

## Next

1. Run this focused Godot 4.3 workflow and the full compatibility gate on the exact PR HEAD.
2. Add a coordinator-level regression that prepares Index, scoped neighbor state, and partial collider participants together, then injects downstream collider commit failure.
3. Prove the Index generation, Patch neighbor state, and collider resource maps all remain on the old generation after abort.
4. Wire the coordinator into MineralChunkController only after the cross-participant rollback test passes.
5. Profile a non-zero Transition Collider workload; the existing Radius-8 benchmark has zero colliders and cannot prove partial-collider runtime performance.
