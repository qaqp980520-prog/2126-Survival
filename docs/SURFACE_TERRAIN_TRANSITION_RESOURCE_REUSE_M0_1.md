# Terrain Transition Resource Reuse M0.1

## Purpose

Preserve already-active transition collider bodies and four-way corner-cap bodies when a full terrain adjacency synchronization produces identical geometry. Only changed, removed, invalid, or no-longer-active resources are staged/replaced or retired.

This is a resource-lifecycle optimization layered on the existing full adjacency rebuild. It does not yet implement local-neighborhood adjacency discovery.

## Version and GitHub

- Version: Terrain Transition Resource Reuse M0.1.
- Branch: `perf/preserve-unchanged-terrain-transition-resources-2026-11-07`.
- Parent: PR #286 exact head `052147d77e50667dedf6a5a98f4eda6e70c1e179`.
- PR: [#287 — Preserve unchanged terrain transition and corner-cap resources](https://github.com/qaqp980520-prog/2126-Survival/pull/287), stacked on PR #286.
- Current implementation commits include:
  - `d73491ae43600c03cca850667411afddfaee6d50` — preserve unchanged edge/corner bodies during sync.
  - `d9c6fb4d04ff0e2c8f10f94585a2db3ffde4e7b8` — add edge and four-way corner-cap reuse regressions.
  - `ea19c2a599805d624da80687c8141823704c4ae9` — expose reuse counters through the production controller.
  - `cd92c5675a3c0b8f9fd6f59535d301addccbeb0f` — add benchmark accounting assertions and output fields.
  - `4374fe8cd187e1aea5fd41d3d3e49b11598010ce` — guard test assertions against missing resources.
  - `cf57a17e15102fd7208b42dd8a2c27eb9ae19a1f` — validate corner-cap signature fields explicitly without relying on sentinel constants.
- Latest exact branch head: `cf57a17e15102fd7208b42dd8a2c27eb9ae19a1f` (8 commits ahead / 0 behind PR #286).

## Files

- `systems/SurfaceTerrainTransitionColliderManager.gd`: compute deterministic reuse signatures for transition edges and corner caps; reuse only valid manager-owned active bodies with unchanged endpoint identity, sides and geometry; report reused/staged/retired counts; keep reused resources out of failure cleanup.
- `systems/MineralChunkController.gd`: propagate edge/cap reuse counts into opt-in terrain profiling and rebind results.
- `tests/surface_terrain_transition_collider_manager_test.gd`: verify identical sync preserves edge body instances; changing one of two independent seams replaces only the changed edge; a checkerboard four-way junction preserves all four cap instances across identical syncs.
- `tests/surface_chunk_production_benchmark.gd`: validate resource-accounting identities and emit reused/staged/retired edge and cap counts in every production benchmark record.
- `docs/SURFACE_TERRAIN_TRANSITION_RESOURCE_REUSE_M0_1.md`: version, dependencies, import, test contract and limitations.

## Behavior and safety

- Reuse requires an exact signature match, a valid non-queued body still parented to the manager with the active collision layer, and (for edges) both endpoint patches still reporting the shared transition active.
- Edge signatures include stable IDs, patch instance IDs, endpoint sides, basis, center/body origin, slope length, patch size, width and corner trims.
- Corner-cap signatures include stable ID, corner, patch instance ID, junction key/position, midpoint height and patch top height.
- Changed edges/caps are staged while existing resources remain live. Patch activation is completed before old changed/removed resources are retired.
- If staging or activation fails, only newly staged resources are freed; reused active resources remain owned and live.
- Removed or changed edge resources are retired after successful commit. Unaffected body instances remain stable.
- Full candidate validation, corner resolution and descriptor generation still run; this version optimizes resource staging/retirement, not full adjacency discovery.

## Dependencies and import

Requires the Godot 4.3 root project and existing `SurfaceTerrainTransitionColliderManager`, `SurfaceTerrainAdjacencyBinder`, `SurfaceTerrainPatch`, `SurfaceTerrainCornerConflictResolver`, edge policy, transition descriptor and terrain collision scene nodes.

From repository root:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_terrain_transition_collider_manager_test.gd
godot --headless --path . --script res://tests/surface_terrain_adjacency_binder_test.gd
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

## Regression contract

- Repeating identical sync over two independent unequal-height seams reuses both existing edge bodies and stages zero replacements.
- Changing one seam's endpoint height replaces and retires only that seam's body; the independent unchanged seam retains the same active body instance.
- A 2×2 checkerboard four-way junction creates four corner-cap bodies; repeating identical sync reuses all four.
- Existing malformed descriptor preflight still preserves previously active bodies.
- Existing cardinal directions, perpendicular conflicts, corner resolution, spatial-index, adjacency, segmentation batching, failure cleanup and full Godot 4.3 compatibility tests must remain green.

## Limitations and next steps

- No local-neighborhood incremental adjacency algorithm is implemented yet; binder validation, spatial discovery, descriptor generation and corner resolution still process the full loaded patch set.
- This preserves unchanged collider resources but still evaluates candidate geometry for all descriptors.
- No iPhone, GPU, rendered-frame or target-device performance claim is made.
- Next: validate exact-head CI, inspect the resource-reuse counts in focused tests, then extend the real production benchmark to report reused/staged/retired edge and cap counts during boundary shifts. Preserve the full rebuild as the correctness oracle and rollback path.
