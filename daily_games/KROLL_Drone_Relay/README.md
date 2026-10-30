# KROLL Drone Relay M0.1

A deterministic simultaneous multi-agent routing puzzle built with Godot 4.3+.

## Import

Open `project.godot` from Godot Project Manager. No external assets, plugins, audio files, or network services are required.

## Controls

- Select Drone A/B/C with the on-screen buttons or keys 1/2/3.
- Assign UP/LEFT/HOLD/RIGHT/DOWN with the on-screen command pad or WASD/arrow keys; H assigns HOLD.
- Press STEP ALL or Space to commit all three commands simultaneously.
- R restarts the current layout; N advances to the next layout.

## Rules

- The board is 6×6 and contains three independently routed drones.
- A successful cardinal move consumes one battery unit.
- Walls and board edges block movement without consuming battery.
- Same-destination collisions, swaps, and movement into an occupied stationary cell block the involved drone moves.
- Commands reset to HOLD after every committed tick.
- All three drones must reach their own goals before the nine-tick limit.

## Layouts

1. Parallel Approach
2. Cargo Detours
3. Offset Landing

## Validation

- `tests/rules_test.gd`: command validation, simultaneous movement, wall blocking, battery use, collision resolution, terminal states, and authored solutions.
- `tests/game_smoke_test.gd`: scene import, stable controls, button signals, drone selection, command assignment, stepping, restart, and next-layout behavior.

The authored solution checks are deterministic rule-model tests; the Godot runtime smoke test is reported separately by CI.
