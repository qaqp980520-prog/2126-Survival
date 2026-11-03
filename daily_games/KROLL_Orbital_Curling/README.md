# KROLL Orbital Curling M0.1

A small Godot 4.3+ precision-physics game. Each of three rounds gives the player three stones to place as close as possible to a target ring.

## Play

Open `project.godot` in Godot 4.3+ and run `main.tscn`.

- Click/touch the blue launch stone, drag in the opposite direction of the desired throw, then release.
- Longer drags increase launch power; the rules clamp it to a safe range.
- Stones collide with one another and bounce off the rink boundary with friction.
- After three throws, the nearest stone determines the round score: 30, 20, 10 or 0 points.
- Advance through three target layouts. A campaign score of 45 or more clears the mission.
- Use NEXT ROUND after a completed round; RESTART resets the campaign.

## Controls

Mouse and touch drag are supported. The UI buttons support mouse and touch. No keyboard aiming is required.

## Files

- `main.gd`: rink rendering, drag aiming, HUD and campaign controls.
- `rules.gd`: deterministic fixed-step motion, wall bounce, stone collision and scoring.
- `main.tscn`: standalone scene.
- `main_root.tscn`: repository Test Hub scene with root-relative script path.
- `tests/rules_test.gd`: validation, deterministic physics, collision separation, scoring and campaign progression.
- `tests/game_smoke_test.gd`: scene startup and live state smoke test.

No external assets, plugins, network services or external runtime dependencies. Local rendered GUI/GPU and physical iPhone QA are not claimed by headless CI.
