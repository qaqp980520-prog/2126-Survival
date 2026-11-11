# Surface Terrain Selected-Edge Descriptor Build Deduplication — M0.2.13.14

## Motivation and measured baseline

PR #320 added opt-in subphase profiling to `SurfaceTerrainAdjacencyIndex.plan_delta()`. Its corrected exact-head Production Benchmark Artifact 13837748409 contains 24 JSONL records, 455 PASS, 0 FAIL / SCRIPT ERROR / Engine ERROR, and 23/23 valid incremental Index profiles.

On Linux Headless / AMD EPYC 9V45 / 4 vCPU, the nine Radius-8 boundary-crossing samples had these medians:

- `plan_delta`: 33.670 ms.
- `local_descriptor_build_usec`: 10.903 ms.
- `changed_descriptor_build_usec`: 8.845 ms.
- `neighbor_discovery_usec`: 6.000 ms.
- Coordinator total: 63.627 ms.

The profile is a baseline, not rendered FPS and not a causal A/B against a different Runner.

## Identified duplicate work

`_build_descriptors_for_ids()` iterates each selected Stable ID and discovers its cardinal neighbors. When both endpoints of the same undirected edge are in `selected_ids`, the current loop calls `TransitionDescriptorScript.build()` from both endpoints and only deduplicates by `edge_key` after the expensive build.

This is especially relevant to the local descriptor phase because `touched_ids` includes changed patches and their cardinal neighbors.

## Implementation

For a neighbor that is also selected, only the lexically smaller Stable ID builds the undirected edge:

```gdscript
if selected_ids.has(neighbor_id) and stable_id > neighbor_id:
    continue
```

If the neighbor is not selected, the current selected endpoint still builds the edge. The descriptor builder continues to canonicalize endpoints and compute the same edge key. The helper now returns `descriptor_build_count` for direct regression assertions; existing callers continue to consume the `descriptors` dictionary unchanged.

## Regression coverage

The Index test uses the existing real adjacent Patch fixture and verifies:

1. When both endpoints of each selected edge are in the selected set, exactly one descriptor build occurs per undirected edge.
2. The deduplicated descriptor dictionary equals the committed Index descriptor dictionary.
3. When only the center endpoint is selected, its edges to unselected cardinal neighbors are still built.
4. The single-endpoint descriptor set also equals the committed Index.
5. Existing full-rebuild oracle, duplicate position, stale snapshot, replacement, remove/re-add, corner graph and rollback regressions remain in the same suite.

## Files

- `systems/SurfaceTerrainAdjacencyIndex.gd`
- `tests/surface_terrain_adjacency_index_test.gd`
- `.github/workflows/surface-terrain-adjacency-index-validation.yml`
- `docs/SURFACE_TERRAIN_INDEX_SELECTED_EDGE_DESCRIPTOR_DEDUP_M0_2_13_14.md`

## Dependencies and import

- Godot 4.3.
- Existing SurfaceTerrainAdjacencyIndex, SurfaceTerrainTransitionDescriptor, SurfaceTerrainPatch and full-rebuild oracle fixtures.
- No external dependencies, autoloads, Project Settings, scene wiring or save-schema changes.
- Repository root: `godot --headless --path . --import`.
- Focused Index regression: `godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd`.
- Production benchmark: `godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd`.

## GitHub dependency and validation status at branch creation

- Child branch: `perf/terrain-index-deduplicate-selected-edge-builds-2026-11-11`.
- Base: PR #320 corrected HEAD `7aad36ab6fe0d1c340945aaebd13aa3c84cc1c57`.
- Parent PR #320 is Open / Draft / Unmerged. Its corrected-head Index, Coordinator, Controller, lifecycle, Run103/104/105–107 and Production Benchmark workflows succeeded. Full Gate #42982689848 was still in progress at 231/553, 0 failures at the last read; no parent full-gate pass is claimed at branch creation.
- Parent PR #319 exact HEAD `8ced3b9f2e1d75ba54bd8dc96f5fb5ecf43dff00` completed Full Gate 554/554 and all five exact-head workflows.
- main remains `fbf2b8a971cd5ff04946b0e0316da6576c685b5e`; no main modification or merge.

## Validation requirements and limitations

This child PR has not yet been opened or tested at the time this document is created. Its exact-head Index regression, Coordinator and Controller gates, Production Benchmark and full Godot 4.3 gate must pass before the optimization is considered validated.

Compare Radius-8 `local_descriptor_build_usec` and `changed_descriptor_build_usec` medians with the PR #320 baseline. Runner variance must be disclosed; the structural build-count regression is the primary evidence.

Headless tests do not validate rendered FPS, GPU behavior, iPhone memory, touch input or PhysicsServer deep allocation failures.

## Next step

Open a Draft child PR targeting PR #320's branch, run exact-head CI, download and parse the benchmark Artifact, and verify that descriptor build counts and full-rebuild parity remain correct. Do not merge main; preserve the parent PR order and keep both PRs Draft until review and all required gates are complete.
