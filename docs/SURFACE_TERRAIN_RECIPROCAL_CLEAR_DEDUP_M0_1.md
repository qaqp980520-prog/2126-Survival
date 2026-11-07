# Reciprocal Terrain Edge Clear Deduplication M0.1

## Purpose

Avoid invoking the public reciprocal edge-clear operation twice for the same already-bound terrain seam during a full adjacency rebuild. The binder snapshots per-side neighbor endpoints before mutating weak references, then clears each reciprocal pair once. The patch API remains responsible for clearing both local endpoints.

## Version and GitHub

- Version: Reciprocal Terrain Edge Clear Deduplication M0.1.
- PR: [#286 — Deduplicate reciprocal terrain edge clears during full adjacency rebuild](https://github.com/qaqp980520-prog/2126-Survival/pull/286).
- Parent PR: [#285 — Batch reciprocal terrain patch segmentation refreshes](https://github.com/qaqp980520-prog/2126-Survival/pull/285), exact head `c84f1541569b27e692cfd4b5a191152bf2e87dc9`.
- Branch: `perf/deduplicate-reciprocal-terrain-edge-clears-2026-11-07`.
- Initial branch point: `c84f1541569b27e692cfd4b5a191152bf2e87dc9`.

## Files

- `systems/SurfaceTerrainPatch.gd`: adds a read-only per-side weak-neighbor query.
- `systems/SurfaceTerrainAdjacencyBinder.gd`: snapshots reciprocal endpoint pairs before mutation and invokes one public clear per seam; retains legacy clearing when a patch lacks the optional query or the observed endpoint mapping is ambiguous.
- `tests/surface_terrain_adjacency_binder_test.gd`: adds a loaded-seam plus outgoing-external-neighbor regression; asserts exact public clear-call count and reciprocal state.
- `docs/SURFACE_TERRAIN_RECIPROCAL_CLEAR_DEDUP_M0_1.md`: version and integration note.

## Behavior and compatibility

- A single call to `clear_neighbor_edge_state(side)` still clears both local and reciprocal endpoint state.
- Existing single-side callers are unchanged.
- The binder records the current neighbor for each side before the first clear, because the first clear mutates both endpoints.
- A reciprocal pair with both endpoints in the incoming patch set is cleared once rather than once from each endpoint.
- An outgoing neighbor outside the incoming set is still cleared by its loaded endpoint.
- Unpaired or stale sides are cleared individually.
- `SurfaceTerrainPatch` treats clearing a side with no neighbor, edge-state snapshot, or shared-transition flag as a no-op; it does not rebuild unchanged ramp/collision segmentation state.
- A changed local side still refreshes immediately outside a batch, and both changed endpoints refresh when a reciprocal seam is cleared.
- If a custom patch does not implement `get_bound_neighbor_patch(side)`, or if an endpoint is mapped ambiguously, the binder falls back to the previous clear-every-side behavior.
- Collision-segmentation batching from PR #285 remains active and unchanged.
- Full validation, spatial discovery, descriptor generation and transition-collider synchronization remain the authoritative full-rebuild path.

## Dependencies and import

Requires the Godot 4.3 root project, `SurfaceTerrainPatch`, `SurfaceTerrainAdjacencyBinder`, `SurfaceTerrainEdgePolicy`, `SurfaceTerrainTransitionDescriptor`, and the existing terrain collision/surface segment nodes.

From repository root:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_terrain_adjacency_binder_test.gd
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

## Regression contract

- Initial binding creates two internal seams and one seam to an outgoing patch.
- Rebinding only the retained three patches calls the public clear API exactly ten times: twelve loaded side slots minus one duplicate call for each of the two internal reciprocal seams.
- The outgoing external reciprocal state is removed.
- Both retained seams are rebuilt reciprocally.
- Existing 20×20 spatial-index, negative-coordinate/tolerance, descriptor, failure cleanup, segmentation batching and full Godot 4.3 compatibility suites must remain green.

## Limitations and next steps

This reduces duplicate reciprocal clear API calls and associated per-edge ramp-state refresh work during the existing full rebuild. It does not yet implement local-neighborhood incremental adjacency or preserve unaffected descriptors/collider resources. The full rebuild remains the correctness oracle and rollback path. No iPhone/GPU performance claim is made.

Next: run exact-head spatial/adjacency, production benchmark and full Godot 4.3 gates; inspect benchmark output and compare same-runner samples before making any performance claim.
