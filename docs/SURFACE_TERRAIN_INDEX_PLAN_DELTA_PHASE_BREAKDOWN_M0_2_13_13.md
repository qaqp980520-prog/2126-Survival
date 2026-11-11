# Surface Terrain Index plan_delta Phase Profiling — M0.2.13.13

## Purpose

M0.2.13.12 reduced repeated candidate-instance scans from O(K × P) to O(P + K). The existing Coordinator profile showed that Index planning remained the largest measured phase, but it did not identify which part of `SurfaceTerrainAdjacencyIndex.plan_delta()` dominated. This version adds opt-in, non-overlapping subphase timings so the next optimization is selected from measured evidence rather than guesswork.

## Instrumented phases

| Key | Work measured |
| --- | --- |
| `candidate_copy_usec` | Shallow candidate entry and bucket Dictionary copies. |
| `removal_apply_usec` | Removal-ID validation and candidate entry/bucket updates. |
| `candidate_instance_set_usec` | Build the post-removal instance-ID set once. |
| `addition_validation_usec` | Validate additions, Patch records, size and duplicate positions. |
| `neighbor_discovery_usec` | Discover touched cardinal neighbors for removed and added IDs. |
| `changed_descriptor_build_usec` | Build old and candidate descriptors for directly changed IDs. |
| `edge_diff_usec` | Compare old/new changed-edge descriptor maps. |
| `local_descriptor_build_usec` | Build old and candidate descriptors for the touched local component. |
| `corner_graph_delta_usec` | Build local corner reports and apply the persistent corner-graph delta. |
| `closure_snapshot_usec` | Build the old/new union closure and collect closure descriptors/reports. |
| `plan_storage_usec` | Sort and copy the plan summary and store the pending candidate snapshot. |

The profile also contains `total_usec` and `unattributed_usec`. The latter is calculated as total minus the sum of the eleven measured phases. The phases are sequential and non-overlapping; the total covers the complete `plan_delta()` call from entry through pending-plan storage.

## Runtime behavior

- Profiling is opt-in through the existing Controller terrain-adjacency profiling switch.
- `SurfaceTerrainAdjacencyCoordinator.execute_delta()` requests the Index profile only when profiling is enabled.
- The Controller carries the nested Index profile into its existing production adjacency profile.
- The production benchmark emits top-level `plan_delta_phase_profile_valid`, `plan_delta_phase_profile_usec`, and `plan_delta_phase_total_ms` fields in each JSONL record.
- Normal gameplay keeps profiling disabled; no Project Settings, save schema, scene wiring, autoload, external package, or public gameplay API changes are introduced.
- Successful no-op plans can also return a profile when explicitly enabled. Failed validation paths return their original error and do not promise a complete phase profile.

## Regression coverage

The Index regression verifies:

1. Profiling is absent by default.
2. An explicitly profiled no-op returns every phase with non-negative values and an exact remainder.
3. A real adjacent Patch replacement returns all eleven phases.
4. Measured phases do not exceed the total and the unattributed remainder is exact.
5. The prepared plan can still be aborted without publication.

The production benchmark independently requires all eleven subphases on each of the 23 incremental JSONL records, checks the exact remainder, and verifies that the Index profile total does not exceed the enclosing Coordinator plan phase. The synchronous full-binder resource-reuse record is intentionally non-incremental and does not require an Index delta profile.

## Dependencies and import

- Godot 4.3.
- Existing `SurfaceTerrainAdjacencyIndex`, `SurfaceTerrainAdjacencyCoordinator`, `MineralChunkController`, and production SurfaceWorld benchmark fixture.
- No external dependencies.
- From repository root: `godot --headless --path . --import`.
- Focused Index regression: `godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd`.
- Production benchmark: `godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd`.

## Validation status before this version

Parent PR #319 exact HEAD `8ced3b9f2e1d75ba54bd8dc96f5fb5ecf43dff00` completed its five exact-head workflows:
- Index Validation #42977840696: 9/9.
- Production Benchmark #42977840645: 11/11.
- Coordinator #42977840705: 10/10.
- Controller Transaction #42977840603: 11/11.
- Full Godot 4.3 Gate #42977840632: 554/554, 0 failures, 0 skipped.

Parent Artifact 13835798346 contains 24 JSONL records and 432 PASS, with 23/23 valid incremental Coordinator profiles. Its Radius-8 median `plan_delta_usec` was 41.926 ms and Coordinator total was 79.2895 ms on Linux Headless / AMD EPYC 9V74 / 4 vCPU. The earlier PR #318 baseline was 62.542 ms / 97.0965 ms on the same CPU model and vCPU count but a different Runner instance; this is directional only, not a controlled A/B or causal speedup claim.

This version's new Index subphase timings have not yet been collected. Local Godot is unavailable; exact-head engine tests must run on GitHub Actions Godot 4.3. Headless results do not validate rendered FPS, GPU behavior, iPhone memory, touch input, or PhysicsServer deep allocation failures.

## Next step

Use the exact-head production JSONL to identify the dominant `plan_delta()` subphase. Optimize only a measured hotspot, preserve full-rebuild oracle parity, duplicate-ID/position checks, generation reservation, rollback, and stale-snapshot behavior, then repeat the exact-head focused and full compatibility gates.
