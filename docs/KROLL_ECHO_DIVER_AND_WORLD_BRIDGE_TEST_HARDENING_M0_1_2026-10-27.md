# Run 19 — KROLL Echo Diver and World Bridge test hardening

Date: 2026-10-27

## New playable asset
- Path: daily_games/KROLL_Echo_Diver/
- Files: project.godot, main.tscn, main.gd, rules.gd, README.md, tests/rules_test.gd, tests/game_smoke_test.gd.
- Gameplay: 8×7 sonar-navigation board; collect three beacons, avoid hidden hazards, conserve 32 fuel, extract before 75 seconds. Four sonar pulses reveal hazards within Manhattan radius 3 for 2.4 seconds.
- Dependencies: Godot 4.3+, no addons or external art.
- Import: open daily_games/KROLL_Echo_Diver/project.godot in Godot Project Manager.
- Validation: exact-head Godot 4.3 CI Run #317 (40454156074) passed all 78 validation steps on candidate head cb07165259502bbc390bbe31c501e95f9cf29011; PR #70 merged as 66e18a1350bc81c42ffac86eb440c4eba739e4da. No local Godot binary was available, so no local engine/GUI/iPhone test is claimed.

## Existing system / test hardening
- tests/world_bridge_save_adapter_integration.gd now owns, stops and frees its watchdog Timer on all completion paths.
- Expanded legacy world-save bridge cases for invalid inventory container, unknown item, fractional/negative/out-of-range counts, invalid day and unsupported world version.
- Every rejected restore must preserve the previously loaded inventory snapshot; rejected serialization must not mutate the input world-save dictionary.
- The repository does not contain scripts/world.gd on main (fetch returned 404). The M1.3 save-validation files remain unapplied patch files, so they were not blindly applied to a nonexistent controller. This is an explicit integration boundary, not evidence that the active M1.3 world save is complete.

## Remaining
- Apply M1.3 validation to the actual world controller only after its source file is present in the repository.
- Integrate the shared inventory bridge into the actual world/pickup/mining scene, not just the test harness.
- Manual GUI and iPhone testing not performed.
