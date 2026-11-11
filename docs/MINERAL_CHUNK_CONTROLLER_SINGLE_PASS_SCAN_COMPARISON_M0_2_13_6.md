# Mineral Chunk Controller Single-Pass Scan Comparison — M0.2.13.6

## Purpose

The M0.2.13.5 implementation changed candidate Chunk discovery from three independent depth-first traversals to one combined traversal. The first child benchmark artifacts showed runner-to-run variation large enough that cross-run aggregate timings could not establish a reliable speedup.

This version adds an in-process A/B comparison. Both algorithms traverse the exact same synthetic Chunk tree in the same Godot process, with five warm-up iterations and forty measured iterations per algorithm. Measurement order alternates to reduce systematic order bias.

## Implementation

- Extend `tests/surface_chunk_production_benchmark.gd` with a deterministic 521-node tree:
  - one root;
  - eight groups;
  - sixty-four child nodes per group;
  - typed Mineral, Crop Plot, Stateful World Object, and generic Node3D instances.
- Compare the legacy path (`_collect_mineral_nodes`, `_collect_crop_plots`, `_collect_world_state_nodes`) against `_collect_chunk_content_nodes`.
- Validate all three output dictionaries for exact key and Node-reference parity before timing.
- Run five warm-ups and forty alternating measurements for each algorithm.
- Emit per-algorithm count, total, median, p95, minimum, maximum, and median ratio in the existing Radius-8 expansion JSONL record. The benchmark keeps the existing 24-record contract.
- Add a workflow source guard and require the comparison payload in the uploaded JSONL.
- Extend `tests/mineral_chunk_controller_test.gd` with separate invalid-path regressions for Mineral, Crop Plot, and Stateful World Object categories.

## Changed files

- `tests/mineral_chunk_controller_test.gd`
  - Adds invalid-path coverage for each category handled by the combined collector.
- `tests/surface_chunk_production_benchmark.gd`
  - Adds same-process legacy-versus-combined scan comparison and JSONL evidence.
- `.github/workflows/surface-chunk-production-benchmark.yml`
  - Requires the comparison implementation and emitted JSONL payload.
- `docs/MINERAL_CHUNK_CONTROLLER_SINGLE_PASS_SCAN_COMPARISON_M0_2_13_6.md`
  - This technical record.

## Dependencies and import

- Godot 4.3.
- Existing `MineralChunkController.gd`, `MineralMiningNode.gd`, `CropPlotVisual.gd`, and `WorldObjectStatefulProp.gd`.
- No external packages, runtime assets, autoloads, scene wiring, project settings, save schema, or gameplay behavior changes.
- Open the repository root with Godot 4.3 or use the existing headless import workflow. No manual asset import is required.
- The microbenchmark uses detached in-memory Nodes and does not mutate the live SurfaceWorld.

## Validation contract

The benchmark must:
1. Build the same deterministic tree for both algorithms.
2. Confirm exact parity of Mineral, Crop Plot, and Stateful Object dictionaries, including Node identity.
3. Complete five warm-up iterations for each path.
4. Complete forty measured iterations for each path, alternating execution order.
5. Emit one valid comparison object in the Radius-8 `expand_stage_commit` JSONL record.
6. Preserve the existing 24 JSONL records and existing production streaming/collider invariants.
7. Keep timing informational: no assertion requires the new path to be faster, because CI runner scheduling and process load can affect microsecond measurements.

## GitHub version

- Parent: PR #312, exact HEAD `2ec0eb5f9c02192b361bc65686e3bf8c40fdf8ec`.
- Existing child: PR #313, branch `perf/mineral-chunk-controller-single-pass-content-scan-2026-11-11`.
- This version updates the existing PR #313 branch; it does not create a parallel PR.
- The branch remains Open / Draft / unmerged until the new exact-head focused, lifecycle, benchmark, and Full Godot 4.3 workflows complete.

## Limitations

- The synthetic scan comparison isolates scene-tree discovery cost; it does not include Registry operations, Crop catch-up, object-state restoration, adjacency collection, Collider transactions, or Chunk-root retirement.
- The production Radius-8 benchmark remains the integration-level measurement; its timings are not interchangeable with this synthetic microbenchmark.
- Headless timing is not rendered FPS or target-device performance.
- No iPhone, GPU, device-memory, touch, or PhysicsServer allocation-failure QA is claimed.
- No speedup is claimed until the new exact-head artifact is downloaded, parsed, and the A/B output is inspected.

## Next step

Run the exact-head Mineral Chunk Controller integration regression, Lifecycle workflow, Production Benchmark, and Full Godot 4.3 gate. Download and parse the new artifact; report the in-process median and p95 comparison without converting it into a target-device performance claim.
