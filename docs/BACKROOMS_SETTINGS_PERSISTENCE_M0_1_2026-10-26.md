# Backrooms Settings Persistence M0.1 — 2026-10-26

## Scope
Persist camera mode, mouse sensitivity, and the high/low graphics quality setting. The latest main branch makes fluorescent flicker automatic and uses graphics quality to control real shadow/detail cost; there is intentionally no separate flicker toggle.

## Files
- `systems/BackroomsSettingsProfile.gd`: validates and persists settings through Godot `ConfigFile`.
- `prototypes/BackroomsPortalPlayground.gd`: loads settings before UI construction, applies them to the player, reflects values in controls, saves changes, and safely rebuilds maze cells.
- `tests/backrooms_settings_profile_test.gd`: type/range validation and ConfigFile round-trip.
- `tests/backrooms_settings_integration_test.gd`: live controls, restart persistence, shader parameter compatibility, and graphics refresh without duplicate cells.

## Dependencies and import
Godot 4.3, root `project.godot`; no external plugins or assets. Open the repository root with Godot Project Manager.

## Validation
Candidate branch only until complete Godot 4.3 CI passes. CI executes both settings tests. Local GUI, actual GPU shader compilation, and iPhone tests are not claimed.

## Limits / next
Settings persistence is limited to the Backrooms playground. MineralGridStreamingDirector remains synchronous/factory-driven and is not wired to the production world generator.
