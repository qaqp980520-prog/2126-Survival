# Terrain Patch Segmentation Batch M0.1

## Purpose

Defer repeated collision/surface segmentation refreshes while the production adjacency binder clears and rebinds a complete patch set. The binder still performs the authoritative full adjacency rebuild; this change only coalesces the derived 3x3 collision/surface segmentation refresh on each affected patch.

## Version and GitHub

- Version: Terrain Patch Segmentation Batch M0.1.
- PR: [#285 — Batch reciprocal terrain patch segmentation refreshes](https://github.com/qaqp980520-prog/2126-Survival/pull/285).
- Parent: [#284 — Terrain Adjacency Phase Profiling M0.2](https://github.com/qaqp980520-prog/2126-Survival/pull/284).
- Branch: `perf/batched-terrain-patch-segmentation-refresh-2026-11-07`.
- Base: PR #284 exact head `2b40d1b8f70eb2eac0b98df76cd26d7308000017`.

## Files

- `systems/SurfaceTerrainPatch.gd`: nested segmentation-refresh batch scope, reciprocal-neighbor enumeration, deferred refresh request, and opt-in refresh counter for deterministic tests.
- `systems/SurfaceTerrainAdjacencyBinder.gd`: collects loaded patches plus their live reciprocal neighbors, opens supported batch scopes before clearing, and closes all scopes on success and both clear/bind failure paths.
- `tests/surface_terrain_adjacency_binder_test.gd`: verifies one refresh per loaded patch, one refresh for an external reciprocal neighbor during unload, nested scope semantics, immediate public clear behavior, and opt-in counter default.
- `docs/SURFACE_TERRAIN_PATCH_SEGMENTATION_BATCH_M0_1.md`: this version record.

## Behavior and safety contract

- Existing public `clear_neighbor_edge_state(side)` semantics remain immediate when no batch scope is open.
- Batch scopes are nestable. Only the outermost close performs a pending segmentation refresh.
- The binder collects reciprocal neighbors before clearing any edge, including valid neighbors outside the new loaded patch array. This is required because a departing patch may still hold a weak reference to a patch that is not part of the new set.
- Every patch that supports the batch API is opened once and closed once by the binder.
- Clear failure and neighbor-bind failure both execute the existing full cleanup path before closing all started scopes.
- The authoritative full adjacency rebuild, descriptor generation, stable-ID validation, and collider-manager synchronization are not replaced.
- The refresh counter is disabled by default and enabled only by the regression test; normal gameplay does not pay counter-increment overhead.

## Dependencies and import

Godot 4.3 root project; production SurfaceTerrainPatch; SurfaceTerrainAdjacencyBinder; existing SurfaceTerrainEdgePolicy and SurfaceTerrainTransitionDescriptor scripts; existing terrain patch collision and visual segment nodes.

From repository root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_terrain_adjacency_binder_test.gd
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

The full Godot 4.3 compatibility workflow and production benchmark workflow are also required for the exact PR head.

## Validation

Pending exact-head CI for PR #285. Do not infer a pass from PR #284 or predecessor test runs.

Acceptance requires:
- Every production patch in the binder clear/rebind pass receives exactly one segmentation refresh.
- A reciprocal neighbor outside the incoming patch array is also refreshed exactly once.
- Nested batch scopes defer refresh until the outermost scope closes.
- An unmatched close is rejected.
- Public single-side clear remains immediate outside a batch.
- The opt-in refresh counter remains disabled by default.
- Existing adjacency policies, ramp state, descriptors, and spatial-index assertions remain unchanged.
- Full Godot 4.3 compatibility gate and all focused checks pass.

## Limitations and next steps

- This reduces repeated segmentation refreshes during the full clear/rebind phase; it does not yet implement local-neighborhood incremental adjacency.
- The binder still validates and rediscovers the complete patch set, then rebuilds all descriptors.
- `set_shared_transition_active()` calls outside a binder batch still refresh immediately; collider-manager phase profiling remains separate.
- No target-device, iPhone, or GPU performance claim is made.
- Next: inspect exact-head test results and phase timings; if correct, add controlled refresh-call and edge-apply comparisons on the same runner class. Keep the full rebuild as correctness oracle and rollback path.
