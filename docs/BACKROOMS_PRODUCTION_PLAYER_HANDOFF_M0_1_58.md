# Backrooms Production Player Handoff M0.1.58

## Purpose

Connect the validated Backrooms maze runtime/session transaction to the existing production SurfaceWorld player. This change ports the player/world handoff from the historical PR #346 onto the current hardened PR #386 exact HEAD without merging the legacy branch.

## Runtime ownership and scene model

- SurfaceWorld continues to own the existing CharacterBody3D player, camera, surface chunk controller, portal director, maze runtime and transition manager.
- The maze runtime is vertically isolated at `Vector3(0, 1000, 0)`; the surface chunk window remains loaded and its prior visibility values are snapshotted.
- The existing player node is moved into the maze runtime. The player and camera are not replaced.
- While Backrooms is active, surface portal ticking, surface streaming, surface debug moves, and surface-only serialization/restoration are blocked.
- The maze runtime is activated only after the transition manager has committed the one-use portal and LocationSession and the player handoff has completed.

## Entry transaction

1. Validate the active portal visual, owning loaded surface chunk, world-seed identity and interaction range.
2. Prepare the 3x3 maze destination hidden at the isolated runtime offset.
3. Commit the exact prepared portal result and LocationSession snapshot.
4. Move the existing player to the maze entry point and clear held movement/jump input.
5. Activate the prepared maze runtime.
6. Hide the loaded surface chunk roots and remove the consumed portal visual only after successful activation.

If post-commit activation fails, `abort_committed_entry()` retires the staged runtime and restores the exact pre-entry PortalDirector and Session snapshots. SurfaceWorld restores player position/velocity and runtime anchor when rollback completes. If rollback is incomplete, interaction is fail-closed rather than exposing a split world.

## Backrooms movement and return

- Existing WASD/touch movement, sprint, jump and stamina logic are reused.
- When the player moves at least 0.5 world units from the last synchronized position, the maze runtime window and LocationSession are updated transactionally.
- The surface chunk window remains frozen and hidden; its loaded-window bounds are resolved from the saved return position.
- Return validates the original world seed, restores the SurfaceWorld streaming window and player position first, then deactivates the maze runtime and clears the Session.
- A failed return retains the active Session/runtime and restores the player's previous Backrooms position so the return can be retried.

## Files

- `systems/BackroomsTransitionManager.gd`: retains pre-entry Director, Session and Runtime snapshots until handoff activation succeeds; adds exact committed-entry abort/rollback.
- `world/SurfaceWorld.gd`: owns transition manager, entry/return flow, isolated player movement, surface visibility snapshot and streaming guards.
- `tests/backrooms_runtime_session_integration_test.gd`: tests committed-entry abort, exact portal/RNG restoration and retry.
- `tests/production_surface_world_test.gd`: tests the real SurfaceWorld portal interaction, injected post-commit activation failure, exact rollback, successful player handoff, movement/session sync, surface-window preservation, failed-return retry and successful return.
- `.github/workflows/godot-validation.yml`: unchanged; existing exact test steps #29 and #211 execute the updated integration and Production SurfaceWorld tests.
- This document records the M0.1.58 integration.

## Dependencies

- Parent PR #386: Backrooms maze Runtime / LocationSession / TransitionManager transaction.
- Parent PR #385: SurfaceWorld-owned maze cell Runtime.
- Existing BackroomsPortalDirector, BackroomsPortalVisual, SurfaceWorld player, chunk controller and streaming director contracts.

## Import / integration

No manual import is required. All GDScript dependencies use existing `res://systems` paths and are loaded by the existing project scan. Run the project with Godot 4.3 and allow the normal import/parse phase.

## Validation status

- Static patch application: 4 files updated on a child branch of the exact PR #386 HEAD; no legacy PR branch merge.
- Static structural checks: one entry method, one return method, one Backrooms physics method, one visibility helper, one committed-entry abort method, and the production failure-injection assertions are present.
- Godot 4.3 focused tests and Full Compatibility Gate: **pending for the new exact HEAD**. The green PR #386 gate does not validate this child commit.
- Local Godot executable is unavailable in the current environment; no local engine pass is claimed.

## Limitations

- Surface-only `serialize_stream_state()` deliberately returns an empty payload while Backrooms is active. The combined SurfaceWorld + Backrooms save envelope remains a separate follow-up.
- The vertical-offset same-scene strategy is an interim architecture; it is not a separate scene/world instance.
- The headless production test uses metadata-only maze nodes. Actual graphical rendering, lighting, collision feel, navigation, AI, GPU cost, iPhone controls and device performance remain unverified.
- The portal's visual interaction is not yet a complete entity/AI gameplay loop.

## Next steps

1. Complete the new exact-head Godot 4.3 focused tests and Full Compatibility Gate.
2. Inspect all runtime/session rollback assertions and obtain independent review.
3. Integrate the combined world save envelope (historical PR #347) onto the hardened chain, with a new exact-head gate.
4. Perform graphical and device QA before treating Backrooms as production-ready.
