# Surface Terrain Connected Multi-Junction Parity M0.2.5

## Purpose

Extend M0.2.4 full-rebuild differential parity with a connected multi-junction case. Existing scenarios cover isolated edge and one-junction cap changes; this fixture verifies that a change seeded at one patch reaches an adjacent eligible corner-cap junction through their shared transition edge.

## Version and branch

- Version: M0.2.5 — connected multi-junction closure parity.
- Parent PR: [#297 — preserve planner versus production full rebuild](https://github.com/qaqp980520-prog/2126-Survival/pull/297).
- Exact base HEAD: `ab1e46cad14379cb3b384f93d4ba9518e95e9d59`.
- Branch: `test/surface-terrain-connected-junction-parity-2026-11-09`.
- Current implementation commit: `5d531c68ab645667b6ba802682966e20916733a2`.
- Test file: `tests/surface_terrain_collider_preserve_planner_parity_test.gd`.
- This design/test record: `docs/SURFACE_TERRAIN_CONNECTED_JUNCTION_PARITY_M0_2_5.md`.

## Real production fixture

The fixture builds a 3×2 patch grid with two adjacent checkerboard junctions. Each junction initially owns four real corner-cap bodies. The two junctions are connected by the transition edge between the middle-column patches.

The candidate changes only the outer north patch (Stable ID `cap/n2`) from height 0 to height 1. The test derives seed edges only from the changed patch's committed production-manager records; it does not seed the whole graph.

Expected behavior:

1. Exactly two existing transition edges touch the changed patch and seed the closure.
2. The old+candidate Edge↔Junction graph reaches both adjacent junction keys through the shared middle-column edge.
3. The candidate right junction becomes ineligible because its edge midpoint heights no longer agree.
4. The production manager propagates fallback across the shared edge, so the formerly eligible left junction also loses its corner caps.
5. The detached preserve planner must classify all eight old corner-cap bodies for retirement.
6. Every preserve/stage/retire set must still match the existing production full-rebuild manager's exact Node identities and final reuse signatures.

This scenario specifically detects an incomplete closure that stops at the first affected junction and incorrectly preserves resources at the connected neighbor.

## Dependencies

- `systems/SurfaceTerrainAffectedComponentPlanner.gd` — old+candidate Edge↔Junction closure.
- `systems/SurfaceTerrainColliderPreservePlanner.gd` — preserve/stage/retire partition.
- `systems/SurfaceTerrainTransitionColliderManager.gd` — production full-rebuild oracle and corner-cap fallback propagation.
- `systems/SurfaceTerrainAdjacencyBinder.gd` — real edge descriptors and corner reports.
- `systems/SurfaceTerrainPatch.gd` — patch height and shared-edge state.

## Import and test

Repository root with Godot 4.3:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/surface_terrain_collider_preserve_planner_parity_test.gd`

The existing workflow `.github/workflows/surface-terrain-preserve-planner-full-rebuild-parity.yml` is triggered by pull requests that change the test file.

## Scope and limitations

- Test-only; no production Runtime, Controller, manager or PhysicsServer wiring changes.
- The planner remains detached; the existing full-rebuild manager remains the correctness oracle.
- This tests connected closure and fallback propagation, not an incremental live transaction.
- No PhysicsServer-internal failure, GPU/Rendered FPS, iPhone, target-device memory or touch QA is claimed.
- Keep Draft until the exact-head focused and full Godot 4.3 gates pass and the parent review chain is independently reviewed.
