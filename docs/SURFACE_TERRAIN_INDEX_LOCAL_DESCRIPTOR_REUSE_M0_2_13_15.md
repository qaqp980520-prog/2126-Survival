# Surface Terrain Changed-Edge Projection from Local Descriptor Maps — M0.2.13.15

## Motivation

M0.2.13.14 removed duplicate construction when both endpoints of an undirected edge are in one selected Stable-ID set. A second overlap remained inside `SurfaceTerrainAdjacencyIndex.plan_delta()`: it built old/new descriptors for `changed_ids`, then built old/new descriptors again for `touched_ids`. Since `touched_ids` contains every changed Stable ID plus its old/new cardinal neighbors, every edge incident to a changed ID is already present in the local descriptor maps.

## Implementation

`systems/SurfaceTerrainAdjacencyIndex.gd` now:

1. Builds the old and candidate local descriptor maps for `touched_ids` exactly once.
2. Projects the changed-edge subsets by selecting descriptors whose `first_stable_id` or `second_stable_id` is in `changed_ids`.
3. Uses those projected maps for `affected_edge_keys`, added/removed/changed edge classification, and corner-closure seeds.
4. Retains the existing full rebuild and local descriptor builder as the correctness path.

The projection helper validates that every selected descriptor has both endpoint Stable IDs. A malformed descriptor fails the plan before any Index publication or live Patch/Collider mutation.

The historical `changed_descriptor_build_usec` profile key remains present and zero-valued for compatibility. New work is measured in `changed_descriptor_projection_usec`. The plan summary reports `local_descriptor_build_count`, `changed_descriptor_build_count` (zero), and `changed_descriptor_projection_count`.

## Regression coverage

The Index test compares projected old/new maps against an independent direct build for:

- Same-Stable-ID Node replacement.
- One-patch addition.
- Pure patch removal.
- Profiled same-Stable-ID replacement with exact phase accounting.

It also checks that local descriptor build counts match a single old/new local pass, changed descriptor build count is zero, projection counts match the resulting maps, and the existing committed Index still matches the full-rebuild Binder oracle after each successful delta.

Existing stale-generation, duplicate-position, remove/re-add, corner graph, transaction rollback, and full-rebuild parity tests remain enabled.

## Files

- `systems/SurfaceTerrainAdjacencyIndex.gd`
- `tests/surface_terrain_adjacency_index_test.gd`
- `tests/surface_chunk_production_benchmark.gd`
- `.github/workflows/surface-terrain-adjacency-index-validation.yml`
- `docs/SURFACE_TERRAIN_INDEX_LOCAL_DESCRIPTOR_REUSE_M0_2_13_15.md`

## Dependencies and import

- Parent PR #321 — selected-edge descriptor build deduplication.
- Godot 4.3.
- Existing `SurfaceTerrainAdjacencyIndex`, `SurfaceTerrainTransitionDescriptor`, and full-rebuild Binder oracle.
- No third-party dependencies, Project Settings, autoloads, scene wiring, save schema or runtime defaults change.
- Root import: `godot --headless --path . --editor --import --quit`.
- Focused Index regression: `godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd`.
- Production benchmark: `godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd`.

## Validation status

At branch creation, no test result is claimed. Required exact-head evidence:

- Focused Index Validation workflow.
- Coordinator and Controller Transaction workflows.
- Production Surface Chunk Benchmark, including profile validation and JSONL artifact inspection.
- Repository-wide Godot 4.3 Full Compatibility Gate.

Compare Radius-8 local descriptor build and changed descriptor projection timings with the M0.2.13.14 baseline, while disclosing runner CPU differences. Structural descriptor-build counts and exact full-rebuild parity are the primary correctness evidence; timing is secondary.

## Limitations

- Headless timing is not rendered FPS, GPU cost, iPhone frame time, device memory or touch QA.
- This optimization removes duplicate descriptor construction; it does not claim to eliminate the complete local descriptor scan or the remaining plan-delta costs.
- PR #352 must remain a Draft child of PR #321 until all exact-head gates pass. No main merge is part of this version.
