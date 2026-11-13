# Backrooms Production World Handoff M0.1.16

## Purpose

Connect the existing BackroomsTransitionManager, BackroomsLocationSession, and BackroomsMazeCellRuntime to the production SurfaceWorld player without replacing the player node or rebuilding the surface world.

## Runtime contract

- SurfaceWorld remains the owner of the player, camera, surface streaming director, and Backrooms runtime.
- The Backrooms runtime is vertically isolated at a fixed local Y offset while the surface chunk window remains loaded.
- Portal entry validates the live one-use portal, stages the hidden runtime, commits Director + Session, moves the existing player, and only then activates the maze collision/visibility.
- A failed post-commit activation calls abort_committed_entry() to restore the exact pre-entry Director and Session snapshots and retire the staged runtime.
- While in Backrooms, SurfaceWorld does not tick the portal director or surface streaming. The active maze runtime is synchronized through the transition manager.
- Surface chunk roots are hidden during Backrooms and their prior visibility values are restored on return.
- Return restores the original surface position and validates the source world seed before deactivating the maze and clearing the Session.
- Surface-only serialization is deliberately rejected while Backrooms is active. A full save adapter that serializes both SurfaceWorld and Backrooms Session/runtime is still required before saves can be made in Backrooms.

## Files

- systems/BackroomsTransitionManager.gd: committed-entry abort snapshots and exact rollback.
- world/SurfaceWorld.gd: production portal entry, player handoff, Backrooms movement/streaming, and surface return.
- tests/backrooms_runtime_session_integration_test.gd: committed-entry abort and portal restoration regression.
- tests/production_surface_world_test.gd: real SurfaceWorld entry/return integration regression.

## Dependencies

- Parent PR #345: Backrooms runtime/session transaction integration.
- Parent PR #344: SurfaceWorld-owned maze cell runtime.
- Existing portal director and production player-group/interaction contracts.

## Import / integration

All scripts use existing project paths and are preloaded by SurfaceWorld.gd or the existing Godot validation tests. No manual import step is required; open the project with Godot 4.3 and allow the normal project scan/import.

## Test status

- Prior code HEAD `c4c98869a53fff9970cb0fc18dce95a590c770d6` completed exact-head Godot 4.3 Full Compatibility Gate [Run #43361096420](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43361096420): 559/559 success, 0 failures, 0 skipped. This later commit adds the production return rejection/retry regression; its exact-head gate is pending.
- New regression coverage is added to the existing Backrooms runtime/session integration test and production SurfaceWorld integration test, including a source-world seed mismatch that rejects return, verifies the active Backrooms runtime/Session/player position are restored, and then retries successfully after the seed is corrected.
- Local Godot executable is unavailable in the current environment; no local engine pass is claimed.

## Limitations

- Backrooms active-state serialization is not yet integrated into SurfaceWorld.serialize_stream_state(); the method fails closed while Backrooms is active to avoid writing a surface-only payload with a Backrooms player position.
- Visual acceptance, GPU rendering, lighting review, and iPhone testing remain outstanding.
- The fixed vertical isolation offset is an interim same-scene strategy, not a separate-world/scene architecture.

## Next steps

1. Complete exact-head Godot 4.3 validation for the new return rejection/retry test commit and obtain review.
2. Add a combined SurfaceWorld + Backrooms Session/runtime save envelope and transactional restore.
3. Add return-failure and post-commit activation-failure injection at the production SurfaceWorld boundary.
4. Validate graphical maze materials/collision and mobile controls.

## Production-boundary post-commit activation failure regression — 2026-11-13

- Added `FailAfterCommitActivationTransitionManager` in `tests/production_surface_world_test.gd`. It delegates the real prepare and commit calls, then injects a deterministic failure at the activation boundary by deactivating the already-committed maze runtime immediately before delegating to the real `activate_prepared_runtime_after_handoff()`.
- The real `BackroomsTransitionManager.abort_committed_entry()` then executes. The production SurfaceWorld test requires exact rollback of the PortalDirector save dictionary (including RNG, serial, timer and active portal), inactive LocationSession save dictionary, empty/inactive runtime, runtime anchor, player position and velocity, SurfaceWorld mode, loaded surface chunk visibility, and the visibility snapshot.
- The same production portal visual must remain interactable, and the test retries entry through the unwrapped real manager to prove the restored portal can still complete a normal handoff.
- This is a deterministic headless failure-injection test; it does not claim rendered activation, GPU or device behavior.
- Code is on the current PR #346 branch; the new exact-head Godot 4.3 Full Compatibility Gate must validate the resulting commit. The previous HEAD's green result does not validate this added test.
