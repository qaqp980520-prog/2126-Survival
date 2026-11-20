# M0.1.87 — Hound One-Hop Cross-Cell Pursuit and Edge Precision

## Purpose

Enable a Level 2 Hound to pursue a target in another currently loaded Backrooms cell. The Hound does not walk freely across cell ownership boundaries: it follows the current route snapshot to the first cardinal edge, approaches with a narrow NavigationAgent tolerance, and delegates reparenting plus ownership mutation to the production runtime transaction.

## Files

- `systems/BackroomsEntityMovementDriver.gd`
- `systems/BackroomsCellNavigationFactory.gd`
- `tests/backrooms_cell_navigation_factory_test.gd`
- `tests/backrooms_entity_movement_driver_test.gd`
- `tests/backrooms_entity_owner_runtime_integration_test.gd`
- `docs/BACKROOMS_HOUND_CROSS_CELL_PURSUIT_EDGE_APPROACH_M0_1_87.md`

## Movement and ownership contract

- Cross-cell movement is enabled only for `entity_id == "hound"` while its behavior state is `pursue`. Other entities and Hound states remain cell-local.
- The target world position is mapped through `BackroomsMazeLayout.try_cell_for_position()`. The current cell comes from the owning cell root's `backrooms_cell` metadata.
- `BackroomsMazeCellRuntime.plan_route_between_loaded_cells()` is authoritative. The movement driver validates route endpoints, first-hop cell key, cardinal direction, loaded destination root identity, and `is_route_snapshot_current()`.
- The Hound approaches only the first hop. Edge target inset is 0.05 m and perpendicular coordinates remain 0.1 m inside the safe cell extent.
- `NavigationAgent3D.target_desired_distance` is 0.05 m in edge-precision mode. That mode accepts only 0.05–0.1 m. Ordinary movement retains the existing 0.5 m minimum.
- A transfer is attempted only within the runtime's 0.25 m edge tolerance. `transfer_entity_to_next_cell()` remains the sole authority that reparents the CharacterBody3D and commits the Ownership Ledger.
- At most one hop is committed per entity per movement tick. The next tick collects the entity under its new owner cell and replans. A stale route fails closed before movement or transfer.
- `BackroomsEntityMovementDriver.tick()` returns `transferred_count` and a `transfer_results` array so callers can reconcile the exact committed owner transaction without re-reading an unrelated entity's result.
- The runtime's existing transfer transaction still validates immutable spawn identity, owner revision, source/target identity arrays, target physics handoff, and rollback.

## Dependencies

- PR #402: NavigationAgent3D, cell-local navigation regions and bounded physics movement.
- PR #404: durable world-file persistence and Hound ownership/runtime recovery.
- Existing BackroomsCellRoutePlanner, BackroomsMazeCellRuntime, EntityOwnershipLedger, EntityRuntimeState and MazeLayout contracts.
- Godot 4.3. No new third-party dependency, autoload, project setting or input action.

## Import and execution

Root project import:

```bash
godot --headless --path . --editor --import --quit
```

Focused tests:

```bash
godot --headless --path . --script res://tests/backrooms_cell_navigation_factory_test.gd
godot --headless --path . --script res://tests/backrooms_entity_movement_driver_test.gd
godot --headless --path . --script res://tests/backrooms_entity_owner_runtime_integration_test.gd
```

All three tests are already registered in `.github/workflows/godot-validation.yml`. The owner-runtime integration test is also included in the Xvfb/Mesa software-rendered job. Changes to the movement driver and tests trigger the Full Compatibility Gate; the production owner-runtime test also triggers the focused persistence workflow.

## Regression coverage

- Ordinary target tolerance remains at least 0.5 m.
- Precision mode accepts 0.05 m, rejects values above 0.1 m, and restores ordinary tolerance when disabled.
- A stale route snapshot causes no movement and no transfer request.
- Hound approaches the first edge before the 0.25 m transfer precondition is satisfied.
- The fake-runtime movement test verifies exactly one first-hop request and preserves the immutable spawn key.
- The production owner-runtime integration now asks the movement driver to initiate the real transactional transfer, reads the exact transaction from `transfer_results`, then retains the existing owner revision, source/target identity-array, rollback and durable file round-trip assertions.

## Validation status

- Static diff review and source-contract checks completed before opening the PR.
- Godot 4.3 exact-head runtime validation is pending in GitHub Actions. No local Godot executable is available in the authoring environment.
- Physical iPhone/iPad and hardware-GPU validation are not claimed.

## Limitations and next step

- The route planner only searches the currently loaded window. Pursuit pauses safely if the target cell is not loaded or no route exists in the current snapshot.
- The driver commits one transactional hop per movement tick; it does not transfer multiple cells in one frame.
- Only Hound pursuit is enabled. Investigate, patrol, avoidance, retreat and other entity types remain cell-local.
- After exact-head Full Compatibility Gate and software-rendered owner-runtime integration pass, extend the scenario to A→B→C pursuit and verify multi-hop save/recovery across a fresh-world reload.


## Run 346 follow-up regressions

- The production owner-runtime integration now invokes the movement driver from a dedicated Node `_physics_process` callback, matching the call context used by `SurfaceWorld._physics_process_backrooms()`. It verifies the transactional reparent, owner revision and durable save/restore from that callback context.
- The production integration fixture uses a non-center player target offset perpendicular to the open edge and asserts that the projected coordinate survives the handoff within the safe cell bounds.
- The movement-driver unit fixture now routes toward a target two loaded cells away (`0,0 -> 1,0 -> 2,0`) and asserts that one movement tick commits only the first hop to `1,0`, preserving the full route snapshot and revision 1. The next tick/replan remains a separate multi-hop milestone.
- The no-route assertion wording now reflects the implemented Hound one-hop capability: cross-cell pursuit fails closed when no loaded-cell route is available.
- These tests are included in the existing Full Compatibility Gate and Xvfb/Mesa owner-runtime job; no new dependency or workflow is required.
