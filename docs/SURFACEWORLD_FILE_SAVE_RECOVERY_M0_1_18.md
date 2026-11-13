# M0.1.18 — Production SurfaceWorld File Save and Recovery

## Purpose

Connect the already validated combined SurfaceWorld + Backrooms envelope to durable files in the actual main scene. The production scene is `world/SurfaceWorld.tscn`; its inherited `scripts/world.gd` controller did not previously expose the prototype's `save_game()` / `load_game()` file path. This version adds that missing production boundary without replacing the combined envelope contract.

## Production API

- `SurfaceWorld.save_game(path = "user://2126_survival_world.json")`
  - Calls `serialize_world_envelope()`.
  - Writes JSON through `WorldEnvelopeFileStore.write_atomically()`.
  - Works for surface, underground, and an active Backrooms visit when the envelope is valid.
- `SurfaceWorld.load_game(path = "user://2126_survival_world.json")`
  - Restores through `restore_world_envelope()`.
  - Uses a valid `.bak` only after a missing, malformed, or semantically rejected primary.
  - Stops if the restore report says rollback is incomplete or the destination is not an eligible idle SurfaceWorld.
- `get_last_world_file_report()` exposes the latest file operation result and recovery source.

Keyboard shortcuts:
- F5 saves the active combined envelope.
- F9 loads into an eligible SurfaceWorld. Loading while already inside Backrooms is deliberately rejected; use a fresh/idle SurfaceWorld for a world-load transaction.

## File transaction

For a save path such as `user://2126_survival_world.json`:

- `.tmp`: staged JSON, parsed and compared with the supplied Dictionary before the current primary is moved.
- primary: installed by rename only after the temporary file is verified.
- `.bak`: previous primary retained as the last-known-good recovery point.
- `.corrupt`, `.corrupt.1`, ...: malformed or semantically invalid primaries preserved after a valid backup has restored successfully.

A failed temporary write or rename must not overwrite the previous primary. Temporary and installed files are read back and re-encoded with the same canonical JSON settings before they are accepted. A failed primary restore may fall back only when the SurfaceWorld restore report confirms rollback completion. Incomplete rollback is fail-closed and blocks backup application.

## Files

- `systems/WorldEnvelopeFileStore.gd`
  - Atomic JSON write, exact readback, retained backup, corrupt-primary preservation, and restore-callback-based fallback.
- `world/SurfaceWorld.gd`
  - Adds the production save/load API, F5/F9 shortcuts, and HUD status feedback.
- `tests/surface_world_file_persistence_test.gd`
  - Exercises surface file round-trip, previous-primary backup, malformed JSON fallback, semantic-invalid fallback, missing-primary recovery, fail-closed backup blocking after incomplete rollback, temporary-path obstruction, and active Backrooms save/load/return.
- `.github/workflows/godot-validation.yml`
  - Adds the production file-persistence test to the Godot 4.3 Full Compatibility Gate.

## Dependencies and import

- Godot 4.3+.
- Existing `SurfaceWorld`, `BackroomsTransitionManager`, `BackroomsLocationSession`, `BackroomsMazeCellRuntime`, and combined world-envelope APIs.
- No third-party plugin or imported binary asset is required.
- The helper is loaded by `preload("res://systems/WorldEnvelopeFileStore.gd")`.

## Validation

- Exact-head Godot 4.3 Full Compatibility Gate is required for this PR.
- The file-persistence test watchdog is added to the SceneTree only after deferred test startup, avoiding a Timer start-before-tree error.
- New command: `godot --headless --path . --script res://tests/surface_world_file_persistence_test.gd`.
- Local Godot executable is unavailable in this environment; no local engine result is claimed.
- Graphical/GPU and iPhone validation remain outstanding.

## Limitations

- Restore requires an idle SurfaceWorld with inactive Backrooms Session and empty maze runtime.
- A primary restore that leaves an incomplete rollback report is never followed by a backup attempt.
- The file API is now available from the production scene, but a dedicated in-game save-slot UI and cloud synchronization are not part of this version.

## Next step

Run the exact-head Full Compatibility Gate, inspect the new Step #213 logs, correct any Godot parser/runtime or filesystem portability issue, then obtain independent review. Keep the parent-first dependency order: PR #347 before this PR.
## JSON numeric compatibility correction

- Godot 4.3 JSON decoding can represent integral JSON numbers as either integer or float Variants. Save validators for `SurvivalStamina` and `SurvivalQuickUse` now accept finite whole-valued numeric schema/slot fields and still reject fractional or out-of-range values.
- The file-persistence regression suite includes JSON round-trip fixtures for integral-float schema versions and hotbar slot indices, plus fractional-value rejection.
