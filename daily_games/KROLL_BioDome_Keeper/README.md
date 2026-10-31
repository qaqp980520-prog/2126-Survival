# KROLL BioDome Keeper M0.1

A deterministic six-day ecosystem restoration game built with Godot 4.3 or newer.

## Objective
Restore three KROLL biodomes by growing enough plants, preserving three species, releasing pollinators and keeping pests below each mission limit.

## Controls
- Click or tap a plot to select it.
- Plant Fern, Moss or Bloom: spend one seed and one action.
- Water: add up to two moisture to the selected plot.
- Compost: add up to two nutrients.
- Release Pollinators: increase the dome's pollinator coverage.
- Prune Pests: remove up to two pests from the selected plot.
- End Day: simulate growth, rain, seed spread and pest pressure.
- Reset Dome or Next Dome: restart or progress after meeting the targets.

Keyboard: 1/2/3 plant species, Q water, E compost, P pollinators, X prune, Enter end day, R reset, N next dome.

## Simulation
- 6×5 plots, three starter species and four actions per day.
- Rain arrives every third day.
- Two or more pollinators enable deterministic bloom-seed spread and suppress pest pressure.
- Each mission has a six-day target for plant count, species diversity, pollinator coverage and pest limits.
- Rules are deterministic and have no external assets or network dependencies.

## Import and test
Open this folder in Godot 4.3 or newer. The standalone project mirrors main.gd and rules.gd in the nested daily_games/KROLL_BioDome_Keeper path so it also loads from the repository root.

Run the Godot editor import, then tests/rules_test.gd and tests/game_smoke_test.gd in headless mode.
