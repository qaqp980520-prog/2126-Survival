# KROLL Signal Siphon M0.1

A standalone Godot 4.3+ pipe-rotation puzzle. Rotate conduit tiles to connect the fixed green source to the amber receiver before the 45-second timer expires.

## Controls
- Mouse click or touchscreen tap on a conduit: rotate clockwise.
- Source and receiver terminals are fixed.
- Press R after win/timeout to restart.

## Import
Open this folder in Godot Project Manager via `project.godot`. No external assets or plugins are required.

## Tests
- `godot --headless --path . --script res://tests/rules_test.gd`
- `godot --headless --path . --script res://tests/game_smoke_test.gd`

## Scope and limitations
The puzzle has one deterministic board and a 45-second timer. It has no generated level set, sound, save system, or iPhone device test yet. CI is the engine test source; no local Godot executable is available in the current work environment.
