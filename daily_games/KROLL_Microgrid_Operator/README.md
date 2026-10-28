# KROLL Microgrid Operator M0.1

A compact Godot 4 resource-management arcade game. Keep the microgrid alive for eight demand cycles by balancing stored power, fuel, heat and stability.

## Controls

- 1: Generate power (power +10, fuel -2, heat +14).
- 2: Cool the reactor (heat -22, power +2).
- 3: Optimize the grid (stability +12, power +3, heat -5).
- Mouse or touch: select an action card.
- R: restart with a new deterministic demand seed.

Every accepted action consumes one cycle. Unserved demand reduces stability; thermal runaway or zero stability ends the shift.

## Import

Open project.godot with Godot 4.3 or newer. No external assets or add-ons are required.

## Validation

- tests/rules_test.gd: deterministic demand, valid/invalid actions, resource accounting, win/loss and thermal limit.
- tests/game_smoke_test.gd: scene startup, action-state mutation and reset.
- Root integration test: actual mineral mining through the active world's bridge, weight change, file save/load and inventory restoration.

This is a small prototype without audio, long-term campaign progress or mobile-device performance certification.
