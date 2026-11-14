# Terrain Transition Resource Reuse M0.1

## Purpose

Preserve already-active transition collider bodies and four-way corner-cap bodies when a full terrain adjacency synchronization produces identical geometry. Only changed, removed, invalid, or no-longer-active resources are staged/replaced or retired.

This is a resource-lifecycle optimization layered on the existing full adjacency rebuild. It does not yet implement local-neighborhood adjacency discovery.

## Version and GitHub

- Version: Terrain Transition Resource Reuse M0.1.
- Branch: `perf/preserve-unchanged-terrain-transition-resources-2026-11-07`.
- Integrated parent: PR #280 feature branch exact head `16b9c53651aac2bc77d3068443658c63ed374429`. Original source PR #287 was historically stacked on PR #286 head `052147d77e50667dedf6a5a98f4eda6e70c1e179`; the original source branch is preserved unchanged.
- Source PR: [#287 — Preserve unchanged terrain transition and corner-cap resources](https://github.com/qaqp980520-prog/2126-Survival/pull/287). Current-parent integration candidate is tracked separately against PR #280.
- Current implementation commits include:
  - `d73491ae43600c03cca850667411afddfaee6d50` — preserve unchanged edge/corner bodies during sync.
  - `d9c6fb4d04ff0e2c8f10f94585a2db3ffde4e7b8` — add edge and four-way corner-cap reuse regressions.
  - `ea19c2a599805d624da80687c8141823704c4ae9` — expose reuse counters through the production controller.
  - `cd92c5675a3c0b8f9fd6f59535d301addccbeb0f` — add benchmark accounting assertions and output fields.
  - `4374fe8cd187e1aea5fd41d3d3e49b11598010ce` — guard test assertions against missing resources.
  - `cf57a17e15102fd7208b42dd8a2c27eb9ae19a1f` — validate corner-cap signature fields explicitly without relying on sentinel constants.
  - `4c59c77beca664dd673f9e93fa24dc0b534a42ce` — reuse unchanged bodies while reactivating patch segmentation after binder clearing.
  - `cb3906e2fbc5a5af118734b4a611b6e4647c7335` — expose reactivation counts through the controller.
  - `a136e709486624db74e2c941e6c4a35b73b9f333` — validate and emit reactivation accounting in production benchmark records.
  - `793f092abf009aa25a577a44ccc72aa736c49432` — assert that reused bodies are reactivated when binder rebuild clears patch state.
  - `17706424278aa67a64442434e039d75919a86e37` — add a real-factory transition reuse fixture.
  - `4d1488ced73616bb9d89a1adbb6622dd7802586b` — remove an unused benchmark helper.
  - `b5f68fd5ebf480782bbcb2fd1c0c0d7633f2d482` — update benchmark artifact validation to 20 records.
  - `260b00d1c6e66b284d4b89ed14928dafbf750e08` — run production fixture through the adjacency batch API for complete profiling.
  - `049aad2fa224763a5a86051e278620aaa8ce5e35` — select only descriptors marked transition_required when capturing the production transition body.
- Source branch head before current-parent port: `1211b5489189fdd6020f6a67ed6350f410097d58`. The current integration candidate receives a new exact-head validation after patch application.

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


## Issue #288 — real SurfaceWorld four-way corner-cap reuse fixture

- The benchmark wrapper calls the real `SurfaceChunkFactory.make_chunk()`, then injects four real `SurfaceTerrainPatch` nodes into only the designated `Chunk_1000_2000` root before Controller registration. The factory's seven original terrain patches remain untouched.
- Exact fixture nodes/positions: NW `(5.5, 0, 3.5)`, NE `(7.5, 0, 3.5)`, SW `(5.5, 0, 5.5)`, SE `(7.5, 0, 5.5)`; stable IDs use the real Controller path rule.
- Prop isolation is benchmark-only and moves only `CropPlot_1` and `SalvageCrate` to local y=-10. `CropPlot_0` and ore remain at factory positions; no node is deleted, renamed or state-mutated.
- The complete world-object registry payload (schema plus every record) is copied; only the four fixture patch records are updated to the mainline checkerboard NW/SE height 2 + metal, NE/SW height 0 + soil, with each revision incremented.
- The full payload is applied through `controller.restore_world_object_states()` inside one adjacency batch. Controller read-only forwarding getters expose corner-cap count and body identity without accessing the private Manager.
- The benchmark verifies exactly four caps after seeding, same-world rebind reuse of all four, identity preservation through the one-chunk east shift while the original chunk remains loaded, and retirement/release of all four after contraction to radius 0 at the shifted center.
- Resource accounting is asserted for edges and caps on same-world, boundary-shift and contraction phases. Exactly one additional JSONL record is emitted: `corner_cap_reuse_same_world_sync`; workflow record count is 21.
- This remains production coverage, not a new incremental adjacency algorithm. Full-set validation and the Full Rebuild correctness oracle remain unchanged.
