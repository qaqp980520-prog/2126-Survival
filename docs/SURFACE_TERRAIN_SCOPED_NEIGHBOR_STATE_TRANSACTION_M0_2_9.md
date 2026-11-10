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
5. After Apply, pass the returned `endpoint_expectations` to `SurfaceTerrainTransitionColliderManager.accept_scoped_neighbor_state_apply(manager_transaction_id, endpoint_expectations)`. Partial collider Prepare snapshots all four shared-transition sides of every Patch in its affected old/candidate edge set. The handshake verifies exact live neighbor references and rebases only the explicitly changed side flags; transforms, world state, and every unlisted side flag remain anchored to Prepare.
6. If the downstream collider commit succeeds, call Finalize to flush each affected Patch segmentation once and release temporary strong Node references.
7. If the downstream collider commit fails, call Rollback. It clears candidate pairs, restores old reciprocal Node bindings, restores the exact old shared-transition flags, and then closes the segmentation batches.
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
9. The future coordinator must commit the index generation and collider resource map under one explicit cross-participant protocol. A simple sequential commit is not yet proven atomic: if the index generation commit fails after collider publication, the coordinator must restore the previous collider map as well as Rollback the scoped neighbor transaction.
10. Only after every participant succeeds may the coordinator detach and free retiring Chunk roots.

The coordinator itself is not wired in this PR. Index generation commit and post-collider failure recovery still need one owner in the future Controller integration. Do not call the legacy full mutating Binder before this scoped transaction; it clears neighbor state outside the affected closure.

## Files and dependencies

- `systems/SurfaceTerrainAdjacencyScopedTransaction.gd` — reversible scoped transaction coordinator.
- `systems/SurfaceTerrainTransitionColliderManager.gd` — explicit handshake to accept only the scoped endpoint/flag changes before collider Commit.
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
- Old or replacement Patch world-state/transform/neighbor changes between Prepare and Apply are rejected as stale before any neighbor mutation.

## Limits

- This PR adds a reversible scoped neighbor-state participant; it does not wire the production MineralChunkController or SurfaceWorld coordinator.
- The candidate descriptor builder still produces the complete supplied candidate descriptor map; spatial-index delta-to-scoped projection wiring remains in the Controller.
- The existing partial collider manager still resolves candidate corner reports from the complete candidate set.
- This participant restores neighbor links and shared-transition flags only. It does not undo world-object state or transform changes made before Prepare. For a Stable ID whose terrain state/transform changes, the coordinator must stage a separate candidate Patch Node or pair this participant with a separate reversible world-state participant; do not mutate the committed old Patch in place and expect this class to reconstruct its prior state.
- PhysicsServer-internal allocation failure injection, GPU/Rendered FPS, iPhone, target-device memory, and touch QA are not covered.
- Full Binder and full collider rebuild remain the compatibility/fallback oracle.
- No main merge is included.

## Next

1. Run this focused Godot 4.3 workflow and the full compatibility gate on the exact PR HEAD.
2. Add a coordinator-level regression that prepares Index, scoped neighbor state, and partial collider participants together, then injects downstream collider commit failure.
3. Prove the Index generation, Patch neighbor state, and collider resource maps all remain on the old generation after abort.
4. Wire the coordinator into MineralChunkController only after the cross-participant rollback test passes.
5. Profile a non-zero Transition Collider workload; the existing Radius-8 benchmark has zero colliders and cannot prove partial-collider runtime performance.


## Failure-recovery retention hardening — Run 195

A code audit found that the Apply failure helper previously cleared `_pending` even when restoring old Patch state or closing segmentation batches failed. That discarded the only retained strong Patch references and removed the transaction state needed for recovery.

The transaction now:
- Retains `_pending`, snapshots, old/candidate pairs, and strong Patch references whenever recovery is incomplete.
- Marks the transaction with `recovery_required` and returns `pending_retained=true`.
- Removes each successfully ended segmentation batch from the pending retry list, so a later retry never decrements the same batch depth twice.
- Uses the same retry-safe batch close helper from Rollback and Finalize. A partial close can be retried without re-ending batches that already closed.
- Refuses Finalize while `recovery_required` is set, so a caller cannot accidentally discard an incomplete rollback by taking the success path.
- Clears pending references only after restoration and all remaining batch closures succeed.

A new Godot 4.3 regression uses a fault-injecting SurfaceTerrainPatch subclass to make Apply fail, make the first rollback attempt fail, and make one Patch's segmentation-batch close fail transiently. It verifies that the transaction remains pending, already-closed batches are removed, premature Finalize is rejected, and a second Rollback restores the exact original reciprocal Patch Node references and closes only the remaining batch before releasing pending state.

This is a fail-closed recovery guarantee; it does not claim that a permanently invalid/freed Patch can be repaired automatically. If a required batch endpoint becomes invalid, the transaction intentionally remains retained and reports the unresolved batch instead of silently discarding recovery state.


## Finalize-recovery guard — Run 195 follow-up

A second cross-participant safety check covers the case where the collider manager has already committed but Patch segmentation batch closure fails during `finalize()`. The transaction marks `finalize_pending`; Rollback and Abort now refuse with `finalize_recovery_required` instead of reverting neighbor links while the collider resource map is already on the new generation. The caller can retry Finalize, which closes only the remaining batches and then releases pending references.

The new regression injects one batch-close failure after Apply, verifies that the other Patch batches close and are removed, verifies both Rollback and Abort are rejected while finalization is pending, then retries Finalize and checks the candidate reciprocal Node bindings remain committed.
