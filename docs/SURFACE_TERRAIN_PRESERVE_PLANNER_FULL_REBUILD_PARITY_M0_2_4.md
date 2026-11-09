# Surface Terrain Preserve Planner Full-Rebuild Parity M0.2.4

## Purpose

Add a differential regression suite for the detached M0.2.3 preserve/stage/retire planner. The existing production `SurfaceTerrainTransitionColliderManager.sync_transitions()` remains the full-rebuild oracle. The new suite predicts resource outcomes from old/candidate manager snapshots, then applies the same candidate descriptors through the existing manager and compares exact Node identities and final reuse signatures.

This is test-only. It does not wire the planner into production or change live runtime behavior.

## Version and branch

- Version: M0.2.4 — full-rebuild resource identity parity.
- Parent PR: [#296 — detached collider preserve-set planner](https://github.com/qaqp980520-prog/2126-Survival/pull/296).
- Base HEAD: `160d10f554a891e64a0dd3b39b27437e7c08246a`.
- Branch: `test/surface-terrain-preserve-planner-full-rebuild-parity-2026-11-09`.
- Test file: `tests/surface_terrain_collider_preserve_planner_parity_test.gd`.
- Workflow: `.github/workflows/surface-terrain-preserve-planner-full-rebuild-parity.yml`.

## Differential method

1. Build an old topology through `SurfaceTerrainAdjacencyBinder.bind_patches()` and a real `SurfaceTerrainTransitionColliderManager.sync_transitions()`.
2. Capture the complete old manager-owned edge/cap maps, exact body references, reuse signatures, body liveness, edge patch-side activation state, and old resolver reports.
3. Apply candidate patch-state or topology changes and build a second, fresh manager as the candidate full-rebuild oracle.
4. Compute the old+candidate Edge↔Junction closure with `SurfaceTerrainAffectedComponentPlanner`.
5. Feed the preserve planner the complete old maps and only candidate resources inside the computed closure.
6. Apply the candidate descriptors to the original old manager through its existing full-rebuild path.
7. Derive actual preserve/stage/retire sets from old-versus-final body identity; derive reactivation from the captured old patch-side state.
8. Compare every planner output set against the actual full-rebuild identity result, then compare final manager keys and reuse signatures against the candidate oracle.

The test uses the same patch Node instances for retained Stable IDs so the production reuse signatures' instance-ID fields remain comparable. Added and removed patches remain alive in the fixture while they are excluded from one side of the topology snapshot; this isolates topology removal from object destruction.

## Real production scenarios

- Edge addition: one isolated patch becomes a two-patch sloped transition.
- Edge removal: the two-patch transition is removed from the candidate topology.
- Edge replacement: the same edge key receives a changed real geometry signature.
- Edge reactivation: a valid unchanged body is retained while both patch-side activation flags are deliberately cleared, then the full rebuild reactivates the same body.
- Corner-cap addition: a three-patch L topology becomes a four-way checkerboard with four manager-owned caps.
- Corner-cap removal: the four-way checkerboard loses one patch and all four caps are retired.
- Corner-cap replacement: the checkerboard is inverted 0↔2 while remaining eligible, forcing four real cap signatures to change.

For every scenario, the edge and cap preserve/stage/retire outputs are compared to the real manager's actual post-rebuild body identities. Final resource key sets and signatures are also compared to the candidate manager oracle.

## Dependencies

- `systems/SurfaceTerrainAffectedComponentPlanner.gd` — old/candidate topology closure.
- `systems/SurfaceTerrainColliderPreservePlanner.gd` — detached resource partition.
- `systems/SurfaceTerrainTransitionColliderManager.gd` — real resource staging, reuse, activation and retirement.
- `systems/SurfaceTerrainAdjacencyBinder.gd` — production topology descriptors.
- `systems/SurfaceTerrainPatch.gd` — real patch state and activation contract.

## Import and test

Repository root, Godot 4.3:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/surface_terrain_collider_preserve_planner_parity_test.gd`

GitHub Actions workflow: `surface-terrain-preserve-planner-full-rebuild-parity.yml`.

## Scope and limitations

- Test-only; no production manager/Controller wiring and no main merge.
- The candidate manager is an independent full-rebuild oracle in the same fixture, not a live incremental transaction.
- This does not test PhysicsServer-internal allocation failure, GPU/Rendered FPS, iPhone, target-device memory or touch QA.
- The production full-rebuild path remains authoritative until differential parity and the existing rollback suite are both stable on the exact PR head.
- Keep this child PR Draft until the parent terrain stack receives independent human review. Do not bypass #296 → #295 → #293 → #292 → #287.
