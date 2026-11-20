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
- tests/backrooms_perception_driver_test.gd — keeps the fake runtime contract aligned with immutable spawn-cell identity and verifies incomplete staging nodes are ignored safely.
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


## Exact-head correction — perception fixture contract

The first validation of the owner-local boundary fix passed the new owner-transfer integration test (Full Gate step #29), including immediate post-transfer save and the subsequent ownership reconstruction assertions. It then exposed an existing perception-driver test fixture that had not been updated for immutable spawn identity: its fake entities omitted the `spawn_cell` metadata and its fake Runtime method still used the pre-codec four-argument submission signature.

Correction on this PR branch:

- The production perception collector now checks `has_meta("spawn_cell")` before reading the metadata, so incomplete staging nodes are skipped without emitting Godot missing-metadata errors.
- The perception test fixture now assigns explicit immutable spawn cells, passes the fifth `spawn_cell_key` argument, and matches the requested immutable identity.
- The 13-entity round-robin fixture uses unique spawn-cell identities.
- The fake AI brain is configured with the same immutable spawn cell recorded on its entity root, so perception fixtures exercise the production identity contract end to end.
- A regression asserts that an incomplete staging entity without immutable spawn metadata is ignored while the valid entity is still sampled.

The exact-head Full Gate and all focused workflows for the new HEAD must complete before PR #400 can leave Draft. No pass is claimed until then.


## Exact-head correction — JSON numeric normalization for ownership saves

The owner-transfer and perception tests passed on HEAD `c34ee2bf08a8a09f57a71b61630c27a4bdab0b20`. The next exact-head Full Gate exposed a real Session JSON round-trip defect at the runtime-session integration test:

- Diagnostic: Session `last_load_error=maze_stream_state_mismatch`; nested MazeStreamState `last_load_error=entity_ownership_ledger_payload_invalid`.
- Saved center `[1, 0]` matched the position-derived center `(1, 0)`; one entity runtime-state record was present.
- Root cause: `JSON.parse_string(JSON.stringify(...))` converts integer-valued JSON numbers to floats. The ownership ledger loader and nested schema checks required Variant type `int`, rejecting valid values such as schema version, world seed, spawn algorithm version and owner revision after a normal JSON save/load round-trip.

Correction on this PR branch:

- `BackroomsEntityOwnershipLedger.gd` now uses bounded integer parsing for schema version, world seed, spawn algorithm version and owner revision. Integer-valued floats are normalized to integers; fractional, non-finite and out-of-range values remain rejected.
- `BackroomsMazeStreamState.gd` validates the nested ownership schema with its bounded integer parser and stores the schema version canonically as an integer.
- `set_entity_ownership_ledger_state` applies the same canonical schema normalization.
- `tests/backrooms_entity_ownership_ledger_test.gd` now performs a real JSON stringify/parse restore and verifies that a fractional owner revision is rejected without mutating the existing ledger.
- `tests/backrooms_runtime_session_integration_test.gd` prints failure-only nested validation diagnostics for Session and MazeStreamState errors.

The latest exact-head Full Gate and focused workflows must pass before PR #400 can leave Draft. No pass is claimed until then.


## Exact-head correction — schema-one migration fixture

After the JSON ownership-ledger normalization passed its direct ledger test and the Session JSON round-trip, the next Full Gate reached the legacy nested-stream migration assertions and rejected the schema-one fixture. The fixture changed `schema_version` to 1 and removed the schema-two/three fields, but retained `entity_ownership_ledger_version` and `entity_ownership_ledger` from schema four. The production loader correctly rejects newer fields on a legacy schema to prevent downgrade ambiguity.

Correction:
- The legacy integration fixture now removes both schema-four ownership fields before presenting the payload as schema one.
- It explicitly asserts those fields are absent before invoking the production world-load manager.
- The production downgrade rejection behavior is unchanged.

The latest exact-head Full Gate must pass the Session JSON round-trip and the corrected legacy migration fixture before PR #400 can leave Draft.


## Exact-head preflight hardening — serialized owner-local bounds

Code review found that the live transfer API checked finite source coordinates and the boundary axis, but did not independently enforce the same perpendicular X/Z and vertical Y limits used by the runtime-state save codec. A caller could therefore present an entity at the correct edge while its other local coordinate was outside the serializable cell bounds; the ledger could commit an owner change that the next save would reject.

Correction on the live-transfer path:

- Before creating a pending ownership transaction or reparenting the Node, validate the perpendicular X/Z coordinate against the serialized safe cell extent plus only a 0.001 numeric-rounding tolerance. The 0.25 edge tolerance is reserved exclusively for the travel-axis boundary check.
- Validate local Y against the runtime-state codec's shared `MIN_LOCAL_Y` and `MAX_LOCAL_Y` constants.
- Reject invalid positions with `transfer_entity_position_out_of_bounds`; do not create a pending transfer or mutate owner metadata.

Regression coverage in `tests/backrooms_entity_owner_runtime_integration_test.gd`:

- Correct edge coordinate plus an out-of-bounds perpendicular coordinate is rejected.
- Correct edge coordinate plus an out-of-bounds vertical coordinate is rejected.
- Both rejections preserve the source parent, owner cell, owner revision, and zero pending ledger transactions.

This is a fail-closed precondition hardening; the save schema and successful transfer behavior are unchanged. Exact-head Full Gate and all focused workflows must be rerun for the resulting commit.

## Exact-head regression correction — separate edge and perpendicular tolerances

The first bounds-hardening commit correctly added the vertical preflight but reused the 0.25 travel-edge tolerance for the perpendicular axis. The new regression intentionally placed the perpendicular coordinate at safe extent +0.25, exposing that the invalid position was still accepted and the transfer test then cascaded.

Correction:

- Added `ENTITY_TRANSFER_PERPENDICULAR_TOLERANCE = 0.001`.
- Only the axis perpendicular to travel is checked against safe extent plus the small numeric-rounding tolerance.
- The travel axis continues to use the existing 0.25 edge tolerance and is clamped to the safe destination extent during handoff.
- Vertical Y remains strictly bounded by the runtime-state codec constants.

The horizontal regression uses a +0.25 perpendicular offset and now must be rejected before ledger planning; the vertical regression remains unchanged. The failed exact-head Full Gate is recorded as a real regression and is not treated as a pass.

## Follow-up integration — M0.1.74 state/ownership pairing child

- PR #401 was merged into this PR's feature branch `integration/backrooms-entity-live-owner-transfer-2026-11-18`, not into `main`.
- Merge commit: `e196fb27498f7cd5c3cbcc4af3feb1474775d03b`.
- The merged child adds the runtime-state / ownership-ledger pairing invariant, detached save candidate, restore/stream-shift validation, and schema-three owner==spawn-only deterministic backfill.
- PR #401 is now Closed / Merged. PR #400 remains Open / Draft / Unmerged at the new head pending exact-head revalidation.
- Earlier CI evidence is not transferable to the merge commit: PR #400's 570/570 Full Gate was on `ee95a31e324a36a58d266387d7865233f7d0ba7c`; PR #401's 570-step Full Gate was on `72b194557549ee4569f2992a537d6fd742fa975d`. The merged head requires a fresh Full Compatibility Gate and focused workflow run.
- No main change, no main merge, and no `daily_games/` change.
- Next: trigger exact-head CI on the updated PR #400 branch, audit complete logs, then retarget the next stacked child only after the merged parent is validated.
