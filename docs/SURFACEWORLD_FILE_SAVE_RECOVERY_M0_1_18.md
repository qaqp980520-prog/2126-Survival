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
- `.github/workflows/world-file-persistence-validation.yml`
  - Focused Godot 4.3 root-import plus production file-persistence integration gate, triggered when the file store, production SurfaceWorld save path, or its restore dependencies/tests change.

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


## Exact-head test assertion correction — canonical Backrooms payloads

- Review of the previous exact-head log showed the detached `BackroomsLocationSession.load_save_dict()` intentionally normalizes integral JSON Variants and canonicalizes its nested maze-stream state. The test already logged that its canonical Session readback differed from the raw JSON dictionary, but a later assertion still compared the restored Session directly with that raw dictionary.
- Updated the production file-persistence fixture to retain the detached canonical Session dictionary, independently validate/canonicalize the saved `backrooms_runtime` with `BackroomsMazeStreamState`, and assert that the Session's nested stream snapshot agrees with the standalone runtime snapshot after canonicalization.
- Fresh-world load assertions now compare the restored live Session and Runtime against those canonical expected dictionaries, not the raw JSON-decoded numeric representation. This preserves exact state verification while respecting the documented JSON normalization boundary.
- The earlier RefCounted cleanup fix remains: no explicit `free()` is called on RefCounted probes.
- New exact-head Godot 4.3 Full Gate required; the prior run on HEAD `fb73c7b1...` is superseded and cannot validate these updated assertions.


## Backrooms file-load visibility and consumed-portal regression

- The production file-persistence integration test captures the original loaded SurfaceWorld chunk visibility before entering Backrooms.
- It verifies the saved Backrooms envelope retains that original visibility snapshot even though the live SurfaceWorld chunks are hidden during the visit.
- A fresh-world file load must keep those surface chunks hidden while Backrooms is active, preserve the consumed one-use portal state, and restore every original chunk visibility value after returning to the saved SurfaceWorld position.
- This guards the two-world handoff boundary against invisible-surface returns and accidental reappearance of a consumed portal.


## Nested user:// save-directory support — 2026-11-13

- `WorldEnvelopeFileStore.write_atomically()` now creates a missing parent directory recursively after validating the destination path and JSON payload, but before touching the primary, temporary, or backup files.
- If directory creation fails, the operation reports `directory_create` and leaves existing save files untouched.
- The production file-persistence test exercises nested `user://` paths through both the helper and actual `SurfaceWorld.save_game()` / `load_game()` API. It verifies traversal-segment rejection before directory creation, directory creation, production world-envelope/player-position round-trip, first-write readback, second-save `.bak` rotation, normal primary restore, then corrupts the nested primary and verifies `.bak` fallback, corrupt-primary preservation, and verified primary repair.
- Test cleanup removes the nested save files and empty test directories.
- Import/use remains unchanged: `SurfaceWorld.save_game(path)` and `load_game(path)` accept the nested `user://` path; no Project Settings, autoload, or third-party dependency is required.
- Validation: new exact-head Godot 4.3 Full Compatibility Gate required. Local Godot executable is unavailable; no local engine pass is claimed.
- Limitation: paths remain restricted to non-empty `user://` paths without traversal segments. This change does not add save-slot UI or cloud synchronization.


## Focused production file-persistence CI

- Added `.github/workflows/world-file-persistence-validation.yml` so changes to the file store, production SurfaceWorld save/load boundary, its Session/Runtime/JSON validators, or the persistence test run a focused Godot 4.3 job.
- The job performs a root-project editor import with explicit `--import`, checks Backrooms SVG import metadata, then runs `tests/surface_world_file_persistence_test.gd` with a 150-second external timeout and requires the explicit success marker.
- The repository-wide Full Compatibility Gate remains required; this focused workflow is an earlier, narrower signal and does not replace the full exact-head gate.


## Focused CI shell correction — 2026-11-13

- The first focused workflow run [#43415353968](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43415353968) failed in the Godot-version preflight before import or test execution. Its default container shell was `sh`, which does not support `set -o pipefail`.
- Added explicit `shell: bash` to the preflight step. The failure is a workflow-shell configuration error, not a Godot or save-system test result.
- A new exact-head focused workflow and full compatibility gate are required; no production test pass is claimed from the failed run.


- Focused run #43415527398 reached the new nested tests and found six assertion mismatches in the test fixture comparisons: JSON-decoded integral schema numbers are floats, while the expected Dictionaries used integer `1`. The production save/load path and directory creation assertions passed; the six failures were direct helper readback/backup comparisons. The fixture now uses `1.0` for both schema versions so comparisons use the canonical JSON-decoded type. A fresh exact-head run is required.


## Parent-directory obstruction hardening — 2026-11-13

- `WorldEnvelopeFileStore.write_atomically()` now checks each existing ancestor of a missing parent directory before calling recursive directory creation. If a regular file occupies any required ancestor path, the writer reports `directory_create` without invoking the failing mkdir operation.
- This avoids expected engine-level directory-creation errors for a deterministic obstruction case and preserves the blocking file.
- `tests/surface_world_file_persistence_test.gd` creates a sentinel file where a parent directory is required, attempts a nested save beneath it, and verifies: the result is rejected with `directory_create`; sentinel bytes are unchanged; no primary, `.tmp`, or `.bak` file appears; no partial nested directory is created; and the fixture is removed.
- Import/use remains unchanged: the existing `SurfaceWorld.save_game(path)` / `load_game(path)` APIs and `WorldEnvelopeFileStore` are reused. No new dependencies or Project Settings are required.
- Validation status: exact-head focused Godot 4.3 file-persistence workflow and repository-wide Full Compatibility Gate are required for the updated branch. No result is claimed until both complete on the new HEAD.
- Limitation: this guard detects regular-file ancestors; it does not claim to provide a filesystem sandbox against hostile symlink manipulation. The public save API remains restricted to non-empty `user://` paths without traversal segments.


## User-data symbolic-link path guard — 2026-11-13

- `WorldEnvelopeFileStore` now rejects save and load paths that traverse a symbolic link, directory junction, or other reparse point below the trusted `user://` root.
- The guard checks the primary, temporary, and backup write paths before creating directories or touching save files; load checks both primary and backup paths before reading or invoking restore callbacks.
- Corrupt-primary diagnostic candidates that resolve through a link are skipped.
- The Godot regression creates a directory link under `user://`, places a valid payload behind it, and verifies both write and load are rejected with `path_symlink`, no target file is created, the restore callback is not invoked, and target bytes remain unchanged.
- This is a preflight defense against pre-existing links, not a race-free filesystem sandbox: concurrent replacement of a path component between validation and I/O is outside the guarantee. The `user://` root itself is treated as trusted.
- API dependency: Godot 4.3 `DirAccess.open()`, instance `is_link()`, and `create_link()`; see [Godot 4.3 DirAccess](https://docs.godotengine.org/en/4.3/classes/class_diraccess.html).
- Validation status: pending exact-head focused file-persistence workflow and repository-wide Full Compatibility Gate. Local Godot executable is unavailable; do not claim engine validation until GitHub Actions completes.
