# Backrooms Transition Manager — M0.0.8

## Purpose

Add a production-facing state coordinator around BackroomsPortalDirector and BackroomsLocationSession. It enforces the prepare/commit entry boundary and prevents the return session from being cleared until the SurfaceWorld restore callback reports success.

This is an orchestration contract, not yet a playable transition or scene owner.

## Files

- systems/BackroomsTransitionManager.gd — RefCounted coordinator with IDLE, ENTRY_PREPARED, and IN_BACKROOMS states.
- tests/backrooms_transition_manager_test.gd — headless transaction regressions.
- .github/workflows/godot-validation.yml — focused test input guard and execution step.
- docs/BACKROOMS_TRANSITION_MANAGER_M0_0_8.md — this version record.

## Dependencies and import

- Godot 4.3.
- systems/BackroomsLocationSession.gd from parent PR #331.
- systems/BackroomsPortalDirector.gd from parent PR #331.
- No third-party packages, autoloads, Project Settings, scenes, or new input mappings.
- Import from repository root: godot --headless --path . --import.
- Focused test: godot --headless --path . --script res://tests/backrooms_transition_manager_test.gd.

## State contract

- prepare_portal_entry() calls the non-mutating portal preview and session preflight; it must not consume the portal or advance RNG.
- commit_portal_entry() requires the exact same Director instance, Portal ID, return position, source seed, and entry position; it rechecks the preview and session preflight immediately before consumption.
- Before the mutating consume call, the manager snapshots the complete PortalDirector save payload. The director must expose to_save_dict() and load_save_dict() or the manager rejects the commit before consuming.
- If consume_portal() rejects or the session rejects begin_from_portal_result() after consumption, the manager restores the exact director snapshot, including RNG state, active one-use portal, serial, and spawn countdown. It then reads the save payload back and requires exact Dictionary equality; a true load return alone is not treated as proof of rollback. The result reports whether exact director restoration completed.
- A failed or stale pre-consumption commit clears the prepared state without mutating the Director.
- Commit revalidates that the session is still inactive and the original preview remains acceptable before consuming the portal; external session mutation cannot silently consume the one-use portal.
- Return rechecks that the same return context remains active after the restore callback before clearing it.
- cancel_prepared_entry() only clears manager state; it does not consume or alter the portal.
- return_to_surface() passes a copy of the saved return context to a callback. A false/non-boolean callback result retains the complete session for retry. Only a true result allows complete_return() to clear the session.

## Validation

- Added a failure-injection session whose preflight succeeds but whose commit deliberately rejects after the Director has consumed the portal.
- Added a mutating Director double whose consume operation changes RNG, serial, countdown and active-portal state before returning failure; the manager must restore and verify the exact original save payload.
- Both regressions require the Director save payload to match the exact pre-commit snapshot after rollback, including RNG, spawn timer, serial, and active portal.
- Exact-head Godot 4.3 focused and Full Compatibility Gate for the updated commit are pending. No pass is claimed until CI completes.
- The preceding pre-hardening HEAD had its focused transition-manager test pass in Full Gate run 43173784724; that run does not validate the new rollback commit.

## Deliberate limitations

- The manager does not instantiate a maze, spawn the production portal visual, move the player, change collision/visibility, pause surface streaming, or serialize itself.
- SurfaceWorld must own scene construction and activation, and must call this coordinator only after its destination runtime is prepared.
- The session is surface-origin only; underground-origin transitions require mine-depth/window context.
- Graphics, GPU, and iPhone tests are not covered by headless CI.


## M0.0.8.1 — Session rollback hardening

- The entry transaction now snapshots both participants before consuming a one-use portal: the PortalDirector payload and the inactive BackroomsLocationSession payload.
- A Session without non-empty `to_save_dict()` and `load_save_dict()` support is rejected before portal consumption; this is a fail-closed contract requirement.
- If `begin_from_portal_result()` returns false after mutating Session fields, the manager restores both Director and Session snapshots and reads both back. The result exposes `director_state_restored`, `session_state_restored`, and `rollback_complete` separately.
- Added a failure-injection Session that mutates active state, destination, portal ID, return position and a marker before returning false. The regression requires exact pre-commit Session and Director payload equality.
- Added a fail-closed regression proving that a Session without snapshot/restore methods cannot consume the one-use portal.
- Updated files: `systems/BackroomsTransitionManager.gd`, `tests/backrooms_transition_manager_test.gd`, and this version record.
- Dependency remains PR #332 and its ancestors #331/#327. Godot 4.3 focused and Full Compatibility Gate are pending for the new child HEAD; no pass is claimed yet.


## M0.0.8.2 — Return-side Session rollback hardening

- Before invoking the SurfaceWorld restore callback, the manager now requires a non-empty Session save snapshot and a load/restore method. A missing rollback contract fails closed before changing the SurfaceWorld.
- If the SurfaceWorld callback fails or mutates the Session context before returning, the manager restores the pre-return Session snapshot and reads it back for exact Dictionary equality.
- After the SurfaceWorld is restored, a failed or partially mutating complete_return() also restores and verifies the exact active return context.
- A reported successful complete_return() is accepted only when the Session is inactive, its return context is empty, and its full save payload equals the canonical inactive BackroomsLocationSession payload.
- Added regressions for a partially mutating complete_return() failure, a callback that mutates the Session before failing, and a Session without snapshot/restore support. The existing successful return/retry path remains covered.
- Updated files: systems/BackroomsTransitionManager.gd, tests/backrooms_transition_manager_test.gd, and this version record.
- Dependency: PR #334 integration candidate, which reconciles the production SurfaceWorld interaction/restore stack with the Backrooms Director/Session/TransitionManager stack.
- Validation: pending exact-head Godot 4.3 focused and Full Compatibility Gate. Local Godot executable unavailable; no local engine pass is claimed.
