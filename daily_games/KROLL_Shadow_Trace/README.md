# KROLL Shadow Trace M0.1

A compact turn-based stealth game for Godot 4.3+.

## Play

Open `project.godot` in Godot Project Manager and run the main scene.

- Move one tile with WASD or arrow keys.
- Space waits one turn while patrols move.
- Mouse/touch can move one adjacent tile by tapping it.
- Collect all three intel caches, then reach OUT.
- Guards patrol deterministic routes and see in straight lines up to three tiles; walls block sight.
- Three alert points or 40 turns ends the run.
- R restarts; N loads the next deterministic intel layout.

## Files

- `main.gd`: custom-drawn board and keyboard/mouse/touch input.
- `rules.gd`: deterministic, headless-testable state transitions.
- `tests/rules_test.gd`: movement, LOS, collection, wait, win/loss and terminal-state checks.
- `tests/game_smoke_test.gd`: scene startup and input-driven state smoke test.

No external assets, plugins, or network dependencies. This is a small prototype; it has no audio, save system, procedural maps, or local device QA evidence.
