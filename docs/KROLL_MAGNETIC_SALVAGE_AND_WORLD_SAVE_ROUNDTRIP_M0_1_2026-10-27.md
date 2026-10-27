# Run 20 — KROLL Magnetic Salvage + active world save roundtrip

Date: 2026-10-27

## New mini-game
- Path: `daily_games/KROLL_Magnetic_Salvage/`
- Gameplay: continuous top-down drone movement, magnetic pulses pull nearby metal, debris hazards drain charge, collect six parts and extract at the dock within 75 seconds.
- Dependencies: Godot 4.3+, no addons or external assets.
- Import: open `daily_games/KROLL_Magnetic_Salvage/project.godot`.
- Tests: rules test and scene runtime smoke test. Exact-head CI is required before merge; no local Godot executable is available in this run.

## Existing system integration
- New `tests/world_session_save_roundtrip_test.gd` instantiates the active `prototypes/BackroomsPortalPlayground.tscn`, uses its actual `SurvivalWorldBridge`, writes and reads the existing user:// save file, and verifies inventory/player-position roundtrip.
- Negative cases: unknown inventory item and non-finite player position must be rejected without changing the live inventory or player position.
- This improves integration coverage of the active prototype. It does not create or claim the missing `scripts/world.gd` production controller; M1.3 crop persistence patches remain unapplied.

## Validation / limits
- Godot 4.3 CI exact-head validation required.
- No local Godot GUI, GPU, or iPhone hardware test is claimed.
- Next: after the exact-head CI succeeds, consider merging; then integrate the actual production world controller when its source is added to the repository.
