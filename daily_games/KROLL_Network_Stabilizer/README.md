# KROLL Network Stabilizer M0.1

A standalone Godot 4.3+ relay-defense arcade prototype. Place auto-scanning relays on the 10×8 grid, start three packet waves, and keep the core alive.

## Controls
- Click a free non-path tile to place a relay (40 credits).
- Click START PACKET WAVE or press Space to begin the next wave.
- Press R or click RESTART to reset the mission.
- Kills grant 12 credits; keep the network stable's 10 integrity through all three waves.

## Import
Open project.godot in Godot Project Manager. No external assets or add-ons are required; visuals are drawn procedurally.

## Validation
- tests/rules_test.gd: deterministic placement, economy, waves, targeting, escape, reward, and terminal-state checks.
- tests/game_smoke_test.gd: scene instantiation, placement, and wave-start smoke test.

The prototype uses simple grid-distance targeting and instant relay hits rather than projectile physics. GUI and iPhone device playtesting are not claimed by headless CI.
