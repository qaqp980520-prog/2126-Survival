# KROLL Airlock Operator M0.1

A deterministic turn-based airlock safety puzzle built with Godot 4.3+.

## Import
Open this folder's `project.godot` in Godot Project Manager. No external assets, audio, add-ons or network access are required.

## Objective
Transfer all three cargo pods from the exterior to the habitat. Equalize pressure to within 10 kPa before opening a door, never open both doors together, and finish with both doors sealed. The shift allows 28 successful actions.

## Controls
- Q / E: pressurize / vent by 50 kPa
- T: recycle oxygen (+20)
- 1 / 2 / 3: open outer / load pod / close outer
- 4 / 5 / 6: open inner / unload pod / close inner
- R: restart
- On-screen buttons support mouse and touch.

## Verification
The rules test covers door interlocks, pressure and oxygen limits, side-effect-free rejection, a complete three-pod solution and action-budget failure. The smoke test covers scene instantiation, button signals, transfers, restart and keyboard input.

## Limits
This is a deterministic training puzzle, not a physical gas simulation. Pressure and oxygen use discrete game units.
