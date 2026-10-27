# KROLL Orbit Warden M0.1

A compact top-down space-navigation arcade game for Godot 4.3+.

## Play

Open this folder's project.godot in Godot Project Manager and run the project.

- A / Left Arrow: turn left
- D / Right Arrow: turn right
- W / Up Arrow: thrust
- Space: activate a brief deflection shield (five-second cooldown)
- R: restart
- Touch controls: hold the bottom turn/thrust controls; tap SHIELD or RESET.

Recover all six energy cells before time expires. Avoid drifting asteroids; a shield pulse can deflect an impact, otherwise a collision costs one life. The ship and asteroids wrap around the playfield. There are no external assets, plugins, or downloaded dependencies.

## Files

- project.godot — standalone project settings
- main.tscn, main.gd — game scene and procedural visuals/arcade loop
- rules.gd — deterministic collection, life and timer rules
- tests/rules_test.gd — rule boundary tests
- tests/game_smoke_test.gd — scene startup, shield, win and restart smoke test

## Validation

The repository Godot 4.3 CI workflow imports the project, runs the rule tests, and launches the scene smoke test in headless mode. Do not treat a pending CI run as a pass. This is a small custom 2D arcade prototype rather than a rigid-body physics simulation; manual GUI, GPU-performance and iPhone-device playtests are separate outstanding checks.
