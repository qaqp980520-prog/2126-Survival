# KROLL Magnetic Pinball — M0.1

A self-contained Godot 4.3+ arcade pinball prototype. All visuals are drawn by GDScript; there are no external asset or plugin dependencies.

## Run
1. Open this folder in Godot Project Manager.
2. Import the project if prompted.
3. Press F6/F5 or use Project > Run.

## Controls
- Space: launch the ball / launch the next ball.
- A or Left Arrow: left flipper.
- D or Right Arrow: right flipper.
- R: restart the table.

## Gameplay
Score 100 points for each bumper hit. The table starts with three balls. Letting a ball drain consumes one ball; the table ends at zero. The ball uses a deterministic custom 2D physics loop to keep the prototype and its rules tests simple and reproducible.

## Validation
- tests/rules_test.gd: geometry, bounce, flipper kick, scoring, and drain rules.
- tests/game_smoke_test.gd: scene loading, launch, simulation tick, and reset.
- The repository's Godot 4.3 CI is the engine validation source. A passing headless run is not a substitute for manual visual playtesting or iPhone device testing.

## Known limits
- Single-screen table, one ball at a time, no saved high score, sound, multiball, or touch controls.
- Collision/physics are custom approximations rather than Godot rigid-body simulation.
