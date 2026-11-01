# KROLL Reactor Balancer M0.1

A deterministic process-control puzzle for Godot 4.3+.

## Objective

Stabilize three chemical batches by tuning pH, temperature and pressure, then maintain all three target windows for four consecutive stir cycles.

Scenarios:
- Polymer Batch
- Cryo Solvent
- Ceramic Sinter

Each batch has 12 control actions. Four stable stir cycles award a 100-point batch bonus; partial cycles do not award reusable score. Safety interlocks fail the batch if pH, temperature or pressure leaves the safe operating envelope.

## Controls

- A / D: add acid / add base
- W / S: heat / cool
- V: vent pressure
- Space: stir one stability cycle
- R: reset the current batch before it is complete
- N: advance after a successful batch

All six process actions and campaign buttons support mouse and touch input.

## Files

- `project.godot`, `main.tscn`: standalone project.
- `main_root.tscn`: root-project entry scene.
- `main.gd`: UI, controls and campaign flow.
- `rules.gd`: deterministic process, safety and stabilization rules.
- `tests/rules_test.gd`: all three authored solutions, action limits, safety interlock and reset behavior.
- `tests/game_smoke_test.gd`: scene, controls, first batch completion and campaign progression.

No external assets, plugins, audio or network dependencies. The prototype has no campaign save, random chemistry or multiplayer.
