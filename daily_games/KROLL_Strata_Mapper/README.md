# KROLL Strata Mapper M0.1

A Godot 4 stratigraphy-ordering puzzle. Reconstruct three borehole columns at each of three survey sites by swapping adjacent samples. Each core must be arranged from oldest at the base to youngest at the surface, and the shared volcanic-ash marker must occupy the same target depth in all three cores.

## Gameplay

- Three sites: Delta Basin, Ridge Cut and Crater Shelf.
- Each site has three four-sample core columns.
- Select a sample and move it one layer up or down.
- Every adjacent swap costs one move; each site allows 18 swaps.
- Align the volcanic-ash marker at depth index 2 in all three cores.
- Solve all three cores to unlock the next survey site.
- Reset is available at any time.

## Controls

| Input | Action |
|---|---|
| Click / tap a sample | Select the sample |
| A / D or Left / Right | Select a core |
| W / S or Up / Down | Select a sample within the active core |
| Q / E | Move the selected sample up / down |
| Space | Verify the current core correlation |
| R | Reset the current site |
| N | Advance after a successful site |

The UI also exposes touch-friendly buttons for core selection, sample movement, verification, reset and next site.

## Run standalone

Open this folder in Godot 4.3 or newer, then run the main.tscn scene.

Commands:

- godot --headless --path daily_games/KROLL_Strata_Mapper --editor --quit
- godot --headless --path daily_games/KROLL_Strata_Mapper --script res://tests/rules_test.gd
- godot --headless --path daily_games/KROLL_Strata_Mapper --script res://tests/game_smoke_test.gd

## Root project integration

The root project launches this game from the Survival Test Hub. main_root.tscn points at the same main.gd while the rules loader selects the root resource path. No external assets or plugins are required.

## Validation status

- Rules tests include deterministic adjacent-swap solutions for all nine core columns and verify each site fits the 18-move budget.
- Runtime smoke test verifies scene instantiation, input methods, sample buttons, movement and reset.
- Exact Godot 4.3 cloud CI is pending until the feature PR is created.
- Local GUI/GPU/iPhone testing is not claimed.
