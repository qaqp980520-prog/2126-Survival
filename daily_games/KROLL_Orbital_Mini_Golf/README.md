# KROLL Orbital Mini Golf M0.1

A three-course, top-down mini-golf game built with Godot 4.3+ and procedural drawing only.

## Play
- Mouse/touch: press near the ball, drag backwards to aim, release to shoot.
- WASD or arrow keys: shoot in a cardinal direction.
- Space: shoot toward the current cup.
- R: restart the expedition.
- A course is cleared by sinking the ball at low speed in five strokes or fewer.
- Finish all three courses before the 90-second expedition timer expires.

## Files
- `project.godot`: standalone project settings.
- `main.tscn`, `main.gd`: scene, drawing, input, and simple 2D ball simulation.
- `rules.gd`: deterministic shot, friction, cup-capture, and bounce helpers.
- `tests/rules_test.gd`: rules regression tests.
- `tests/game_smoke_test.gd`: scene/state smoke test.

## Import
Open `daily_games/KROLL_Orbital_Mini_Golf/project.godot` in Godot Project Manager.

## Dependencies and limits
- No external assets or add-ons.
- The ball simulation is a small custom 2D approximation, not a rigid-body golf physics engine.
- Automated headless tests do not replace graphical playtesting or iPhone device validation.
