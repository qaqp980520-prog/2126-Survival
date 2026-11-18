# Backrooms Live Entity Owner Transfer and Reconstruction — M0.1.73

## Purpose

Add a transactional live CharacterBody3D ownership handoff between two adjacent, already-loaded Backrooms maze cells. Preserve immutable spawn identity while updating mutable owner-cell identity, and reconstruct migrated entities under their saved owner cell after stream unload/reload and Combined World Save round-trip.

This is a runtime ownership primitive. It does not yet enable autonomous cross-cell roaming or NavigationAgent3D.

## Files

- systems/BackroomsMazeCellRuntime.gd — owns the live transfer transaction, stages migrated entity roots from ownership records, and restores owner-local runtime state.
- systems/BackroomsEntityOwnershipLedger.gd — validates one adjacent route hop, commits owner revision changes, and rejects stale/pending transactions.
- systems/BackroomsEntityRuntimeState.gd — captures/restores mutable owner-local position while retaining immutable spawn identity.
- systems/BackroomsEntityMovementDriver.gd — keys scheduler state by immutable spawn identity so ownership changes do not reset scheduling identity.
- systems/BackroomsPerceptionDriver.gd — submits perception with the immutable spawn key to disambiguate same-type entities sharing one owner cell.
- systems/BackroomsMazeStreamState.gd — persists the ownership-ledger schema in maze save schema v4.
- tests/backrooms_entity_owner_runtime_integration_test.gd — exercises stale-route rejection, edge-only handoff, physics-blocked rollback, live Node reparent, owner metadata-array transfer, owner-cell unload/reconstruction, and save/load round-trip.
- tests/backrooms_maze_cell_runtime_test.gd — covers schema-v4 migration and shared-owner runtime restoration.
- tests/backrooms_maze_stream_state_test.gd — covers legacy schema 1/2/3 migration to the current schema.
- tests/backrooms_combined_world_save_test.gd — verifies the ownership ledger is included in the combined world envelope.
- .github/workflows/godot-validation.yml — required-file guard and bounded Godot 4.3 integration-test invocation.

## Dependencies and import

- Godot 4.3.
- Existing Backrooms maze layout, loaded-cell route planner, entity director, collision factory, runtime-state codec v2, and transactional ownership ledger.
- Existing SurfaceWorld / LocationSession / TransitionManager / Combined World Save integration.
- No third-party plugins, new autoloads, input mappings, or external binaries.
- No manual import is required. Root resource import uses godot --headless --path . --import.

## Ownership contract

- Immutable identity: spawn_cell_key|entity_id.
- Mutable owner: owner_cell_key / runtime-state cell_key.
- Owner-local position is always relative to the current owner-cell root.
- owner_revision increments exactly once for each committed adjacent transfer.
- Both source and target cells must be present in the active loaded window.
- The route snapshot must be current and its first hop must be reciprocal/open.
- The entity must be at the source cell safe boundary before transfer; the API cannot teleport an entity from the middle of a cell.
- Source and target cell identity metadata arrays must be valid, unique, and aligned with their spawn IDs.
- Live Node reparent and physics handoff happen before ledger commit. A blocked handoff reparents the Node back, restores its exact prior transform and metadata, and rolls back the pending ledger plan.
- On commit, source/target cell metadata arrays and the live entity owner metadata are updated together with the ledger revision.

## Stream and save behavior

- When a migrated owner cell leaves the loaded window but remains inside the one-cell retention halo, the ledger keeps the owner assignment and runtime-state archive.
- When the owner cell is loaded again, the runtime regenerates the entity from its immutable spawn descriptor, attaches it under the mutable owner cell, and restores its owner-local position, brain state, patrol index, and owner revision.
- The original spawn cell does not create a duplicate while another cell owns the entity.
- Combined World Save includes maze schema v4, entity runtime-state codec v2, and ownership-ledger schema v1.
- A pending ownership transfer is not serializable; save fails closed until the transaction commits or rolls back.

## Validation

The new integration test uses a real Godot SceneTree, CharacterBody3D, collision proxies, StaticBody3D obstruction, and the transactional ledger. It verifies:
- transfer is rejected before the entity reaches the safe cell edge;
- stale route snapshots are rejected without mutation;
- a physical obstruction causes full Node/transform/ledger/metadata rollback;
- a valid adjacent transfer reparents the live Node and increments owner revision;
- source/target identity metadata arrays remain aligned;
- owner-cell unload archives the migrated entity within the retention halo;
- reloading the owner cell reconstructs exactly one entity under the saved owner;
- a fresh runtime restores the same ownership under the Combined World Save payload.

The test is run under the existing timeout -k 5s 90s hard-kill guard. The full Godot 4.3 Compatibility Gate must pass on the exact branch HEAD before this PR can leave Draft.

## Limitations

- No autonomous cross-cell roaming is enabled; BackroomsEntityMovementDriver remains cell-local and does not yet request/consume route snapshots.
- No NavigationRegion3D or NavigationAgent3D is created. This PR transfers ownership only after a caller supplies a validated route snapshot and the entity reaches the source-cell boundary.
- Cross-cell perception target handoff, player-driven pursuit across multiple cells, and multi-hop transfer scheduling remain future work.
- No hardware GPU, iPhone, or mobile performance claim is made.

## Next

Integrate the movement driver with the loaded-cell route planner: move toward the next-hop boundary, request one validated adjacent transfer when the entity reaches the safe edge, and recompute the route after each committed hop. Add bounded NavigationRegion3D/NavigationAgent3D intra-cell pathfinding afterward, then verify multi-hop pursuit, streaming, rollback, and Combined World Save under a single end-to-end scenario.


## Exact-head correction — owner-local save boundary

The first exact-head Full Gate on HEAD `befb1cdec3a9fb969048081e5e3c47dc26214462` reached the live-transfer integration test and passed the boundary precondition, stale-route rejection, physics obstruction rollback, valid one-hop transfer, owner revision and source/target identity metadata checks. The first failing operation was the immediate post-transfer save:

- Diagnostic: `entity_runtime_position_out_of_bounds`.
- Captured owner-local position: `(0, 0, 3.35)`.
- The transfer placed the CharacterBody3D center exactly on the strict serialized safe extent. Reparenting through global/local transforms introduced a small floating-point boundary overshoot, so the strict save validator correctly rejected the snapshot. All later unload/reconstruction/save assertions were cascading failures.

Correction on the same PR branch:

- Add `ENTITY_TRANSFER_ENTRY_INSET = 0.02`.
- Compute a bounded inward inset (at most 10% of the safe extent) and land the entity inside, rather than exactly on, the target-cell serialization boundary.
- Extend the real owner-runtime integration test to assert the inset and require immediate post-transfer save to succeed.

The exact-head Full Gate and all focused workflows for the new HEAD must complete before PR #400 can leave Draft. No pass is claimed until then.
