# M0.1.17 — Backrooms Combined World Save Envelope

## Purpose

Provide one versioned save contract that can represent the active SurfaceWorld location and, when the player is in Backrooms, the exact return-side SurfaceWorld payload plus the active Backrooms LocationSession, maze runtime stream state, player transform, and original surface-chunk visibility.

The existing serialize_stream_state() and restore_stream_state() APIs remain surface/underground-only. They continue to fail closed while Backrooms is active. Callers that need a save at any supported location must use serialize_world_envelope() and restore_world_envelope().

## Envelope schema 1

Top-level fields:

- schema_version: integer 1.
- active_location: surface, underground, or backrooms.
- surface_world: existing SurfaceWorld stream payload, anchored to the saved surface return position when active_location is backrooms.
- backrooms_session: canonical BackroomsLocationSession.to_save_dict() payload.
- backrooms_runtime: canonical BackroomsMazeCellRuntime.to_save_dict() payload; empty outside Backrooms.
- backrooms_player: player position and velocity arrays.
- surface_chunk_ids: sorted loaded surface/* chunk IDs.
- surface_chunk_visibility: original visibility for every saved surface chunk.

For Backrooms saves, serialization first synchronizes the live player position into the runtime and Session. The surface payload's player_position is the Session's surface_return_position; the Backrooms player's transform is stored separately. The surface portal director payload represents the post-consumption state, so the one-use portal does not reappear after load.

## Restore transaction

1. Reject restore unless the destination SurfaceWorld is idle, its Session is inactive, and its maze runtime is empty.
2. Validate the envelope schema, location, vectors, surface chunk snapshot, Session payload, and (for Backrooms) the maze runtime payload using detached probes.
3. Capture the current SurfaceWorld stream payload, Session, player transform, surface chunk IDs, and visibility.
4. Restore the SurfaceWorld payload through the existing transactional restore_stream_state().
5. Verify that the loaded surface chunk window exactly matches the saved surface chunk IDs.
6. For a Backrooms target, restore the active Session, rebuild the hidden maze runtime from the Session payload, move the player to the saved Backrooms transform, and activate through BackroomsTransitionManager.
7. Apply the saved original surface visibility and hide surface chunks while Backrooms is active.
8. If any post-surface stage fails, deactivate staged maze nodes, restore the prior Session and SurfaceWorld snapshots, verify the readback, and fail closed if rollback is incomplete.

The manager exposes restore_session_for_world_load() and rollback_session_for_world_load() only for this combined restore transaction. The normal portal-entry transaction remains unchanged.

## Files

- systems/BackroomsTransitionManager.gd
  - Adds validated active-Session restore and exact Session rollback for a world-load transaction.
- world/SurfaceWorld.gd
  - Adds serialize_world_envelope(), restore_world_envelope(), surface visibility snapshots, validation, and cross-system rollback.
  - Preserves the existing surface-only APIs and their Backrooms fail-closed behavior.
- tests/backrooms_combined_world_save_test.gd
  - Creates a real production portal entry, saves while in Backrooms, rejects a mismatched Session seed, injects maze-cell staging failure and verifies rollback, retries the valid restore, and returns to the exact surface position.
- .github/workflows/godot-validation.yml
  - Runs the new integration test in the Godot 4.3 Full Compatibility Gate.

## Dependencies

- BackroomsLocationSession
- BackroomsTransitionManager
- BackroomsPortalDirector
- BackroomsMazeCellRuntime
- BackroomsMazeStreamState
- WorldSessionController / SurfaceWorld
- Existing mineral, crop, inventory, and world-object save/restore contracts

## Import and use

No asset import step is required. The scripts are loaded through preload() and the test is invoked with:

    godot --headless --path . --script res://tests/backrooms_combined_world_save_test.gd

Production save callers should use:

- serialize_world_envelope() to capture the active location.
- restore_world_envelope(payload, now_unix) to restore into a fresh, idle SurfaceWorld.

Do not call restore_stream_state() to load an active Backrooms envelope.

## Validation status

- Static integration review completed against the current PR #346 code and the inherited Session, runtime, and SurfaceWorld restore contracts.
- Exact-head Godot 4.3 CI is required; no local Godot executable is available in this environment.
- The new test includes a real production portal handoff and a runtime cell-builder failure injection. Its pass/fail status is pending the exact-head Full Compatibility Gate.

## Limitations

- The restore target must be a fresh/idle SurfaceWorld. Replacing an already-active Backrooms world with another envelope is intentionally rejected.
- The saved surface chunk window is verified exactly. The underground mine window continues to follow the existing SurfaceWorld restore contract and may be rebuilt at its canonical origin when loading a surface-layer save.
- Graphical/GPU and iPhone validation remain outstanding.

## Next step

Run the exact-head Godot 4.3 Full Compatibility Gate, fix any parser/runtime/regression failures, then obtain an independent review before merging the parent chain.
