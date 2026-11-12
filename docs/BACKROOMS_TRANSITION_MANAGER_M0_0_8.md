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
- commit_portal_entry() requires the exact same Director instance, Portal ID, return position, source seed, and entry position; it rechecks the preview before consuming.
- The Director's own preview/consume parity remains the final destination guard.
- A failed or stale commit clears the prepared state without mutating the Director.
- Commit revalidates that the session is still inactive and the original preview remains acceptable before consuming the portal; external session mutation cannot silently consume the one-use portal.
- Return rechecks that the same return context remains active after the restore callback before clearing it.
- cancel_prepared_entry() only clears manager state; it does not consume or alter the portal.
- return_to_surface() passes a copy of the saved return context to a callback. A false/non-boolean callback result retains the complete session for retry. Only a true result allows complete_return() to clear the session.

## Validation

Pending exact-head Godot 4.3 focused and Full Compatibility Gate. No pass is claimed until CI completes.

## Deliberate limitations

- The manager does not instantiate a maze, spawn the production portal visual, move the player, change collision/visibility, pause surface streaming, or serialize itself.
- SurfaceWorld must own scene construction and activation, and must call this coordinator only after its destination runtime is prepared.
- The session is surface-origin only; underground-origin transitions require mine-depth/window context.
- Graphics, GPU, and iPhone tests are not covered by headless CI.
