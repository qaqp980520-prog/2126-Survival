# KROLL Orbit Warden M0.1

A compact top-down asteroid-survival arcade game for Godot 4.3+.

## Play

Open this folder's project.godot in Godot Project Manager and run the project.

- A / Left Arrow: turn left
- D / Right Arrow: turn right
- W / Up Arrow: thrust
- Space: fire
- R: restart
- Touch controls: hold the four bottom controls to turn or thrust; tap FIRE to shoot and RESET to restart.

Destroy 12 asteroids before time expires or the ship loses all three lives. The ship and asteroids wrap around the playfield. There are no external assets, plugins, or downloaded dependencies.

## Files

- project.godot — standalone project settings
- main.tscn, main.gd — game scene and procedural visuals/arcade loop
- rules.gd — deterministic score, life and timer rules
- tests/rules_test.gd — rule boundary tests
- tests/game_smoke_test.gd — scene startup, firing, win and restart smoke test

## Validation

The repository Godot 4.3 CI workflow imports the project, runs the rule tests, and launches the scene smoke test in headless mode. Do not treat a pending CI run as a pass. This is a small custom 2D arcade prototype rather than a rigid-body physics simulation; manual GUI, GPU-performance and iPhone-device playtests are separate outstanding checks.
