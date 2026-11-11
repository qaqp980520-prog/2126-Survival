# Surface Terrain Index Plan-Delta Instance Set — M0.2.13.12

## Motivation and measured baseline

PR #318 added opt-in Coordinator phase profiling. Its exact-head production benchmark Artifact 13836460269 contains 24 JSONL records; 23/23 incremental records have valid Coordinator profiles, 432 PASS, and zero FAIL / SCRIPT ERROR / Engine ERROR lines.

On the Linux Headless AMD EPYC 7763 / 4-vCPU runner, the median of the eight Radius-8 boundary-repeat samples was:

- `plan_delta_usec`: 62.542 ms.
- Coordinator total: 97.0965 ms.
- Candidate Patch-map materialization: 3.865 ms.
- Candidate descriptor snapshot: 1.838 ms.
- Collider prepare: 7.457 ms.
- Scoped prepare: 4.434 ms.
- Scoped apply: 3.517 ms.
- Index publish: 6.913 ms.

The Index `plan_delta` phase accounts for about 64% of the measured Coordinator total. This version addresses one clearly avoidable repeated scan inside that phase; it does not claim to remove all remaining plan cost.

## Change

### Build the candidate instance set once

Previously, each addition called `_contains_instance(candidate_entries, instance_id)`, which iterated all candidate records. With P existing Patches and K incoming additions, duplicate-instance validation could perform O(K × P) record checks.

After removals are applied, the Index now builds `candidate_instance_ids` once by iterating the remaining candidate entries. Every incoming Patch then uses a Dictionary membership check and is added to that set. The expected work becomes O(P + K), while preserving the post-removal semantics:

- A Node still present in the candidate Index cannot be added under another Stable ID.
- A Node repeated within the same additions array is rejected.
- A Node removed earlier in the same plan may be re-added, including under the same Stable ID.
- Duplicate Stable-ID and duplicate-position validation remain unchanged.

### Reuse the committed patch-size invariant

The old `_first_patch_size(candidate_entries)` used `entries.values()[0]`, materializing an Array of all values to read one record. The Index already maintains `_patch_size` as a committed invariant through rebuild, publish, and rollback.

The candidate now uses `_patch_size` when entries remain after removals, or `-1.0` when the candidate is empty and its first addition must establish a new size. An invalid committed size with non-empty entries fails closed as `committed_patch_size_invalid`.

## Files

- `systems/SurfaceTerrainAdjacencyIndex.gd`
- `tests/surface_terrain_adjacency_index_test.gd`
- `.github/workflows/surface-terrain-adjacency-index-validation.yml`
- `docs/SURFACE_TERRAIN_INDEX_PLAN_DELTA_INSTANCE_SET_M0_2_13_12.md`

## Regression coverage

- Existing committed Patch instance cannot be reused under a second Stable ID.
- One Node repeated twice in the same additions array is rejected.
- Remove/re-add of the same Node remains valid because the instance set is built after removals.
- Removing the last Patch commits an empty Index.
- A new Patch size is accepted after the Index becomes empty.
- Further additions using the new committed size succeed.
- A later mixed-size candidate is still rejected.
- The full-rebuild oracle and existing rollback / stale-snapshot tests remain in the same Index regression script.

## Dependencies and import

- Godot 4.3.
- Existing SurfaceTerrainAdjacencyIndex, SurfaceTerrainAdjacencyBinder, SurfaceTerrainAffectedComponentPlanner, SurfaceTerrainCornerConflictResolver, and SurfaceTerrainTransitionDescriptor.
- No external packages, autoloads, Project Settings, scene wiring, or save-schema changes.
- From repository root: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd`.

The Index validation workflow is also switched from editor-quit import to the deterministic `--import` barrier.

## Validation status

- Static source review: completed.
- Local Godot execution: unavailable in the current working environment; no local engine pass is claimed.
- Required exact-head evidence: Index regression, Production Benchmark, and full Godot 4.3 compatibility CI on the child PR.
- The PR #318 benchmark is the pre-change baseline. Child timing is a directional comparison across separate runner instances, not a controlled same-runner A/B. Do not claim a definitive speedup unless repeated controlled measurements support it.

## Next step

Inspect the child benchmark's Radius-8 `plan_delta_usec` and overall Coordinator medians. If the repeated instance scan was material, retain the change; then profile the remaining Index subphases before attempting broader copy-on-write or corner-graph redesign. Preserve all duplicate-instance, empty-index, generation, and rollback invariants.
