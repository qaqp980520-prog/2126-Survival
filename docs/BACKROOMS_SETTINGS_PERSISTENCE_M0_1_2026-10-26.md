# Backrooms Settings Persistence M0.2 — 2026-10-26

## Scope
Persist camera mode, mouse sensitivity, and the graphics/shadow-quality toggle in the Backrooms 3D playground. Fluorescent light flicker is automatic and intentionally has no user toggle, matching the latest main-branch behavior. The graphics option enables a deterministic subset of local shadows plus higher-detail procedural materials; disabling it turns off those dynamic shadows and reduces decorative geometry.

## Files
- `systems/BackroomsSettingsProfile.gd`: validates defaults and stores the three user-configurable settings using Godot `ConfigFile`. Legacy `flicker_enabled` values are ignored.
- `prototypes/BackroomsPortalPlayground.gd`: loads settings before building UI, applies them to the player, updates the shadow/graphics mode, and saves each change.
- `tests/backrooms_settings_profile_test.gd`: type/range validation, legacy-config compatibility, and ConfigFile round-trip.
- `tests/backrooms_settings_integration_test.gd`: live player/UI updates, restart persistence, automatic flicker, deterministic shadow selection, and maze refresh without duplicate cells.

## Dependencies and import
Godot 4.3; repository root `project.godot`; no external plugins or assets. Open the repository root with Godot Project Manager.

## Validation
This is a clean-main candidate. Run #179 failed on the earlier head because the portal integration test expected third-person mode, while the latest main contract is first-person by default. The current candidate updates that expectation and adds explicit shadow-toggle tests. Do not merge until a complete Godot 4.3 CI run passes on the exact candidate head.

## Limits / next
Settings persistence remains scoped to the Backrooms playground, not a global options service. Mineral grid streaming remains synchronous and factory-driven; production world-generator wiring remains future work. Local graphical play and iPhone testing are not claimed.
