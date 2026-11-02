# KROLL Planetary Climate Lab M0.1

A three-world climate-balancing simulation. Adjust surface albedo and greenhouse retention, inspect the resulting equilibrium temperature, then submit a stable climate configuration.

## Missions

- **Nysa / Temperate Archive** — solar flux 1361 W/m²; target 289.3 K.
- **Vesper / Frost Relay** — solar flux 900 W/m²; target 243.3 K.
- **Orin / Equatorial Habitat** — solar flux 1800 W/m²; target 291.4 K.

Each planet awards 100 points once when its equilibrium temperature is within ±1.5 K of the target. Completed planets cannot be reset to farm score; the final campaign can be restarted explicitly.

## Model

The game uses a deliberately simplified global energy-balance equilibrium:

`T = [S(1-A) / (4 σ (1-G))]^(1/4)`

- `S`: incoming stellar flux (W/m²)
- `A`: planetary albedo (reflected fraction)
- `G`: simplified greenhouse-retention fraction
- `σ`: Stefan–Boltzmann constant

This is an educational arcade model, not a climate forecast. It omits atmosphere layers, clouds, oceans, circulation, seasonal geometry, feedbacks, weakly nonlinear chemistry and time-dependent heat storage.

## Controls

- Left / Right: decrease / increase albedo
- Up / Down: increase / decrease greenhouse retention
- Enter: simulate the current configuration
- R: restart the unfinished planet
- N: advance after a successful stabilization
- On-screen sliders and buttons support mouse and touch

## Import

- Standalone: open this folder in Godot 4.3+ and run `main.tscn`.
- Repository Test Hub: open the repository root project and launch **KROLL Planetary Climate Lab**; the root wrapper loads `main_root.tscn`.

No external assets, plugins, network services or runtime dependencies are required.
