# M0.3.17 — Surface Terrain Adjacency Delta Work Counters and Matched Oracle Benchmark

## Scope

This version advances Issue #282 Stage 2 without wiring the staged index into production chunk loading or collider ownership.

It makes the existing delta planner's structural work observable and removes one avoidable full report-bucket count pass.

## Files

- `systems/SurfaceTerrainAdjacencyIndex.gd`
  - Maintains `_corner_report_count` as committed index state.
  - Rebuild initializes the cached count from the full corner graph.
  - Publish installs the candidate count; rollback restores the previous count.
  - `get_corner_graph_stats()` reads the cached count instead of walking every report bucket.
  - `_apply_corner_report_delta()` updates the count from touched Stable-ID buckets and no longer scans all candidate report buckets to recount them.
  - Opt-in `plan_delta_profile_counts` reports shallow map-copy sizes, candidate instance records scanned, report buckets/reports visited, touched report buckets, report records replaced, full-count-scan entries, and old/new closure sizes.
- `tests/surface_terrain_adjacency_index_test.gd`
  - Asserts deterministic profile counters.
  - Verifies the cached corner report count after publish and after rollback.
  - Verifies the report count remains correct after retrying and committing the same delta.
- `tests/surface_terrain_adjacency_delta_benchmark.gd` (new)
  - Runs five matched one-column boundary deltas at radii 1/2/3/4/8.
  - Compares the detached delta candidate with a full Binder + corner resolver + corner graph rebuild on the same candidate patch set and runner.
  - Emits five machine-readable JSONL records with p50/p95/max timings and structural counters.
- `.github/workflows/surface-terrain-adjacency-spatial-index-validation.yml`
  - Runs the new benchmark after the focused index lifecycle test.
  - Uploads the benchmark log and JSONL artifact.

## Dependencies and import

- Godot 4.3 root project.
- `SurfaceTerrainPatch.gd`, `SurfaceTerrainAdjacencyBinder.gd`, `SurfaceTerrainAdjacencyIndex.gd`, `SurfaceTerrainCornerConflictResolver.gd`, and the affected-component planner.
- No new third-party dependency, autoload, Project Settings, save-schema, scene, or production controller dependency.
- The benchmark is invoked by the focused GitHub Actions workflow as `res://tests/surface_terrain_adjacency_delta_benchmark.gd`; it is not a runtime game scene.

## Validation status

The executable code/test/workflow tree at `c9e9384c462fd4e0850a02e41d92617ede1a2a7e` passed the exact-head focused workflow (14/14 steps), matched benchmark (five radii × five samples), Production Surface Chunk Benchmark, and Full Compatibility Gate (559/559 steps). Full logs and the matched benchmark artifact were downloaded and independently audited. The final PR body and Notion Run 427 record carry the authoritative current PR HEAD and validation run IDs.

- Focused workflow: [45591565017](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45591565017).
- Matched benchmark artifact: [15011501719](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45591565017/artifacts/15011501719).
- Production benchmark: [45591564883](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45591564883).
- Full Compatibility Gate: [45591564875](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45591564875).

The matched synthetic radius-8 delta p50 was 60.011 ms vs 111.824 ms for full Binder + resolver + graph rebuild on the same headless runner (46.3% faster); radius 1 was 34.4% slower. At radius 8 the checkerboard closure spanned 272 junctions / 577 edges and visited 2,048 reports; 289 entries and 289 buckets were still shallow-copied. Full report-count recount entries were 0. This is not production/GPU/FPS/mobile evidence or proof of bounded O(Δ) behavior.

Full Gate: 559/559 steps, 78,723 PASS, 0 failed / 0 skipped; 0 actual engine diagnostics, 0 ObjectDB leaks, 0 Orphan StringName. 23 Godot warnings and one Node.js 20 deprecation warning remain and are not claimed fixed.

This version remains a staged standalone primitive; no production controller/collider wiring is included. The final doc-only PR HEAD and its Full Gate result are tracked in PR #435 and the Run 427 Notion record.

## Interpretation and limitations

- The cached report count removes the O(number of report buckets) recount at the end of each corner-report delta and from `get_corner_graph_stats()`.
- The new counters intentionally expose remaining O(N)-class shallow dictionary copies and the full report-bucket scan performed by closure snapshot collection. This version does not claim those costs are eliminated.
- The matched benchmark compares the detached index plan against a full Binder + resolver + graph rebuild on the same candidate set and CI runner. It is headless synthetic terrain, not a production SurfaceWorld transaction, GPU frame time, rendered FPS, mobile result, or target-device performance.
- The index remains a standalone staged primitive. No production MineralChunkController or collider-manager wiring is introduced.
- The full Binder rebuild remains the correctness oracle and recovery path.

## Next step

Use exact-head benchmark counters to decide whether the next optimization should be a junction-to-report reverse index, copy-on-write/overlay maps, or a bounded closure strategy. Preserve full-rebuild parity and transaction rollback before any production controller/collider adoption.
