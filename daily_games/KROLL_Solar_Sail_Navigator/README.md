# KROLL Solar Sail Navigator M0.1

A turn-based trajectory game for Godot 4.3+. Trim a solar sail to steer light pressure, manage inertial drift, avoid debris and capture three relay beacons.

## Flight model

Each turn applies deterministic light-pressure acceleration. Sail trim is -30 to +30 degrees in 10-degree steps; deployment is 0–3. Normal acceleration is scaled by deployment and the square of the incidence cosine, then velocity is damped by 0.82. Missions 2 and 3 include deterministic solar gust variation. This is an educational arcade model, not a high-fidelity orbital propagator.

A relay is captured when the probe enters its target radius at or below the mission speed limit. Debris collision, leaving the 0–100 map, or reaching the turn limit ends the attempt.

## Controls

- Q / E: trim sail left / right
- W / S: increase / decrease sail deployment
- Space / Enter: advance one flight turn
- R: reset an incomplete or failed relay; after the final relay, restart the full expedition
- N: advance after a successful relay
- On-screen buttons: mouse and touch support

## Import

- Standalone: open this folder in Godot 4.3+ and run main.tscn.
- Repository Test Hub: open the repository root project and launch KROLL Solar Sail Navigator; the hub loads main_root.tscn.
- No external assets, plugins, audio, network or runtime services are required.

## Validation

- Rules tests cover deterministic flight plans, sail controls, coasting, invalid state, debris collision and timeout.
- Runtime smoke covers scene loading, mission progression, scoring integrity, terminal guards and campaign restart.
- Local GUI/GPU/device QA is separate from cloud headless validation.
