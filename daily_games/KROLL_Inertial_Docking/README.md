# KROLL Inertial Docking M0.1

A deterministic top-down spacecraft docking trial for Godot 4.3+.

## Play

Open this folder as a standalone Godot project or launch the root-integrated scene from the Survival Test Hub.

- W / Up: main thruster
- S / Down: reverse thruster
- A / Left: rotate left
- D / Right: rotate right
- Space: retro-brake
- R: reset current berth
- N: advance after a successful dock

On-screen hold buttons support mouse and touch.

## Trials

1. Cargo Bay — fixed berth and open approach.
2. Rotating Ring — moving target and two debris hazards.
3. Debris Corridor — narrow central route with three hazards.

Docking requires all three conditions to remain true for one second: distance within 25 units, relative speed no greater than 15 units/s, and heading error within 0.32 radians.

## Reference-route validation

The rules suite also runs deterministic waypoint controllers against all three authored trials. This guards against scenario changes that accidentally make a berth unreachable within the fuel and time limits.

## Files

- `project.godot`, `main.tscn`: standalone project.
- `main_root.tscn`: root-project scene entry.
- `main.gd`: drawing, UI, keyboard and touch controls.
- `rules.gd`: pure deterministic flight and docking model.
- `tests/rules_test.gd`: physics, fuel, collision, boundary, docking rules and three reference-route reachability checks.
- `tests/game_smoke_test.gd`: scene and input integration smoke test.

No external assets or plugins are required. Physics are deliberately simplified; no orbital gravity, multiplayer, save data, audio or hardware performance claims are included.
