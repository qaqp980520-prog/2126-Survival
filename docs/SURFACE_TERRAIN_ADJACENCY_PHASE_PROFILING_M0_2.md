# Terrain Adjacency Phase Profiling M0.2

## Purpose

Extend the M0.1 opt-in phase profiler with repeated, same-runner production boundary-crossing samples at the maximum configured radius. The original 15 expansion, one-chunk boundary and contraction records remain unchanged; four additional radius-8 transactions alternate west/east before the final contraction, producing 19 JSONL records total.

This gives five radius-8 boundary observations in one benchmark process (the original eastward crossing plus four alternating repeats) while keeping the real production SurfaceWorld, SurfaceChunkFactory, MineralGridStreamingDirector and MineralChunkController active.

## Version and GitHub

- Version: Terrain Adjacency Phase Profiling M0.2.
- PR: [#284 — Profile terrain adjacency and collider phases in production benchmark](https://github.com/qaqp980520-prog/2126-Survival/pull/284).
- Parent: [#283 — Batch terrain adjacency rebuilds during async chunk-window commits](https://github.com/qaqp980520-prog/2126-Survival/pull/283).
- Branch: `perf/terrain-adjacency-phase-profiling-2026-11-07`.
- Base implementation: `d8216539b14e2712734204f5815aa8540dc71761`.
- M0.2 adds four alternating radius-8 boundary transactions and changes the benchmark workflow's expected JSONL record count from 15 to 19.

## Files

- `tests/surface_chunk_production_benchmark.gd`: four additional radius-8 boundary transactions alternate west/east; each checks exact active IDs, Director/Controller parity, one adjacency rebuild, incoming/outgoing root counts, production factory calls, departing-root release and retained-root lifetime.
- `.github/workflows/surface-chunk-production-benchmark.yml`: requires exactly 19 JSONL records and retains the existing completion-marker assertion.
- `docs/SURFACE_TERRAIN_ADJACENCY_PHASE_PROFILING_M0_2.md`: this version record.

## Dependencies and import

Godot 4.3 root project; production SurfaceWorld; MineralGridStreamingDirector; MineralChunkController; SurfaceTerrainAdjacencyBinder; SurfaceTerrainTransitionColliderManager; SurfaceChunkFactory and existing world-object, mineral and crop dependencies.

From repository root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

The existing Production Surface Chunk Benchmark workflow uploads the log and JSONL artifact.

## Repeated-trial design

At radius 8, after the baseline eastward crossing, the benchmark performs four additional one-chunk shifts in this order:

1. West
2. East
3. West
4. East

Each shift stages and retires exactly 17 surface chunk roots, keeps the 272 overlapping roots alive, and must commit exactly one terrain-adjacency rebuild. The final position returns to the baseline eastward window, so the existing contraction fixture remains valid.

The JSONL phase values are tagged:
- `boundary_cross_repeat_1_west`
- `boundary_cross_repeat_2_east`
- `boundary_cross_repeat_3_west`
- `boundary_cross_repeat_4_east`

The baseline 15 scenarios remain present; total output is 19 records.

## Validation

Pending exact-head Godot 4.3 and production benchmark workflows for the M0.2 commits. Do not infer success from M0.1 results.

Acceptance requires:
- Exactly 19 valid JSONL records.
- All four repeated radius-8 transactions complete.
- Each repeated transaction commits one adjacency rebuild.
- Each repeated transaction stages/commits/retires exactly 17 roots.
- Director and Controller active IDs match after every move.
- Departing roots are released and overlapping roots remain alive.
- All phase timing fields are non-negative and aggregate timing checks pass.
- Full Godot 4.3 compatibility gate passes.

## Limitations and next step

- These are repeated transactions within one Headless process, not independent cold-start process runs.
- Alternating direction reduces one-way cache/order bias but does not replace multiple workflow executions on the same runner class.
- Headless timings are not GPU frame-time or iPhone/device measurements.
- Profiling remains opt-in and disabled during normal gameplay.
- This is still measurement instrumentation; local-neighborhood incremental adjacency remains unimplemented.
- Use the five radius-8 boundary samples to compare medians/ranges within the same process, then run multiple exact-head workflow executions before setting budgets or claiming a speedup.
- Preserve the full binder/collider rebuild as the correctness oracle and rollback fallback for Issue #282.
