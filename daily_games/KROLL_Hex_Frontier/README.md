# KROLL Hex Frontier M0.1

A turn-based hex territory strategy game for Godot 4.3+.

## Objective

Expand from your blue headquarters and control ten of the nineteen hexes before the KROLL AI reaches the same target. Three deterministic resource layouts are included: Dockside, Ridge and Floodplain.

## Rules

- The board is an axial radius-two hex map (19 cells).
- A neutral hex can only be claimed if it touches one of your owned hexes.
- Claiming costs 1 energy.
- Upgrading an owned hex costs 2 energy and increases its future energy yield by one, up to +3.
- At the end of your turn the AI claims its best connected resource hex (or upgrades if no claim is available), then both sides receive income from owned hexes.
- Energy is capped at 9. First faction to control 10 hexes wins.
- Rejected actions do not mutate the input state.

## Controls

- C: select Claim
- U: select Upgrade
- Enter: end turn and resolve the AI response
- R: reset the current map
- N: next resource layout
- Mouse / touch: click a hex to perform the selected action

## Import

Open project.godot in Godot 4.3 or newer. The project has no external assets, plugins, audio or network dependency. It is also available from the 2126 Survival Test Hub.

## Files

- main.gd / main.tscn: hex board rendering, action bar and input
- rules.gd: deterministic territory, energy, upgrade and AI model
- tests/rules_test.gd: connectivity, action rejection, economy, AI and victory tests
- tests/game_smoke_test.gd: scene import, board action, AI response and UI smoke test
