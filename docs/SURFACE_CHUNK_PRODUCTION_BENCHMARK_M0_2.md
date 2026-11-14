# Production Surface Chunk Benchmark M0.2 — Boundary Crossing

## Purpose

Extend M0.1's real-production benchmark with a representative one-chunk eastward boundary crossing at radii 1, 2, 3, 4 and 8. Keep the existing distant full-window replacement and radius-zero contraction stress scenarios so the output distinguishes normal movement from worst-case window replacement.

This is measurement-only. No gameplay runtime code, radius cap/default, save schema, mining rule or world content is changed.

## Version and GitHub

- Asset: SurfaceChunkFactory Production Benchmark M0.2.
- Parent PR: [#280 — tolerance-aware terrain adjacency spatial index](https://github.com/qaqp980520-prog/2126-Survival/pull/280).
- Benchmark parent: [#279 — real production SurfaceChunkFactory benchmark](https://github.com/qaqp980520-prog/2126-Survival/pull/279).
- Branch: `perf/surface-chunk-boundary-crossing-benchmark-2026-11-06`.
- Parent base head: `4537e3f2b2b408238caf1be72e426c335c8f8ae8`.
- PR #281 is stacked on PR #280; do not merge it independently to main.

## Files

- `tests/surface_chunk_production_benchmark.gd` — adds one-chunk eastward boundary movement and exact retained/departed root assertions.
- `.github/workflows/surface-chunk-production-benchmark.yml` — expects 15 benchmark JSON records.
- `docs/SURFACE_CHUNK_PRODUCTION_BENCHMARK_M0_2.md` — this version record.

## Benchmark scenarios

For each radius (r \in \{1,2,3,4,8\}\), the harness now emits three records:

1. `expand_stage_commit`: replace the complete active window with a distant window, using the real SurfaceWorld, SurfaceChunkFactory, MineralGridStreamingDirector and MineralChunkController.
2. `boundary_cross_east`: move the target exactly one runtime `chunk_size_x` east. The expected window remains ((2r+1)^2) chunks; exactly (2r+1) roots enter and (2r+1) roots leave. The harness asserts that every overlapping root remains alive, every departing root is released, the Director/Controller ID sets match, and factory calls equal the incoming column size.
3. `contract_unload`: contract the current window to radius zero and verify all non-center roots are released.

The boundary displacement is read from the live Director's `chunk_size_x`; the test does not hard-code the world chunk size.

## Output and dependencies

- 15 `SURFACE_CHUNK_BENCHMARK_JSON:` records per run (three phases × five radii).
- Godot 4.3 root project.
- `world/SurfaceWorld.tscn`, `world/SurfaceWorld.gd`, and `scripts/world.gd`.
- `systems/SurfaceChunkFactory.gd`, `systems/SurfaceTerrainPatch.gd`.
- `systems/MineralGridStreamingDirector.gd`, `systems/MineralChunkController.gd`.
- Production mineral, crop, world-object, adjacency and transition-collider dependencies composed by SurfaceWorld.

## Import and run

From repository root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_chunk_production_benchmark.gd
```

For rendered desktop/device sampling, run without `--headless`:

```sh
godot --path . --script res://tests/surface_chunk_production_benchmark.gd
```

Keep headless and rendered-device results separate. The benchmark workflow uploads the readable log and filtered JSONL artifact.

## Prior optimized full-window evidence

PR #280 exact head `4537e3f2b2b408238caf1be72e426c335c8f8ae8` produced a successful headless real-factory benchmark artifact in run [#42210299402](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/42210299402).

- Radius 1 full-window expansion: 268.709 ms; contraction: 31.628 ms.
- Radius 4 full-window expansion: 4.243 s; contraction: 3.528 s.
- Radius 8 full-window expansion: 50.842 s; contraction: 51.666 s.
- Radius 8 instantiated 51,153 surface subtree nodes and reported 230.1 MB process static memory after expansion.

The earlier baseline run [#42208223651](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/42208223651) reported radius-8 expansion 250.716 s and contraction 242.362 s. However, the baseline runner reported AMD EPYC 7763 while the optimized runner reported AMD EPYC 9V45. These are different CI hosts; treat the timing difference as directional evidence only, not a controlled speedup claim. The spatial-index 20×20 fixture independently reduces adjacency candidate comparisons from 79,800 all-pairs checks to 760 exact candidate checks.

## Validation status and limits

- The new boundary-crossing scenario has not yet completed exact-head CI; no boundary timing or pass is claimed in this version record.
- PR #280's focused spatial-index workflow and optimized full-window benchmark have passed on its own head; its full Godot compatibility gate was still running at this record's creation.
- Headless frame intervals are not GPU frame-time evidence.
- Process static memory is process-wide and may retain resource caches.
- Target-device rendered measurements remain outstanding.
- No production radius cap/default change is proposed. The playable-world default remains radius 1.

## Next steps

1. Complete PR #280's exact-head full Godot gate.
2. Run the new 15-record benchmark on PR #281 and inspect the boundary-crossing records separately from full-window stress records.
3. If a single boundary crossing still creates a long frame, profile the production commit/adjacency/collider path before changing runtime behavior.
4. Repeat the rendered benchmark on target hardware before setting production budgets or changing the radius cap/default.
