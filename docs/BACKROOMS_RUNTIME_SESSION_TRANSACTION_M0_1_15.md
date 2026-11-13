# Backrooms Runtime Session Transaction — M0.1.15

## Purpose

Bind the SurfaceWorld-owned BackroomsMazeCellRuntime save payload to BackroomsLocationSession and coordinate entry, active-window persistence, save restoration, and return through BackroomsTransitionManager.

This is a transaction integration milestone. It does not yet perform the actual player transform, SurfaceWorld visibility/collision switch, or pause/resume of the surface streaming controller.

## Files

- systems/BackroomsLocationSession.gd
  - Adds the optional maze_stream_state save field.
  - Validates the nested BackroomsMazeStreamState payload against destination level, derived Backrooms seed, and the Session's player position.
  - Adds update_backrooms_runtime_state() so position and stream payload update together.
  - Preserves legacy schema-version-1 saves that do not contain the optional field.
- systems/BackroomsTransitionManager.gd
  - Adds prepare_portal_entry_with_runtime() and commit_portal_entry_with_runtime().
  - Prepares the hidden runtime before portal consumption and rejects a changed runtime snapshot before commit.
  - Stores the exact runtime payload in Session in the same commit as portal consumption.
  - Adds post-handoff activation, atomic runtime-window/Session updates, runtime restoration from a loaded Session, and runtime-aware return.
  - Verifies runtime and Session snapshots after rollback.
- tests/backrooms_runtime_session_integration_test.gd
  - Covers successful entry, delayed activation, stream movement persistence, JSON save/load, legacy-v1 migration, nested payload rejection, position-drift rejection, runtime reconstruction, failed return retry, staging failure, and stale runtime rejection.
  - Injects a Session that mutates its save state and rejects commit; exact PortalDirector, Session, and staged-runtime rollback/readback are required.
- .github/workflows/godot-validation.yml
  - Adds the test file guard and dedicated Godot test step.
- docs/BACKROOMS_RUNTIME_SESSION_TRANSACTION_M0_1_15.md
  - This version record.

## Dependencies and import

- Parent PR #344 — SurfaceWorld-owned maze cell runtime.
- BackroomsMazeCellRuntime.gd
- BackroomsMazeStreamState.gd
- BackroomsMazeLayout.gd
- BackroomsLocationSession.gd
- BackroomsTransitionManager.gd
- Godot 4.3; no third-party packages, new autoloads, Project Settings, or input mappings.

Import:

    godot --headless --path . --import

Focused integration test:

    godot --headless --path . --script res://tests/backrooms_runtime_session_integration_test.gd

Existing related tests remain required:

- tests/backrooms_location_session_test.gd
- tests/backrooms_transition_manager_test.gd
- tests/backrooms_maze_cell_runtime_test.gd
- tests/production_surface_world_test.gd

## Transaction contract

1. Preview the portal without consuming it.
2. Build a hidden runtime from the previewed level, derived seed, entry position, cell size, and stream radius.
3. Validate the runtime save payload against the Session's expected level, seed, and center cell.
4. Recheck the exact prepared runtime payload immediately before consuming the portal.
5. Consume the portal and commit the Session with the same payload. If Session commit fails, restore Director, Session, and the staged runtime.
6. Keep the runtime hidden until the caller has completed the player/world handoff; only then call activate_prepared_runtime_after_handoff().
7. On player movement, stage/commit the runtime window and update Session position plus payload as one validated operation. If Session rejects the payload, rebuild the prior runtime snapshot.
8. On save restoration, rebuild the runtime hidden from the Session payload, verify exact readback, then activate only after the caller's world handoff.
9. On return, restore SurfaceWorld first. Retire the runtime and clear Session only after successful surface restoration. Any failure reconstructs the previous active runtime and Session snapshots.

## Compatibility and migration

- Session schema_version remains 1 because maze_stream_state is an additive optional field.
- Older schema-version-1 Session payloads without maze_stream_state load as legacy Sessions with an empty runtime payload.
- New runtime-aware entry requires a valid non-empty stream payload.
- A non-empty payload must use the supported maze algorithm version and match the Session level, derived Backrooms seed, and center cell for the saved player position.
- Inactive Session saves must contain an empty runtime payload.

## Scope limits

- This PR does not move the player, change the player's collision layer or visibility, suspend/resume SurfaceWorld chunk streaming, unlock the portal visual/input path, or complete a playable end-to-end transition.
- The actual handoff remains an explicit caller responsibility between commit_portal_entry_with_runtime() and activate_prepared_runtime_after_handoff().
- Graphical geometry, physics interaction, lighting, GPU performance, and iPhone behavior remain outside the headless gate.
- Verified linear PR ancestry: #334 → #335 → #336 → #337 → #339 → #340 → #341 → #342 → #343 → #344 → #345. PR #334 combines the earlier production player/portal interaction stack with the transition/session stack; #335–#345 are sequential descendants. Integrate in order, rechecking each child's base/head and exact-head CI after every parent merge.

## Validation status

Exact-head Godot 4.3 Full Compatibility Gate is pending for the final HEAD of PR #345. The authoritative final commit SHA and corresponding run URL are maintained in the PR description; a run for an earlier HEAD does not validate later commits. Do not claim a pass until the latest exact-head run completes successfully.
