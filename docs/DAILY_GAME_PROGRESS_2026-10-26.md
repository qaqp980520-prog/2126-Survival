# Daily Game Progress — 2026-10-26

## Mini-game: KROLL Orbital Convoy

- New arcade navigation loop: recover six cargo cells within 75 seconds while avoiding moving asteroids; three hull points.
- Controls: WASD/arrows; mouse or touch sets a glide target; R restarts.
- Project path: daily_games/KROLL_Orbital_Convoy. No external assets or add-ons.
- Godot 4.3 headless CI run #15 passed project import/parser, rules tests, and runtime smoke test on 2026-10-25T23:01:53Z (UTC).
- The local environment has no Godot executable; local checks were static only. Manual desktop/iPhone checks remain outstanding.

## 2126 Survival: BackroomsPortalDirector M0.1

- Added isolated rules module at systems/BackroomsPortalDirector.gd.
- Natural portal spawn countdown: 45–75 seconds; spawn position stays within configured world bounds and a minimum distance from the player.
- If no safe position is available, retry after five seconds; only one active portal; portal ID is single-use.
- On interaction, choose a destination from the Level 0–3 prototype pool without requiring a fixed next-level exit door.
- Added versioned save payload and atomic validation to avoid overwriting unrelated M1.3 world-save fields.
- Added a reusable 3D portal visual scene: emissive ring, translucent portal field, Area3D trigger, and E interaction prompt; it emits an entry signal but leaves level switching to the world controller.
- Added headless tests for timer, bounds/safe distance, retry, one-time consumption, save round-trip, and atomic rejection of invalid saves, plus a scene smoke test for node structure and coordinate mapping.

## M1.3 save bridge integration PR #14

- Added serialize_world_save and restore_world_save to SurvivalWorldBridge, preserving stamina, hotbar, player position, crops, world seed, and world state.
- Added a bridge integration test for legacy world-save round-trip, input immutability, and atomic rejection of invalid data.
- Runs #20–#23 remain in progress from earlier assert-only/frame-wait drafts; they are not counted as passes.
- Godot 4.3 CI run #24 passed on 2026-10-25T23:18:11Z (UTC), including the corrected bridge integration test, explicit inventory preload, all portal tests, both mini-game tests, and inventory save/adapter regressions.
- PR #14 merged to main at commit 3509c33777a3eecd68e48bcd49744718fc1b8264. Run #25 is a documentation-only revalidation and remains in progress.

## Integration and merge status

- PR #13 (KROLL Orbital Convoy + Backrooms portal director/visual) passed CI runs #15–#19 and merged to main at commit 02ed72e151d6d70339ec4048bf1c149f107908f2.
- PR #7 (inventory save validation) passed the combined CI suite and merged to main at commit 67c3bf20c70f926aab87cf6d075b83ebcfd0792a.
- KROLL Signal Sweep documentation PR #12 passed CI run #14 and merged at commit 3cbdd84893d3645b073cf2701c192a3a699ee622.
- PR #9 was closed as superseded by PR #14 to avoid duplicate adapter changes.

## Known limitations

- The 3D portal scene is not yet wired to M1.3 world.gd or level transitions; the world controller must consume the portal ID and own scene switching.
- Portals persist until consumed; no unconfirmed auto-despawn rule was added.
- RNG internal state is not saved, so future random outcomes after loading will not exactly replay.
- Destination pool is only Level 0–3; iPhone layout/touch and manual gameplay tests remain.
- The production M1.3 world.gd is not present in this repository; bridge-level save methods still need to be called by the actual world controller.
