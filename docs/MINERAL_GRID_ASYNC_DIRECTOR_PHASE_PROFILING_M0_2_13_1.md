# Mineral Grid Director Async Phase Profiling and Stage-Budget Sweep — M0.2.13.1

## Purpose

Separate intentional process-frame yield latency from the Director's actual asynchronous streaming work, then compare bounded staging budgets of 1, 2, and 4 roots per frame on the same warmed Radius-8 production window.

This version is measurement-only. It does not change the staging budget default, chunk selection, commit ordering, or rollback semantics.

## Changed files

- `systems/MineralGridStreamingDirector.gd`
  - Adds opt-in asynchronous phase profiling, disabled by default.
  - Measures planning, factory calls, staged-root validation, intentional frame waits, Controller registration, staged-root ownership transfer, stale unload, and adjacency-finalize call time.
  - Records the effective `max_staged_per_frame` and exact frame-yield count per request.
- `tests/mineral_grid_streaming_director_test.gd`
  - Adds a real Controller/Director boundary-shift regression.
  - Verifies profiling is off by default, the 1-root budget yields exactly three times for a three-root shift, all timing fields are present and non-negative, and the non-overlapping phase sum does not exceed request duration.
- `tests/surface_chunk_production_benchmark.gd`
  - Enables opt-in profiling for the production benchmark.
  - Sweeps the warmed Radius-8 one-chunk boundary shifts through budgets 1, 2, and 4, with two samples per budget.
  - Emits phase timings and frame-yield counts into the JSONL artifact.
- `.github/workflows/mineral-grid-streaming-lifecycle-validation.yml`
  - Includes the production benchmark and profiling document in its path filters.
  - Verifies the profiling API and frame-wait metric are present before running the Director regression.

## Timing contract

The Director phase timings are disjoint wall-clock intervals:

- `planning_usec`
- `factory_build_usec`
- `staged_validation_usec`
- `frame_yield_wait_usec`
- `controller_registration_usec`
- `staged_root_transfer_usec`
- `stale_unload_usec`
- `adjacency_finalize_call_usec`

Their sum is checked against the request's `duration_usec`. The Controller's `batch_total_usec` is a nested measurement spanning Controller registration, stale retirement, and adjacency finalization; it must not be added to the Director phase sum.

The legacy `async_other_ms` field remains for historical comparability and still includes frame-yield latency. New analysis should use `director_phase_profile_usec` and `director_unattributed_ms`.

## Dependencies / import

- Godot 4.3.
- Existing `MineralGridStreamingDirector.gd`, `MineralChunkController.gd`, `SurfaceTerrainAdjacencyCoordinator.gd`, and production SurfaceWorld scene.
- No external packages, imported assets, autoloads, project settings, or scene wiring changes.

## Validation commands

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/mineral_grid_streaming_director_test.gd
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

## Expected Radius-8 stage-budget samples

For a one-chunk horizontal shift at load radius 8, 17 roots are staged. The expected intentional frame-yield counts are:

| Budget | Expected yields |
|---:|---:|
| 1 | 17 |
| 2 | 8 |
| 4 | 4 |

The benchmark uses two samples per budget on one warmed Runner, alternating east/west shifts. It records total request duration, factory time, Director phase timings, Controller adjacency batch profile, and frame-interval samples. No cross-runner speedup claim is allowed.

## Limitations

- Linux Headless timings are not rendered FPS or device-performance results.
- The benchmark still uses a benchmark-only 2×2 checkerboard fixture to ensure non-zero Edge and Corner Cap resources.
- PhysicsServer-internal allocation failure, GPU/rendered FPS, iPhone, device memory, and touch QA are not covered.
- Same-Node in-place terrain-state edits still use the authoritative full Binder fallback.
- Keep the PR Draft and unmerged until exact-head focused, benchmark, and full Godot 4.3 gates pass and the parent PR chain receives independent review.
