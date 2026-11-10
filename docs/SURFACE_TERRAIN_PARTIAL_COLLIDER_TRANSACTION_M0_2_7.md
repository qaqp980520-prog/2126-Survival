# Surface Terrain Partial Collider Transaction M0.2.7

## Purpose

Add a live, manager-owned partial collider update path that consumes the validated Edge↔Junction affected-component closure and Preserve/Stage/Retire plan. The existing full `sync_transitions()` path remains unchanged and is the fallback/correctness path.

## Files

- `systems/SurfaceTerrainTransitionColliderManager.gd`
- `tests/surface_terrain_collider_partial_transaction_test.gd`
- `.github/workflows/surface-terrain-collider-partial-transaction-validation.yml`
- `docs/SURFACE_TERRAIN_PARTIAL_COLLIDER_TRANSACTION_M0_2_7.md`

## API

`prepare_partial_sync_transitions(descriptors, patches_by_stable_id, changed_edge_keys, profile_enabled=false)`

- `descriptors` must describe the complete candidate transition topology, not only the changed edges.
- `patches_by_stable_id` must contain every candidate patch referenced by candidate reports.
- `changed_edge_keys` must include every directly changed, added, or removed transition edge seed.
- The method computes the old+candidate Edge↔Junction closure, runs the preserve planner, and stages only resources that must be replaced inside that closure.
- Existing resources outside the closure are retained by exact Node identity.
- A candidate change outside the supplied closure fails closed before any resource is staged.
- `prepare_sync_transitions()` and `sync_transitions()` retain their full-rebuild compatibility behavior.

## Transaction behavior

1. Build and validate the complete candidate geometry and resolver report set.
2. Derive the affected closure from committed reports plus candidate reports.
3. Build old and candidate Edge/Corner-Cap resource records.
4. Reject incomplete seed lists or stale resources outside the closure.
5. Preserve exact unchanged bodies, stage only changed bodies, and omit retired keys from the merged candidate maps.
6. Snapshot patch endpoints in the affected edge closure while retaining a full committed resource-map snapshot to prevent lost updates.
7. Reuse the existing Prepare/Commit/Abort protocol to publish replacements and retire old resources atomically.

## Dependencies

- PR #300 exact parent HEAD: `b999a76b26d35dc55446290bd607fce0fb38df66`.
- `SurfaceTerrainAffectedComponentPlanner.gd`.
- `SurfaceTerrainColliderPreservePlanner.gd`.
- `SurfaceTerrainCornerConflictResolver.gd`.
- `SurfaceTerrainPatch.gd` shared-transition activation API.
- `SurfaceTerrainTransitionDescriptor.gd` descriptor contract.

## Import and test

Godot 4.3 repository root:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/surface_terrain_collider_partial_transaction_test.gd`

Focused workflow: `.github/workflows/surface-terrain-collider-partial-transaction-validation.yml`.

## Regression coverage

- Replace one edge while preserving an unrelated committed edge by exact Node identity.
- Remove one edge while preserving an unrelated committed edge and clearing only the removed edge's patch-side flags.
- Change two disconnected edges while supplying only one seed; partial prepare must fail closed and leave both committed resources untouched.

## Limits

- This is a collider-resource partial update, not yet an incremental adjacency Binder. Candidate geometry and corner resolution are still computed from the complete descriptor set.
- Callers must not run the full mutating `SurfaceTerrainAdjacencyBinder.bind_patches()` immediately before this API, because that full bind clears shared-transition flags globally. A non-mutating candidate descriptor build and scoped adjacency update are the next integration step.
- No PhysicsServer-internal allocation failure injection is added.
- No GPU/Rendered FPS, iPhone, target-device memory, or touch QA is claimed.
- No Controller wiring and no main merge.
- This PR is stacked on PR #300 and remains Draft pending exact-head CI and independent parent-stack review.

## Next

1. Complete the focused partial-transaction workflow.
2. Complete the full Godot 4.3 compatibility gate on this exact HEAD.
3. Add partial Corner-Cap replacement parity and scoped adjacency descriptor generation.
4. Integrate the API into the world/Chunk Controller only after the scoped Binder contract is validated.
5. Keep full rebuild as the fallback until live parity is established.
