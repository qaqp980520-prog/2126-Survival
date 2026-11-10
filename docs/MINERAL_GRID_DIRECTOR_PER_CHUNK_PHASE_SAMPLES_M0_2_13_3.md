# Mineral Grid Director Per-Chunk Phase Samples — M0.2.13.3

## Purpose

Refine the async Director profiling added by M0.2.13.1/.2. Aggregate registration and stale-unload durations identify expensive phases, but do not show whether the cost is evenly distributed across chunks or dominated by one slow chunk. This version records one opt-in sample for each Controller operation and validates that the samples reconcile exactly with the aggregate timer.

## Implementation

- `MineralGridStreamingDirector._finish_async_phase_timer()` now returns the exact elapsed microseconds it adds to the aggregate.
- `_record_async_phase_sample()` appends a compact `{chunk_id, duration_usec}` record only when that request captured profiling as enabled.
- Each async request diagnostic includes:
  - `controller_registration_samples`
  - `stale_unload_samples`
- Each successful `load_chunk()` call contributes one registration sample.
- Each `unload_chunk()` call contributes one stale-unload sample, including a failed call so failure-path diagnostics remain useful.
- The benchmark validates sample count, unique non-empty Chunk IDs, non-negative durations, and exact equality between sample-duration sum and the existing aggregate phase duration.
- JSONL records include raw samples plus count, total, min, median, p95, max and slowest Chunk ID summaries.
- The lifecycle workflow source guard checks the new runtime keys and benchmark summarizer.

## Changed files

- `systems/MineralGridStreamingDirector.gd`
- `tests/mineral_grid_streaming_director_test.gd`
- `tests/surface_chunk_production_benchmark.gd`
- `.github/workflows/mineral-grid-streaming-lifecycle-validation.yml`
- `docs/MINERAL_GRID_DIRECTOR_PER_CHUNK_PHASE_SAMPLES_M0_2_13_3.md`

## Dependencies and import

- Godot 4.3.
- Existing `MineralGridStreamingDirector`, `MineralChunkController`, and production `SurfaceWorld` composition.
- No external packages, assets, autoloads, project settings, or scene wiring.
- Profiling remains disabled by default. Per-chunk sample arrays are only appended for requests that explicitly captured profiling as enabled.
- Import: open the repository root with Godot 4.3 or run the existing headless import step; no manual asset import is required.

## Validation contract

The focused Director regression performs a real one-chunk boundary shift with three incoming and three departing chunks, then asserts:

1. Exactly three registration samples and three stale-unload samples are present.
2. Every sample is a Dictionary with a non-empty unique Chunk ID.
3. Every duration is non-negative.
4. Registration sample durations sum exactly to `controller_registration_usec`.
5. Stale-unload sample durations sum exactly to `stale_unload_usec`.
6. Existing aggregate phase totals still fit inside total request duration.

The production Radius-8 benchmark repeats these checks for every profiled async record and emits the raw per-chunk observations and summary statistics to JSONL.

## GitHub version

- Parent PR: #310.
- Parent exact HEAD: `cb4710bccf05209f7b4430faa80dc377c7b7fdf8`.
- Branch: `perf/mineral-grid-director-per-chunk-phase-samples-2026-11-11`.
- New PR: #312 (created after implementation commits).
- PR remains Draft until exact-head focused, lifecycle, benchmark and full Godot 4.3 gates complete.

## Limitations

- Per-chunk samples explain the distribution inside registration and unload aggregates; they do not yet split the internal work performed inside `MineralChunkController.load_chunk()` or `unload_chunk()`.
- Headless timings are not rendered FPS or target-device performance.
- No PhysicsServer allocation fault injection, GPU, iPhone, device-memory, or touch QA is included.
- No production staging-budget default is changed.

## Next step

Use the per-chunk p95/max and slowest Chunk IDs to decide whether Controller registration or stale retirement needs a deeper internal phase profile. Then optimize the measured hot path while preserving the exact Chunk-root, Patch, Index and Collider rollback contract.