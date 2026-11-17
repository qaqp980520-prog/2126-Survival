# Backrooms Runtime/Session Transaction on Hardened Chain — M0.1.57

## Purpose

Bind the SurfaceWorld-owned BackroomsMazeCellRuntime save payload to BackroomsLocationSession and coordinate portal preparation, exact runtime snapshot validation, one-use portal consumption, Session commit/rollback, runtime-window persistence, save reconstruction and retryable return.

This is the first transition-integration stage on the corrected #385 ancestry. It deliberately does not yet move the production player, freeze SurfaceWorld streaming, change surface chunk visibility, or unlock the production portal interaction path; those are the next child stage.

## Source provenance and destination

- Selectively ported from historical PR #345 exact HEAD `c607c7d5cb3ee03ae366494678de0f9aa55aaf26` (M0.1.15).
- Historical PR #345 Full Gate #43358973711 reported Success but its complete log contained two actual Godot 4.3 signed-64-bit conversion errors inherited from the old portal RNG parser. That historical green is explicitly not accepted as validation for this port.
- Destination parent: PR #385 exact HEAD `5103e2795d58e573ead054b5b660d07c93e965b6`.
- New child branch: `integration/backrooms-runtime-session-transaction-2026-11-17`.
- No legacy branch merge; only the Session/TransitionManager implementation and its focused integration test are selectively ported. The corrected BackroomsPortalDirector and hardened workflow remain inherited from #385.

## Files

- `systems/BackroomsLocationSession.gd` — optional version-1 maze stream payload, runtime-aware position updates, seed/level/cell validation, canonical nested payload load and legacy v1 compatibility.
- `systems/BackroomsTransitionManager.gd` — hidden runtime preparation, exact payload revalidation before portal consumption, Director/Session/runtime snapshots, commit rollback, post-handoff activation, runtime sync, reconstruction and retryable runtime-aware return.
- `tests/backrooms_runtime_session_integration_test.gd` — end-to-end Session/Manager/Runtime transaction tests with metadata-only cell roots and injected failures.
- `.github/workflows/godot-validation.yml` — required-file guard and bounded output-capturing Godot test step.
- `docs/BACKROOMS_RUNTIME_SESSION_TRANSACTION_HARDENED_CHAIN_M0_1_57.md` — this version record.

## Dependencies and import

- PR #384: deterministic BackroomsMazeLayout and transactional BackroomsMazeStreamState.
- PR #385: SurfaceWorld-owned BackroomsMazeCellRuntime.
- Corrected BackroomsPortalDirector signed-64-bit RNG save parser already present in the #385 ancestry.
- Godot 4.3; no third-party dependencies, new autoloads, Project Settings or input mappings.

Import: `godot --headless --path . --editor --quit`

Focused test: `godot --headless --path . --script res://tests/backrooms_runtime_session_integration_test.gd`

Existing regression tests retained:
- `tests/backrooms_location_session_test.gd`
- `tests/backrooms_transition_manager_test.gd`
- `tests/backrooms_maze_cell_runtime_test.gd`
- `tests/production_surface_world_test.gd`

## Transaction contract

1. Prepare a hidden maze runtime without consuming the one-use portal or advancing Director RNG.
2. Validate the runtime's exact serialized maze payload against destination level, derived Backrooms seed and player center cell.
3. Before consumption, snapshot the complete Director, Session and staged runtime state.
4. Consume the portal and commit the Session with the exact same runtime payload.
5. If Session commit or readback fails, restore Director, Session and runtime snapshots and verify exact readback; report incomplete rollback honestly.
6. Keep the runtime hidden until the production caller completes the player/world handoff and explicitly activates it.
7. Persist each successful runtime-window shift and player position as one validated Session mutation.
8. Rebuild a hidden runtime from an active saved Session before allowing return.
9. Restore SurfaceWorld first; only then deactivate the maze and clear Session. Failed surface restore retains the active Session/runtime for retry.
10. Reject legacy return paths when an active or persisted maze runtime exists, preventing bypass of runtime-aware cleanup.

## Validation status

- Exact-head Full Gate: pending for this child branch.
- New runtime/session integration test: pending exact-head Godot 4.3 CI.
- Existing Session, TransitionManager, maze runtime and Production SurfaceWorld regressions must all pass on the same exact HEAD.
- Complete decoded Full Gate log scan must exclude literal shell guard command lines and confirm zero actual Godot Runtime diagnostics.
- Local Godot executable is unavailable; no local engine pass is claimed.

## Scope limits

- No player transform/velocity handoff, camera/collision/visibility change, SurfaceWorld chunk-stream pause, surface-chunk visibility snapshot, portal visual/input unlock or production portal activation.
- No combined SurfaceWorld + Backrooms save envelope yet.
- The focused integration test uses metadata-only maze roots; graphical meshes/collisions, lighting, GPU performance, iPhone and target-device behavior remain unverified.
- Historical PR #345/#346/#347 Full Gate results are not reused because their ancestry contains the portal RNG parser false-green. This child must pass its own exact-head gate on the corrected #385 ancestry.
- No main merge.

## Next steps

1. Complete this child's exact-head Godot 4.3 Full Gate and full-log scan.
2. Review the Session/TransitionManager changes and obtain independent review.
3. Integrate only into PR #385's feature branch after review, then rerun #385 exact-head validation.
4. Port the production player/world handoff from historical PR #346 selectively, preserving #385's current SurfaceWorld runtime and #384 crop/maze safeguards.
5. Port the combined world save envelope from historical PR #347 only after player handoff is integrated and revalidated.
