# KROLL Debris Skimmer M0.1

A standalone Godot 4.3+ top-down inertia arcade game. Pilot a small salvage craft through three debris fields, collect the required cargo with a short-range tractor pulse, and return to the dock beacon before hull integrity reaches zero.

## Campaign

- Ring Fragments: deliver 3 crates.
- Ice Drift: deliver 4 crates with three moving hazards.
- Station Graveyard: deliver 5 crates through the densest field.
- Each sector awards 100 points once after its delivery quota is met; the campaign cap is 300.
- Ship motion has thrust, reverse thrust, angular steering, frame-rate-scaled drag, a speed cap and wraparound field boundaries.
- Asteroids move continuously and reduce hull integrity on contact. A short invulnerability interval prevents one collision from draining the entire hull.
- Cargo must be collected within tractor range and delivered inside the dock radius.

## Controls

- W / Up: thrust.
- S / Down: reverse thrust.
- A / Left and D / Right: rotate.
- Space: tractor pulse.
- E / Enter: dock carried cargo.
- R: retry the current sector.
- N: advance after meeting the delivery quota.
- C: restart the campaign.
- Touch users can hold the steering/thrust controls, tap TRACTOR/DOCK, and use the on-screen R/N/C buttons to retry, advance and restart without a keyboard.

## Import

Open this folder's project.godot in Godot 4.3+ and run main.tscn. The project uses the Compatibility renderer and contains no external assets, plugins, network calls or save integration.

## Tests

- tests/rules_test.gd covers thrust, reverse thrust, steering, speed cap, drag, field wrapping, tractor/dock ranges and one-time rewards.
- tests/game_smoke_test.gd instantiates the real scene, uses its public gameplay actions to complete all three sectors, verifies touch controls and confirms the 300-point campaign cap.
