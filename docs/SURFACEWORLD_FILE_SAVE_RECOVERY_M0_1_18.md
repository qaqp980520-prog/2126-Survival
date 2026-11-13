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
- The production restore boundary also accepts finite integral JSON numbers for the base WorldSession schema and SurfaceWorld mine-depth field. The file integration test writes an explicit integral-float envelope fixture across top-level schema, base schema, mine depth, stamina schema, and quick-use schema/slot fields.
## CI import-order hardening

- The latest exact-head run exposed a pre-existing standalone Backrooms Playground test dependency: `BackroomsPortalPlayground.gd` preloads SVG textures, but the workflow's root editor invocation did not explicitly force resource import before script-mode tests.
- The root import command now includes `--import`, followed by an explicit check for the generated wallpaper/carpet `.svg.import` metadata and `.godot/imported` directory before any headless scene tests run.
- This prevents a missing-import cache from being misreported as a production save/load regression. The new exact-head Full Gate must validate the updated workflow.
- World-object node validators now follow the same JSON numeric rule: `SurfaceTerrainPatch` height/revision and `WorldObjectStatefulProp` loot counts accept finite whole-valued int/float Variants while retaining bounds and fractional-value rejection. The file-persistence suite includes direct positive/negative node-state fixtures.


## Underground lift JSON numeric compatibility correction

- The production mine lift is included in the world-object registry as a stateful object. Its `layer_index` validator previously required an exact GDScript `int`, so a valid JSON round-trip that decoded the integral layer as a float caused the entire SurfaceWorld file restore to fail at `world_object_restore`.
- `UndergroundMineLift.validate_world_object_state()` now accepts finite, whole-valued integer/float Variants within the existing layer bounds, while still requiring the saved layer to equal the lift's authored layer. Fractional, out-of-range, and mismatched values remain rejected.
- The production file-persistence integration fixture now rewrites the actual saved mine-lift record's `layer_index` as an integral float before JSON serialization, so the failure is exercised through `load_game()`, not only through a direct validator test.
- Direct regression coverage also verifies apply success for integral floats and rejection of fractional, out-of-range, and mismatched layers.
- Validation: pending new exact-head Godot 4.3 Full Compatibility Gate; local Godot executable unavailable. Keep the child PR Draft until the file-persistence Step #214 and the complete gate pass.


## Backup repair and integral JSON schema compatibility correction

- Exact-head PR #349 run [#43393541270](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43393541270) passed the new mine-lift JSON tests and production integral-float `load_game()` fixture. It then exposed a separate file-store boundary: `WorldEnvelopeFileStore.write_atomically()` required the envelope schema Variant to be exactly int. A backup read from JSON may carry an integral float schema, so the world could be restored while the primary-file repair silently failed.
- `WorldEnvelopeFileStore.write_atomically()` now accepts finite whole-valued int/float schema variants. Unsupported envelope schemas remain rejected by the production SurfaceWorld restore validator before application.
- Added a focused backup-recovery regression using a malformed primary and a valid backup with `schema_version: 1.0`; it requires the backup to restore and the primary to be rewritten and verified.
- Added explicit recovery-report assertions and failure-only diagnostics for corrupt-primary, semantic-invalid, missing-primary, and active Backrooms file loads.
- The same exact-head run also showed the active Backrooms file-load path still fails after the mine-lift fix; its restore report is now printed on failure so the next exact-head run can identify the remaining phase. The four failing assertions on the superseded HEAD were: three primary-repair checks and the fresh-world Backrooms file load. No full-gate pass is claimed.
- New exact-head validation is required; keep PR #349 Draft until the backup-repair regression, active Backrooms file-load test, and complete Full Compatibility Gate pass.


## Active Backrooms file-load Session canonicalization correction

- The latest child exact-head run [#43394518703](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43394518703) passed the mine-lift integral-float restore, production JSON file load, backup-repair schema regression, and all three primary-repair checks. Only fresh-world active Backrooms file loading remained failing at `session_restore`.
- The transition manager's `restore_session_for_world_load()` previously loaded the JSON-decoded payload directly into the live Session and then compared `session.to_save_dict() == raw_payload`. The Session loader canonicalizes integer fields and nested maze-stream state, so exact comparison to raw JSON can reject a semantically valid payload after numeric Variant normalization.
- The method now validates the complete payload in a detached `BackroomsLocationSession`, obtains its canonical save dictionary, then applies and verifies that canonical dictionary against the live Session. It records explicit failure reasons for preconditions, validation, apply, and readback.
- `SurfaceWorld.restore_world_envelope()` now includes the transition manager's failure reason in the restore report. The file-persistence test directly probes the JSON-decoded active Session before invoking the production fresh-world `load_game()` path.
- New exact-head Godot 4.3 validation is required. No pass is claimed for the current child HEAD until Step #214 and the full gate succeed.


## Exact-head validation correction — RefCounted probe lifetime

- The exact-head Gate [#43395535775](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43395535775) reached the production file-persistence test and exposed a test-harness error after the active Backrooms Session had been saved and detached-validated: the test called `free()` on `BackroomsLocationSession`, which extends `RefCounted`. Godot correctly emitted `Can't free a RefCounted object` and stopped before the fresh-world load assertion.
- Removed the explicit `session_probe.free()`; the local RefCounted probe is released by reference counting when its scope ends. No production ownership or runtime behavior is changed by this correction.
- New exact-head Full Gate required. The active fresh-world Backrooms load assertion remains unverified until the corrected test proceeds beyond the former abort point.
