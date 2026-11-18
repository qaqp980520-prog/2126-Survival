# Backrooms Loaded-Cell Route Planner — M0.1.68

## Purpose

Add a deterministic, bounded route planner over the currently loaded Backrooms cell window. This is the topology prerequisite for NavigationAgent3D and cross-cell ownership transfer; it deliberately does not move entities or transfer Node ownership.

## Files

- systems/BackroomsCellRoutePlanner.gd — validates loaded cell descriptors and performs deterministic breadth-first search.
- systems/BackroomsMazeCellRuntime.gd — exposes plan_route_between_loaded_cells() only while the destination is active.
- tests/backrooms_cell_route_planner_test.gd — verifies deterministic routes, open-edge agreement, loaded-window bounds, missing endpoints, duplicate/tampered descriptors, seed mismatch, and search budgets.
- .github/workflows/godot-validation.yml — checks required files and runs the new Godot test under the existing hard-kill timeout guard.

## Dependencies and import

- Godot 4.3.
- Existing BackroomsMazeLayout.gd deterministic edge contract.
- Existing BackroomsMazeStreamState.gd loaded-cell descriptor API.
- Existing BackroomsMazeCellRuntime.gd.
- No external plugin, binary asset, or manual import is required.
- The runtime loads the planner through preload("res://systems/BackroomsCellRoutePlanner.gd").

## Route contract

- Search is limited to the current loaded-cell descriptor set, at most 289 cells (stream radius 8).
- Neighbor expansion order is fixed: north, east, south, west.
- Every descriptor must match the requested level, world seed, layout algorithm version, canonical cell key, and deterministic BackroomsMazeLayout.edge_is_open() values.
- A route may cross only reciprocal open edges whose source and destination cells are both currently loaded.
- The result contains ordered cell_path, canonical cell_keys, and one cardinal edge_directions entry per transition.
- The BFS has an explicit expansion budget and returns a reasoned failure when the start/goal is missing, the loaded graph is disconnected, or the budget is exhausted.
- Route planning is read-only and does not change stream state, entity state, save payloads, or Node ownership.

## Validation

The exact-head Godot 4.3 Full Compatibility Gate must pass. The new test prepares and activates a metadata-only Level 0 runtime, routes between loaded cells through the guaranteed deterministic spanning-tree edges, checks repeated route determinism and same-cell behavior, rejects unloaded endpoints and disconnected subsets, verifies every edge against the layout contract, and checks duplicate/tampered/foreign-seed descriptors and the expansion budget.

## Limitations

- This is cell-graph routing only, not intra-cell pathfinding.
- It does not create NavigationRegion3D/NavigationAgent3D, move entities across cells, or transfer entity ownership.
- Routes are restricted to cells already in the loaded window; a goal outside that window is rejected rather than implicitly loading cells.
- No save schema changes or hardware/mobile performance claims.

## Next step

After independent review and exact-head validation, add bounded intra-cell navigation and a transactional ownership-transfer contract that updates the runtime-state owner cell while preserving the deterministic spawn identity. Only then enable cross-cell roaming.


## M0.1.69 — Route snapshot freshness and maximum-window stress

- `BackroomsMazeStreamState` now exposes read-only generation and configuration-revision values.
- Successful runtime route results include both values, the stream center and loaded-cell count.
- `BackroomsMazeCellRuntime.is_route_snapshot_current()` rejects routes after a committed window shift, configuration change, malformed/tampered path, missing loaded cell, duplicate cell, non-cardinal edge or topology mismatch.
- Regression tests verify a fresh route, reject a modified edge, shift the active runtime and reject the stale route, then accept a new same-cell route snapshot.
- Maximum-window stress creates the full 17x17 / 289-cell loaded window for seeds 0, 1, 42, 20261118 and 2147483647. For every seed it routes opposite corners, checks the guaranteed <=33-cell spanning-tree upper bound, verifies every reciprocal edge, enforces <=289 expansions, and confirms repeatability. It also rejects a 290th descriptor.
- The same existing Godot 4.3 test entry remains under the workflow's `timeout -k 5s 45s` guard.
- No navigation agent, cross-cell entity movement, ownership transfer or save-schema change is introduced. Route snapshots are read-only and generation-bound.

- Route snapshots carry a schema version plus explicit start/goal cells, route length, and expansion count. The runtime validator requires strict value types and checks these fields against the actual path before accepting a snapshot.


## M0.1.70 — Deterministic root resource-import gate

- The Full Gate previously invoked `godot --headless --path . --editor --quit` for the root project. Godot 4.3 logged `Scan thread aborted...` because the editor was asked to quit before the filesystem scan/import completed.
- The later Backrooms settings integration test then correctly exposed missing SVG import loaders for `assets/textures/backrooms_carpet.svg` and `assets/textures/backrooms_wallpaper.svg`.
- The root import step now uses `timeout -k 5s 120s godot --headless --path . --import`. Godot 4.3's documented `--import` mode waits for resources to finish importing, then exits; it implies editor and quit modes.
- The workflow now treats `Scan thread aborted` as a hard failure and retains the timeout hard-kill guard.
- The existing settings integration test remains the resource-load regression: both SVG textures must load into the floor and wall materials.
- Exact-head CI after this change is pending. The previous Full Gate [44292729749](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/44292729749) passed the loaded-cell route planner tests but failed the unrelated settings integration texture checks because the root import scan had been aborted.
- No gameplay code, visual asset or daily_games file was changed by this CI correction.
