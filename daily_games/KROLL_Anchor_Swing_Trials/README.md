# KROLL Anchor Swing Trials M0.1

A three-course 2D momentum platformer built with Godot 4.3+ and procedural drawing.

## Play

- A/D or Left/Right: pump horizontal momentum.
- Space: jump from a platform.
- E or click/tap in the play area: attach to the nearest anchor or release the tether.
- While tethered, keep moving to build a pendulum swing and release near the next platform.
- R: retry the current course before it is cleared.
- N: advance after clearing a course.
- C: restart the whole campaign.
- Touch UI: LEFT, RIGHT, JUMP, HOOK, RESET and NEXT.

## Courses

1. Dockyard Swing
2. Broken Gantry
3. Spiral Lift

Each course has a 90-second limit and up to three recoveries. Clearing a course awards a one-time score based on remaining time and falls. A cleared course cannot be restarted for duplicate points.

## Files

- `project.godot`: standalone Godot project.
- `main.tscn`, `main_root.tscn`: standalone and root Test Hub scenes.
- `main.gd`: player physics, tether controls, course layout and procedural drawing.
- `rules.gd`: deterministic anchor selection, rope constraint, horizontal motion and score helpers.
- `tests/rules_test.gd`: physics-rule edge cases.
- `tests/game_smoke_test.gd`: scene, tether, progression and score-once checks.

## Import

Open `daily_games/KROLL_Anchor_Swing_Trials/project.godot` in Godot Project Manager, or launch it from the root Survival Test Hub.

## Dependencies and limits

- Godot 4.3+.
- No external assets, add-ons, audio files or network dependency.
- The tether is a lightweight 2D constraint approximation, not a full rope solver.
- Cloud headless tests do not replace local rendered playtesting, GPU checks or physical iPhone input QA.
