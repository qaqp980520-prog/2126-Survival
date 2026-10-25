# Daily Game Progress — 2026-10-26

## Mini-game: KROLL Orbital Convoy

- New arcade navigation loop: recover six cargo cells within 75 seconds while avoiding moving asteroids; three hull points.
- Controls: WASD/arrows; mouse or touch sets a glide target; R restarts.
- Project path: daily_games/KROLL_Orbital_Convoy. No external assets or add-ons.
- Automated rule tests and runtime smoke test are included in the Godot 4.3 CI workflow. The new feature branch CI result must be checked before claiming engine validation.
- The local environment has no Godot executable. Only static checks and ZIP integrity checks were run locally.

## 2126 Survival: BackroomsPortalDirector M0.1

- Added isolated rules module at systems/BackroomsPortalDirector.gd.
- Natural portal spawn countdown: 45–75 seconds; spawn position stays within configured world bounds and a minimum distance from the player.
- If no safe position is available, retry after five seconds; only one active portal; portal ID is single-use.
- On interaction, choose a destination from the Level 0–3 prototype pool without requiring a fixed next-level exit door.
- Added versioned save payload and atomic validation to avoid overwriting unrelated M1.3 world-save fields.
- Added headless tests for timer, bounds/safe distance, retry, one-time consumption, save round-trip, and atomic rejection of invalid saves.

## Integration and test status

- The Godot 4.3 CI workflow now imports and tests the new mini-game and runs the portal-director tests.
- Existing KROLL Signal Sweep documentation PR #12 passed Godot 4.3 CI run #14 and was merged to main at commit 3cbdd84893d3645b073cf2701c192a3a699ee622.
- New code is isolated on a feature branch; do not merge to main until the PR's CI is green.

## Known limitations

- The portal director is not yet wired to M1.3 world.gd, 3D portal nodes/colliders, or level transitions.
- Portals persist until consumed; no unconfirmed auto-despawn rule was added.
- RNG internal state is not saved, so future random outcomes after loading will not exactly replay.
- Destination pool is only Level 0–3; iPhone layout/touch and manual gameplay tests remain.
