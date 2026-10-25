# Backrooms Portal Playground M0.1 — 2026-10-26

## Purpose

Provide a runnable 3D integration harness for the existing BackroomsPortalDirector, BackroomsPortalVisual, SurvivalWorldBridge, and SurvivalInventorySaveAdapter. The repository previously had director and visual smoke tests but no end-to-end scene showing portal spawning, E interaction, room switching, and world-save round-trip together.

## Assets

- Root project: project.godot
- Main scene: prototypes/BackroomsPortalPlayground.tscn
- World controller: prototypes/BackroomsPortalPlayground.gd
- Player controller: prototypes/BackroomsPlayerController.gd
- Integration test: tests/backrooms_portal_playground_test.gd
- Existing systems used: systems/BackroomsPortalDirector.gd, systems/BackroomsPortalVisual.tscn, systems/SurvivalWorldBridge.gd, systems/SurvivalInventorySaveAdapter.gd

## Controls

WASD / arrow keys move; Space jumps; E enters a portal. T forces a test portal, B returns to the surface for testing, G adds one berry, H drops one berry, F5 saves, and F9 loads.

The first portal appears after two seconds in this sandbox only. The production director still schedules normal portals after 45–75 seconds. Press T to force a test portal during development.

## Integration behavior

- Uses one BackroomsPortalDirector instance to schedule and consume portal IDs.
- Instantiates the shared portal visual from the director spawn result.
- E interaction consumes the active ID once and switches to a Level 0–3 room; no fixed next-level exit door is introduced.
- Reuses SurvivalWorldBridge for inventory changes and the existing save adapter for inventory payload validation.
- Save envelopes preserve existing legacy fields and add portal state, current level, in-Backrooms flag, and player position.
- Invalid portal state is validated before inventory or scene state is changed.
- Fixes portal visual alignment: the torus ring is vertical to match the portal plane, and the portal center sits one metre above the ground.

## Dependencies and import

Godot 4.3+, no external assets or plug-ins. Open the repository root in Godot Project Manager using project.godot. The root main scene is the portal playground; the daily Gravity Lander remains a separate project folder.

## Validation status

- Static review: pending CI for this branch.
- Local Godot executable is unavailable in this environment, so no local engine run is claimed.
- The PR workflow is expected to run the existing portal, inventory, bridge, mini-game, and new end-to-end integration suites.
- Manual visual inspection, collision feel, and iPhone touch/UI checks remain outstanding.

## Known limitations and next steps

- This is a standalone integration harness, not a claim that the missing production M1.3 world.gd has been migrated.
- Level 0–3 are compact colored room variants, not final Backrooms art or full canonical layouts.
- The debug B shortcut intentionally returns to the surface for testing; it is not a designed in-world exit.
- Portal RNG internal state is not saved by the current director schema.
- Next: run CI, inspect logs, fix failures, then consider wiring the same controller calls into the actual production world once that source is available.
