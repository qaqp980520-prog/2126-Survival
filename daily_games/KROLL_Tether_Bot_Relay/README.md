# KROLL Tether Bot Relay M0.1

A fictional maintenance drone navigates three artificial-gravity service routes using tether nodes and short thruster boosts. Built with Godot 4.3+ and procedural drawing.

## Play

- A/D or Left/Right: use thruster bursts to build horizontal drift.
- Space: boost from a platform.
- E or click/tap in the play area: attach to the nearest maintenance node or release the tether.
- While tethered, use controlled thruster bursts to build drift momentum, then release near the next service platform.
- R: retry the current course before it is cleared.
- N: advance after clearing a course.
- C: restart the whole campaign.
- Touch UI: LEFT, RIGHT, BOOST, TETHER, RESET and NEXT.

## Courses

1. Dockyard Relay
2. Broken Gantry
3. Spiral Service Shaft

Each course has a 90-second limit and up to three recoveries. Clearing a course awards a one-time score based on remaining time and falls. A cleared course cannot be restarted for duplicate points.

## Files

- `project.godot`: standalone Godot project.
- `main.tscn`, `main_root.tscn`: standalone and root Test Hub scenes.
- `main.gd`: service-drone physics, tether controls, course layout and procedural drawing.
- `rules.gd`: deterministic maintenance node selection, rope constraint, horizontal motion and score helpers.
- `tests/rules_test.gd`: physics-rule edge cases.
- `tests/game_smoke_test.gd`: scene, tether, progression and score-once checks.

## Import

Open `daily_games/KROLL_Tether_Bot_Relay/project.godot` in Godot Project Manager, or launch it from the root Survival Test Hub.

## Dependencies and limits

- Godot 4.3+.
- No external assets, add-ons, audio files or network dependency.
- The tether is a lightweight 2D constraint approximation, not a full rope solver.
- Cloud headless tests do not replace local rendered playtesting, GPU checks or physical iPhone input QA.
