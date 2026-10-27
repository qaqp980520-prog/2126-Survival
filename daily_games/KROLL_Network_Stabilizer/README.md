# KROLL Network Stabilizer M0.1

A standalone Godot 4.3+ network-stabilization arcade prototype. Place scanning relays on the 10×8 grid, clear three waves of corrupted data packets, and keep the network stable.

## Controls
- Click a free non-path tile to place a relay (40 credits).
- Click START PACKET WAVE or press Space to begin the next wave.
- Press R or click RESTART to reset the mission.
- Each cleaned packet grants 12 credits; preserve the network's 10 integrity points through all three waves.

## Import
Open project.godot in Godot Project Manager. No external assets or add-ons are required; visuals are drawn procedurally.

## Validation
- tests/rules_test.gd: deterministic placement, economy, waves, targeting, escape, reward, and terminal-state checks.
- tests/game_smoke_test.gd: scene instantiation, placement, and wave-start smoke test.

The prototype uses simple grid-distance targeting and instant scan resolution rather than physical projectiles. GUI and iPhone device playtesting are not claimed by headless CI.
