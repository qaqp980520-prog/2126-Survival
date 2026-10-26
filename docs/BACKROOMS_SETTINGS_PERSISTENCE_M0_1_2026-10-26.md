# Backrooms Settings Persistence M0.1 — 2026-10-26

## Scope
Persist the current 3D playground's camera mode, mouse sensitivity, graphics quality, and flicker option without changing movement, portal, maze, or inventory APIs.

## Files
- `systems/BackroomsSettingsProfile.gd`: validates defaults and stores settings using Godot `ConfigFile`.
- `prototypes/BackroomsPortalPlayground.gd`: loads settings before building UI, applies them to the player, reflects them in controls, and saves each change.
- `tests/backrooms_settings_profile_test.gd`: type/range validation and ConfigFile round-trip.
- `tests/backrooms_settings_integration_test.gd`: live player/UI update, restart persistence, and panel visibility checks.

## Dependencies and import
Godot 4.3, root `project.godot`; no external plugins or assets. Open the repository root with Godot Project Manager.

## Validation
Candidate branch only until complete Godot 4.3 CI passes. CI commands are the two settings test scripts. Local GUI and iPhone testing are not claimed.

## Limits / next
Settings persistence is for the Backrooms playground prototype, not yet a general options service. Mineral grid streaming remains synchronous and is not wired to the production world generator.
