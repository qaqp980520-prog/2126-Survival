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
  - Creates a real production portal entry, verifies normal surface-envelope round-trip, saves while in Backrooms, rejects a mismatched Session seed, injects maze-cell staging failure and verifies rollback, retries the valid restore, and returns to the exact surface position. It also checks non-3D Window collider ancestors are safely ignored by interaction routing.
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


## CI diagnostic and corrective changes — 2026-11-13

- Exact-head run #43370508636 reached the new combined save integration test after root import and production SurfaceWorld Step #211 passed. The new test exposed a SurfaceWorld payload readback mismatch after rollback and a headless interaction-routing error where a Window ancestor was passed to typed Array[Node3D] membership checks.
- Added a Node3D type guard in _resolve_camera_interaction_target() and a regression assertion using the SceneTree root Window. Added per-key rollback payload diagnostics so any remaining difference is explicit.
- Added an ordinary surface-envelope round-trip before the Backrooms restore scenario, covering the non-Backrooms branch of schema 1.
- Save serialization now marks SurfaceWorld streaming fail-closed if runtime synchronization reports an incomplete rollback, and refuses Backrooms saves if the original surface visibility snapshot is incomplete.
- Corrective code/test commits: db6a8dc85a65e087025c7cfe02dadf780fef6748 and ef4fa219d22562a55a974ab0c10a9f601c664d90. The exact-head Full Gate for this new HEAD is pending; the previous run is diagnostic only and does not validate these corrections.


## Incomplete nested SurfaceWorld rollback guard — 2026-11-13

- Combined-envelope restore now resets the nested restore report before invoking restore_stream_state(), preventing stale rollback status from a previous operation from being reused.
- If the nested SurfaceWorld restore reports rollback_complete=false, restore_world_envelope() marks surface streaming pending and disables portal activation before returning failure.
- Added a failure-injection case using a Stamina adapter that mutates its payload and rejects both the candidate apply and rollback apply. The test asserts the combined envelope remains outside Backrooms, leaves Session/runtime inactive, reports rollback incomplete, and locks SurfaceWorld streaming fail-closed.
- The new code and test are committed on the existing PR #347 branch; exact-head Godot 4.3 Full Gate must validate the new HEAD.


## Surface restore rollback fail-closed hardening — 2026-11-13

- restore_world_envelope() now seeds a fresh nested restore report before calling restore_stream_state(), so an early validation rejection cannot accidentally reuse a stale report from an earlier operation.
- If the nested restore reports rollback_complete=false, the combined envelope boundary marks _surface_stream_pending and disables portal activation.
- _rollback_auxiliary_restore_failure() now applies the same fail-closed rule to direct SurfaceWorld restore callers when any cross-system snapshot cannot be restored.
- The new integration regression uses FailAlwaysStamina: it mutates the candidate payload and rejects both the candidate apply and rollback apply. The combined restore must report surface_restore / rollback_complete=false, remain outside Backrooms, leave Session/runtime inactive, and lock streaming.
- Exact-head Godot 4.3 Full Compatibility Gate for the final branch HEAD is pending; no pass is claimed until the new Step #212 and full gate complete.


## Exact SurfaceWorld snapshot rollback correction — 2026-11-13

- The previous exact-head Full Gate [#43371432509](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43371432509) reached Step #212 and exposed one remaining exact-readback mismatch after an injected maze-cell staging failure.
- The diagnostic showed mineral `last_regen_unix` values advanced by one second while the rollback rebuilt the SurfaceWorld stream. The chunk window, player transform, Session, runtime, and transition manager otherwise returned to their expected states.
- `_rollback_world_envelope_restore()` now reapplies the pre-transaction mineral snapshot through `registry.restore_snapshot_exact()` after final streaming, then restores crop and world-object snapshots and requires `serialize_stream_state()` to match the exact original payload.
- Any failed registry restore or final payload mismatch marks SurfaceWorld streaming pending and disables portal activation.
- Corrective code commit: `ac00f87d4b4186242578284136288d1dd16959e3`. Exact-head Full Gate for the corrected HEAD is pending; the failed prior run is diagnostic only.
