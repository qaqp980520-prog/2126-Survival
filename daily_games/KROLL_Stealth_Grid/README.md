# KROLL Stealth Grid M0.1

A deterministic, turn-based stealth route puzzle for Godot 4.3+.

## Gameplay

Complete three station sectors. Collect every access key, then reach the exit while avoiding patrol contact and forward-facing line of sight. Guards advance one patrol node after every legal player move or wait action. Walls block vision. A blocked move does not consume a turn.

- Service Spine: one patrol and one access key.
- Split Relay: two patrols and one access key.
- Black Archive: two patrols and two access keys.
- Each sector awards 100 points once; campaign maximum is 300.
- A detected player fails the current sector. Retry preserves earlier rewards but cannot farm a completed sector.

## Controls

- WASD / arrow keys: move one tile.
- Space: wait one turn.
- R: restart current sector.
- N: advance after a successful sector.
- C: restart the campaign.
- On-screen direction buttons support mouse and touch.

## Import

Open project.godot in Godot 4.3 or newer and run main.tscn. The repository Test Hub opens main_root.tscn, whose script path is repository-root-relative.

## Dependencies and limits

No external assets, add-ons, network access or world-save integration. This is a deterministic grid puzzle, not a real-time stealth simulation. World-save schema is unchanged. Cloud Godot 4.3 CI is the engine-validation path; local rendered GUI/GPU and physical iPhone QA are separate.

## Tests

- tests/rules_test.gd: known safe routes, patrol visibility, invalid moves, retry and one-time rewards.
- tests/game_smoke_test.gd: standalone scene structure and controls.
