# KROLL Deep Current Angler M0.1

A self-contained Godot 4 turn-based fishing game. Catch three fish within 30 valid actions while managing line tension.

## Import
Open `daily_games/KROLL_Deep_Current_Angler/project.godot` in Godot 4.3 or newer. No external assets, plugins, or network access are required.

## Controls
- C / CAST: cast a line
- W / WAIT: wait for a bite; waiting after the bite misses the fish
- H / HOOK: set the hook during the bite window
- R / REEL: tire the fish but raise line tension
- E / EASE: lower tension without reducing fish energy
- Backspace / RESET: restart the current seed
- N / NEXT TIDE: start a deterministic new seed

The fish energy and bite timing are derived from the seed and cast index. The rules are pure state transitions so they can be tested headlessly. The scene smoke test completes a full three-fish win route.

## Files
- `main.tscn`, `main.gd`: playable UI and keyboard/mouse/touch buttons
- `rules.gd`: deterministic state machine
- `tests/rules_test.gd`: invalid actions, bite timing, line break, missed bite, and a full win route
- `tests/game_smoke_test.gd`: live scene play-through
