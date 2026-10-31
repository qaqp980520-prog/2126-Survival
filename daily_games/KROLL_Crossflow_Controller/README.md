# KROLL Crossflow Controller M0.1

A real-time traffic-management game for Godot 4.3+.

## Objective

Manage a four-way depot intersection. Deliver the required number of vehicles before the shift timer expires, while preventing any approach queue from overflowing.

## Controls

- Q / 1: request north-south green.
- E / 2: request east-west green.
- Space: pause or resume.
- R: reset the current shift.
- N: advance after reaching the delivery quota.
- On-screen buttons provide the same controls for mouse and touch.

## Rules

- Only one axis may be green at a time.
- Every signal change passes through an all-red clearance interval.
- Vehicles arrive on a deterministic schedule and wait in one of four approach queues.
- A green axis serves at most one queued vehicle per tick.
- Queue overflow or reaching the shift limit before the quota fails the shift.
- Three shifts: Depot Rush, Rain Shift and Freight Window.

## Import

Open `project.godot` in Godot 4.3 or newer. No external assets, plugins, packages or network services are required.

## Validation

- `tests/rules_test.gd`: all three authored signal strategies, clearance exclusivity, queue fairness, overflow and timeout.
- `tests/game_smoke_test.gd`: scene instantiation, signal transition, manual tick and reset.
- Root integration: Survival Test Hub and root smoke test.

## Limitations

M0.1 uses deterministic vehicle arrivals and abstract queue counters rather than animated individual cars. Campaign save, audio, procedural traffic and multiplayer are not included.
