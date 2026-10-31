# KROLL Knight Circuit M0.1

A self-contained 5×5 knight's-tour puzzle for Godot 4.3+.

## Objective
Visit all 25 squares exactly once. Every move must follow the chess knight's L-shaped movement (two squares along one axis and one along the other). The three authored circuits begin at different squares and each has a verified full tour.

## Controls
- Click or tap a square to attempt a move.
- Arrow keys move the selection cursor; Enter or Space attempts the selected square.
- U: undo
- H: show the next square from the built-in route (only while following its prefix)
- R: reset
- N: advance after completing all 25 squares

## Levels
1. Hangar Circuit — starts at A1.
2. Reactor Circuit — starts at C3.
3. Canyon Circuit — starts at E1.

## Import
Open daily_games/KROLL_Knight_Circuit/project.godot in Godot 4.3 or newer. No external assets, plugins, audio or network services are required. The game is registered in the root Survival Test Hub.

## Tests
- tests/rules_test.gd validates all 75 authored tour positions, legal knight transitions, no revisits, undo, reset, hints and progression.
- tests/game_smoke_test.gd instantiates the scene and emits real Hint, Undo and Reset button signals.
- Root SurvivalTestHub smoke test verifies the scene can be loaded from the main project.
