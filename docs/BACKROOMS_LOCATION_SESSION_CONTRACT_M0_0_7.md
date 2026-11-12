# Backrooms Production Location Session Contract — M0.0.7

## Purpose

Add a deterministic, failure-atomic state model for one SurfaceWorld-to-Backrooms visit. This is the state contract needed before a production transition manager is connected to the existing SurfaceWorld interaction and WorldSession restore transaction.

## Runtime asset

- File: systems/BackroomsLocationSession.gd.
- Class: BackroomsLocationSession, extending RefCounted.
- Dependency: systems/BackroomsPortalDirector.gd from parent PR #327; its supported Level 0–5 destination roster and portal serial bound are the source of truth.
- No third-party packages, autoloads, scene nodes, Project Settings, or input mappings.
- Import: godot --headless --path . --import.
- Focused test: godot --headless --path . --script res://tests/backrooms_location_session_test.gd.

## State contract

The session stores whether a visit is active, the selected Backrooms level, the consumed entry portal ID, the exact SurfaceWorld return position and seed, the current Backrooms player position, and a deterministic Backrooms layout seed derived from the source world seed and portal ID.

The initial contract is intentionally surface-origin only because the existing BackroomsPortalDirector currently generates natural portals in the surface world. Underground-origin portals require a later schema extension that also records mine depth and underground window restoration state.

## Transaction rules

- Preflight methods do not mutate state.
- A second entry cannot overwrite an active visit.
- PortalDirector exposes a non-mutating destination preview using a cloned RNG state. Production can preflight the destination/session before consuming the one-use portal.
- Portal consumption advances the live RNG once and verifies it matches the preview; a mismatch restores the previous RNG state and preserves the active portal.
- Session preflight accepts prepared or entered results, while begin_from_portal_result accepts only the committed entered result.
- The return context remains available until complete_return() is called after the surface world has been restored successfully.
- Save loading validates every field into local values before mutating any live state.
- Inactive saves use a canonical empty representation; stale level/portal/position data is rejected.

## Files and dependencies

- systems/BackroomsLocationSession.gd
- tests/backrooms_location_session_test.gd
- .github/workflows/godot-validation.yml
- systems/BackroomsPortalDirector.gd (parent dependency, unchanged by this PR)
- tests/backrooms_portal_director_test.gd (parent regression contract, unchanged by this PR)

## Validation

The exact-head Godot 4.3 Full Compatibility Gate must execute both the PortalDirector preview/consume regression and the new focused session test. The test covers successful entry/return, portal-director handoff, deterministic layout seed derivation, preflight non-mutation, duplicate-entry rejection, JSON round-trip, canonical inactive state, and atomic rejection of malformed saves.

Local Godot is unavailable in this environment; no local engine run is claimed until the exact-head GitHub Actions result completes.

## Scope boundary

This milestone does not yet spawn the portal in SurfaceWorld, create the Backrooms maze, switch collision/visibility, pause surface streaming, or connect the session to SurfaceWorld.serialize_stream_state()/restore_stream_state(). It supplies the validated state contract for that production runtime work. Do not claim a playable transition from this milestone alone.

## GitHub stack

- Branch: feat/backrooms-location-session-contract-2026-11-12.
- Parent PR #327 branch: fix/backrooms-portal-rng-save-state-2026-11-12.
- Ancestor PR #322 branch: feat/backrooms-level4-5-entities-2026-11-11.
- The new PR must remain stacked on #327 until #327 and #322 are integrated or the stack is deliberately reconciled.
