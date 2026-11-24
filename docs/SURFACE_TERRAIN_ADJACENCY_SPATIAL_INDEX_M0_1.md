# Surface Terrain Adjacency Spatial Index M0.1

## Purpose

Replace the production terrain adjacency binder's repeated all-pairs position and neighbor scans with tolerance-aware spatial buckets. This directly addresses the source-level scaling hotspot identified while investigating [Issue #278](https://github.com/qaqp980520-prog/2126-Survival/issues/278).

## Previous cost

The prior binder performed:
- a linear scan of all prior patch positions for every new patch to reject duplicates; and
- a nested all-pairs scan to discover cardinal neighbors.

The production controller re-runs the binder after each chunk load and unload. With seven terrain patches per surface chunk, a radius-8 window contains 2,023 patches. Repeating quadratic scans as the set grows makes cumulative work approximately cubic in the number of chunks. This is a source-level complexity estimate, not a measured timing result.

## New approach

- Quantize world positions into 0.01-unit `Vector3i` buckets.
- For duplicate-position validation, inspect the 27 buckets adjacent to each patch and retain the original Euclidean distance check at the 0.01 tolerance.
- For adjacency discovery, inspect only the 27 buckets around each of the four expected cardinal neighbor positions.
- Retain the original `_side_between` tolerance test and transition descriptor builder.
- Sort discovered candidate indices before descriptor construction to preserve deterministic pair ordering.
- Keep all validation and descriptor construction before clearing or mutating live neighbor edges.
- Return additive counters for bucket lookups and candidate comparisons to make algorithmic behavior testable.

Expected lookup work is bounded by a fixed neighborhood per patch for normal non-pathological layouts; exact candidate comparisons are proportional to actual nearby patches rather than every pair.

## Regression coverage

The existing `tests/surface_terrain_adjacency_binder_test.gd` now runs both the original real-patch scenarios and a lightweight 20x20 fixture grid; the full Godot compatibility gate already executes this test. The focused Godot 4.3 workflow also runs the transition collider manager compatibility test.

The new fixture asserts:
- 400 patches produce exactly 760 cardinal adjacency pairs;
- the binder performs 760 adjacency candidate checks, not 79,800 all-pairs comparisons;
- duplicate validation and adjacency use fixed 27-bucket neighborhoods;
- negative and positive world coordinates are handled;
- tolerance-adjacent patches across bucket boundaries still bind;
- near-duplicate positions across bucket boundaries are rejected before live edge mutation.

## Files

- `systems/SurfaceTerrainAdjacencyBinder.gd`
- `tests/surface_terrain_adjacency_binder_test.gd` — original real-patch scenarios plus the 20x20 spatial-index and tolerance-boundary regressions.
- `.github/workflows/surface-terrain-adjacency-spatial-index-validation.yml`
- `.github/workflows/surface-chunk-production-benchmark.yml` — expanded dependency path coverage so binder/transition changes rerun the real-factory benchmark.
- `docs/SURFACE_TERRAIN_ADJACENCY_SPATIAL_INDEX_M0_1.md`

## Dependencies and import

Godot 4.3 root project; SurfaceTerrainPatch; SurfaceTerrainTransitionDescriptor; MineralChunkController; SurfaceTerrainTransitionColliderManager; SurfaceTerrainCornerConflictResolver.

Import:

```sh
godot --headless --path . --editor --quit
```

Focused validation:

```sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_binder_test.gd
godot --headless --path . --script res://tests/surface_terrain_transition_collider_manager_test.gd
```

## Validation status and limitations

This change is based on the source-level complexity finding. It has not yet passed exact-head Godot CI; no runtime speedup is claimed until the focused tests, full compatibility gate and real-factory benchmark complete.

The spatial buckets preserve the existing tolerance checks. Pathological layouts with many patches in the same or adjacent buckets can still increase candidate comparisons, and the 20x20 test measures algorithmic candidate counts rather than wall-clock performance.

## Integration

This branch is stacked on the production benchmark PR #279 so the real-factory benchmark can compare the optimized binder against the baseline. Review and merge #279 first; then re-run the benchmark and full Godot gate on this branch. Do not change the supported radius cap or playable-world default based only on this optimization.
