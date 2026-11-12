# Backrooms Production SurfaceWorld Spawn Window — M0.1.7

## Purpose

Connect the validated BackroomsPortalDirector spawn-window API to the real production SurfaceWorld streaming geometry without yet spawning or consuming a visual portal.

## Runtime integration

- SurfaceWorld derives the currently loaded rectangular window from MineralGridStreamingDirector's chunk_size_x, chunk_size_z, load_radius, and the player's current grid coordinate.
- The bounds are centered on the current grid cell and cover exactly (2 × load_radius + 1) chunks in each axis.
- SurfaceWorld exposes tunable backrooms_portal_safe_distance (default 8 m) and backrooms_portal_spawn_padding (default 4 m).
- create_backrooms_portal_director() creates a director seeded from the current world_seed and applies the actual loaded-window policy.
- configure_backrooms_portal_director() refreshes a director's window as the player changes grid cells and fails closed while underground or while asynchronous surface streaming is pending.
- This does not yet tick the director in the live world, instantiate BackroomsPortalVisual, pin portal chunks, connect the portal signal to TransitionManager, or activate a Backrooms runtime.

## Files

- world/SurfaceWorld.gd
- tests/production_surface_world_test.gd
- docs/BACKROOMS_SURFACEWORLD_PORTAL_SPAWN_WINDOW_M0_1_7.md

## Dependencies and import

- Parent PR #336 provides BackroomsPortalDirector.set_spawn_window().
- Godot 4.3; no third-party packages, new scenes, Project Settings, or autoloads.
- Import: godot --headless --path . --import.
- Focused test: godot --headless --path . --script res://tests/production_surface_world_test.gd.

## Regression evidence required

- The real SurfaceWorld's initial 3×3 loaded window must resolve to Rect2(-10, -10, 30, 30).
- A director created by SurfaceWorld must use the exact loaded bounds, safe distance, and edge padding.
- A deterministic portal candidate must lie inside the loaded bounds, respect both edge margins and the player-safe radius.
- Configuration must be rejected while asynchronous streaming is pending and must not mutate the existing director window.

## Limitations and next step

The 8 m / 4 m defaults are tunable initial values, not final balance validated through graphical play. The next runtime change must own the director's live tick and visual lifecycle, pin or retire the portal's chunk safely when streaming changes, connect portal_entered to the two-phase TransitionManager, and stage a destination runtime before consuming the one-use portal. Graphical and iPhone validation remain outstanding.
