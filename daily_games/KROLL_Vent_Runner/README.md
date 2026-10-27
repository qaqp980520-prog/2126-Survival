# KROLL Vent Runner M0.1

A standalone Godot 4 side-view platforming escape prototype. Collect five power cells, avoid moving hazards, use air vents for boosted jumps, and reach the extraction hatch before the 90-second timer expires.

## Requirements and import

- Godot 4.3 or newer.
- No external assets, plugins, or network access required.
- Open `daily_games/KROLL_Vent_Runner/project.godot` with Godot Project Manager and run the main scene.

## Controls

- A/D or Left/Right: move.
- Space, W, or Up: jump.
- Touch/click the bottom LEFT, JUMP, RIGHT and RESET controls on a touch device.
- R or RESET: restart.

## Rules

- Five power cells are required to unlock extraction.
- Three lives; touching a moving hazard or falling into the shaft costs one life.
- The run ends after 90 seconds or when lives reach zero.
- Vents automatically launch the player when landed on, with a short cooldown.

## Validation

The canonical repository workflow imports this project and runs deterministic rules plus a headless scene smoke test. Headless CI does not replace manual graphical playtesting or iPhone hardware validation.
