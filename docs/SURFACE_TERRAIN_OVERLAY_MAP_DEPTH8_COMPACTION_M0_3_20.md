# Surface Terrain Overlay Depth-Eight Compaction Validation — M0.3.20

## Purpose

Close the M0.3.19 validation gap: the original overlay microbenchmark measured only depth-one staging and did not measure the periodic depth-eight compaction path. This version adds an explicit depth-eight contract and a matched nine-transaction benchmark.

## Files

- `systems/SurfaceTerrainOverlayMap.gd` — unchanged prototype implementation from M0.3.19.
- `tests/surface_terrain_adjacency_index_test.gd` — verifies the depth-eight fork materializes once, resets the new parent to depth zero, creates a depth-one child, transfers the flattened Dictionary without a second shallow copy, and leaves the sealed source snapshot unchanged.
- `tests/surface_terrain_adjacency_delta_benchmark.gd` — adds four depth-eight compaction fixtures at 225, 576, 2,048, and 8,192 entries. Each fixture uses seven samples and nine matched transactions; the ninth fork triggers exactly one depth-eight compaction.
- `docs/SURFACE_TERRAIN_OVERLAY_MAP_DEPTH8_COMPACTION_M0_3_20.md` — this record.

## Matched benchmark protocol

Each sample performs nine sequential transactions on both paths:

- eight replacements;
- four removals;
- four insertions;
- 32 single-call lookups using the same key sequence and missing-key sentinel.

The Dictionary baseline performs a shallow duplicate and the same edits/lookups on every transaction. The overlay path performs bounded forks and the same edits/lookups; its ninth fork compacts the depth-eight chain. The initial root setup is outside the timed interval on both paths.

Recorded separately:

- cumulative nine-transaction Dictionary time;
- cumulative nine-transaction overlay time, including the depth-eight compaction;
- the ninth fork's compaction latency;
- per-transaction lookup checksum parity;
- final materialized Dictionary parity and cached-size parity.

The benchmark emits a distinct `SURFACE_TERRAIN_OVERLAY_COMPACTION_BENCHMARK_JSON:` log prefix. It does not change the existing six-record `SURFACE_TERRAIN_ADJACENCY_DELTA_BENCHMARK_JSON:` artifact contract.

## Dependencies and execution

- Godot 4.3 root project; no third-party packages, autoloads, scenes, Project Settings, runtime controller wiring, or save-schema changes.
- Existing focused workflow: `Surface Terrain Adjacency Spatial Index Validation`.
- Run the contract suite with:

```sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd
```

- Run both the original matched benchmark and the depth-eight compaction benchmark with:

```sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_delta_benchmark.gd
```

## Run 431 diagnostic correction

The first Run 431 focused benchmark log exposed a pre-existing helper defect: the depth-one checksum helpers compared a Dictionary value directly with a String sentinel before checking its type. Godot 4.3 emitted repeated `Invalid operands 'Dictionary' and 'String' in operator '!=' ` Script Errors, even though the benchmark script still returned exit code zero. The helpers now use a Dictionary type check directly, and the focused workflow explicitly fails if the benchmark log contains `SCRIPT ERROR`, `ERROR:`, or `FAIL:`. The earlier Run 431 artifact is retained as a failed diagnostic checkpoint and is not accepted as final evidence.

## Safety and limitations

- This remains an isolated data-structure prototype; it is not wired into SurfaceTerrainAdjacencyIndex or MineralChunkController.
- The map is shallow. Nested Array/Dictionary values remain shared; callers must treat them as immutable or clone before mutation.
- Root construction, materialization, and compaction remain O(N). This benchmark measures the periodic compaction cost and amortized nine-transaction path; it does not prove the full Index planner is O(Δ).
- The full Binder rebuild remains the production correctness and recovery oracle.
- Headless microbenchmark timings are runner-specific. They are not rendered FPS, GPU, mobile, or target-device evidence.
- No result is considered validated until focused, production, and full Godot 4.3 workflows pass on the exact final PR HEAD and the new artifact is independently parsed.

## Provenance

- Parent PR #436 exact HEAD: `84b688b969b170b6466837c6803be5830c594201`.
- PR #438 branch: `perf/terrain-adjacency-overlay-map-prototype-2026-11-25-run430`.
- Pre-change HEAD: `d9de894265114a783de2e0faf4b2752d428b2d65`.
- Backup branch: `backup/pr438-before-depth8-compaction-2026-11-25-run431`.
- M0.3.19 exact-head validation is recorded in Run 430; this version supersedes only the missing depth-eight contract/benchmark coverage, not the earlier depth-one measurements.
