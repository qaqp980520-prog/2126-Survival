# Surface Terrain Collider Preserve-Set Planner M0.2.3

## Purpose

Add a detached, deterministic resource-preservation planner after the Edge↔Junction affected-component closure (M0.2.2). It converts the closure into exact edge and corner-cap preserve/stage/retire key sets without mutating production Nodes or manager-owned resources.

## Files

- systems/SurfaceTerrainColliderPreservePlanner.gd
- tests/surface_terrain_collider_preserve_planner_test.gd
- .github/workflows/surface-terrain-collider-preserve-planner-validation.yml

## Input contract

- Affected edge keys and junction keys come from the union-of-old-and-candidate Edge↔Junction closure.
- Old edge and cap maps represent the complete committed manager-owned resource set.
- Candidate edge and cap maps contain only resources inside the affected closure.
- Every resource record carries the exact manager reuse signature.
- Old edge records additionally carry body_reusable and patch_states_active.
- Old cap records carry junction_key and body_reusable.
- Candidate cap records carry their candidate junction_key.

The caller must derive body_reusable using the same manager ownership/liveness contract: valid, not queued for deletion, parented to the manager, and collision layer enabled. Edge patch-side activation is supplied separately so a valid preserved body can be reactivated without restaging.

## Output

The planner returns sorted, deterministic sets:

- preserve_edge_keys
- reactivate_edge_keys
- stage_edge_keys
- retire_edge_keys
- preserve_corner_cap_keys
- stage_corner_cap_keys
- retire_corner_cap_keys

A signature-identical reusable resource is preserved even when it is inside the affected closure. A changed or non-reusable old resource is staged/replaced. A removed old resource is retired. New candidate resources are staged.

## Fail-closed conditions

- Candidate edge or cap appears outside the supplied closure.
- An old resource outside the closure is stale/non-reusable.
- A cap's old junction is outside the closure while a candidate with the same resource key moves into it.
- Blank/non-string keys, malformed records, missing signatures, or missing old-state booleans.

These checks deliberately reject an incomplete closure rather than silently changing resources outside the declared component. If a resource is stale outside the closure, the caller must expand the closure or use the full-rebuild recovery path.

## Dependencies

- SurfaceTerrainAffectedComponentPlanner.gd M0.2.2 for Edge↔Junction closure.
- SurfaceTerrainTransitionColliderManager.gd for edge/cap reuse signatures and managed-resource ownership contract.
- SurfaceTerrainPatch.gd for shared transition activation state.
- SurfaceTerrainAdjacencyBinder.gd remains the topology correctness oracle.

## Import and test

Repository root, Godot 4.3:

- godot --headless --path . --editor --quit
- godot --headless --path . --script res://tests/surface_terrain_collider_preserve_planner_test.gd

Focused workflow: surface-terrain-collider-preserve-planner-validation.yml.

## Coverage

- Deterministic edge preserve/stage/retire partition.
- Edge reactivation when the old body is reusable but patch-side flags are inactive.
- New, changed, removed and non-reusable edge resources.
- Candidate changes outside the affected closure fail closed.
- Stale old resources outside the closure fail closed.
- Deterministic corner-cap preserve/stage/retire partition.
- Cap movement requires both old and candidate junctions in the closure.
- Real four-way checkerboard manager records are captured from the production manager; unchanged signatures preserve all four cap resources, while one changed signature stages/retires only that cap.

## Scope and limitations

- Detached planner only. It is not wired into SurfaceTerrainTransitionColliderManager.sync_transitions() or MineralChunkController.
- No live Node mutation, collider staging, PhysicsServer operation, resource activation, manager-map publication, or rollback is performed by this planner.
- The production full-rebuild binder and current manager remain the runtime path and correctness oracle.
- No PhysicsServer-internal failure injection, GPU/Rendered FPS, iPhone, or target-device QA is claimed.
- Keep this child PR Draft until the parent terrain stack receives independent review. Do not merge or bypass parent dependencies.

## Next

Differentially compare the preserve/stage/retire sets against the existing full-rebuild manager on real edge and cap topology changes, then introduce a prepare/commit/abort manager API only after the planner and M0.1 rollback fault-injection suite agree on exact resource identities.
