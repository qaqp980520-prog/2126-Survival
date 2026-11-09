# Surface Terrain Affected Component Closure M0.2 — Detached Planner

## Purpose

Implement the first isolated Edge↔Junction affected-component closure primitive for the incremental terrain-adjacency work. It is a detached planner only; the production full-rebuild binder and collider manager remain unchanged.

## Files

- systems/SurfaceTerrainAffectedComponentPlanner.gd
- tests/surface_terrain_affected_component_planner_test.gd
- .github/workflows/surface-terrain-affected-component-planner-validation.yml

## Contract

- Input is the changed edge-key seed set, old resolver reports with the old Stable-ID-to-Patch map, candidate resolver reports with the candidate map, and the common patch size.
- Every resolver report participates, including step-fallback/ineligible reports. The planner does not filter on policy.
- Build a bipartite graph from edge key to the junction derived from the report's patch position and corner. Merge old and candidate graphs before breadth-first expansion.
- The result is the sorted union of all connected edge keys and junction keys reached from the seed edges. A seed with no corner reports remains a one-edge component.
- Empty seeds return an empty successful result. Malformed reports, missing patch references, invalid corners, duplicate edge keys within one report, and invalid seed keys fail closed.
- Junction formatting and corner offsets are kept in parity with SurfaceTerrainTransitionColliderManager; the focused test checks all four corners against the manager's existing private helpers.

## Import and test

Repository root, Godot 4.3:

- godot --headless --path . --editor --quit
- godot --headless --path . --script res://tests/surface_terrain_affected_component_planner_test.gd

Focused GitHub Actions workflow runs the same test on every pull request touching the planner, manager, test or workflow.

## Scope and limitations

- No production runtime behavior is changed. The planner is not yet wired into SurfaceTerrainTransitionColliderManager or MineralChunkController.
- The planner returns a closure only; it does not calculate cap eligibility, stage colliders, preserve resource identities or commit/rollback a live transaction.
- Old and candidate reports must be generated from their respective exact topology snapshots while both old and candidate patch Nodes are still alive.
- The production full-rebuild binder remains the correctness oracle.
- No GPU, Rendered FPS, iPhone, target-device or PhysicsServer internal failure test is included.

## Next

Compare the closure's affected edges/junctions against the manager's full rebuild on real two-way and checkerboard fixtures, then derive a preserve-set for existing edge/cap resources. Do not wire the planner into production until those differential and rollback tests pass.
