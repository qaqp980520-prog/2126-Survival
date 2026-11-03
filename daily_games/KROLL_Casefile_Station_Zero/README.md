# KROLL Casefile: Station Zero M0.1

A deterministic deduction puzzle with three fictional station incidents. For each file, select one suspect and exactly two evidence records that jointly prove the connection. Each case has one authored solution and a three-strike limit.

## Campaign
- Airlock 03 — identify the source of a forged pressure-door override.
- Relay 04 — trace a navigation beacon route change.
- Archive 09 — identify who disabled a sealed archive cabinet.
- Each solved file awards 100 points once; maximum campaign score is 300.
- Three incorrect deductions fail the current file. Retry resets only that file's strikes and selections.

## Import and run
Open `project.godot` in Godot 4.3 or later and run `main.tscn`. The root Survival Test Hub opens `main_root.tscn`.

## Controls
- Mouse/touch: choose a suspect, choose two evidence cards, then Submit.
- 1–3: select a suspect.
- Q/W/E: toggle evidence records.
- Enter: submit deduction.
- Backspace: clear selection.
- N: advance after a solved file.
- R: retry a failed file.
- C: reset the campaign.

## Tests
From this folder:
- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/rules_test.gd`
- `godot --headless --path . --script res://tests/game_smoke_test.gd`

No external assets, plugins, network calls or world-save integration are required. This is a fictional authored deduction game, not a real incident-investigation tool.
