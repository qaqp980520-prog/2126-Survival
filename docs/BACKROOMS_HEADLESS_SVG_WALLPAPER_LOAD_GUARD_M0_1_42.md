# Backrooms Headless SVG Wallpaper Load Guard — M0.1.42

## Purpose

Allow the existing Backrooms portal playground integration test to load in Godot 4.3 headless/server builds that do not register the editor SVG resource loader, while preserving the wallpaper texture in graphical runs.

## Root cause

The exact-head Full Gate [#43821375995](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43821375995) failed at step #26, `Run Backrooms portal playground integration test`.

Godot reported:

- `SCRIPT ERROR: Parse Error: Preload file "res://assets/textures/backrooms_wallpaper.svg" has no resource loaders (unrecognized file extension).`
- Script: `prototypes/BackroomsPortalPlayground.gd:13`.
- The subsequent `get_current_level` missing-call and watchdog timeout were consequences of the script failing to load, not independent API defects.

The root project import and Backrooms Portal Director step #22 had passed. The visual scene smoke test #25 also passed; the playground script uniquely preloaded the SVG at parse time.

## Change

- Removed `const BACKROOMS_WALLPAPER = preload(...svg)`.
- Added a path constant and deferred resource loading inside `_prepare_maze_materials()`.
- Load the SVG only when `DisplayServer.get_name() != "headless"` and `ResourceLoader.exists()` is true.
- In headless mode, use the existing wall-color material fallback without attempting to load SVG.
- If the graphical resource is unavailable, retain the wall-color fallback and emit a warning rather than an engine error.
- No maze generation, portal logic, collision, persistence, player movement, save schema, project settings, or external dependencies changed.

## Files and commits

- Code: `prototypes/BackroomsPortalPlayground.gd`.
- Code commit: `cafb14cd77c79e45da62c2dce57bb5a2c2b11be4`.
- M0.1.41 history update: `docs/BACKROOMS_UNDERGROUND_ALL_LAYER_RUNTIME_BUDGET_M0_1_41.md`, commit `33fc317626ddb5bf75318e4222e0d91e30467199`.
- This version record: `docs/BACKROOMS_HEADLESS_SVG_WALLPAPER_LOAD_GUARD_M0_1_42.md`.
- Branch: `fix/backrooms-underground-surface-window-on-reconciled-runtime-2026-11-16`.
- PR #377, base PR #376.

## Dependencies and import

- Godot 4.3.
- Existing `BackroomsPortalPlayground.tscn`, `BackroomsPortalPlayground.gd`, BackroomsPortalDirector, entity director, SurvivalWorldBridge and material/maze construction.
- No new third-party dependencies.
- Import: `godot --headless --path . --editor --quit`.
- Focused test: `godot --headless --path . --script res://tests/backrooms_portal_playground_test.gd`.
- The headless test must not require an SVG importer; graphical builds may load the imported SVG when available.

## Validation status

- Failed prior run #43821375995 at step #26 is not a pass.
- Fresh exact-head Full Gate required after this code and documentation change.
- No local Godot executable is available; no local engine pass is claimed.

## Limitations and next steps

1. Confirm root import and portal playground integration step #26 pass.
2. Confirm Production SurfaceWorld #207 completes all eight underground layers within the 90-second budget, including layer-8 rollback.
3. Require the full 554-step gate and complete log scan to pass.
4. Keep PR #377 Draft until exact-head validation passes and independent review is obtained.
5. Merge only into PR #376 feature branch, then rerun #376. Do not merge main.