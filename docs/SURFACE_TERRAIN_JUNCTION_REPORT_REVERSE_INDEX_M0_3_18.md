# M0.3.18 — Surface Terrain Junction-to-Report Reverse Index

## Scope

Continue Issue #282 Stage 2 by replacing the full Stable-ID report-bucket scan used to snapshot affected corner reports with a committed Junction-to-Stable-ID reverse index.

The index remains a standalone staged primitive. No production controller/collider wiring is included.

## Files

- `systems/SurfaceTerrainAdjacencyIndex.gd`
  - Builds `junction_to_report_stable_ids` during a full rebuild.
  - Maintains the reverse index and cached membership count through detached delta planning, publish, rollback, and finalize.
  - Updates only arrays for Junctions touched by changed Stable IDs.
  - Collects closure reports by resolving Stable IDs from selected Junctions rather than walking every report bucket.
  - Adds counters for reverse Junction lookups, top-level map copies, copied arrays, and added/removed memberships.
- `tests/surface_terrain_adjacency_index_test.gd`
  - Compares the reverse index with an oracle derived from the committed report cache after rebuild, publish, rollback, and retry/commit.
  - Checks cached reverse-index membership counts.
  - Replaces the previous full-scan counter expectation with exact reverse-index visit counts.
- `tests/surface_terrain_adjacency_delta_benchmark.gd`
  - Retains five matched contiguous checkerboard boundary fixtures at radii 1/2/3/4/8.
  - Adds a sparse localized fixture with nine disconnected 5×5 islands (225 patches total), replacing one center patch for five matched samples.
  - Compares descriptors, corner reports, graph links, refcounts, reverse index, and membership count with the full Binder + resolver + graph rebuild oracle.
  - Asserts the localized fixture visits fewer report buckets and report records than a full scan.
- `.github/workflows/surface-terrain-adjacency-spatial-index-validation.yml`
  - Expects six JSONL benchmark records: five contiguous radii plus one sparse localized fixture.

## Dependencies and import

- Godot 4.3 root project.
- `SurfaceTerrainPatch.gd`, `SurfaceTerrainAdjacencyBinder.gd`, `SurfaceTerrainTransitionDescriptor.gd`, `SurfaceTerrainCornerConflictResolver.gd`, and `SurfaceTerrainAffectedComponentPlanner.gd`.
- No third-party dependencies, autoloads, scenes, Project Settings, save-schema, or production controller changes.
- Focused workflow entry point: `res://tests/surface_terrain_adjacency_index_test.gd` and `res://tests/surface_terrain_adjacency_delta_benchmark.gd`.

## Parent and version

- Parent PR #435 exact base HEAD: `8ccc8844f8343b22eddeeff09259b42c0810cd60`.
- Branch: `perf/terrain-adjacency-reverse-report-index-2026-11-25-run428`.
- Exact-head validation: pending; no pass is claimed until focused, benchmark, production benchmark, and Full Compatibility Gate runs finish and their logs are audited.

## Correctness and performance interpretation

The reverse index removes the full report-bucket traversal from closure snapshot collection for sparse/localized changes. It does **not** yet prove bounded O(Δ) planning:

- The top-level candidate entries, spatial buckets, corner maps, and reverse-index dictionary are still shallow-copied.
- The corner graph closure can legitimately span a large connected component.
- The full Binder rebuild remains the correctness and recovery oracle.
- The benchmark is headless synthetic terrain, not a production SurfaceWorld, GPU, rendered FPS, mobile, or target-device speedup claim.

## Next step

Use the sparse fixture and reverse-index counters to evaluate persistent/overlay maps for the remaining O(N)-class top-level copies. Keep exact full-rebuild parity and publish/rollback tests before introducing a transactional coordinator or production MineralChunkController/collider-manager adoption.
