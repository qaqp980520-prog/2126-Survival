# KROLL Magnetic Maze M0.1

A deterministic 7x7 magnetic crate-routing puzzle built for Godot 4.3+.

## Import

Open daily_games/KROLL_Magnetic_Maze/project.godot in the Godot Project Manager.

No external assets, plugins, audio files, or network access are required.

## Controls

- WASD or arrow keys: move one tile; a blocked direction still turns the magnet.
- Space: pulse the aligned crate using the current mode.
- Tab: toggle PUSH / PULL.
- R: restart the current layout.
- N: advance to the next layout.
- The on-screen buttons support mouse and touch.

## Rules

The player can pulse the first crate visible along the facing row or column. PUSH moves it one tile away from the player; PULL moves it one tile toward the player. Walls block both movement and magnetic rays. A pulse consumes one charge only when the crate actually moves. A layout is solved when the crate reaches its green goal.

The three authored layouts are deterministic and have tested action sequences. The third layout uses all eight magnetic charges.

## Tests

- tests/rules_test.gd: all three authored solutions, push/pull behavior, blocked rays, invalid directions, blocked turning and charge accounting.
- tests/game_smoke_test.gd: real scene instantiation, named UI controls, button signal behavior, mode toggle, restart, movement, next layout and status label.

The canonical repository workflow runs project import, rules tests and the runtime smoke test on Godot 4.3.
