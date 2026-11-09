# Surface Terrain Collider Transaction API M0.2.6

## Purpose

Split the production transition-collider manager's existing synchronous rebuild into an explicit prepare/commit/abort boundary without changing the existing caller contract. This is the first live-manager transaction API required before the detached affected-component and preserve-set planners can safely mutate only a scoped resource set.

## Version and branch

- Version: M0.2.6 — staged collider prepare/commit/abort transaction.
- Parent: PR #298 exact HEAD `056b35d959aa711e8531609a45bcb4ed324af035`.
- Branch: `feat/terrain-collider-prepare-commit-abort-2026-11-10`.
- Runtime manager: `systems/SurfaceTerrainTransitionColliderManager.gd`.
- Focused test: `tests/surface_terrain_collider_transaction_test.gd`.
- Fixtures:
  - `tests/fixtures/transactional_surface_terrain_collider_manager.gd`
  - `tests/fixtures/transactional_surface_terrain_patch.gd`

## API

- `prepare_sync_transitions(descriptors, patches_by_stable_id, profile_enabled=false)`
  - Validates candidate geometry and corner policy.
  - Stages replacement edge/cap bodies with collision layer 0.
  - Captures committed resource-map identities and patch transform/world-state/side-state snapshots.
  - Returns an opaque integer `transaction_id` and staged/reused counts.
  - Does not activate patch sides, retire committed resources, or publish new maps.
  - Only one transaction may be pending per manager.

- `commit_sync_transitions(transaction_id)`
  - Requires the matching pending transaction.
  - Fails closed if committed maps, patch transforms, world-object states, or shared-transition flags changed after prepare.
  - Activates candidate patch sides, restores captured side states if activation fails, then publishes replacement collision layers and retires superseded resources.
  - Publishes the new edge/cap maps only after activation and staged-resource validation succeed.

- `abort_sync_transitions(transaction_id)`
  - Requires the matching transaction ID.
  - Frees only newly staged resources; reused committed bodies are never freed.
  - Leaves committed maps and patch side flags unchanged.

- `sync_transitions(...)`
  - Remains the compatibility entry point and delegates to prepare followed immediately by commit.
  - Existing callers do not need to change.

- `clear_all()`
  - Aborts any pending transaction before clearing committed resources.

## Transaction invariants

1. A prepared replacement remains collision-disabled.
2. Existing committed edge and corner-cap bodies remain active until commit succeeds.
3. A wrong transaction ID cannot commit or abort the pending transaction.
4. A second prepare is rejected while one transaction is pending.
5. A stale patch or resource-map snapshot rejects commit and releases only staged resources.
6. Activation failure restores every captured patch-side flag before aborting staged resources.
7. A successful commit publishes the new managed maps and only then queues superseded resources for deletion.
8. The compatibility wrapper continues to return the existing success metrics and counts.

## Test and import

Repository root, Godot 4.3:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/surface_terrain_collider_transaction_test.gd`

Focused workflow: `.github/workflows/surface-terrain-collider-transaction-validation.yml`.

The regression suite covers edge prepare/abort, corner-cap prepare/abort, successful commit, stale patch snapshot rejection, second-endpoint activation failure rollback, and clear-all while a transaction is pending.

## Dependencies

- `SurfaceTerrainTransitionColliderManager.gd` — owns the pending transaction and committed resources.
- `SurfaceTerrainPatch.gd` — world-state and shared-transition activation contract.
- `SurfaceTerrainAdjacencyBinder.gd` — candidate descriptors used by the compatibility wrapper and tests.
- `SurfaceTerrainCornerConflictResolver.gd` — candidate edge/corner policy.
- Existing M0.2.2 Edge↔Junction closure and M0.2.3 preserve-set planner remain detached inputs for the next incremental integration step.

## Scope and limitations

- This version still stages the complete descriptor set; it does not yet apply the affected-component closure or preserve-set plan to a live partial manager update.
- The full-rebuild manager remains the correctness path and oracle.
- The activation fault is injected at the patch API contract. Internal PhysicsServer allocation/activation failures are not injected.
- No GPU/Rendered FPS, iPhone, target-device memory, or touch QA is claimed.
- Do not merge main or bypass the parent review stack. Keep this PR Draft until focused and full Godot 4.3 exact-head gates pass and the parent chain is independently reviewed.

## Next

Integrate the detached Edge↔Junction closure and preserve/stage/retire planners into this transaction boundary. The next stage must scope candidate geometry and resource staging to affected edges/junctions while retaining full rebuild as explicit fallback and differential oracle.


## Run 189 — staged and committed collider-state snapshot hardening

The exact-head review added a second layer of transaction validation:

- Capture each previously committed edge/corner-cap body's validity, instance ID, queued-for-deletion flag, parent, collision layer and collision mask at prepare time.
- Reject commit if a committed resource is externally changed, detached, queued or freed after prepare. The snapshot records the observed state rather than assuming every old resource was healthy before prepare, so a subsequent full-rebuild sync can replace a stale body.
- Preflight every newly staged edge and cap before changing patch-side flags. A staged body must still be valid, attached to this manager, not queued for deletion and collision-disabled.
- Repeat the staged-body check immediately before publishing collision layers, protecting against patch activation side effects.
- Reused resources are checked through the committed-map snapshot and are not mistaken for newly staged collision-disabled bodies.

New focused regressions:
- Staged edge externally enabled between prepare and commit: reject before patch activation, disable and release the staged body, preserve the old committed edge.
- Staged corner cap externally enabled between prepare and commit: reject before patch activation, disable and release staged caps, preserve all old caps.
- Committed edge collision layer changed after prepare: reject stale transaction, then recover through the existing full-rebuild sync_transitions() compatibility path.
- Committed corner-cap collision layer changed after prepare: reject stale transaction, then recover all four caps through full rebuild.

Exact-head validation for this hardening is pending the new GitHub Actions runs. Do not reuse the earlier 97-PASS focused or 553/553 full-gate results as evidence for the updated HEAD.
