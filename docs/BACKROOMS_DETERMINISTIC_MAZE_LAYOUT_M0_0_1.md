# M0.1.12 — Deterministic Backrooms Maze Layout Core

## Purpose

Extract the Backrooms maze's pure topology rules from the 1,371-line playground controller into a reusable, headless-testable module. This is the first production-reuse layer for the later SurfaceWorld-owned Backrooms runtime; it does not yet instantiate or activate that runtime.

## Runtime contract

- `systems/BackroomsMazeLayout.gd` exposes deterministic cell mapping, parent selection, integer hashing, and shared-edge openness.
- Cell boundaries remain centered on multiples of the configured cell size, matching the existing 8 m prototype behavior.
- Every non-origin cell has one deterministic parent edge that reduces Manhattan distance by exactly one; this creates a spanning tree connecting every cell to the origin.
- Optional passages use the existing 34% seeded edge roll, with unordered endpoint hashing so both adjacent cells agree on the same edge.
- Invalid/non-cardinal edge directions fail closed. Invalid cell-size or non-finite position input is surfaced by `try_cell_for_position()`.
- The playground retains its existing private helper names but delegates to the shared module, preserving existing layout seed and hash constants.

## Files

- `systems/BackroomsMazeLayout.gd` — reusable pure topology contract.
- `prototypes/BackroomsPortalPlayground.gd` — delegates cell mapping, edge tests, parent selection and seeded hash to the shared module; no visual-generation behavior is moved.
- `tests/backrooms_maze_layout_test.gd` — boundary mapping, invalid input, parent-tree connectivity, edge symmetry, determinism and seed variation.
- `.github/workflows/godot-validation.yml` — verifies the new source/test inputs and runs the focused test in the full gate.
- `docs/BACKROOMS_DETERMINISTIC_MAZE_LAYOUT_M0_0_1.md` — this version record.

## Dependencies and import

- Godot 4.3; no third-party packages, autoloads, scenes, Project Settings or input mappings.
- Existing Backrooms playground and its current `WORLD_SEED`, `CELL_SIZE`, and entity/visual systems.
- Import from repository root: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/backrooms_maze_layout_test.gd`.
- Full validation: GitHub Actions `Godot Full Compatibility Gate` on the exact PR head.

## Test coverage

- Cell mapping at positive/negative half-cell boundaries.
- Invalid cell size and non-finite coordinates fail closed.
- Every sampled non-origin cell reaches (0,0) through guaranteed parent edges in exactly its Manhattan distance.
- Shared edges are symmetric when queried from either neighboring cell.
- Same seed is deterministic; changing the seed changes optional passages but never closes spanning-tree edges.

## Limitations

- This module defines topology only. It does not create floors/walls, materials, lights, collision, entities, or streamed Node trees.
- The existing playground still owns geometry and rendering. Production SurfaceWorld does not yet instantiate a Backrooms maze or switch player/world layers.
- Existing prototype visual/entity code remains outside this extraction; graphics/GPU and iPhone behavior are not covered by the headless test.

## Next step

Use this pure layout module from a stageable Backrooms maze runtime owned by SurfaceWorld. Keep geometry creation separate from topology, make cell streaming deterministic across unload/reload, and validate the runtime without creating render-only nodes in headless mode.
