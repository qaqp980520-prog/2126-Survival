# KROLL Pressure Circuit M0.1

A small Godot 4 pipe-routing puzzle. Rotate the cyan conduit tiles to connect the green IN port to the amber OUT port before using all 30 moves.

## Controls

- Click or tap a conduit tile to rotate it clockwise.
- Use WASD or arrow keys to move the selection.
- Press Space or Enter to rotate the selected conduit.
- Press R to generate a fresh puzzle.

## Import

Open \`project.godot\` from the Godot 4.3+ Project Manager. No external assets or add-ons are required.

## Validation

- \`tests/rules_test.gd\`: deterministic generation, rotation, connectivity, invalid moves and move-limit behavior.
- \`tests/game_smoke_test.gd\`: scene startup, input-driven state mutation, solved HUD state and reset.

The board is intentionally a compact prototype. It does not yet include multiple levels, save data, audio, or a level editor.
