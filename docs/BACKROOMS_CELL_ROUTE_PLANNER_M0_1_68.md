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
