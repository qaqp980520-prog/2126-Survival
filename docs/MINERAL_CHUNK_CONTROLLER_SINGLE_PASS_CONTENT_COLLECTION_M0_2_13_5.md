# Mineral Chunk Controller Single-Pass Chunk Content Collection — M0.2.13.5

Status: implementation committed; exact-head CI pending.

## Problem

`MineralChunkController.load_chunk()` independently traversed the same candidate Chunk tree three times to discover:
- `MiningNode` minerals via `_collect_mineral_nodes()`.
- `CropPlotVisual` plots via `_collect_crop_plots()`.
- Stateful world-object nodes via `_collect_world_state_nodes()`.

These collectors each perform a depth-first walk and call `get_children()` for every visited node. A candidate Chunk therefore incurred three complete scene-tree traversals before registration could proceed.

## Change

- `load_chunk()` now calls `_collect_chunk_content_nodes()` once.
- The combined depth-first traversal discovers minerals, crop plots, and stateful world objects during the same visit to each node.
- Each category retains its previous path validation, duplicate-key rejection, output dictionary key, and node reference.
- The former category collectors remain available as compatibility/parity references; the new regression compares all three combined outputs with their former collector outputs.
- No registration order, registry mutation, crop catch-up, object-state restoration, terrain transaction, chunk ownership, save schema, or gameplay behavior was intentionally changed.

## Files

- `systems/MineralChunkController.gd`
  - Replaced the three candidate-tree scans in `load_chunk()` with one combined scan.
  - Added `_collect_chunk_content_nodes()`.
- `tests/mineral_chunk_controller_test.gd`
  - Added a mixed nested Chunk-tree regression for mineral, crop, and stateful-object discovery.
  - Compares the new outputs against the former category collectors.
  - Checks invalid stable-path rejection.

## Dependencies and import

- Godot 4.3.
- Existing `MineralMiningNode.gd`, `CropPlotVisual.gd`, and `WorldObjectStatefulProp.gd` scripts.
- No external packages, new assets, autoloads, project settings, scenes, or manual import steps.
- Open the repository root with Godot 4.3 or use the repository's deterministic headless import workflow.

## Validation status

- Static diff review: completed; only the two intended runtime/test files are changed so far.
- Exact-head Godot tests: pending PR workflow execution.
- No performance improvement is claimed until the exact-head production benchmark has completed and its artifact has been parsed.
- The parent PR #312 exact HEAD `2ec0eb5f9c02192b361bc65686e3bf8c40fdf8ec` has a successful Full Compatibility Gate (554/554 step entries), successful Mineral Grid Lifecycle (13/13), and successful Production Benchmark (11/11). These are parent-head results, not evidence for this new child branch.

## Limitations

- This reduces candidate Chunk discovery from three full tree walks to one. It does not optimize registry calls, crop catch-up, object-state restoration, terrain adjacency collection, collider transactions, or pending-root retirement.
- The previous private collectors are retained and add no work to the production `load_chunk()` path.
- Headless timing is not rendered FPS or target-device performance.
- No iPhone, GPU, rendered-frame, PhysicsServer fault-injection, or device-memory QA is claimed.

## Next step

Run the focused Mineral Chunk Controller integration test, Mineral Grid Streaming Lifecycle, Production Chunk Benchmark, and full Godot 4.3 gate on this exact child-PR HEAD. Inspect the benchmark artifact and compare per-Chunk Controller Registration samples under the same runner conditions before claiming a measurable speedup.
