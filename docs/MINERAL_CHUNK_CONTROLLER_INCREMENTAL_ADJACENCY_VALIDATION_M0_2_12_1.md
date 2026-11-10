# Mineral Chunk Controller Incremental Adjacency — Validation Corrections M0.2.12.1

## Purpose

Record the exact-head corrections required after the first PR #307 production integration run. This version changes no transaction semantics; it removes a global script-class-cache dependency from runtime declarations and corrects two assertions that did not reflect the production chunk grid and the new incremental preservation contract.

## Changed files

- `systems/MineralChunkController.gd`
  - Remove global custom-class type annotations from the persistent Index, Scoped Transaction, Coordinator fields, and two script-instantiated Index locals.
  - Continue constructing the same runtime classes through the existing preloaded Script constants.
- `tests/mineral_chunk_controller_incremental_adjacency_test.gd`
  - Remove a global Index type annotation from the full-rebuild oracle.
  - Make the fault-injecting Collider Manager test subclass extend the production script path directly instead of depending on the global `SurfaceTerrainTransitionColliderManager` class cache.
  - Move the async Director test target from X=32 to X=64, because the default chunk width is 64; explicitly assert the expected grid coordinate before submitting the request.
- `tests/surface_chunk_production_benchmark.gd`
  - Replace the obsolete expectation that an incremental boundary shift reactivates preserved endpoints.
  - Verify that the exact seeded Collider Node survives, both Patch endpoints retain reciprocal neighbor bindings, the reused-edge count is positive, and reactivation count is zero.
  - Return the seeded Collider body from the same-world reuse fixture and add a Stable-ID-to-Patch lookup helper.
- `docs/MINERAL_CHUNK_CONTROLLER_INCREMENTAL_ADJACENCY_M0_2_12.md`
  - Append the exact-head failure analysis and correction record.

## Root-cause evidence

- Controller-focused and several existing streaming focused jobs on HEAD `46175ccd01339b74fc5fb26059a697fb6e2268dd` failed to parse `MineralChunkController.gd` because `SurfaceTerrainAdjacencyIndex`, `SurfaceTerrainAdjacencyScopedTransaction`, and `SurfaceTerrainAdjacencyCoordinator` were not available as global types in those headless entry points. The scripts are already preloaded explicitly; dynamic declarations avoid relying on the global class cache. A follow-up run then exposed the same cache dependency in the nested test subclass base, which is now referenced by its direct script path.
- The new async recovery test failed its expected ID because X=32 / 64 floors to coordinate (0, 0), not (1, 0).
- The production benchmark failed because it expected a full-Binder reactivation count on an incremental transaction. Incremental preservation intentionally keeps unaffected Patch endpoint bindings intact and therefore must not reactivate them.

## Validation commands

```bash
godot --headless --path . --script res://tests/mineral_chunk_controller_incremental_adjacency_test.gd
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

Also required on the exact PR head:

- Surface Terrain Controller Transaction Validation.
- Mineral Grid Streaming Lifecycle Validation.
- Existing Run 101–108 focused streaming suites.
- Full Godot 4.3 compatibility gate (554 steps).
- Production Surface Chunk Benchmark with a non-zero Radius-1 transition collider fixture.

## Dependencies and import

Godot 4.3 and the existing M0.2.10/M0.2.12 scripts. No new external packages, imported assets, autoloads, project settings, or scene wiring.

## Limitations

- In-place same-Node terrain-state edits still use the authoritative full Binder fallback.
- A full Radius-8 benchmark with non-zero Transition Edge and Corner Cap resources is still outstanding.
- PhysicsServer-internal allocation failure, GPU/rendered FPS, iPhone, device memory, and touch QA remain untested.
- Keep PR #307 Draft and unmerged until corrected exact-head CI and parent-chain independent review are complete.
