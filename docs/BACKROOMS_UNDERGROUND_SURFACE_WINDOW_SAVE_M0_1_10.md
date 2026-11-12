# M0.1.10 — Underground Surface-Window Save/Restore Anchor

## Purpose

Fix a production save/load defect when the player explores horizontally away from the mine entrance. SurfaceWorld keeps its surface chunk window anchored at the saved surface return position while the separate mine director streams underground chunks. The old portal persistence guard derived the surface window from the underground player's current X/Z coordinates, so an otherwise valid underground save could fail once the player moved outside the still-loaded surface window.

## GitHub delivery

- Parent: PR #339 — SurfaceWorld portal runtime and durable lifecycle.
- Parent exact HEAD: `ff690871a42846c1ae59e72e10605d01fe61bf5d`.
- Child branch: `fix/backrooms-underground-surface-window-save-2026-11-12`.
- Child PR: #340 (to be opened after the code and documentation commits).
- Godot 4.3; no third-party dependencies, autoloads, scenes, Project Settings, or input mappings.

## Runtime changes

- Add `get_loaded_surface_window_bounds_at(reference_position)` so the loaded-window check is explicitly anchored to a supplied surface position.
- Make `get_loaded_surface_window_bounds()` use `_surface_return_position` while underground and the live player position while on the surface.
- Serialize the portal director against the actual loaded surface window at the saved return position, not the mine player's unrelated horizontal coordinates.
- During an underground restore, pass the saved surface return position to the base SurfaceWorld streaming restore, then restore the player to the saved underground position after the surface window is rebuilt.
- During rollback from an underground restore, rebuild the surface stream around the previous return position and then restore the previous mine player position. This keeps the surface and mine streaming responsibilities distinct.

## Files

- `world/SurfaceWorld.gd` — surface-window reference helper, underground save anchor, underground restore and rollback anchoring.
- `tests/production_surface_world_test.gd` — move the mine window beyond the surface window, save while underground, restore from a different mine window, verify the surface return window and active portal anchor; inject Stamina and Quick Use failures during an underground world-seed change and require exact rollback of both streaming windows and the portal envelope; then restore the surface fixture.
- `docs/BACKROOMS_UNDERGROUND_SURFACE_WINDOW_SAVE_M0_1_10.md` — this version record.

## Dependencies and import

- Parent PR #339 supplies the SurfaceWorld-owned BackroomsPortalDirector, active portal visual lifecycle, and world-session persistence envelope.
- Existing `WorldSessionController`, `MineralGridStreamingDirector`, `UndergroundMineDirector`, and `BackroomsPortalDirector`.
- Import from repository root: `godot --headless --path . --import`.
- Focused regression: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Validation status

- Code and regression tests are committed to the child branch.
- Exact-head Godot 4.3 Full Compatibility Gate is required after the latest test commit; no test pass is claimed before the workflow completes.
- Local Godot executable is unavailable in this environment; no local engine pass is claimed.
- Graphical rendering, GPU, visual alignment/Z-fighting, and iPhone touch/performance remain unverified.

## Limitations and next step

- This change keeps the SurfaceWorld stream anchored at the saved return location while the player explores the mine; it does not implement the Backrooms maze runtime or activate portal entry.
- Verify the focused production SurfaceWorld regression and the exact-head full compatibility gate. If either fails, correct the test or runtime before marking the PR Ready for Review.
- After this contract is accepted, continue with hidden Backrooms runtime staging/activation and a failure-atomic world-layer switch.
