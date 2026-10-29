# KROLL Echo Survey — M0.1

A self-contained Godot 4.3+ turn-based sonar exploration game. Navigate an 8×8 seabed, reveal hidden terrain with sonar pings, recover three caches, and return to the extraction beacon before oxygen runs out.

## Run
1. Open this folder in Godot Project Manager.
2. Import the project if prompted.
3. Press F6/F5 or use Project > Run.

## Controls
- WASD / arrow keys: move one cell.
- P: sonar ping (2 battery, 1 oxygen).
- Click/touch the on-screen directional and PING buttons.
- R: restart the current layout.
- N: cycle the three fixed layouts.

## Rules
Movement and pings consume oxygen. A sonar ping reveals cells within Manhattan distance two. Entering an unscanned rock reveals it but blocks movement. Recover all three caches and return to S to win. Oxygen reaching zero fails the run. The three layouts are deterministic and require no external assets or plugins.

## Validation
- tests/rules_test.gd checks deterministic layouts, reachable caches, sonar reveal/cost, rock collisions, invalid moves, oxygen exhaustion, battery limits, complete extraction and terminal lockout.
- tests/game_smoke_test.gd checks scene load, ping, keyboard movement, reset, next layout and touch-capable controls.
- The shared repository CI runs Godot 4.3 headless import, rules and live-scene smoke tests. Manual GUI/GPU/iPhone hardware QA is separate and is not claimed by headless CI.
