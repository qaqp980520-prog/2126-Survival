# Backrooms settings/material test reconciliation — Run 12 — 2026-10-26

## Scope
- Preserve the current-main settings contract: `high_graphics` controls procedural geometry/detail; `shadows_enabled` independently controls deterministic local dynamic shadows.
- Fluorescent flicker remains automatic and is not exposed as a user setting.
- Correct the stale integration test: `_make_surface_material()` returns `StandardMaterial3D` with the project's carpet/wallpaper SVG textures and mesh UV mapping, not the old ShaderMaterial shader parameters.
- Import/parse the root Godot project before root-level integration tests load `res://assets/textures/*.svg`, avoiding resource-order false failures.

## Files
- `tests/backrooms_settings_integration_test.gd`: assert StandardMaterial3D, non-null albedo textures, and `uv1_triplanar == false`; retain independent geometry/shadow setting assertions.
- `.github/workflows/godot-validation.yml`: root project import/parse step before tests; add Reactor Balance and transactional streaming rollback tests.
- `systems/MineralGridStreamingDirector.gd`: transaction rollback when an unload fails after earlier stale chunks were unloaded.
- `tests/helpers/FakeMineralChunkController.gd` and `tests/mineral_grid_streaming_transaction_test.gd`: failure-injection regression for a later stale unload.

## Validation
- Upstream candidate PR #53 exact-head CI Run #225 (40332844576) succeeded on `1218df8088b735d80a18f4b191bab356d0defb56`, including Reactor Balance and transactional rollback tests.
- This clean-main port has not yet been tested; a new exact-head CI run is required before merge.
- Local Godot executable unavailable; no GUI/GPU/iPhone test is claimed.

## Next
1. Run the full Godot 4.3 workflow on the clean-main PR head.
2. Fix any failure based on its logs, then rerun the new exact head.
3. Only merge after the full CI passes; update PROJECT_INDEX and Notion with the actual merge commit and CI result.
