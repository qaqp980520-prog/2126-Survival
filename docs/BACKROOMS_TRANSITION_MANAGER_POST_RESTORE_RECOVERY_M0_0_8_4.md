# Backrooms Transition Manager — M0.0.8.4: Post-Restore Recovery Barrier

## Problem

A successful SurfaceWorld restore callback commits the world transition before the manager finalizes the Backrooms Session. If the callback mutates the Session, or complete_return() fails after partially clearing it, restoring the Session snapshot does not undo the already-restored SurfaceWorld. The previous implementation could report IN_BACKROOMS and rollback_complete=true even though the two systems were on opposite sides of the transition.

## Contract

- The restore callback must be failure-atomic: a false/non-boolean result means the SurfaceWorld remains in its pre-call state.
- A true result means the SurfaceWorld has been restored to the saved return context.
- If Session validation or finalization fails after a true result, the manager cannot claim a complete rollback because it has no compensating SurfaceWorld callback.
- The manager therefore enters RECOVERY_REQUIRED regardless of whether the Session snapshot itself restores successfully.
- The result reports session_state_restored separately, sets rollback_complete=false, and sets recovery_required=true.
- Prepare, commit, and return remain blocked until the higher-level owner reconstructs a consistent world/session state.

## Files

- systems/BackroomsTransitionManager.gd
- tests/backrooms_transition_manager_test.gd
- docs/BACKROOMS_TRANSITION_MANAGER_M0_0_8.md
- docs/BACKROOMS_TRANSITION_MANAGER_POST_RESTORE_RECOVERY_M0_0_8_4.md

## Dependencies and adoption

- Godot 4.3.
- Parent PR #334: Backrooms/SurfaceWorld root integration.
- Feature PR #335: Backrooms return Session transaction.
- No new autoload, scene, input mapping, third-party package, resource import, or persisted save-schema field.
- Callers must treat RECOVERY_REQUIRED as a hard boundary and invoke a higher-level world reconstruction path; this manager does not implement automatic reload or a recovery UI.

## Regression coverage

- A complete_return() failure after successful SurfaceWorld restoration, with the Session snapshot restore succeeding.
- A Session mutation during a successful SurfaceWorld callback, with the Session snapshot restore succeeding.
- Both cases require surface_restored=true, session_state_restored=true, rollback_complete=false, recovery_required=true, and a blocked retry.
- Existing tests continue to cover callback failure with Session rollback, callback failure with Session rollback rejection, and post-restore Session rollback rejection.

## Validation

The exact-head Godot 4.3 focused test and Full Compatibility Gate must pass on the PR #335 and synchronized PR #432 heads. Final run links and results are recorded in the Notion M0.0.8.4 asset page. No local Godot executable is available; no local engine pass is claimed.
