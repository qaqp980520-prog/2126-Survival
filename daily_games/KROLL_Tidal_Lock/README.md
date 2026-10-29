# KROLL Tidal Lock M0.1

A deterministic four-chamber water-lock puzzle. Open gates, pump water levels, and move the vessel through the lock without crossing a pressure difference greater than one.

## Run

Open `daily_games/KROLL_Tidal_Lock/project.godot` in Godot 4.3 or newer and press Play. No external assets or add-ons are required.

## Controls

- A / Left: move vessel left
- D / Right: move vessel right
- Space: toggle the gate in front of the vessel
- W / Up: pump the current chamber one level higher
- S / Down: pump the current chamber one level lower
- R: restart the current layout
- N: next deterministic layout
- On-screen buttons support mouse and touch

## Rules

- Four chambers, three gates, water levels 0–3.
- A gate must be open before crossing it.
- Adjacent water levels may differ by at most one.
- Each successful action consumes one turn; the budget is 10.
- Three pump-energy units are available.
- Reach chamber 4 before the action budget is exhausted.

## Tests

- `tests/rules_test.gd`: deterministic seeds, pressure and gate guards, immutable rejected actions, pump limits, terminal lock, and solvability of all layouts.
- `tests/game_smoke_test.gd`: scene initialization, four panels, complete transit, restart and next layout.

The game is a compact puzzle prototype, not a simulation of real hydraulic engineering.
