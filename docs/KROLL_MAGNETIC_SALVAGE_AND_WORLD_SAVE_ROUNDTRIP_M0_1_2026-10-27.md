# Run 20 — KROLL Magnetic Salvage + active world save roundtrip

Date: 2026-10-27

## New mini-game
- Path: `daily_games/KROLL_Magnetic_Salvage/`
- Gameplay: continuous top-down drone movement, magnetic pulses pull nearby metal, debris hazards drain charge, collect six parts and extract at the dock within 75 seconds.
- Dependencies: Godot 4.3+, no addons or external assets.
- Import: open `daily_games/KROLL_Magnetic_Salvage/project.godot`.
- Tests: rules test and scene runtime smoke test. Exact-head Godot 4.3 CI Run #321 (40465124945) passed all 82 numbered validation steps; PR #72 merged as `fa4f680434fe7e961b1d6266a8a7357b9ef0e77a`. No local Godot executable is available in this run.

## Existing system integration
- New `tests/world_session_save_roundtrip_test.gd` instantiates the active `prototypes/BackroomsPortalPlayground.tscn`, uses its actual `SurvivalWorldBridge`, writes and reads the existing user:// save file, and verifies inventory/player-position roundtrip.
- Negative cases: unknown inventory item and non-finite player position must be rejected without changing the live inventory or player position.
- This improves integration coverage of the active prototype. It does not create or claim the missing `scripts/world.gd` production controller; M1.3 crop persistence patches remain unapplied.

## Validation / limits
- Exact-head validation: Run #321 succeeded, including Magnetic Salvage import/rules/runtime tests and active world save roundtrip integration (step #82). Post-merge main-push Run #322 (40465398061) also completed successfully on main SHA `fa4f680434fe7e961b1d6266a8a7357b9ef0e77a`; all 82 numbered validation steps passed.
- No local Godot GUI, GPU, or iPhone hardware test is claimed.
- Next: confirm Run #322 and update the final main-push result; then integrate the actual production world controller when its source is added to the repository.
