# Terrain Adjacency Phase Profiling M0.1

## Purpose

Expose opt-in phase timings for the existing asynchronous terrain-adjacency batch commit so Issue #282 can target measured work rather than attributing the entire non-factory duration to adjacency.

Profiling is disabled by default. The production benchmark explicitly enables it on the real SurfaceWorld controller, captures one profile after each async expansion, boundary crossing and contraction, and emits the profile into the existing JSONL artifact.

## Files

- `systems/MineralChunkController.gd`: opt-in profiling switch, defensive profile snapshot, loaded-patch collection, stable-ID map and total rebind timings.
- `systems/SurfaceTerrainAdjacencyBinder.gd`: validation, cardinal-neighbor discovery and live edge-application timings.
- `systems/SurfaceTerrainTransitionColliderManager.gd`: candidate geometry, corner resolution, resource staging and activation/commit timings.
- `tests/surface_chunk_production_benchmark.gd`: asserts profiling is disabled by default, enables it for the benchmark, validates non-negative phase values and consistent aggregate totals, and writes phase data into each JSONL record.
- `docs/SURFACE_TERRAIN_ADJACENCY_PHASE_PROFILING_M0_1.md`: this version record.

## Profile fields

All durations are integer microseconds.

- `collect_loaded_patches_usec`
- `stable_id_map_usec`
- `binder_total_usec`
- `binder_validation_usec`
- `binder_adjacency_discovery_usec`
- `binder_edge_apply_usec`
- `collider_sync_total_usec`
- `collider_candidate_geometry_usec`
- `collider_corner_resolution_usec`
- `collider_resource_staging_usec`
- `collider_activation_commit_usec`
- `controller_rebind_total_usec`
- `batch_total_usec`

Each benchmark JSONL record also reports `terrain_adjacency_batch_ms` and `async_other_ms`. The latter is a residual of the request duration after subtracting measured factory build and adjacency batch time; it is not a single isolated subsystem and still includes staging, frame waits, registration, persistence and other Director/controller work.

## Dependencies and import

Godot 4.3 root project; production SurfaceWorld; MineralGridStreamingDirector; MineralChunkController; SurfaceTerrainAdjacencyBinder; SurfaceTerrainTransitionColliderManager; SurfaceChunkFactory and its world-object, mineral and crop dependencies.

From repository root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

The existing Production Surface Chunk Benchmark GitHub Actions workflow collects the JSONL output; no new workflow is required.

## Safety and limitations

- Profiling is opt-in and disabled in normal gameplay unless a caller explicitly enables it.
- The instrumentation measures the current full-set binder/collider pipeline; it does not implement local-neighborhood incremental updates.
- Timings are diagnostic observations, not performance budgets.
- Headless CI timings are not GPU frame-time or iPhone/device measurements.
- The async transaction profile excludes staging work performed before the commit batch and excludes per-frame waits; use `async_other_ms` only as an aggregate residual, not as a named subsystem cost.
- The synchronous `sync_to_world_position()` path remains unchanged.
- Local Godot is unavailable in this environment; exact-head validation must come from cloud Godot 4.3 CI.

## Validation state

Pending exact-head GitHub Actions for the branch `perf/terrain-adjacency-phase-profiling-2026-11-07`, stacked on PR #283 head `389afed9867e4e0aa072db2a9c12fac08b2ded3f`.

The benchmark must confirm all 15 production transactions emit complete non-negative phase profiles, aggregate timing relationships hold, and the existing one-rebuild-per-transaction, root lifetime and Director/Controller ownership assertions remain green.

## Next step

Use same-runner repeated trials to identify whether stable-ID map construction, binder validation/discovery/application, or collider geometry/corner/staging/activation dominates. Only then design the Issue #282 local-neighborhood update, retaining full rebuild as the correctness oracle and rollback fallback.
