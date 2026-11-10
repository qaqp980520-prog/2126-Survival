# Surface Terrain Collider Collision-Mask Invariants M0.2.6.2

## Purpose

Close a gap in the M0.2.6.1 transaction snapshot hardening: staged and reusable collider readiness checked collision_layer but did not require the canonical collision_mask == 0, even though both edge and corner-cap staging explicitly initialize layer and mask to zero and commit only publishes the layer.

## Files

- systems/SurfaceTerrainTransitionColliderManager.gd
- tests/surface_terrain_collider_transaction_test.gd
- .github/workflows/surface-terrain-collider-transaction-validation.yml (existing workflow; triggered by manager/test path filters)
- docs/SURFACE_TERRAIN_COLLIDER_COLLISION_MASK_INVARIANTS_M0_2_6_2.md

## Canonical resource contract

- Newly staged Edge and Corner Cap bodies must remain attached to the manager, valid, not queued for deletion, collision_layer == 0, and collision_mask == 0 until publication.
- Published managed Edge and Corner Cap bodies use collision_layer == COLLISION_LAYER and collision_mask == 0.
- A previously committed body whose mask is nonzero before Prepare is stale and must be staged for replacement rather than reused.
- Abort/retire cleanup clears both layer and mask before queueing the body for deletion.

## Implementation

- Extend _is_staged_body_ready() to require both collision layer and mask to be zero.
- Extend _is_reusable_managed_body() to require the canonical active layer and zero mask.
- Reset both collision layer and mask in staged cleanup and old-resource retirement for Edge and Corner Cap bodies.

## Regression coverage

1. Mutate a staged Edge collision mask between Prepare and Commit: Commit rejects before patch activation; cleanup clears both fields; the committed Edge remains the exact old object.
2. Mutate a staged Corner Cap collision mask between Prepare and Commit: same fail-closed behavior; all old caps remain unchanged.
3. Corrupt a committed Edge mask before Prepare: planner stages a replacement, publishes a canonical body, and retires the stale body.
4. Corrupt one committed Corner Cap mask before Prepare: exactly one cap is replaced; the other three valid caps retain exact Node identity.

## Dependencies

- Godot 4.3.
- Existing SurfaceTerrainTransitionColliderManager Prepare/Commit/Abort API from PR #299.
- Existing transactional test fixtures and real production patch/binder scripts.

## Import and test

From repository root:

- godot --headless --path . --editor --quit
- godot --headless --path . --script res://tests/surface_terrain_collider_transaction_test.gd

Focused CI is defined by .github/workflows/surface-terrain-collider-transaction-validation.yml. The full project Godot 4.3 compatibility gate is also required on the exact PR HEAD.

## Status and limitations

- Implementation and regression source are committed on a child branch based on PR #299's exact HEAD.
- Runtime execution is pending the new exact-head GitHub Actions runs; no pass is claimed before those runs complete.
- No PhysicsServer-internal allocation failure is injected; these regressions mutate real StaticBody3D collision properties in the live manager fixture.
- No GPU/Rendered FPS, iPhone, target-device memory, or touch QA is claimed.
- The parent PR #299 remains unmerged; this PR must remain Draft and must not bypass the parent review chain.

## Next

After exact-head focused and full Godot gates pass and the parent stack receives independent review, continue integrating the affected Edge↔Junction closure and preserve/stage/retire planner into the live partial update path while retaining full rebuild as the correctness oracle.
