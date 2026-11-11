# Surface Terrain Coordinator Phase Profiling — M0.2.13.11

## Purpose

Expose the internal cost of one successful incremental terrain adjacency transaction. The previous production benchmark measured the complete Coordinator call and the Collider Manager's own sub-phases, but it could not distinguish Index planning, candidate snapshot materialization, scoped Patch preparation, publication, and finalization.

This version adds an opt-in phase profile to `SurfaceTerrainAdjacencyCoordinator.execute_delta()` and carries it through `MineralChunkController.get_last_terrain_adjacency_profile()` into the production JSONL benchmark.

## Files

- `systems/SurfaceTerrainAdjacencyCoordinator.gd`
  - Measures each non-overlapping transaction phase.
  - Adds `coordinator_profile_usec` to a successful, finalized, profiled result.
  - Keeps profiling disabled unless the caller passes `profile_enabled=true`.
- `systems/MineralChunkController.gd`
  - Copies Coordinator phase values into the existing terrain adjacency profile.
  - Reports whether a Coordinator profile was present.
- `tests/surface_terrain_adjacency_coordinator_test.gd`
  - Confirms default-off behavior.
  - Runs a real three-participant replacement with profiling enabled.
  - Verifies every phase is non-negative, the phase sum does not exceed total time, and the unattributed remainder is exact.
- `tests/surface_chunk_production_benchmark.gd`
  - Validates the Coordinator phase profile for incremental records.
  - Emits the per-phase values into each JSONL record.
- `.github/workflows/mineral-chunk-controller-batch-index-snapshot-validation.yml`
  - Adds source guards and includes the production benchmark in the focused workflow path filter.
- `.github/workflows/surface-chunk-production-benchmark.yml`
  - Adds source guards for the Coordinator profile payload before running the real-factory benchmark.

## Phase fields

All values are integer microseconds:

- `plan_delta_usec`
- `index_reservation_usec`
- `candidate_patch_map_usec`
- `candidate_descriptor_snapshot_usec`
- `collider_prepare_usec`
- `scoped_prepare_usec`
- `scoped_apply_usec`
- `collider_accept_usec`
- `index_publish_usec`
- `collider_commit_usec`
- `scoped_finalize_usec`
- `index_finalize_usec`
- `total_usec`
- `unattributed_usec`

The candidate snapshot fields are intentionally separate: the first measures WeakRef resolution into the candidate Stable-ID-to-Node map; the second measures the Index's candidate descriptor snapshot retrieval/copy.

The measured phases are sequential and must not overlap. The benchmark checks:

`sum(phase_usec) <= total_usec`

and

`unattributed_usec == total_usec - sum(phase_usec)`.

The Coordinator total must also fit inside the outer Controller rebind duration.

## Dependencies and runtime behavior

- Godot 4.3.
- Existing Index, Scoped Transaction, Collider Manager, and MineralChunkController participant APIs.
- Profiling is opt-in. Normal gameplay leaves `profile_enabled=false`, so no phase clock reads or profile dictionary allocation are added to the normal path.
- The profile is currently attached to successful, finalized, non-noop three-participant transactions. Early error returns, no-op plans, and Index-only transactions do not yet emit this profile.
- The existing Collider Manager profile remains separate and can be compared with `collider_prepare_usec` and `collider_commit_usec`; do not add overlapping totals together.

## Import and test procedure

From the repository root:

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/surface_terrain_adjacency_coordinator_test.gd
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

The GitHub focused workflow runs the Controller integration test, Coordinator transaction test, and import/clean-workspace checks. The production benchmark workflow validates the JSONL phase accounting.

## Validation status for this version

- Static source review: completed.
- Local Godot execution: unavailable in the current working environment; do not treat static review as an engine test.
- Required engine evidence: GitHub Actions Godot 4.3 focused and production benchmark runs on this branch.
- No main merge is authorized by this asset record.

## Next step

Use the new Radius 8 benchmark samples to compare `plan_delta_usec`, `candidate_patch_map_usec`, `candidate_descriptor_snapshot_usec`, `collider_prepare_usec`, and `scoped_prepare_usec`. Only optimize a phase after the same-runner measurements show it is material, and preserve the existing three-participant rollback and generation invariants.
