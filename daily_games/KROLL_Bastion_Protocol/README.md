# KROLL Bastion Protocol M0.1

A standalone Godot 4.3+ tower-defense arcade prototype. Place auto-firing turrets on the 10×8 grid, start three enemy waves, and keep the core alive.

## Controls
- Click a free non-path tile to place a turret (40 credits).
- Click START WAVE or press Space to begin the next wave.
- Press R or click RESTART to reset the mission.
- Kills grant 12 credits; protect the core's 10 lives through all three waves.

## Import
Open project.godot in Godot Project Manager. No external assets or add-ons are required; visuals are drawn procedurally.

## Validation
- tests/rules_test.gd: deterministic placement, economy, waves, targeting, escape, reward, and terminal-state checks.
- tests/game_smoke_test.gd: scene instantiation, placement, and wave-start smoke test.

The prototype uses simple grid-distance targeting and instant turret hits rather than projectile physics. GUI and iPhone device playtesting are not claimed by headless CI.
